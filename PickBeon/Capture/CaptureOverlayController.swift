import AppKit
import SwiftUI
import ScreenCaptureKit

// AppKit 오버레이: 마우스 트래킹 + 직접 그리기.
// 스텝: [1]딤+힌트 → [2]mouseDown 힌트숨김 → [3]드래그 사각형+치수 → [4]mouseUp 고정+툴바 → [5]액션에서만 캡쳐.

enum CaptureAction {
    case copy, save, pin, ocr, translate
}

final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class CaptureOverlayController {
    let screen: NSScreen
    let display: SCDisplay
    let scale: CGFloat
    var onSelect: ((CGRect, SCDisplay, CGSize) -> Void)?
    var onPerform: ((CaptureAction, NSImage) -> Void)?
    var onCancel: (() -> Void)?
    var onReuse: (() -> Void)?

    private var window: KeyableWindow!
    private var overlay: OverlayView!
    private var toolbar: NSPanel!
    private var hintbar: NSPanel!
    private let hintSize = NSSize(width: 360, height: 40)
    private let toolbarSize = NSSize(width: 330, height: 42)

    init(screen: NSScreen, display: SCDisplay) {
        self.screen = screen
        self.display = display
        self.scale = screen.backingScaleFactor

        window = KeyableWindow(contentRect: screen.frame, styleMask: .borderless,
                               backing: .buffered, defer: false, screen: screen)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        overlay = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        overlay.onChange = { [weak self] _ in self?.layoutPanels() }
        overlay.onFreeze = { [weak self] _ in self?.beginCapture() }
        overlay.onCancel = { [weak self] in self?.onCancel?() }
        overlay.onReuse = { [weak self] in
            if self?.overlay.sel == nil { self?.onReuse?() }
        }
        overlay.onPrimary = { [weak self] in self?.perform(action: .translate) }
        window.contentView = overlay

        let tb = CaptureToolbarView(onAction: { [weak self] a in self?.perform(action: a) })
        toolbar = NSPanel(contentViewController: NSHostingController(rootView: tb))
        toolbar.styleMask = [.borderless, .nonactivatingPanel]
        toolbar.isOpaque = false
        toolbar.backgroundColor = .clear
        toolbar.hasShadow = true
        toolbar.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        toolbar.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toolbar.isReleasedWhenClosed = false
        toolbar.setContentSize(toolbarSize)

        let hb = HintBarView()
        hintbar = NSPanel(contentViewController: NSHostingController(rootView: hb))
        hintbar.styleMask = [.borderless, .nonactivatingPanel]
        hintbar.isOpaque = false
        hintbar.backgroundColor = .clear
        hintbar.hasShadow = true
        hintbar.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        hintbar.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hintbar.isReleasedWhenClosed = false
        hintbar.setContentSize(hintSize)
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        centerHint()
        hintbar.orderFrontRegardless()
    }

    private func centerHint() {
        hintbar.contentView?.layoutSubtreeIfNeeded()
        let sz = hintbar.frame.size
        hintbar.setFrameOrigin(NSPoint(x: screen.frame.midX - sz.width / 2,
                                      y: screen.frame.midY - sz.height / 2))
    }

    func close() {
        hintbar.orderOut(nil)
        toolbar.orderOut(nil)
        window.orderOut(nil)
    }

    private var frozenImage: NSImage?

    // mouseUp → 즉시 캡쳐 요청 (이미지는 비동기 도착)
    private func beginCapture() {
        guard let rect = overlay.sel, rect.width > 10, rect.height > 10 else { return }
        overlay.capturing = true
        overlay.needsDisplay = true
        layoutPanels()
        let tl = CGRect(x: rect.minX, y: overlay.bounds.height - rect.maxY,
                        width: rect.width, height: rect.height)
        onSelect?(tl, display, screen.frame.size)
    }

    // 캡쳐 완료 → 정지 이미지 + 툴바
    func freeze(_ image: NSImage) {
        frozenImage = image
        overlay.capturing = false
        overlay.frozenImage = image
        overlay.needsDisplay = true
        layoutPanels()
    }

    private func perform(action: CaptureAction) {
        guard let img = frozenImage,
              let rect = overlay.sel, rect.width > 10, rect.height > 10 else { return }
        onPerform?(action, img)
    }

    private func layoutPanels() {
        // 툴바는 정지 이미지 도착 후에만
        if frozenImage != nil,
           let r = overlay.sel, r.width > 10, r.height > 10 {
            hintbar.orderOut(nil)
            var x = window.frame.origin.x + r.midX - toolbarSize.width / 2
            var y = window.frame.origin.y + r.minY - toolbarSize.height - 12
            x = max(screen.frame.minX + 8, min(x, screen.frame.maxX - toolbarSize.width - 8))
            y = max(screen.frame.minY + 8, min(y, screen.frame.maxY - toolbarSize.height - 8))
            toolbar.setFrameOrigin(NSPoint(x: x, y: y))
            toolbar.orderFrontRegardless()
        } else if overlay.sel != nil {
            hintbar.orderOut(nil)
            toolbar.orderOut(nil)
        } else {
            toolbar.orderOut(nil)
            hintbar.orderFrontRegardless()
        }
    }
}

final class OverlayView: NSView {
    var onChange: ((CGRect?) -> Void)?
    var onFreeze: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var onReuse: (() -> Void)?
    var onPrimary: (() -> Void)?
    private(set) var sel: CGRect?
    var capturing = false
    var frozenImage: NSImage?
    private var anchor: CGPoint?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with e: NSEvent) {
        anchor = convert(e.locationInWindow, from: nil)
        sel = nil
        needsDisplay = true
        onChange?(nil)
    }

    override func mouseDragged(with e: NSEvent) {
        guard let a = anchor else { return }
        let p = convert(e.locationInWindow, from: nil)
        sel = CGRect(x: min(a.x, p.x), y: min(a.y, p.y),
                     width: abs(p.x - a.x), height: abs(p.y - a.y))
        needsDisplay = true
        onChange?(sel)
    }

    override func mouseUp(with e: NSEvent) {
        // 고정만. 캡쳐는 툴바 액션에서.
        if let r = sel, r.width > 10, r.height > 10 { onFreeze?(r) }
        else { sel = nil; needsDisplay = true; onChange?(nil) }
    }

    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 53: onCancel?()          // Esc
        case 15: onReuse?()           // R
        case 36, 76: onPrimary?()     // Enter (번역)
        default: super.keyDown(with: e)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSColor.black.withAlphaComponent(0.48)
        guard let r = sel, r.width > 4, r.height > 4 else {
            dim.setFill(); bounds.fill() // 중앙 문구 없음. 힌트바만.
            return
        }
        // 딤 + 선택 컷아웃
        let path = NSBezierPath(rect: bounds)
        path.append(NSBezierPath(rect: r))
        path.windingRule = .evenOdd
        dim.setFill(); path.fill()
        if let img = frozenImage {
            img.draw(in: r) // 정지 이미지
            NSColor.white.setStroke()
            let sp = NSBezierPath(rect: r); sp.lineWidth = 1.5; sp.stroke()
            return // 치수 pill 없음 (툴바가 대신)
        }
        // 테두리 + 핸들 (드래그 중에만)
        NSColor.white.setStroke()
        let sp = NSBezierPath(rect: r); sp.lineWidth = 1.5; sp.stroke()
        if frozenImage == nil {
            NSColor.white.setFill()
            for p in [NSPoint(x: r.minX, y: r.minY), NSPoint(x: r.maxX, y: r.minY),
                      NSPoint(x: r.minX, y: r.maxY), NSPoint(x: r.maxX, y: r.maxY)] {
                NSBezierPath(rect: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)).fill()
            }
        }
        if capturing {
            pill(String(localized: "캡쳐 중…"), at: r)
            return
        }
        // 치수 (박스 아래 pill, 크기만 — 드래그 중에만)
        pill("\(Int(r.width)) x \(Int(r.height)) px", at: r)
    }

    private func pill(_ text: String, at r: CGRect) {
        let label = text as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)]
        let s = label.size(withAttributes: attrs)
        let ly = max(8, r.minY - s.height - 10)
        label.draw(at: NSPoint(x: r.midX - s.width / 2, y: ly), withAttributes: attrs)
    }
}

struct HintBarView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text(String(localized: "드래그하여 선택")).font(.system(size: 12, weight: .semibold))
            Divider().frame(height: 16)
            Kbd("R"); Text(String(localized: "마지막 영역")).font(.system(size: 12)).foregroundColor(.secondary)
            Divider().frame(height: 16)
            Kbd("Esc"); Text(String(localized: "취소")).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .shadow(radius: 10)
    }
    private func Kbd(_ t: String) -> some View {
        Text(t).font(.system(size: 11, design: .monospaced)).foregroundColor(.primary)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.white.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2)))
    }
}

struct CaptureToolbarView: View {
    var onAction: (CaptureAction) -> Void
    var body: some View {
        HStack(spacing: 2) {
            TB(String(localized: "⧉ 복사"), .copy)
            TB(String(localized: "💾 저장"), .save)
            TB("📌", .pin)
            Divider().frame(height: 20)
            TB("OCR", .ocr)
            TB(String(localized: "번역"), .translate, primary: true)
        }
        .padding(5)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .shadow(radius: 12)
    }
    private func TB(_ t: String, _ a: CaptureAction, primary: Bool = false) -> some View {
        Button(t) { onAction(a) }
            .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(primary ? Color.accentColor : Color.white.opacity(0.08))
            .foregroundColor(primary ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .help(a == .translate ? String(localized: "Enter") : "")
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

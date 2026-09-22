import AppKit
import SwiftUI
import ScreenCaptureKit

// AppKit 오버레이: 마우스 트래킹 + 직접 그리기.
// 스텝: [1]딤+힌트 → [2]mouseDown → [3]드래그(치수+loupe) → [4]mouseUp 고정+툴바 → [5]액션에서만 캡쳐.
// v0.4: loupe(전체화면 1회 캡쳐), Option+드래그 즉시 번역, 프리즈 후 코너 핸들 리사이즈.

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
    private let hintSize = NSSize(width: 460, height: 40)
    private let toolbarSize = NSSize(width: 330, height: 42)
    private var pendingTranslate = false

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
        window.acceptsMouseMovedEvents = true

        overlay = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        overlay.onChange = { [weak self] _ in self?.layoutPanels() }
        overlay.onFreezeRequest = { [weak self] rect, option in self?.beginCapture(rect: rect, option: option) }
        overlay.onCancel = { [weak self] in self?.onCancel?() }
        overlay.onReuse = { [weak self] in
            if self?.overlay.sel == nil { self?.onReuse?() }
        }
        overlay.onPrimary = { [weak self] in self?.perform(action: .translate) }
        overlay.onResizeCommit = { [weak self] rect in self?.recropAfterResize(rect) }
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
        // loupe용 전체화면 1회 캡쳐 → 완료 후 오버레이 표시 (자체 윈도우 미포함)
        Task { @MainActor in
            let shot = await Self.grabFull(display: display, screen: screen)
            self.overlay.fullShot = shot
            self.window.makeKeyAndOrderFront(nil)
            self.centerHint()
            self.hintbar.orderFrontRegardless()
        }
    }

    private static func grabFull(display: SCDisplay, screen: NSScreen) async -> CGImage? {
        await withTaskGroup(of: CGImage?.self) { group in
            group.addTask {
                do {
                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    let config = SCStreamConfiguration()
                    config.width = display.width
                    config.height = display.height
                    config.showsCursor = false
                    return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                } catch { return nil }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 400_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
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

    // mouseUp → 즉시 캡쳐 요청. option 보관(프리즈 후 즉시 번역).
    private func beginCapture(rect: CGRect, option: Bool) {
        guard rect.width > 10, rect.height > 10 else { return }
        pendingTranslate = option
        overlay.capturing = true
        overlay.needsDisplay = true
        layoutPanels()
        let tl = CGRect(x: rect.minX, y: overlay.bounds.height - rect.maxY,
                        width: rect.width, height: rect.height)
        onSelect?(tl, display, screen.frame.size)
    }

    // 캡쳐 완료 → 정지 이미지 + 툴바 (+Option이면 즉시 번역)
    func freeze(_ image: NSImage) {
        frozenImage = image
        overlay.capturing = false
        overlay.frozenImage = image
        overlay.needsDisplay = true
        layoutPanels()
        if pendingTranslate {
            pendingTranslate = false
            perform(action: .translate)
        }
    }

    // 핸들 리사이즈 확정: loupe용 전체샷에서 로컬 crop (재캡쳐 없이 즉시)
    private func recropAfterResize(_ rect: CGRect) {
        guard rect.width > 10, rect.height > 10 else { return }
        if let cropped = overlay.cropFromShot(rect) {
            freeze(cropped)
        } else {
            beginCapture(rect: rect, option: false)
        }
    }

    private func perform(action: CaptureAction) {
        guard let img = frozenImage,
              let rect = overlay.sel, rect.width > 10, rect.height > 10 else { return }
        onPerform?(action, img)
    }

    private func layoutPanels() {
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
    var onFreezeRequest: ((CGRect, Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onReuse: (() -> Void)?
    var onPrimary: (() -> Void)?
    var onResizeCommit: ((CGRect) -> Void)?
    private(set) var sel: CGRect?
    var capturing = false
    var frozenImage: NSImage?
    var fullShot: CGImage? { didSet { needsDisplay = true } }
    private var anchor: CGPoint?
    private var cursor: CGPoint?
    private var mode: DragMode = .none
    private var resizeAnchor: CGPoint? // 리사이즈 기준(대각) 핸들 위치
    private let handleHit: CGFloat = 12

    private enum DragMode { case none, select, resizeTL, resizeTR, resizeBL, resizeBR }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        cursor = p
        // 프리즈 후: 코너 핸들 근처면 리사이즈
        if frozenImage != nil, let r = sel, let h = handleAt(p, in: r) {
            mode = h
            resizeAnchor = oppositeCorner(of: h, in: r)
            return
        }
        mode = .select
        anchor = p
        sel = nil
        needsDisplay = true
        onChange?(nil)
    }

    override func mouseDragged(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        cursor = p
        switch mode {
        case .select:
            guard let a = anchor else { return }
            sel = CGRect(x: min(a.x, p.x), y: min(a.y, p.y),
                         width: abs(p.x - a.x), height: abs(p.y - a.y))
        case .resizeTL, .resizeTR, .resizeBL, .resizeBR:
            guard let a = resizeAnchor else { return }
            sel = CGRect(x: min(a.x, p.x), y: min(a.y, p.y),
                         width: abs(p.x - a.x), height: abs(p.y - a.y))
        case .none:
            break
        }
        needsDisplay = true
        onChange?(sel)
    }

    override func mouseUp(with e: NSEvent) {
        let option = e.modifierFlags.contains(.option)
        defer { mode = .none; resizeAnchor = nil }
        switch mode {
        case .resizeTL, .resizeTR, .resizeBL, .resizeBR:
            if let r = sel, r.width > 10, r.height > 10 { onResizeCommit?(r) }
        case .select:
            if let r = sel, r.width > 10, r.height > 10 {
                onFreezeRequest?(r, option)
            } else {
                sel = nil; needsDisplay = true; onChange?(nil)
            }
        case .none:
            break
        }
    }

    override func mouseMoved(with e: NSEvent) {
        cursor = convert(e.locationInWindow, from: nil)
        if sel != nil && fullShot != nil { needsDisplay = true }
    }

    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 53: onCancel?()          // Esc
        case 15: onReuse?()           // R
        case 36, 76: onPrimary?()     // Enter (번역)
        default: super.keyDown(with: e)
        }
    }

    // 프리즈 후 리사이즈용: loupe용 전체샷에서 points→pixel crop
    func cropFromShot(_ rect: CGRect) -> NSImage? {
        guard let cg = fullShot else { return nil }
        let sx = CGFloat(cg.width) / bounds.width
        let sy = CGFloat(cg.height) / bounds.height
        // points(top-left 기준 뷰 좌표) → 이미지 픽셀 (CG top-left는 crop이 이해하는 CGRect임)
        var px = CGRect(x: rect.minX * sx, y: rect.minY * sy,
                        width: rect.width * sx, height: rect.height * sy)
        px = px.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard px.width > 4, px.height > 4, let cropped = cg.cropping(to: px.integral) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }

    // MARK: 핸들 히트/반대 모서리
    private func handleAt(_ p: CGPoint, in r: CGRect) -> DragMode? {
        let h = handleHit
        if abs(p.x - r.minX) <= h && abs(p.y - r.minY) <= h { return .resizeBL }
        if abs(p.x - r.maxX) <= h && abs(p.y - r.minY) <= h { return .resizeBR }
        if abs(p.x - r.minX) <= h && abs(p.y - r.maxY) <= h { return .resizeTL }
        if abs(p.x - r.maxX) <= h && abs(p.y - r.maxY) <= h { return .resizeTR }
        return nil
    }
    private func oppositeCorner(of m: DragMode, in r: CGRect) -> CGPoint {
        switch m {
        case .resizeTL: return CGPoint(x: r.maxX, y: r.minY)
        case .resizeTR: return CGPoint(x: r.minX, y: r.minY)
        case .resizeBL: return CGPoint(x: r.maxX, y: r.maxY)
        case .resizeBR: return CGPoint(x: r.minX, y: r.maxY)
        case .none, .select: return .zero
        }
    }

    // MARK: 그리기
    override func draw(_ dirtyRect: NSRect) {
        let dim = NSColor.black.withAlphaComponent(0.48)
        guard let r = sel, r.width > 4, r.height > 4 else {
            dim.setFill(); bounds.fill()
            return
        }
        let path = NSBezierPath(rect: bounds)
        path.append(NSBezierPath(rect: r))
        path.windingRule = .evenOdd
        dim.setFill(); path.fill()
        if let img = frozenImage {
            img.draw(in: r)
        }
        NSColor.white.setStroke()
        let sp = NSBezierPath(rect: r); sp.lineWidth = 1.5; sp.stroke()
        // 코너 핸들 (드래그 중 + 프리즈 후 모두)
        NSColor.white.setFill()
        for p in [NSPoint(x: r.minX, y: r.minY), NSPoint(x: r.maxX, y: r.minY),
                  NSPoint(x: r.minX, y: r.maxY), NSPoint(x: r.maxX, y: r.maxY)] {
            NSBezierPath(rect: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)).fill()
        }
        if capturing {
            pill(String(localized: "캡쳐 중…"), at: r)
            return
        }
        if frozenImage == nil {
            pill("\(Int(r.width)) x \(Int(r.height)) px", at: r)
        } else {
            // 프리즈 후: 치수 pill 상단 표시
            pillAtTop("\(Int(r.width)) x \(Int(r.height)) px", at: r)
        }
    }

    private func pill(_ text: String, at r: CGRect) {
        drawPill(text, origin: NSPoint(x: r.midX, y: max(8, r.minY - 26)), centered: true)
    }
    private func pillAtTop(_ text: String, at r: CGRect) {
        drawPill(text, origin: NSPoint(x: r.midX, y: r.maxY + 8), centered: true)
    }
    private func drawPill(_ text: String, origin: NSPoint, centered: Bool) {
        let label = text as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)]
        let s = label.size(withAttributes: attrs)
        let x = centered ? origin.x - s.width / 2 : origin.x
        label.draw(at: NSPoint(x: x, y: origin.y), withAttributes: attrs)
    }
}

struct HintBarView: View {
    var body: some View {
        HStack(spacing: 8) {
            Text(String(localized: "드래그하여 선택")).font(Theme.font(12, weight: .semibold))
            Divider().frame(height: 16)
            Kbd("⌥"); Text(String(localized: "번역")).font(Theme.font(12)).foregroundColor(.secondary)
            Divider().frame(height: 16)
            Kbd("R"); Text(String(localized: "마지막")).font(Theme.font(12)).foregroundColor(.secondary)
            Divider().frame(height: 16)
            Kbd("Esc"); Text(String(localized: "취소")).font(Theme.font(12)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.14)))
        .shadow(radius: 10)
    }
    private func Kbd(_ t: String) -> some View {
        Text(t).font(Theme.font(11, weight: .semibold, mono: true)).foregroundColor(.primary)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.white.opacity(0.14)).clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.2)))
    }
}

struct CaptureToolbarView: View {
    var onAction: (CaptureAction) -> Void
    @State private var hover: CaptureAction?

    var body: some View {
        HStack(spacing: 2) {
            TB(String(localized: "복사"), "doc.on.doc", .copy)
            TB(String(localized: "저장"), "square.and.arrow.down", .save)
            TB(String(localized: "핀"), "pin", .pin)
            Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 20)
            TB("OCR", "text.viewfinder", .ocr)
            TB(String(localized: "번역"), "character.bubble", .translate, primary: true)
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.14)))
        .shadow(radius: 12)
    }
    private func TB(_ t: String, _ icon: String, _ a: CaptureAction, primary: Bool = false) -> some View {
        Button { onAction(a) } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(t).font(Theme.font(12, weight: .semibold))
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(primary ? Theme.accent : (hover == a ? Color.white.opacity(0.16) : Color.white.opacity(0.08)))
            )
            .foregroundStyle(primary ? Color.white : Theme.textPrimary)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { h in hover = h ? a : nil }
        .animation(Theme.hoverFade, value: hover)
        .help(a == .translate ? String(localized: "Enter · Option+드래그") : "")
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

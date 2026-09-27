import AppKit
import SwiftUI
import ScreenCaptureKit

// AppKit 오버레이: 마우스 트래킹 + 직접 그리기.
// 스텝: [1]딤+힌트 → [2]mouseDown → [3]드래그(치수) → [4]mouseUp 고정+툴바 → [5]액션에서만 캡쳐.
// Same area: 이전 영역 프리즈 복원 → 핸들 조정 → 툴바 실행.

enum CaptureAction {
    case copy, save, pin, ocr, translate, ocrCopy
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
    /// GIF 모드: 힌트바 문구 변경 + 영역 선택 후 '녹화' 툴바 대기
    var gifMode = false
    /// A2: 영역 선택 → OCR → 클립보드 즉시 복사 (툴바 없음)
    var quickCopyMode = false
    /// B3: 창 클릭 캡쳐 모드 — 마우스 아래 창 하이라이트, 클릭 시 onWindowSelect
    var windowMode = false
    /// B3: 클릭할 창 목록 (CG 전역 top-left 프레임)
    var windowCandidates: [SCWindow] = []
    /// B3: 창 클릭 완료
    var onWindowSelect: ((SCWindow) -> Void)?
    /// GIF 영역 선택 완료 — 녹화 버튼 대기 (자동 시작 아님)
    private(set) var gifReady = false
    /// GIF 녹화 중: 선택 영역 유지 + REC 표시 (툴바/힌트 숨김)
    private(set) var gifRecording = false
    /// '녹화' 버튼 클릭 시 호출
    var onGifRecord: (() -> Void)?
    /// [P0-6] 녹화 중 Esc → 실제 중지. 과거엔 onCancel(오버레이만 닫기)로 가서
    /// 녹화가 계속되던 채 오버레이만 사라져 "멈춘 앱"처럼 보였다.
    var onStopGif: (() -> Void)?

    private var window: KeyableWindow!
    private var overlay: OverlayView!
    private var toolbar: NSPanel!
    private var hintbar: NSPanel!
    private let hintSize = NSSize(width: 520, height: 40)
    private var pendingTranslate = false
    /// Same area 복원용: top-left 좌표 (show() 완료 후 적용)
    var pendingRestore: CGRect?
    /// Same area 정보 (툴바 pill)
    var hasLastArea = false
    var lastAreaLabel = ""
    private var toolbarHost: NSHostingController<CaptureToolbarView>?

    init(screen: NSScreen, display: SCDisplay, gifMode: Bool = false,
         quickCopy: Bool = false, windowPick: Bool = false) {
        self.screen = screen
        self.display = display
        self.scale = screen.backingScaleFactor
        self.gifMode = gifMode
        self.quickCopyMode = quickCopy
        self.windowMode = windowPick

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
        overlay.windowMode = windowPick
        overlay.onChange = { [weak self] sel in
            // 새 선택 시작(sel=nil) 시 이전 프리즈 이미지 폐기 — 재드래그 늘림 방지
            if sel == nil {
                self?.frozenImage = nil
                self?.pendingTranslate = false
                self?.gifReady = false
            }
            self?.layoutPanels()
        }
        overlay.onFreezeRequest = { [weak self] rect, option in self?.beginCapture(rect: rect, option: option) }
        overlay.onCancel = { [weak self] in self?.onCancel?() }
        overlay.onReuse = { [weak self] in
            if self?.overlay.sel == nil { self?.onReuse?() }
        }
        overlay.onPrimary = { [weak self] in self?.perform(action: .translate) }
        overlay.onResizeCommit = { [weak self] rect in self?.recropAfterResize(rect) }
        overlay.onStopGif = { [weak self] in self?.onStopGif?() }
        overlay.onWindowClick = { [weak self] p in
            guard let self, self.windowMode else { return }
            // 로컬 bottom-left → Cocoa 전역 → CG 전역 top-left
            let cocoaX = self.screen.frame.minX + p.x
            let cocoaY = self.screen.frame.minY + p.y
            let primaryH = NSScreen.screens.first?.frame.maxY ?? 0
            let cgX = cocoaX
            let cgY = primaryH - cocoaY
            guard let hit = Self.topWindow(at: CGPoint(x: cgX, y: cgY),
                                           in: self.windowCandidates) else { return }
            self.onWindowSelect?(hit)
        }
        window.contentView = overlay

        let host = NSHostingController(rootView: makeToolbarRoot())
        toolbarHost = host
        toolbar = NSPanel(contentViewController: host)
        toolbar.styleMask = [.borderless, .nonactivatingPanel]
        toolbar.isOpaque = false
        toolbar.backgroundColor = .clear
        toolbar.hasShadow = true
        toolbar.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        toolbar.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toolbar.isReleasedWhenClosed = false
        toolbar.setContentSize(toolbarSize)

        let hb = HintBarView(gifMode: gifMode, quickCopy: quickCopyMode, windowPick: windowPick)
        hintbar = NSPanel(contentViewController: NSHostingController(rootView: hb))
        hintbar.isOpaque = false
        hintbar.backgroundColor = .clear
        hintbar.hasShadow = true
        hintbar.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        hintbar.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hintbar.isReleasedWhenClosed = false
        hintbar.setContentSize(hintSize)
    }

    func show() {
        // loupe/복원용 전체화면 1회 캡쳐 → 완료 후 오버레이 표시
        Task { @MainActor in
            let shot = await Self.grabFull(display: display, screen: screen)
            self.overlay.fullShot = shot
            self.window.makeKeyAndOrderFront(nil)
            if let restore = self.pendingRestore {
                self.pendingRestore = nil
                self.restoreSelection(restore)
            } else {
                self.centerHint()
                self.hintbar.orderFrontRegardless()
            }
        }
    }

    /// 이전 영역(top-left)을 프리즈 상태로 복원 — 확인/핸들 조정 후 툴바로 실행
    func restoreSelection(_ tl: CGRect) {
        guard tl.width > 10, tl.height > 10 else { return }
        let bl = CGRect(x: tl.minX,
                        y: overlay.bounds.height - tl.maxY,
                        width: tl.width, height: tl.height)
        overlay.modeIdle()
        overlay.sel = bl
        overlay.needsDisplay = true
        hintbar.orderOut(nil)
        if let img = overlay.cropFromShot(bl) {
            freeze(img)
        } else {
            beginCapture(rect: bl, option: false)
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
        gifRecording = false
        gifReady = false
        window.ignoresMouseEvents = false
        hintbar.orderOut(nil)
        toolbar.orderOut(nil)
        window.orderOut(nil)
    }

    private var toolbarSize: NSSize {
        if gifMode { return NSSize(width: 210, height: 42) }
        if quickCopyMode { return NSSize(width: 160, height: 42) }
        return NSSize(width: 420, height: 42)
    }

    /// B3: CG 전역 좌표에서 가장 위쪽 온스크린 윈도우 (자기 앱 제외)
    /// SCShareableContent.windows는 보통 front→back — 순회 첫 매칭이 최상단.
    static func topWindow(at p: CGPoint, in windows: [SCWindow]) -> SCWindow? {
        let own = ProcessInfo.processInfo.processIdentifier
        return windows.first { w in
            w.owningApplication?.processID != own
                && w.isOnScreen
                && w.frame.width > 40 && w.frame.height > 40
                && w.frame.contains(p)
        }
    }

    /// B3: 창 목록 갱신 후 오버레이에 후보 전달
    func setWindowCandidates(_ wins: [SCWindow]) {
        windowCandidates = wins
        overlay.windowCandidates = wins
        overlay.windowFrameCache = wins.compactMap { Self.localRect(of: $0, screen: screen) }
        overlay.needsDisplay = true
    }

    /// SCWindow.frame (CG top-left 전역) → 로컬 bottom-left (오버레이 좌표계)
    static func localRect(of w: SCWindow, screen: NSScreen) -> CGRect? {
        let primaryH = NSScreen.screens.first?.frame.maxY ?? 0
        let cocoaMinY = primaryH - w.frame.maxY
        let local = CGRect(x: w.frame.minX - screen.frame.minX,
                           y: cocoaMinY - screen.frame.minY,
                           width: w.frame.width, height: w.frame.height)
        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        let inter = local.intersection(bounds)
        guard !inter.isNull, inter.width > 8, inter.height > 8 else { return nil }
        return inter
    }

    /// GIF 영역 선택 완료 → '녹화' 툴바 표시 (스트림 시작 전)
    func enterGifReady() {
        guard !gifRecording else { return }
        gifReady = true
        overlay.capturing = false
        overlay.needsDisplay = true
        refreshToolbar()
        layoutPanels()
        FileLog.log("GIF 준비 완료 — 녹화 버튼 대기")
    }

    /// GIF 녹화 시작: rect는 top-left → overlay.sel은 bottom-left. 툴바/힌트 숨김, REC 표시.
    /// [P0-6] 녹화 중에는 오버레이가 마우스를 가로채지 않게 한다. GIF 는 "인터랙션을 담는" 기능이라
    /// 다른 앱을 조작할 수 있어야 한다. (과거엔 screenSaver 레벨 오버레이가 클릭을 전부 삼켰다)
    func beginGifRecording(rect: CGRect) {
        gifRecording = true
        gifReady = false
        pendingTranslate = false
        frozenImage = nil
        overlay.recordingGIF = true
        overlay.modeIdle()
        // onSelect payload = top-left, OverlayView.sel = bottom-left (restoreSelection와 동일 변환)
        overlay.sel = CGRect(x: rect.minX,
                             y: overlay.bounds.height - rect.maxY,
                             width: rect.width, height: rect.height)
        overlay.capturing = false
        overlay.needsDisplay = true
        hintbar.orderOut(nil)
        toolbar.orderOut(nil)
        // 렌더는 유지하되 히트 테스트만 끈다 → REC 테두리 표시 + 마우스/클릭은 하단 앱으로 통과
        window.ignoresMouseEvents = true
        if window.isVisible == false {
            window.makeKeyAndOrderFront(nil)
        }
        FileLog.log("GIF REC 표시 TL=\(rect) → BL=\(String(describing: overlay.sel)) 마우스통과 ON")
    }

    /// GIF 녹화 종료: REC 표시 해제 + 마우스 다시 차단 (오버레이 닫기는 AppCoordinator가 처리)
    func endGifRecording() {
        gifRecording = false
        gifReady = false
        overlay.recordingGIF = false
        overlay.gifElapsed = 0
        window.ignoresMouseEvents = false
        overlay.needsDisplay = true
    }

    /// HUD elapsed → REC pill 갱신
    func updateGifElapsed(_ t: TimeInterval) {
        guard gifRecording else { return }
        overlay.gifElapsed = t
        overlay.needsDisplay = true
    }

    private var frozenImage: NSImage?

    // mouseUp → 즉시 캡쳐 요청. option 보관(프리즈 후 즉시 번역).
    private func beginCapture(rect: CGRect, option: Bool) {
        guard !gifRecording else {
            FileLog.log("GIF 녹화 중 beginCapture 무시")
            return
        }
        guard rect.width > 10, rect.height > 10 else { return }
        // [FIX] A2 텍스트 바로 복사 모드에서는 Option 을 무시한다. 이전엔 Option+드래그 시
        // freeze() 가 .translate 로 먼저 실행되고 이어서 .ocrCopy 가 또 실행돼
        // "번역 + 텍스트복사" 가 이중 실행됐다.
        pendingTranslate = option && !quickCopyMode
        overlay.capturing = true
        gifReady = false
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
        if hasLastArea && !quickCopyMode { refreshToolbar() }
        layoutPanels()
        if pendingTranslate {
            pendingTranslate = false
            perform(action: .translate)
        }
    }

    /// A2: 프리즈 직후 OCR 복사 자동 실행 (사용자 툴바 선택 없음)
    func performQuickCopyIfReady() {
        guard quickCopyMode else { return }
        perform(action: .ocrCopy)
    }

    /// B3: 창 캡쳐 완료 → 프리즈 + 툴바 (sel = top-left)
    func freezeWindow(_ image: NSImage, tlRect: CGRect) {
        windowMode = false
        overlay.windowMode = false
        overlay.modeIdle()
        overlay.sel = CGRect(x: tlRect.minX,
                             y: overlay.bounds.height - tlRect.maxY,
                             width: tlRect.width, height: tlRect.height)
        hintbar.orderOut(nil)
        freeze(image)
        FileLog.log("창 프리즈 TL=\(tlRect)")
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

    private func makeToolbarRoot() -> CaptureToolbarView {
        CaptureToolbarView(
            gifMode: gifMode,
            quickCopy: quickCopyMode,
            onAction: { [weak self] a in self?.perform(action: a) },
            onRecord: { [weak self] in self?.onGifRecord?() },
            showSameArea: hasLastArea && !quickCopyMode && !gifMode,
            sameAreaSize: lastAreaLabel,
            onSameArea: { [weak self] in self?.onReuse?() }
        )
    }

    private func refreshToolbar() {
        toolbarHost?.rootView = makeToolbarRoot()
    }

    private func perform(action: CaptureAction) {
        guard !gifRecording, !gifReady else { return }
        guard let img = frozenImage,
              let rect = overlay.sel, rect.width > 10, rect.height > 10 else { return }
        onPerform?(action, img)
    }

    /// 녹화 중/프리즈/빈 상태 레이아웃 — GIF REC 모드에서는 툴바·힌트 모두 숨김
    private func layoutPanels() {
        if gifRecording {
            hintbar.orderOut(nil)
            toolbar.orderOut(nil)
            return
        }
        // GIF: 영역 선택 후 '녹화' 툴바 (프리즈 유무와 무관)
        if gifMode, gifReady, let r = overlay.sel, r.width > 10, r.height > 10 {
            hintbar.orderOut(nil)
            placeToolbar(for: r)
            return
        }
        // A2 quickCopy: 프리즈 직후 ocrCopy 수행 — 툴바 노출 금지
        if quickCopyMode {
            hintbar.orderOut(nil)
            toolbar.orderOut(nil)
            return
        }
        if frozenImage != nil,
           let r = overlay.sel, r.width > 10, r.height > 10 {
            hintbar.orderOut(nil)
            placeToolbar(for: r)
        } else if overlay.sel != nil {
            hintbar.orderOut(nil)
            toolbar.orderOut(nil)
        } else {
            toolbar.orderOut(nil)
            hintbar.orderFrontRegardless()
        }
    }

    /// [FIX] 툴바 배치 두 가지 결함 수정:
    ///  1) 중앙 정렬이 어긋남 — 가로 위치 계산에 하드코딩 `toolbarSize.width`(420)를 썼지만
    ///     실제 패널 너비는 SwiftUI 콘텐츠 크기(~320)였다. (420-320)/2 만큼 왼쪽으로 밀렸다.
    ///     → 패널 크기를 호스팅 뷰의 fittingSize 로 확정하고 그 값으로 중앙 정렬.
    ///  2) 선택 영역이 화면 하단에 닿으면 아래 공간이 없어, 아래 배치를 화면 바닥으로 clamp 해
    ///     **선택 영역 안쪽**에 겹쳐 그렸다. → 공간이 없으면 선택 영역 **위(외부)** 로 넘긴다.
    private func placeToolbar(for selRect: CGRect) {
        toolbarHost?.view.layoutSubtreeIfNeeded()
        let fit = toolbarHost?.view.fittingSize ?? .zero
        let w = fit.width > 1 ? fit.width : toolbarSize.width
        let h = fit.height > 1 ? fit.height : toolbarSize.height
        if abs(toolbar.frame.width - w) > 0.5 || abs(toolbar.frame.height - h) > 0.5 {
            toolbar.setContentSize(NSSize(width: w, height: h))
        }
        toolbar.layoutIfNeeded()
        // 배치는 방금 설정한 "실제 패널 frame" 으로 계산한다. (계산용 너비와 패널 너비가 다르면 다시 어긋난다)
        let pw = toolbar.frame.width > 1 ? toolbar.frame.width : w
        let ph = toolbar.frame.height > 1 ? toolbar.frame.height : h

        let gap: CGFloat = 12
        let margin: CGFloat = 8
        let sf = screen.frame

        // 가로 — 선택 영역 중앙 (실제 패널 너비 기준)
        var x = window.frame.origin.x + selRect.midX - pw / 2
        x = max(sf.minX + margin, min(x, sf.maxX - pw - margin))

        // 세로 — 아래 우선, 안 되면 위(선택 영역 외부), 그래도 안 되면 화면 안으로 clamp
        let below = selRect.minY - ph - gap
        let above = selRect.maxY + gap
        let y: CGFloat
        let mode: String
        if below >= sf.minY + margin {
            y = below; mode = "below"
        } else if above + ph <= sf.maxY - margin {
            y = above; mode = "above"
        } else {
            y = max(sf.minY + margin, min(below, sf.maxY - ph - margin)); mode = "clamp"
        }
        toolbar.setFrameOrigin(NSPoint(x: x, y: y))
        toolbar.orderFrontRegardless()
        FileLog.log("툴바 배치 sel=\(selRect) panel=\(Int(pw))x\(Int(ph)) pos=\(String(format:"%.0f,%.0f", x, y)) mode=\(mode)")
    }
}

final class OverlayView: NSView {
    var onChange: ((CGRect?) -> Void)?
    var onFreezeRequest: ((CGRect, Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onReuse: (() -> Void)?
    var onPrimary: (() -> Void)?
    var onResizeCommit: ((CGRect) -> Void)?
    var onWindowClick: ((CGPoint) -> Void)?
    /// [P0-6] 녹화 중 Esc → 실제 중지 (컨트롤러의 onStopGif 로 전달)
    var onStopGif: (() -> Void)?
    var sel: CGRect?
    var capturing = false
    var frozenImage: NSImage?
    /// GIF 녹화 중: 빨간 테두리 + REC pill
    var recordingGIF = false
    /// 녹화 경과 시간 (REC pill 표시용)
    var gifElapsed: TimeInterval = 0
    /// B3: 창 피킹 모드 — 하이라이트 + 클릭 캡쳐
    var windowMode = false
    var windowCandidates: [SCWindow] = []
    /// 로컬 bottom-left 프레임 캐시 (인덱스는 windowCandidates와 동일)
    var windowFrameCache: [CGRect?] = []
    var fullShot: CGImage? { didSet { needsDisplay = true } }
    private var anchor: CGPoint?
    private var cursor: CGPoint?
    private var mode: DragMode = .none
    private var resizeAnchor: CGPoint? // 리사이즈 기준(대각) 핸들 위치
    private let handleHit: CGFloat = 12

    private enum DragMode { case none, select, resizeTL, resizeTR, resizeBL, resizeBR }

    func modeIdle() {
        mode = .none
        resizeAnchor = nil
        anchor = nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with e: NSEvent) {
        guard !recordingGIF else { return }
        let p = convert(e.locationInWindow, from: nil)
        cursor = p
        if windowMode {
            // 클릭 창 선택은 mouseUp에서 처리 (드래그와 구분)
            mode = .select
            anchor = p
            return
        }
        // 프리즈 후: 코너 핸들 근처면 리사이즈
        if frozenImage != nil, let r = sel, let h = handleAt(p, in: r) {
            mode = h
            resizeAnchor = oppositeCorner(of: h, in: r)
            return
        }
        mode = .select
        anchor = p
        sel = nil
        // 이전 캡쳐 이미지를 새 영역에 늘려 그리지 않도록 제거
        frozenImage = nil
        needsDisplay = true
        onChange?(nil)
    }

    override func mouseDragged(with e: NSEvent) {
        guard !recordingGIF else { return }
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
        guard !recordingGIF else {
            mode = .none
            resizeAnchor = nil
            return
        }
        let option = e.modifierFlags.contains(.option)
        defer { mode = .none; resizeAnchor = nil; anchor = nil }
        if windowMode {
            onWindowClick?(convert(e.locationInWindow, from: nil))
            return
        }
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
        // 준비/드래그/리사이즈 중 크로스헤어 갱신
        if shouldDrawCrosshair || windowMode { needsDisplay = true }
    }

    /// 준비 상태·드래그·핸들 조정 중 — 프리즈 유휴/녹화 중에는 끔
    private var shouldDrawCrosshair: Bool {
        guard cursor != nil, !capturing, !recordingGIF else { return false }
        if frozenImage != nil && mode == .none { return false }
        return true
    }

    override func keyDown(with e: NSEvent) {
        if recordingGIF {
            // [P0-6] 녹화 중 Esc 는 중지. 오버레이만 닫으면 안 된다.
            if e.keyCode == 53 { onStopGif?() }
            return
        }
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
        if windowMode {
            // 창 피킹: 전체 딤 + 커서 아래 창 하이라이트 + 힌트
            dim.setFill(); bounds.fill()
            if let c = cursor, let idx = hoverWindowIndex(at: c), let fr = windowFrameCache[idx] {
                NSColor.systemBlue.withAlphaComponent(0.18).setFill()
                fr.fill()
                NSColor.systemBlue.setStroke()
                let bp = NSBezierPath(rect: fr); bp.lineWidth = 2.5; bp.stroke()
                // 하이라이트 안쪽 밝게
                NSColor.white.withAlphaComponent(0.06).setFill()
                fr.fill()
                drawCoord("Window \(Int(fr.width))×\(Int(fr.height))", near: c)
            }
            drawCrosshair()
            return
        }
        guard let r = sel, r.width > 4, r.height > 4 else {
            dim.setFill(); bounds.fill()
            drawCrosshair()
            return
        }
        let path = NSBezierPath(rect: bounds)
        path.append(NSBezierPath(rect: r))
        path.windingRule = .evenOdd
        dim.setFill(); path.fill()
        // 유휴(프리즈 완료) 때만 이미지 표시. 핸들/재드래그 중에는 라이브 화면(투명 구멍) 유지
        if let img = frozenImage, mode == .none, !recordingGIF {
            img.draw(in: r)
        }
        if recordingGIF {
            // 녹화 중: 빨간 테두리 + 코너 + REC pill (라이브 화면은 투명 구멍으로 노출)
            NSColor.systemRed.setStroke()
            let sp = NSBezierPath(rect: r); sp.lineWidth = 2; sp.stroke()
            NSColor.systemRed.setFill()
            for p in [NSPoint(x: r.minX, y: r.minY), NSPoint(x: r.maxX, y: r.minY),
                      NSPoint(x: r.minX, y: r.maxY), NSPoint(x: r.maxX, y: r.maxY)] {
                NSBezierPath(rect: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)).fill()
            }
            let time = String(format: "%.1fs", gifElapsed)
            pill("● REC  \(time)  \(Int(r.width))×\(Int(r.height))", at: r, color: NSColor.systemRed)
            return
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
        drawCrosshair()
        if frozenImage == nil {
            pill("\(Int(r.width)) x \(Int(r.height)) px", at: r)
        } else {
            // 프리즈 후: 치수 pill 상단 표시
            pillAtTop("\(Int(r.width)) x \(Int(r.height)) px", at: r)
        }
    }

    /// 커서를 가로지르는 십자 가이드 + 좌표 (시작점/치수 측정용)
    private func drawCrosshair() {
        guard shouldDrawCrosshair, let c = cursor else { return }
        // 세로/가로 전체선 — 다크 UI 위에서도 보이도록 이중 스트로크
        for (color, w) in [(NSColor.black.withAlphaComponent(0.55), CGFloat(1.5)),
                           (NSColor.white.withAlphaComponent(0.9), CGFloat(1.0))] {
            color.setStroke()
            let v = NSBezierPath()
            v.move(to: NSPoint(x: c.x, y: bounds.minY))
            v.line(to: NSPoint(x: c.x, y: bounds.maxY))
            v.lineWidth = w
            v.stroke()
            let h = NSBezierPath()
            h.move(to: NSPoint(x: bounds.minX, y: c.y))
            h.line(to: NSPoint(x: bounds.maxX, y: c.y))
            h.lineWidth = w
            h.stroke()
        }
        // 교점 마커
        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)).fill()
        // 좌표 (좌상단 원점 기준 — 스크린샷 툴 관례)
        let yTop = Int(bounds.height - c.y)
        drawCoord("\(Int(c.x)), \(yTop)", near: c)
    }

    /// B3: 커서 아래 창 인덱스 (로컬 프레임 포함 검사, front→back 첫 매칭)
    private func hoverWindowIndex(at p: CGPoint) -> Int? {
        for i in windowFrameCache.indices {
            if let fr = windowFrameCache[i], fr.contains(p) { return i }
        }
        return nil
    }

    private func drawCoord(_ text: String, near c: CGPoint) {
        let label = text as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.75)]
        let s = label.size(withAttributes: attrs)
        var x = c.x + 14
        var y = c.y + 14
        if x + s.width + 6 > bounds.maxX { x = c.x - 14 - s.width }
        if y + s.height + 6 > bounds.maxY { y = c.y - 14 - s.height }
        x = max(bounds.minX + 4, x)
        y = max(bounds.minY + 4, y)
        let bg = CGRect(x: x - 4, y: y - 2, width: s.width + 8, height: s.height + 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: bg, xRadius: 4, yRadius: 4).fill()
        label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    private func pill(_ text: String, at r: CGRect, color: NSColor? = nil) {
        // 아래(선택 영역 하단 밑)에 두고, 공간이 없으면 위(외부)로 넘긴다.
        // 과거엔 max(8, …) 하드 클램프로 화면 바닥에 붙여 선택 영역 안쪽에 겹쳐 그렸다.
        let h: CGFloat = 20
        let gap: CGFloat = 6
        let below = r.minY - h - gap
        let originY: CGFloat
        if below >= bounds.minY + 4 {
            originY = below
        } else {
            originY = min(r.maxY + gap, bounds.maxY - h)
        }
        drawPill(text, origin: NSPoint(x: r.midX, y: originY), centered: true, color: color)
    }

    private func pillAtTop(_ text: String, at r: CGRect) {
        // 선택 영역 위쪽 고정. 위 공간이 없으면 아래로 넘긴다.
        let h: CGFloat = 20
        let gap: CGFloat = 6
        let above = r.maxY + gap
        let originY: CGFloat = (above + h <= bounds.maxY - 4) ? above : max(bounds.minY + 4, r.minY - h - gap)
        drawPill(text, origin: NSPoint(x: r.midX, y: originY), centered: true, color: nil)
    }
    private func drawPill(_ text: String, origin: NSPoint, centered: Bool, color: NSColor?) {
        let label = text as NSString
        let bg = color ?? NSColor.black.withAlphaComponent(0.7)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: bg]
        let s = label.size(withAttributes: attrs)
        let x = centered ? origin.x - s.width / 2 : origin.x
        label.draw(at: NSPoint(x: x, y: origin.y), withAttributes: attrs)
    }
}

struct HintBarView: View {
    var gifMode = false
    var quickCopy = false
    var windowPick = false

    var body: some View {
        HStack(spacing: 8) {
            if windowPick {
                Text(String(localized: "창을 클릭")).font(Theme.font(12, weight: .semibold))
                Divider().frame(height: 16)
                Kbd("클릭"); Text(String(localized: "창 캡쳐")).font(Theme.font(12)).foregroundColor(.secondary)
                Divider().frame(height: 16)
                Kbd("Esc"); Text(String(localized: "취소")).font(Theme.font(12)).foregroundColor(.secondary)
            } else if quickCopy {
                Text(String(localized: "드래그하여 복사")).font(Theme.font(12, weight: .semibold))
                Divider().frame(height: 16)
                Kbd("드래그"); Text(String(localized: "OCR → 클립보드")).font(Theme.font(12)).foregroundColor(.secondary)
                Divider().frame(height: 16)
                Kbd("Esc"); Text(String(localized: "취소")).font(Theme.font(12)).foregroundColor(.secondary)
            } else if gifMode {
                Text(String(localized: "드래그하여 선택")).font(Theme.font(12, weight: .semibold))
                Divider().frame(height: 16)
                Kbd("드래그"); Text(String(localized: "영역 선택")).font(Theme.font(12)).foregroundColor(.secondary)
                Divider().frame(height: 16)
                Text(String(localized: "→ 녹화 버튼으로 시작")).font(Theme.font(12)).foregroundColor(.secondary)
                Divider().frame(height: 16)
                Kbd("Esc"); Text(String(localized: "취소")).font(Theme.font(12)).foregroundColor(.secondary)
            } else {
                Text(String(localized: "드래그하여 선택")).font(Theme.font(12, weight: .semibold))
                Divider().frame(height: 16)
                Kbd("⏎"); Text(String(localized: "번역")).font(Theme.font(12)).foregroundColor(.secondary)
                Divider().frame(height: 16)
                Kbd("⌥"); Text(String(localized: "즉시 번역")).font(Theme.font(12)).foregroundColor(.secondary)
                Divider().frame(height: 16)
                Kbd("R"); Text(String(localized: "이전 영역")).font(Theme.font(12)).foregroundColor(.secondary)
                Divider().frame(height: 16)
                Kbd("Esc"); Text(String(localized: "취소")).font(Theme.font(12)).foregroundColor(.secondary)
            }
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
    var gifMode = false
    var quickCopy = false
    var onAction: (CaptureAction) -> Void
    var onRecord: (() -> Void)? = nil
    var showSameArea: Bool = false
    var sameAreaSize: String = ""
    var onSameArea: (() -> Void)? = nil
    @State private var hover: CaptureAction?
    @State private var hoverSame = false
    @State private var hoverRecord = false

    var body: some View {
        if gifMode {
            gifRecordBar
        } else {
            captureBar
        }
    }

    // [P0-5 부수] quickCopy(⌥⌘C) 툴바는 도달 불가였다 — layoutPanels() 가 quickCopyMode 에서
    // 항상 toolbar.orderOut() 하므로 화면에 뜨지 않았다. 제거.

    /// GIF: 영역 확정 후 '녹화' 시작 (자동 시작 아님)
    private var gifRecordBar: some View {
        HStack(spacing: 8) {
            Button { onRecord?() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "record.circle").font(.system(size: 12, weight: .bold))
                    Text(String(localized: "녹화")).font(Theme.font(12, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(hoverRecord ? Color.red.opacity(0.95) : Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .contentShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .onHover { hoverRecord = $0 }
            Text(String(localized: "Esc 취소"))
                .font(Theme.font(11))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.14)))
        .shadow(radius: 12)
    }

    private var captureBar: some View {
        HStack(spacing: 2) {
            TB(String(localized: "번역"), "character.bubble", .translate, primary: true)
            Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 20)
            TB(String(localized: "복사"), "doc.on.doc", .copy)
            TB(String(localized: "저장"), "square.and.arrow.down", .save)
            TB(String(localized: "핀"), "pin", .pin)
            Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 20)
            TB("OCR", "text.viewfinder", .ocr)
            if showSameArea {
                sameAreaTB
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.14)))
        .shadow(radius: 12)
    }

    private var sameAreaTB: some View {
        Button { onSameArea?() } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.dashed").font(.system(size: 11, weight: .semibold))
                Text(sameAreaSize.isEmpty
                     ? String(localized: "Same area")
                     : String(localized: "Same area") + " " + sameAreaSize)
                    .font(Theme.font(12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(hoverSame ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
            )
            .foregroundStyle(Theme.textPrimary)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hoverSame = $0 }
        .animation(Theme.hoverFade, value: hoverSame)
        .help(String(localized: "이전 영역 복원"))
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

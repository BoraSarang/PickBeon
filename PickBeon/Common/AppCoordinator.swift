import AppKit
import SwiftUI
import SwiftData
import ScreenCaptureKit
import Combine

// 전역 라우터: 메뉴 클릭 → NSWindow 직접 띄우기 (SwiftUI 상태 토글 아님).
enum ResultMode {
    case translation, message, error
}

enum CardAction {
    case openScreenRecording, openLanguageSettings, retryTranslate, none
}

@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    @Published var latestText = ""
    @Published var latestTranslated = ""
    @Published var latestImage: NSImage?
    @Published var lastArea: CGRect = .zero
    @Published var cardMode: ResultMode = .translation
    @Published var cardAction: CardAction = .none
    @Published var cardTitle = ""
    @Published var cardBody = ""
    @Published var cardPinned = false
    /// 복사 결과 토스트 (에디터·카드가 공유). "무엇이 복사됐는지"를 사용자에게 명시한다.
    @Published var copyToast: String?

    let capture = ScreenCaptureManager()
    let ocr = OCRService()
    let translator = TranslationService()
    let clipboard = ClipboardStore()
    let permissions = PermissionService()

    private var overlayControllers: [CaptureOverlayController] = []
    private var escMonitor: Any?
    private var cardEscMonitor: Any?
    private var resultPanel: NSPanel?
    private var cardHideTimer: Timer?
    private var cardHovering = false
    private var editorWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var debugWindow: NSWindow?
    var dismissMenu: (() -> Void)?
    private var updateSheetWindow: NSWindow?

    // GIF 녹화 (A1)
    private var gifMode = false
    private var gifRecorder: GifRecorder?
    private var gifHudPanel: NSPanel?
    private var gifEscMonitor: Any?
    private var gifElapsedCancellable: AnyCancellable?
    /// 영역 선택 완료 → 녹화 버튼 대기 중인 좌표
    private var gifPendingRect: CGRect?
    private var gifPendingDisplay: SCDisplay?
    private var gifPendingPointSize: CGSize = .zero
    /// A2: 영역 선택 → OCR → 클립보드 즉시 복사
    private var quickCopyMode = false
    /// B3: 창 클릭 캡쳐
    private var windowPickMode = false

    func menuAction(_ work: @escaping () -> Void) {
        dismissMenu?()
        work()
    }

    // MARK: - 업데이트 시트 (설정 밖 — 전용 NSWindow)
    func showUpdateSheet() {
        guard let u = UpdateCenter.shared.availableUpdate else { return }
        if updateSheetWindow != nil {
            updateSheetWindow?.makeKeyAndOrderFront(nil)
            return
        }
        let root = UpdateAvailableSheet(
            tag: u.tag,
            htmlURL: u.htmlURL,
            notes: u.notes,
            onOpenRelease: {
                if let url = URL(string: u.htmlURL) { NSWorkspace.shared.open(url) }
            },
            onClose: { [weak self] in self?.updateSheetWindow?.close() }
        )
        let w = NSWindow(contentViewController: NSHostingController(rootView: root))
        w.styleMask = [.titled, .closable]
        w.title = String(localized: "업데이트")
        w.isReleasedWhenClosed = false
        w.center()
        WindowDropper.attach(to: w) { [weak self] in self?.updateSheetWindow = nil }
        updateSheetWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func openSettingsWindow() {
        showAppSettings()
    }
    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        modelContext = context
        clipboard.startPolling(context: context)
    }

    // MARK: - 첫 실행
    func checkPermissionsOnLaunch() {
        permissions.refresh()
        if !permissions.allOK { showOnboarding() }
        else { DebugLogger.shared.info(feature: "App", "권한 OK, 메뉴바 대기") }
    }

    func showOnboarding() {
        if onboardingWindow != nil { onboardingWindow?.makeKeyAndOrderFront(nil); return }
        permissions.onAllGranted = { [weak self] in self?.closeOnboarding() }
        permissions.startAutoCheck()
        let v = OnboardingView(coordinator: self).environmentObject(permissions)
        let w = NSWindow(contentViewController: NSHostingController(rootView: v))
        w.styleMask = [.titled, .closable]
        w.title = String(localized: "PickBeon 시작하기")
        w.setContentSize(NSSize(width: 360, height: 430))
        w.center(); w.isReleasedWhenClosed = false
        WindowDropper.attach(to: w) { [weak self] in
            self?.permissions.stopAutoCheck()
            self?.onboardingWindow = nil
        }
        onboardingWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    func closeOnboarding() {
        permissions.stopAutoCheck()
        onboardingWindow?.orderOut(nil)
        onboardingWindow = nil
    }

    // MARK: - 캡쳐 오버레이 (화면당 1 AppKit 윈도우)
    /// restoreArea: 이전 영역(top-left)을 주면 열자마자 그 자리에 프리즈로 복원 (Same area)
    /// gifMode: true면 영역 선택 후 '녹화' 버튼으로 시작 (자동 녹화 아님)
    /// quickCopy: true면 영역 선택 후 OCR → 클립보드 즉시 복사 (A2)
    /// windowPick: true면 창 클릭 캡쳐 모드 (B3)
    func startCapture(restoreArea: CGRect? = nil, gif: Bool = false,
                      quickCopy: Bool = false, windowPick: Bool = false) {
        // GIF 녹화 진행 중 일반 캡쳐 금지 (REC 오버레이 보호)
        if gifRecorder != nil {
            FileLog.log("GIF 진행 중 startCapture 무시 gif=\(gif)")
            return
        }
        guard permissions.screenRecordingOK else { showOnboarding(); return }
        closeOverlay()
        gifMode = gif
        quickCopyMode = quickCopy
        windowPickMode = windowPick
        gifPendingRect = nil
        gifPendingDisplay = nil
        NSApp.activate(ignoringOtherApps: true)
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            // Esc만. R/Enter는 key 윈도우의 keyDown이 처리 (이중 실행 방지).
            if e.keyCode == 53 { Task { @MainActor in self?.closeOverlay() }; return nil }
            return e
        }
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                DebugLogger.shared.info(feature: "Capture", "디스플레이 \(content.displays.count)개")
                // B3: 창 후보 (자기 앱 제외, 너무 작은 창 제외)
                let ownPID = ProcessInfo.processInfo.processIdentifier
                let wins = content.windows.filter {
                    $0.owningApplication?.processID != ownPID
                        && $0.isOnScreen
                        && $0.frame.width > 40 && $0.frame.height > 40
                }
                var shown = 0
                var pending: [(CaptureOverlayController, SCDisplay, NSScreen)] = []
                for screen in NSScreen.screens {
                    guard let id = screen.displayID,
                          let disp = content.displays.first(where: { $0.displayID == id }) else { continue }
                    let ctl = CaptureOverlayController(screen: screen, display: disp,
                                                       gifMode: gif, quickCopy: quickCopy,
                                                       windowPick: windowPick)
                    if windowPick {
                        ctl.setWindowCandidates(wins)
                        // self 는 싱글턴이라 강한 캡처가 안전하다(아래 나머지 클로저와 동일).
                        // ctl 만 weak — overlayControllers 가 소유자다.
                        ctl.onWindowSelect = { [weak ctl] win in
                            self.didSelectWindow(win, controller: ctl)
                        }
                    } else {
                        ctl.onSelect = { rect, display, pointSize in
                            self.didSelectArea(rect, display: display, pointSize: pointSize, controller: ctl)
                        }
                        ctl.onPerform = { action, image in
                            self.performAction(action, image: image)
                        }
                        ctl.onCancel = { self.closeOverlay() }
                        ctl.onReuse = { self.repeatFromOverlay() }
                        if gif {
                            ctl.onGifRecord = { [weak ctl] in
                                self.confirmGifRecord(controller: ctl)
                            }
                        }
                        if self.lastArea != .zero {
                            ctl.hasLastArea = true
                            ctl.lastAreaLabel = "\(Int(self.lastArea.width))×\(Int(self.lastArea.height))"
                        }
                    }
                    pending.append((ctl, disp, screen))
                    shown += 1
                }
                // Same area: show() 전에 복원 대상 1곳에 pendingRestore 지정
                var restorePlaced = false
                if let restore = restoreArea {
                    for (ctl, disp, _) in pending {
                        let match = (lastDisplay == nil) || (disp.displayID == lastDisplay?.displayID)
                        if match {
                            ctl.pendingRestore = restore
                            restorePlaced = true
                            break
                        }
                    }
                    if !restorePlaced, let first = pending.first {
                        first.0.pendingRestore = restore
                    }
                }
                for (ctl, _, _) in pending {
                    ctl.show()
                    overlayControllers.append(ctl)
                }
                DebugLogger.shared.info(feature: "Capture", "오버레이 \(shown)화면 표시")
                if shown == 0 {
                    FileLog.log("디스플레이 매칭 실패")
                    closeOverlay()
                    cardMode = .error
                    cardAction = .openScreenRecording
                    cardTitle = String(localized: "⚠ 캡쳐 실패")
                    cardBody = String(localized: "디스플레이를 찾지 못했습니다. 화면 기록 권한을 확인하세요.")
                    showResultCard()
                }
            } catch {
                FileLog.log("화면 목록 실패 \(error)")
                closeOverlay()
                cardMode = .error
                cardAction = .openScreenRecording
                cardTitle = String(localized: "⚠ 캡쳐 실패")
                cardBody = String(localized: "화면 기록 권한이 필요합니다.")
                showResultCard()
            }
        }
    }

    func closeOverlay() {
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        gifMode = false
        quickCopyMode = false
        windowPickMode = false
        gifPendingRect = nil
        gifPendingDisplay = nil
        overlayControllers.forEach { $0.close() }
        overlayControllers = []
    }

    private var lastDisplay: SCDisplay?
    private var lastPointSize: CGSize = .zero

    func didSelectArea(_ rect: CGRect, display: SCDisplay, pointSize: CGSize, controller: CaptureOverlayController) {
        // 녹화 중/대기 중 도착한 선택은 무시 (입력 가드 우회 방어)
        if gifRecorder != nil {
            FileLog.log("GIF 진행 중 onSelect 무시 rect=\(rect)")
            return
        }
        lastArea = rect
        lastDisplay = display
        lastPointSize = pointSize
        // GIF 모드: 프리즈 미리보기 + '녹화' 툴바 대기 (자동 시작 아님)
        if gifMode {
            gifPendingRect = rect
            gifPendingDisplay = display
            gifPendingPointSize = pointSize
            Task { [weak self, weak controller] in
                guard let self else { return }
                // 미리보기용 1회 캡쳐 (실패해도 녹화 버튼은 표시)
                if let img = try? await self.capture.captureArea(rect, display: display, pointSize: pointSize) {
                    self.latestImage = img
                    await MainActor.run {
                        guard self.overlayControllers.contains(where: { $0 === controller }) else { return }
                        controller?.freeze(img)
                    }
                }
                await MainActor.run {
                    guard self.overlayControllers.contains(where: { $0 === controller }) else { return }
                    controller?.enterGifReady()
                }
            }
            return
        }
        // A2 quickCopy: 프리즈 + 즉시 OCR 복사 (툴바 선택 없음)
        if quickCopyMode {
            Task { [weak self, weak controller] in
                guard let self else { return }
                do {
                    let img = try await self.capture.captureArea(rect, display: display, pointSize: pointSize)
                    self.latestImage = img
                    await MainActor.run {
                        guard self.overlayControllers.contains(where: { $0 === controller }) else { return }
                        controller?.freeze(img)
                        // freeze → perform(.ocrCopy)가 onPerform로 라우팅됨
                        controller?.performQuickCopyIfReady()
                    }
                } catch {
                    await MainActor.run {
                        self.closeOverlay()
                        self.cardMode = .error
                        self.cardTitle = String(localized: "⚠ 캡쳐 실패")
                        self.cardBody = String(localized: "화면 기록 권한이 필요합니다.")
                        self.showResultCard()
                    }
                }
            }
            return
        }
        // mouseUp 즉시 1회 캡쳐 → 정지 이미지로 교체 (오버레이 유지)
        Task { [weak self, weak controller] in
            guard let self else { return }
            do {
                let img = try await self.capture.captureArea(rect, display: display, pointSize: pointSize)
                self.latestImage = img
                await MainActor.run {
                    if self.overlayControllers.contains(where: { $0 === controller }) {
                        controller?.freeze(img)
                    }
                }
            } catch {
                DebugLogger.shared.error(code: "E-MAC-CAPTURE-0001", "캡쳐 실패 \(error)")
                await MainActor.run {
                    self.closeOverlay()
                    self.cardMode = .error
                    self.cardTitle = String(localized: "⚠ 캡쳐 실패")
                    self.cardBody = String(localized: "화면 기록 권한이 필요합니다.")
                    self.showResultCard()
                }
            }
        }
    }

    /// '녹화' 버튼 클릭 → REC 표시 + SCStream 시작
    private func confirmGifRecord(controller: CaptureOverlayController?) {
        guard gifRecorder == nil,
              let rect = gifPendingRect,
              let display = gifPendingDisplay else {
            FileLog.log("GIF 녹화 확인 조건 미충족")
            return
        }
        FileLog.log("GIF 녹화 버튼 클릭 rect=\(rect)")
        gifMode = false
        // 선택 Esc → 녹화 중에는 HUD Esc로 대체
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        let pointSize = gifPendingPointSize
        gifPendingRect = nil
        gifPendingDisplay = nil
        controller?.beginGifRecording(rect: rect)
        Task { [weak self] in
            await self?.startGifRecording(rect: rect, display: display, pointSize: pointSize)
        }
    }

    func performAction(_ action: CaptureAction, image: NSImage) {
        FileLog.log("액션 \(action)")
        closeOverlay()
        Task { await self.applyAction(action, image: image) }
    }

    func applyAction(_ action: CaptureAction, image: NSImage) async {
        switch action {
        case .copy:
            PasteboardService.write(image: image)
            cardMode = .message
            cardTitle = String(localized: "이미지 복사됨")
            cardBody = String(localized: "⌘V 로 붙여넣기")
            showResultCard()
        case .save:
            do {
                let url = try savePNG(image)
                cardMode = .message
                cardAction = .none
                cardTitle = String(localized: "저장됨")
                cardBody = url.path(percentEncoded: false)
                showResultCard()
            } catch {
                cardMode = .error
                cardAction = .none
                cardTitle = String(localized: "⚠ 저장 실패")
                cardBody = "\(error)"
                showResultCard()
            }
        case .pin:
            pinImage(image)
        case .ocr:
            latestImage = image
            do {
                let lines = try await ocr.recognize(image)
                latestText = lines.map(\.text).joined(separator: "\n")
            } catch {
                latestText = ""
            }
            showEditor()
        case .ocrCopy:
            latestImage = image
            do {
                let lines = try await ocr.recognize(image)
                let text = lines.map(\.text).joined(separator: "\n")
                guard !text.isEmpty else {
                    cardMode = .message
                    cardAction = .none
                    cardTitle = String(localized: "텍스트 없음")
                    cardBody = String(localized: "선택 영역에서 텍스트를 찾지 못했습니다.")
                    showResultCard()
                    return
                }
                latestText = text
                PasteboardService.write(text: text)
                if let ctx = modelContext {
                    clipboard.add(text: text, translated: "", context: ctx)
                }
                cardMode = .message
                cardAction = .none
                cardTitle = String(localized: "텍스트 복사됨")
                cardBody = String(format: "%d자 · ⌘V 로 붙여넣기", text.count)
                showResultCard()
                DebugLogger.shared.cache("A2 OCR 복사 \(text.count)자")
            } catch {
                cardMode = .error
                cardAction = .none
                cardTitle = String(localized: "⚠ OCR 실패")
                cardBody = String(localized: "다시 시도해주세요.")
                showResultCard()
            }
        case .translate:
            latestImage = image
            await runTranslate(img: image)
        }
    }

    /// Same area: 이전 영역을 오버레이에 복원 → 사용자가 확인/조정 후 툴바로 실행
    func repeatLastArea() {
        guard lastArea != .zero else { startCapture(); return }
        // 오버레이가 이미 떠 있으면 그 자리에 복원
        let onSame = overlayControllers.filter {
            lastDisplay == nil || $0.display.displayID == lastDisplay?.displayID
        }
        if !onSame.isEmpty {
            NSApp.activate(ignoringOtherApps: true)
            onSame.forEach { $0.restoreSelection(lastArea) }
            return
        }
        startCapture(restoreArea: lastArea)
    }

    /// 오버레이 R: 선택 없을 때 이전 영역 복원 (재캡쳐·재시작 아님)
    func repeatFromOverlay() {
        guard lastArea != .zero else { return }
        let targets = overlayControllers.filter {
            lastDisplay == nil || $0.display.displayID == lastDisplay?.displayID
        }
        (targets.isEmpty ? overlayControllers : targets).forEach {
            $0.restoreSelection(lastArea)
        }
    }

    // MARK: - 캡쳐 1회 → 액션 분기 (중복 캡쳐 금지, 분기는 applyAction 단일 경로)
    func captureAndRoute(area: CGRect, display: SCDisplay, pointSize: CGSize, action: CaptureAction) async {
        do {
            let img = try await capture.captureArea(area, display: display, pointSize: pointSize)
            latestImage = img
            await applyAction(action, image: img)
        } catch {
            DebugLogger.shared.error(code: "E-MAC-CAPTURE-0001", "캡쳐 실패 \(error)")
            cardMode = .error
            cardAction = .openScreenRecording
            cardTitle = String(localized: "⚠ 캡쳐 실패")
            cardBody = String(localized: "화면 기록 권한이 필요합니다.")
            showResultCard()
        }
    }

    func savePNG(_ img: NSImage) throws -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/PickBeon", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = dir.appendingPathComponent("Pick \(fmt.string(from: Date())).png")
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw PickBeonError.store("PNG 변환 실패", code: "E-MAC-STORE-0002")
        }
        try png.write(to: url)
        DebugLogger.shared.cache("저장됨 \(url.lastPathComponent)")
        return url
    }

    private var pinPanels: [NSPanel] = []
    func pinImage(_ img: NSImage) {
        let iv = NSImageView(image: img)
        iv.imageScaling = .scaleProportionallyUpOrDown
        let panel = NSPanel(contentViewController: NSViewController())
        panel.contentView = iv
        panel.styleMask = [.titled, .closable, .resizable]
        panel.title = "PickBeon Pin"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.setContentSize(NSSize(width: 400, height: 300))
        panel.center()
        panel.isReleasedWhenClosed = false
        WindowDropper.attach(to: panel) { [weak self, weak panel] in
            guard let panel else { return }
            self?.pinPanels.removeAll { $0 === panel }
        }
        pinPanels.append(panel)
        panel.orderFrontRegardless()
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func openLanguageSettings() {
        // 언어와 지역 Pane (Localization.appex legacy ID 확인됨)
        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization"),
           NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
    }

    private var settingsWindow: NSWindow?
    func showAppSettings() {
        dismissMenu?()
        if settingsWindow != nil { settingsWindow?.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        w.styleMask = [.titled, .closable, .resizable]
        w.title = String(localized: "PickBeon 설정")
        w.setContentSize(NSSize(width: 640, height: 520))
        w.center(); w.isReleasedWhenClosed = false
        WindowDropper.attach(to: w) { [weak self] in self?.settingsWindow = nil }
        settingsWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    // MARK: - GIF 녹화 (A1: ⌥⌘G)
    /// 상태: idle | selecting(오버레이) | starting(start 미완) | recording | stopping
    func startGifCapture() {
        // 1) 실제 녹화 중 → 중지
        if gifRecorder?.isRecording == true {
            FileLog.log("GIF 단축키: 녹화 중 → 중지")
            Task { await stopGifRecording() }
            return
        }
        // 2) 시작 대기/정지 진행 중 (start 미완료) → 취소
        if gifRecorder != nil {
            FileLog.log("GIF 단축키: 시작/정지 대기 → 취소")
            Task { await cancelPendingGif() }
            return
        }
        // 3) 영역 선택/녹화 대기 중 → 취소
        if gifMode || !overlayControllers.isEmpty {
            FileLog.log("GIF 단축키: 선택/대기 중 → 취소")
            closeOverlay()
            return
        }
        guard permissions.screenRecordingOK else { showOnboarding(); return }
        closeGifHud()
        startCapture(gif: true)
    }

    // MARK: - A2: 텍스트 바로 복사 (⌥⌘C) — TextSniper류
    func startQuickCopy() {
        guard permissions.screenRecordingOK else { showOnboarding(); return }
        if gifRecorder != nil { return }
        if quickCopyMode || !overlayControllers.isEmpty {
            closeOverlay()
            return
        }
        startCapture(quickCopy: true)
    }

    // MARK: - B3: 윈도우 캡쳐 (⌥⌘W)
    func startWindowCapture() {
        guard permissions.screenRecordingOK else { showOnboarding(); return }
        if gifRecorder != nil { return }
        if windowPickMode || !overlayControllers.isEmpty {
            closeOverlay()
            return
        }
        startCapture(windowPick: true)
    }

    /// B3: 창 클릭 → 캡쳐 → 프리즈 툴바 (번역/복사/저장 등)
    private func didSelectWindow(_ window: SCWindow, controller: CaptureOverlayController?) {
        guard let screen = controller?.screen else { return }
        FileLog.log("창 선택 \(window.title ?? "?") \(window.frame)")
        Task { [weak self, weak controller, weak window] in
            guard let self, let window else { return }
            do {
                let img = try await self.capture.captureWindow(window)
                let primaryH = NSScreen.screens.first?.frame.maxY ?? 0
                let cocoaMinY = primaryH - window.frame.maxY
                let localBL = CGRect(x: window.frame.minX - screen.frame.minX,
                                     y: cocoaMinY - screen.frame.minY,
                                     width: window.frame.width, height: window.frame.height)
                let tl = CGRect(x: localBL.minX,
                                y: screen.frame.height - localBL.maxY,
                                width: localBL.width, height: localBL.height)
                self.lastArea = tl
                self.lastDisplay = controller?.display
                self.lastPointSize = screen.frame.size
                self.latestImage = img
                await MainActor.run {
                    guard self.overlayControllers.contains(where: { $0 === controller }) else { return }
                    controller?.freezeWindow(img, tlRect: tl)
                }
            } catch {
                FileLog.log("창 캡쳐 실패 \(error)")
                await MainActor.run {
                    self.closeOverlay()
                    self.cardMode = .error
                    self.cardTitle = String(localized: "⚠ 창 캡쳐 실패")
                    self.cardBody = String(localized: "화면 기록 권한이 필요합니다.")
                    self.showResultCard()
                }
            }
        }
    }

    /// start 완료 전 취소: 진행 중이면 stop, 아니면 정리
    private func cancelPendingGif() async {
        if let rec = gifRecorder {
            if rec.isRecording {
                await rec.stop()
            } else {
                // start await 중 — stop 호출 시 didStop false → 정상 stop 경로로 종료 유도
                await rec.stop()
            }
        }
        clearGifElapsed()
        overlayControllers.forEach { $0.endGifRecording() }
        closeGifHud()
        closeOverlay()
        gifRecorder = nil
        gifPendingRect = nil
        gifPendingDisplay = nil
    }

    private func startGifRecording(rect: CGRect, display: SCDisplay, pointSize: CGSize) async {
        let s = AppSettings.shared
        let rec = GifRecorder.prepare(areaPoints: rect, pointSize: pointSize, display: display,
                                      fps: s.gifFps, maxSeconds: s.gifMaxSeconds)
        gifRecorder = rec
        FileLog.log("GIF 시작 진입 rect=\(rect) crop 준비")
        showGifHud(recorder: rec)
        observeGifElapsed(rec)
        do {
            try await rec.start(areaPoints: rect, pointSize: pointSize,
                                fps: s.gifFps, maxSeconds: s.gifMaxSeconds) { [weak self] result in
                Task { @MainActor in self?.finishGif(result) }
            }
            FileLog.log("GIF startCapture OK isRecording=\(rec.isRecording)")
        } catch {
            FileLog.log("GIF 시작 실패 \(error)")
            clearGifElapsed()
            overlayControllers.forEach { $0.endGifRecording() }
            closeGifHud()
            closeOverlay()
            gifRecorder = nil
            cardMode = .error
            cardAction = .openScreenRecording
            cardTitle = String(localized: "⚠ GIF 녹화 실패")
            cardBody = String(localized: "화면 기록 권한이 필요합니다.")
            showResultCard()
        }
    }

    /// HUD/REC pill 경과 시간 연동
    private func observeGifElapsed(_ rec: GifRecorder) {
        clearGifElapsed()
        gifElapsedCancellable = rec.$elapsed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] t in
                self?.overlayControllers.forEach { $0.updateGifElapsed(t) }
            }
    }

    private func clearGifElapsed() {
        gifElapsedCancellable?.cancel()
        gifElapsedCancellable = nil
    }

    private func stopGifRecording() async {
        await gifRecorder?.stop()
    }

    private func finishGif(_ result: Result<(data: Data, frames: Int, duration: TimeInterval), Error>) {
        FileLog.log("GIF finish 시작 frames/duration=\(String(describing: try? result.get().frames))/\(String(describing: try? result.get().duration))")
        // REC 표시만 해제 — closeOverlay는 아래에서 (finish 중 새 오버레이 실수 방지 위해 recorder 정리 후)
        clearGifElapsed()
        overlayControllers.forEach { $0.endGifRecording() }
        closeGifHud()
        gifRecorder = nil
        gifPendingRect = nil
        gifPendingDisplay = nil
        closeOverlay()
        switch result {
        case .success(let r):
            guard r.frames > 0 else {
                cardMode = .message
                cardAction = .none
                cardTitle = String(localized: "GIF 없음")
                cardBody = String(localized: "녹화된 프레임이 없습니다.")
                showResultCard()
                return
            }
            // 에디터/카드 썸네일: GIF 첫 프레임
            if let first = NSImage(data: r.data) {
                latestImage = first
            }
            var savedPath = ""
            do {
                let url = try saveGIF(r.data)
                savedPath = url.path(percentEncoded: false)
            } catch {
                FileLog.log("GIF 저장 실패 \(error)")
            }
            if AppSettings.shared.gifAutoCopy {
                // [P0-2] 과거엔 declareTypes+setData(GIF) 뒤에 writeObjects(파일URL)를 불러
                // GIF 바이트가 소실됐다(카드에는 "GIF 복사됨 · ⌘V" 라고 표시되고 있었음).
                // 파일 URL 과 GIF 데이터는 같은 item 의 서로 다른 타입으로 함께 실린다.
                PasteboardService.write(gifData: r.data, fileURL: savedPath.isEmpty ? nil : URL(fileURLWithPath: savedPath))
            }
            let fps = AppSettings.shared.gifFps
            let playSec = Double(r.frames) / Double(max(fps, 1))
            cardMode = .message
            cardAction = .none
            cardTitle = AppSettings.shared.gifAutoCopy
                ? String(localized: "GIF 복사됨")
                : String(localized: "GIF 저장됨")
            cardBody = String(format: "%d프레임 · %.1fs 녹화 · %.1fs 재생 · ",
                              r.frames, r.duration, playSec)
                + (AppSettings.shared.gifAutoCopy ? String(localized: "⌘V · ") : "")
                + savedPath
            showResultCard()
            DebugLogger.shared.cache("GIF 완료 \(r.frames) frames \(String(format: "%.1f", r.duration))s")
            // C1: 주요 프레임 OCR → 번역 (결과카드 갱신, 실패 시 GIF 카드 유지)
            if AppSettings.shared.gifFrameTranslate, let first = latestImage {
                Task { await translateGifKeyFrames(first) }
            }
        case .failure(let err):
            FileLog.log("GIF 실패 \(err)")
            cardMode = .error
            cardAction = .none
            cardTitle = String(localized: "⚠ GIF 실패")
            cardBody = String(localized: "다시 시도해주세요.")
            showResultCard()
        }
    }

    func saveGIF(_ data: Data) throws -> URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/PickBeon", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = dir.appendingPathComponent("Pick \(fmt.string(from: Date())).gif")
        try data.write(to: url)
        return url
    }

    // MARK: - C1: GIF 주요 프레임 OCR → 번역
    /// 첫 프레임(및 중간 프레임이 있으면 1장 추가)에서 텍스트를 뽑아 번역해 결과카드에 덧붙임.
    private func translateGifKeyFrames(_ image: NSImage) async {
        do {
            let lines = try await ocr.recognize(image)
            let text = lines.map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                FileLog.log("C1: GIF 프레임 텍스트 없음")
                return
            }
            let out = try await translator.translate(text, polite: AppSettings.shared.politeTone)
            latestText = text
            latestTranslated = out
            if let ctx = modelContext {
                clipboard.add(text: text, translated: out, context: ctx)
            }
            // GIF 카드가 아직 떠 있으면 번역 카드로 승격
            if cardMode == .message, cardTitle.contains("GIF") {
                cardMode = .translation
                cardAction = .none
                showResultCard()
            }
            FileLog.log("C1: GIF 프레임 번역 완료 \(text.count)자")
        } catch {
            FileLog.log("C1: GIF 프레임 번역 실패 \(error)")
        }
    }

    // MARK: GIF HUD (● REC + 중지)
    private func showGifHud(recorder: GifRecorder) {
        closeGifHud()
        let v = GifHudView(recorder: recorder) { [weak self] in
            Task { @MainActor in await self?.stopGifRecording() }
        }
        let host = NSHostingController(rootView: v)
        // fittingSize가 0/왜곡 나는 문제 회피 — 콘텐츠 보다 여유 있는 고정 크기
        host.view.frame = NSRect(x: 0, y: 0, width: 260, height: 52)
        host.view.autoresizingMask = []
        let panel = KeyableResultPanel(contentViewController: host)
        panel.styleMask = [.nonactivatingPanel, .borderless]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.setContentSize(NSSize(width: 260, height: 52))
        // 선택 영역 위 중앙 → 없으면 화면 상단 안쪽 (menu bar 아래 여백 확보)
        let target = screenForCapture() ?? NSScreen.main
        if let f = target?.visibleFrame, lastArea != .zero, let sf = target?.frame {
            let areaTopY = sf.maxY - lastArea.minY // Cocoa: 영역 위쪽
            let x = sf.minX + lastArea.midX - 130
            var y = areaTopY + 14
            if y + 52 > f.maxY { y = f.maxY - 52 - 12 }
            y = max(f.minY + 12, y)
            let clampedX = max(f.minX + 12, min(x, f.maxX - 260 - 12))
            panel.setFrameOrigin(NSPoint(x: clampedX, y: y))
        } else if let f = target?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - 130, y: f.maxY - 52 - 16))
        } else { panel.center() }
        gifHudPanel = panel
        panel.orderFrontRegardless()
        FileLog.log("GIF HUD 표시 origin=\(NSStringFromPoint(panel.frame.origin)) size=\(NSStringFromSize(panel.frame.size))")
        gifEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 {
                Task { @MainActor in await self?.stopGifRecording() }
                return nil
            }
            return e
        }
    }

    private func closeGifHud() {
        if let m = gifEscMonitor { NSEvent.removeMonitor(m); gifEscMonitor = nil }
        gifHudPanel?.orderOut(nil)
        gifHudPanel = nil
    }

    // MARK: - 파이프라인: OCR → 번역 → 복사 → afterCapture 라우팅
    func runTranslate(img: NSImage) async {
        FileLog.log("OCR 시작")
        do {
            let lines = try await ocr.recognize(img)
            let joined = lines.map(\.text).joined(separator: "\n")
            FileLog.log("OCR 완료 \(lines.count)줄")
            guard !joined.isEmpty else {
                cardMode = .message
                cardAction = .none
                cardTitle = String(localized: "텍스트 없음")
                cardBody = String(localized: "선택 영역에서 텍스트를 찾지 못했습니다.")
                showResultCard()
                return
            }
            latestText = joined
            FileLog.log("번역 시작: \(joined.prefix(30))")
            let out = try await translator.translate(joined, polite: AppSettings.shared.politeTone)
            FileLog.log("번역 완료")
            latestTranslated = out
            PasteboardService.write(text: out)
            if let ctx = modelContext {
                clipboard.add(text: joined, translated: out, context: ctx)
            }
            DebugLogger.shared.cache("파이프라인 완료, 클립보드 복사")
            routeAfterCapture()
        } catch PickBeonError.trans(_, let code) where code == "E-MAC-TRANS-0005" {
            FileLog.log("번역 언어팩 미설치")
            cardMode = .error
            cardAction = .openLanguageSettings
            cardTitle = String(localized: "⚠ 번역 언어팩 필요")
            cardBody = String(localized: "시스템 설정에서 번역 언어를 다운로드한 뒤 다시 시도하세요.")
            showResultCard()
        } catch {
            FileLog.log("번역 실패 \(error)")
            DebugLogger.shared.error(code: "E-MAC-TRANS-0001", "번역 실패 \(error)")
            cardMode = .error
            cardAction = .retryTranslate
            cardTitle = String(localized: "⚠ 번역 실패")
            cardBody = String(localized: "다시 시도해주세요.")
            showResultCard()
        }
    }

    /// 설정: afterCapture (card=번역카드 / editor=에디터 / clipboard=토스트만)
    /// nearMouse: 선택번역 등 마우스 근처에 카드를 띄울 때 드래그 직후 위치
    private func routeAfterCapture(nearMouse: CGPoint? = nil) {
        switch AppSettings.shared.afterCapture {
        case "editor":
            showEditor()
        case "clipboard":
            cardMode = .message
            cardAction = .none
            cardTitle = String(localized: "번역 복사됨")
            cardBody = String(localized: "⌘V 로 붙여넣기")
            showResultCard(nearMouse: nearMouse)
        default:
            cardMode = .translation
            cardAction = .none
            showResultCard(nearMouse: nearMouse)
        }
    }

    // MARK: - 결과 카드 (시그니처 330px, 3초 자동숨김·핀 유지)
    /// nearMouse: 선택번역(마우스 근처). nil이면 lastArea 캡쳐 영역 오른쪽 → 그 외 우상단.
    func showResultCard(nearMouse: CGPoint? = nil) {
        closeResultCard()
        cardPinned = false
        cardHovering = false
        let v = ResultCardView(coordinator: self)
        let host = NSHostingController(rootView: v)
        let panel = KeyableResultPanel(contentViewController: host)
        panel.styleMask = [.nonactivatingPanel, .titled, .closable, .fullSizeContentView]
        panel.title = "PickBeon"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        // 단축키로 비활성 상태에서 띄울 때도 카드 유지 (기본 true면 deactivate 시 숨음)
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        host.view.layoutSubtreeIfNeeded()
        let fit = host.view.fittingSize
        let w: CGFloat = 346
        let h = min(520, max(180, fit.height))
        panel.setContentSize(NSSize(width: w, height: h))
        placeCard(panel, w: w, h: h, nearMouse: nearMouse)
        panel.isReleasedWhenClosed = false
        WindowDropper.attach(to: panel) { [weak self] in
            self?.resultPanel = nil
            self?.cancelCardTimer()
            if let m = self?.cardEscMonitor { NSEvent.removeMonitor(m); self?.cardEscMonitor = nil }
        }
        resultPanel = panel
        panel.orderFrontRegardless()
        // Esc로 닫기
        cardEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 { Task { @MainActor in self?.closeResultCard() }; return nil }
            return e
        }
        scheduleCardHide()
    }

    /// 배치 우선순위: 마우스 근처 → 캡쳐 영역 오른쪽(모자라면 왼쪽) → 우상단. 항상 visibleFrame 안.
    private func placeCard(_ panel: NSPanel, w: CGFloat, h: CGFloat, nearMouse: CGPoint?) {
        let margin: CGFloat = 12
        let gap: CGFloat = 16
        let clamp: (CGRect, inout CGFloat, inout CGFloat) -> Void = { f, x, y in
            x = min(max(x, f.minX + margin), f.maxX - w - margin)
            y = min(max(y, f.minY + margin), f.maxY - h - margin)
        }

        // 1) 선택번역: 마우스 근처
        if let mouse = nearMouse {
            let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
            if let f = screen?.visibleFrame {
                var x = mouse.x + gap
                var y = mouse.y - h / 2
                if x + w > f.maxX - margin { x = mouse.x - w - gap }
                clamp(f, &x, &y)
                panel.setFrameOrigin(NSPoint(x: x, y: y))
                return
            }
        }

        // 2) 캡쳐 경로: 영역 오른쪽, 모자라면 왼쪽, 세로는 영역 중앙
        if nearMouse == nil, let cap = lastAreaAnchor(),
           let screen = screenForCapture() {
            let f = screen.visibleFrame
            var x = cap.maxX + gap
            var y = cap.midY - h / 2
            if x + w > f.maxX - margin { x = cap.minX - w - gap }
            clamp(f, &x, &y)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }

        // 3) 기본: 우상단
        if let f = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.maxX - w - 24, y: f.maxY - h - 24))
        }
    }

    /// lastArea(top-left, 디스플레이 로컬) → 전역 Cocoa 좌표(하단원점) 캡쳐 rect
    private func lastAreaAnchor() -> CGRect? {
        guard lastArea != .zero, let sf = screenForCapture()?.frame else { return nil }
        return CGRect(x: sf.minX + lastArea.minX,
                      y: sf.maxY - lastArea.maxY,
                      width: lastArea.width,
                      height: lastArea.height)
    }

    private func screenForCapture() -> NSScreen? {
        if let id = lastDisplay?.displayID,
           let s = NSScreen.screens.first(where: { $0.displayID == id }) { return s }
        return NSScreen.main
    }

    /// 번역·메시지만 3초 자동숨김. 에러카드는 유지(사용자 액션 필요).
    private func scheduleCardHide() {
        cancelCardTimer()
        guard cardMode != .error, !cardPinned else { return }
        cardHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.cardHovering, !self.cardPinned else { return }
                self.closeResultCard()
            }
        }
    }

    private func cancelCardTimer() {
        cardHideTimer?.invalidate()
        cardHideTimer = nil
    }

    func setCardHovering(_ h: Bool) {
        cardHovering = h
        if h { cancelCardTimer() }
        else { scheduleCardHide() }
    }

    func toggleCardPin() {
        cardPinned.toggle()
        if cardPinned { cancelCardTimer() }
        else { scheduleCardHide() }
    }

    func closeResultCard() {
        cancelCardTimer()
        cardHovering = false
        resultPanel?.orderOut(nil)
        resultPanel = nil
        if let m = cardEscMonitor { NSEvent.removeMonitor(m); cardEscMonitor = nil }
    }

    // MARK: - 번역 에디터 (Jot 자리, 캡쳐 후에만)
    func showEditor() {
        closeResultCard()
        if editorWindow != nil { editorWindow?.makeKeyAndOrderFront(nil); return }
        let v = TranslationEditorView(image: latestImage, ocr: ocr, translator: translator, coordinator: self)
        let w = NSWindow(contentViewController: NSHostingController(rootView: v))
        w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        w.title = "PickBeon"
        w.setContentSize(NSSize(width: 980, height: 620))
        w.minSize = NSSize(width: 800, height: 520)
        w.center(); w.isReleasedWhenClosed = false
        WindowDropper.attach(to: w) { [weak self] in self?.editorWindow = nil }
        editorWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    // MARK: - 복사 피드백 (P0-2: 무엇이 클립보드에 들어갔는지 사용자에게 명시)

    /// - Parameter extra: 부가 설명 (예: "주석 포함")
    func notifyCopy(ok: Bool, extra: String? = nil) {
        let message: String
        if ok {
            message = extra.map { "\(String(localized: "복사됨")) · \($0)" } ?? String(localized: "복사됨")
        } else {
            message = String(localized: "복사할 내용이 없습니다")
        }
        copyToast = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if self.copyToast == message { self.copyToast = nil }
        }
    }

    // MARK: - 텍스트 선택 번역 (AX + Safari용 Cmd+C 폴백)
    func translateSelection() {
        guard permissions.axOK else { showOnboarding(); return }
        // 드래그 직후 마우스 위치 — 카드를 그 근처에 띄움
        let mouse = NSEvent.mouseLocation
        Task {
            guard let sel = await AXSelectionReader.readSelectedTextWithFallback(), !sel.isEmpty else {
                FileLog.log("선택 텍스트 없음")
                cardMode = .message
                cardAction = .none
                cardTitle = String(localized: "선택된 텍스트 없음")
                cardBody = String(localized: "문자를 드래그로 선택한 뒤 단축키를 누르세요.")
                showResultCard(nearMouse: mouse)
                return
            }
            FileLog.log("선택 번역: \(sel.prefix(30))")
            do {
                let out = try await translator.translate(sel, polite: AppSettings.shared.politeTone)
                latestText = sel; latestTranslated = out
                PasteboardService.write(text: out)
                if let ctx = modelContext { clipboard.add(text: sel, translated: out, context: ctx) }
                routeAfterCapture(nearMouse: mouse)
            } catch {
                FileLog.log("선택 번역 실패 \(error)")
                cardMode = .error
                cardAction = .retryTranslate
                cardTitle = String(localized: "⚠ 번역 실패")
                cardBody = String(localized: "다시 시도해주세요.")
                showResultCard(nearMouse: mouse)
            }
        }
    }

    // MARK: - DebugPanel (Cmd+Shift+D)
    func showDebug() {
        if debugWindow != nil { debugWindow?.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentViewController: NSHostingController(rootView: DebugPanelView()))
        w.styleMask = [.titled, .closable]
        w.title = "DebugPanel"
        w.setContentSize(NSSize(width: 320, height: 140))
        w.isReleasedWhenClosed = false
        WindowDropper.attach(to: w) { [weak self] in self?.debugWindow = nil }
        debugWindow = w
        w.makeKeyAndOrderFront(nil)
    }

    // MARK: - 히스토리 (커맨드 팔레트: 화면 중앙 nonactivating 패널)
    func showHistory() {
        if historyWindow != nil { historyWindow?.makeKeyAndOrderFront(nil); return }
        // onDismiss 로 close() 를 호출해야 WindowDropper 콜백이 돌아 historyWindow 가 정리된다.
        // (과거 orderOut 은 willClose 가 울리지 않아 재오픈 시 검색어/포커스가 리셋되지 않았다)
        let v = ClipboardPopupView(store: clipboard, onDismiss: { [weak self] in
            self?.historyWindow?.close()
        })
        let panel = KeyableResultPanel(contentViewController: NSHostingController(rootView: v))
        panel.styleMask = [.nonactivatingPanel, .titled, .fullSizeContentView, .closable]
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(NSSize(width: 610, height: 480))
        panel.isReleasedWhenClosed = false
        WindowDropper.attach(to: panel) { [weak self] in self?.historyWindow = nil }
        // 커맨드 팔레트처럼 화면 중앙 (마우스/주 화면 visibleFrame 기준)
        let loc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(loc) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            let w = panel.frame.width, h = panel.frame.height
            panel.setFrameOrigin(NSPoint(x: f.midX - w / 2, y: f.midY - h / 2))
        } else {
            panel.center()
        }
        historyWindow = panel
        panel.makeKeyAndOrderFront(nil)
    }
}

// 키 윈도우 가능 패널 (비활성 패널이어도 텍스트필드 포커스 가능)
final class KeyableResultPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class WindowDropper: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }

    /// delegate는 weak — 호출부에서 인스턴스가 즉시 해제되지 않도록 window에 assoc retained 보관
    @MainActor
    static func attach(to window: NSWindow, _ onClose: @escaping () -> Void) {
        let d = WindowDropper(onClose)
        window.delegate = d
        objc_setAssociatedObject(window, &WindowDropper.assocKey, d, .OBJC_ASSOCIATION_RETAIN)
    }
    nonisolated(unsafe) private static var assocKey: UInt8 = 0
}

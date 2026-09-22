import AppKit
import SwiftUI
import SwiftData
import ScreenCaptureKit

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

    let capture = ScreenCaptureManager()
    let ocr = OCRService()
    let translator = TranslationService()
    let clipboard = ClipboardStore()
    let permissions = PermissionService()

    private var overlayControllers: [CaptureOverlayController] = []
    private var escMonitor: Any?
    private var resultPanel: NSPanel?
    private var editorWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var debugWindow: NSWindow?
    var dismissMenu: (() -> Void)?

    func menuAction(_ work: @escaping () -> Void) {
        dismissMenu?()
        work()
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
        w.delegate = WindowDropper { [weak self] in
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
    func startCapture() {
        guard permissions.screenRecordingOK else { showOnboarding(); return }
        closeOverlay()
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
                var shown = 0
                for screen in NSScreen.screens {
                    guard let id = screen.displayID,
                          let disp = content.displays.first(where: { $0.displayID == id }) else { continue }
                    let ctl = CaptureOverlayController(screen: screen, display: disp)
                    ctl.onSelect = { [weak self] rect, display, pointSize in
                        self?.didSelectArea(rect, display: display, pointSize: pointSize, controller: ctl)
                    }
                    ctl.onPerform = { [weak self] action, image in
                        self?.performAction(action, image: image)
                    }
                    ctl.onCancel = { [weak self] in self?.closeOverlay() }
                    ctl.onReuse = { [weak self] in self?.repeatFromOverlay() }
                    ctl.show()
                    overlayControllers.append(ctl)
                    shown += 1
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
        overlayControllers.forEach { $0.close() }
        overlayControllers = []
    }

    private var lastDisplay: SCDisplay?
    private var lastPointSize: CGSize = .zero

    func didSelectArea(_ rect: CGRect, display: SCDisplay, pointSize: CGSize, controller: CaptureOverlayController) {
        lastArea = rect
        lastDisplay = display
        lastPointSize = pointSize
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

    func performAction(_ action: CaptureAction, image: NSImage) {
        FileLog.log("액션 \(action)")
        closeOverlay()
        Task { await self.applyAction(action, image: image) }
    }

    func applyAction(_ action: CaptureAction, image: NSImage) async {
        switch action {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
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
        case .translate:
            latestImage = image
            await runTranslate(img: image)
        }
    }

    func repeatLastArea() {
        // 메뉴 경로: 이력 없으면 새로 캡쳐
        guard lastArea != .zero, let d = lastDisplay else { startCapture(); return }
        closeOverlay()
        Task { await captureAndRoute(area: lastArea, display: d, pointSize: lastPointSize, action: .translate) }
    }

    func repeatFromOverlay() {
        // 오버레이 R키: 선택 없을 때 + 이력 있을 때만. 그 외 무시 (재시작 안 함).
        guard !overlayControllers.isEmpty, lastArea != .zero, let d = lastDisplay else { return }
        closeOverlay()
        Task { await captureAndRoute(area: lastArea, display: d, pointSize: lastPointSize, action: .translate) }
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
        panel.setContentSize(NSSize(width: 400, height: 300))
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.delegate = WindowDropper { [weak self, weak panel] in
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
        w.setContentSize(NSSize(width: 640, height: 430))
        w.center(); w.isReleasedWhenClosed = false
        w.delegate = WindowDropper { [weak self] in self?.settingsWindow = nil }
        settingsWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    // MARK: - 파이프라인: OCR → 번역 → 복사 → 결과카드
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
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(out, forType: .string)
            if let ctx = modelContext {
                clipboard.add(text: joined, translated: out, context: ctx)
            }
            DebugLogger.shared.cache("파이프라인 완료, 클립보드 복사")
            cardMode = .translation
            cardAction = .none
            showResultCard()
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

    // MARK: - 결과 카드 (합의 레이아웃, 내용 맞춤 높이)
    func showResultCard() {
        closeResultCard()
        let v = ResultCardView(coordinator: self)
        let host = NSHostingController(rootView: v)
        let panel = NSPanel(contentViewController: host)
        panel.styleMask = [.nonactivatingPanel, .titled, .closable, .fullSizeContentView]
        panel.title = "PickBeon"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        host.view.layoutSubtreeIfNeeded()
        let fit = host.view.fittingSize
        panel.setContentSize(NSSize(width: 460, height: min(560, max(220, fit.height))))
        if let f = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.maxX - 480, y: f.maxY - min(560, max(220, fit.height)) - 30))
        }
        panel.isReleasedWhenClosed = false
        panel.delegate = WindowDropper { [weak self] in self?.resultPanel = nil }
        resultPanel = panel
        panel.orderFrontRegardless()
    }
    func closeResultCard() { resultPanel?.orderOut(nil); resultPanel = nil }

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
        w.delegate = WindowDropper { [weak self] in self?.editorWindow = nil }
        editorWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    // MARK: - 텍스트 선택 번역 (AX)
    func translateSelection() {
        guard permissions.axOK else { showOnboarding(); return }
        guard let sel = AXSelectionReader.readSelectedText(), !sel.isEmpty else {
            FileLog.log("선택 텍스트 없음")
            cardMode = .message
            cardAction = .none
            cardTitle = String(localized: "선택된 텍스트 없음")
            cardBody = String(localized: "문자를 드래그로 선택한 뒤 단축키를 누르세요.")
            showResultCard()
            return
        }
        FileLog.log("선택 번역: \(sel.prefix(30))")
        Task {
            do {
                let out = try await translator.translate(sel, polite: AppSettings.shared.politeTone)
                latestText = sel; latestTranslated = out
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(out, forType: .string)
                if let ctx = modelContext { clipboard.add(text: sel, translated: out, context: ctx) }
                cardMode = .translation
                cardAction = .none
                showResultCard()
            } catch {
                FileLog.log("선택 번역 실패 \(error)")
                cardMode = .error
                cardAction = .retryTranslate
                cardTitle = String(localized: "⚠ 번역 실패")
                cardBody = String(localized: "다시 시도해주세요.")
                showResultCard()
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
        w.delegate = WindowDropper { [weak self] in self?.debugWindow = nil }
        debugWindow = w
        w.makeKeyAndOrderFront(nil)
    }

    // MARK: - 히스토리
    func showHistory() {
        if historyWindow != nil { historyWindow?.makeKeyAndOrderFront(nil); return }
        let v = ClipboardPopupView(store: clipboard)
        let w = NSWindow(contentViewController: NSHostingController(rootView: v))
        w.styleMask = [.titled, .closable, .resizable]
        w.title = String(localized: "기록")
        w.setContentSize(NSSize(width: 420, height: 480))
        w.center(); w.isReleasedWhenClosed = false
        w.delegate = WindowDropper { [weak self] in self?.historyWindow = nil }
        historyWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

final class WindowDropper: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(_ onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}

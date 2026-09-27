import Foundation
import Carbon.HIToolbox
import AppKit

/// 전역 단축키 (Carbon RegisterEventHotKey 기반 — 추가 권한 불필요).
///
/// 2026-09-27: 5종을 전부 사용자 지정 가능하게 변경.
/// - 하드코딩 대신 AppSettings 의 슬롯을 읽는다.
/// - 등록 실패(다른 앱/system 이 점유) 시 UI 에 노출한다. (이전엔 로그만 남기고
///   UI 는 "정상 등록된 것처럼" 표시돼 실제로 안 눌리는 걸 알 수 없었다.)
@MainActor
final class GlobalHotKeyService: ObservableObject {
    static let shared = GlobalHotKeyService()

    /// 슬롯 → 동작. 순서가 곧 기본값 순서.
    enum Action: String, CaseIterable, Identifiable {
        case capture, translateSelection, gif, quickCopy, windowCapture
        var id: String { rawValue }

        var title: String {
            switch self {
            case .capture: return String(localized: "영역 Pick")
            case .translateSelection: return String(localized: "텍스트 선택 번역")
            case .gif: return String(localized: "GIF 녹화 / 중지")
            case .quickCopy: return String(localized: "텍스트 바로 복사")
            case .windowCapture: return String(localized: "창 캡쳐")
            }
        }

        var subtitle: String {
            switch self {
            case .capture: return String(localized: "드래그 → 번역")
            case .translateSelection: return String(localized: "드래그한 문장 → 번역")
            case .gif: return String(localized: "재단축키로 중지")
            case .quickCopy: return String(localized: "OCR → 클립보드")
            case .windowCapture: return String(localized: "창 클릭 선택")
            }
        }

        /// 기본 바인딩.
        /// ⌥⌘C 는 macOS 시스템 조합과 겹쳐 제거했다(2026-09-27 사용자 보고).
        /// 겹쳤을 때 Carbon 등록이 실패하거나 사용자 기존 동작을 방해한다.
        /// [주의] keyCode 는 QWERTY 물리 위치 기준이다. W=12 이며 13 은 E 다.
        /// (과거 코드가 ⌥⌘W 라 표기하고 13 을 써서 실제로는 ⌥⌘E 였다)
        var defaultBinding: HotKeyBinding {
            switch self {
            case .capture: return HotKeyBinding(keyCode: 7, modifiers: HotKeyBinding.cmd | HotKeyBinding.shift)      // ⌘⇧X
            case .translateSelection: return HotKeyBinding(keyCode: 6, modifiers: HotKeyBinding.cmd | HotKeyBinding.option) // ⌘⌥Z
            case .gif: return HotKeyBinding(keyCode: 5, modifiers: HotKeyBinding.option | HotKeyBinding.cmd)         // ⌥⌘G
            case .quickCopy: return HotKeyBinding(keyCode: 8, modifiers: HotKeyBinding.cmd | HotKeyBinding.shift)     // ⌘⇧C
            case .windowCapture: return HotKeyBinding(keyCode: 12, modifiers: HotKeyBinding.cmd | HotKeyBinding.shift) // ⌘⇧W
            }
        }
    }

    /// 등록 실패한 슬롯 (UI 표시용)
    @Published private(set) var failedActions: Set<Action> = []

    var onCapture: (() -> Void)?
    var onTranslateSelection: (() -> Void)?
    var onGifCapture: (() -> Void)?
    var onQuickCopy: (() -> Void)?
    var onWindowCapture: (() -> Void)?

    private static var callbacks: [UInt32: () -> Void] = [:]
    private static var refs: [EventHotKeyRef?] = []
    private static var handlerRef: EventHandlerRef?
    private static var proc: EventHandlerUPP?

    private init() {}

    /// 앱 기동 시 1회. 설정값으로 등록한다.
    func registerConfigured() {
        installHandlerOnce()
        apply(AppSettings.shared)
    }

    /// 설정 변경 시 재등록. 기존 핸들 해제 후 다시 건다.
    func apply(_ settings: AppSettings) {
        unregisterAll()
        var failed: Set<Action> = []
        for (i, action) in Action.allCases.enumerated() {
            let binding = settings.hotKey(for: action)
            guard binding.isValid else {
                DebugLogger.shared.error(code: "E-MAC-INPUT-0002", "단축키 미지정 \(action.rawValue)")
                failed.insert(action)
                continue
            }
            let signature = UInt32(i + 1)
            if register(
                signature: signature,
                keyCode: binding.keyCode,
                modifiers: binding.modifiers,
                invoke: { [weak self] in self?.invoke(action) }
            ) == false {
                failed.insert(action)
            }
        }
        failedActions = failed
        let summary = Action.allCases
            .map { "\($0.title)=\(settings.hotKey(for: $0).display)\(failed.contains($0) ? "✗" : "")" }
            .joined(separator: " ")
        DebugLogger.shared.info(feature: "HotKey", "전역 단축키 등록 \(summary)")
        if !failed.isEmpty {
            AppLog.log("단축키 등록 실패 \(failed.map(\.rawValue).joined(separator: ",")) — 다른 앱이 사용 중")
        }
    }

    private func invoke(_ action: Action) {
        switch action {
        case .capture: onCapture?()
        case .translateSelection: onTranslateSelection?()
        case .gif: onGifCapture?()
        case .quickCopy: onQuickCopy?()
        case .windowCapture: onWindowCapture?()
        }
    }

    // MARK: - Carbon

    private func installHandlerOnce() {
        guard Self.handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let proc: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hid = EventHotKeyID()
            let size = MemoryLayout.size(ofValue: hid)
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                    EventParamType(typeEventHotKeyID), nil,
                                    size, nil, &hid) == noErr else { return noErr }
            if let cb = GlobalHotKeyService.callbacks[hid.signature] { cb() }
            return noErr
        }
        Self.proc = proc
        let st = InstallEventHandler(GetApplicationEventTarget(), proc, 1, &spec, nil, &Self.handlerRef)
        if st != noErr {
            DebugLogger.shared.error(code: "E-MAC-INPUT-0001", "핫키 핸들러 설치 실패 \(st)")
        }
    }

    @discardableResult
    private func register(signature: UInt32, keyCode: UInt32, modifiers: UInt32, invoke: @escaping () -> Void) -> Bool {
        let hid = EventHotKeyID(signature: signature, id: 0)
        var ref: EventHotKeyRef?
        let st = RegisterEventHotKey(keyCode, OptionBits(modifiers), hid,
                                     GetApplicationEventTarget(), 0, &ref)
        guard st == noErr else {
            DebugLogger.shared.error(code: "E-MAC-INPUT-0002", "핫키 등록 실패 key=\(keyCode) mod=\(modifiers) status=\(st)")
            return false
        }
        Self.refs.append(ref)
        Self.callbacks[signature] = invoke
        return true
    }

    private func unregisterAll() {
        for ref in Self.refs { if let ref { UnregisterEventHotKey(ref) } }
        Self.refs.removeAll()
        Self.callbacks.removeAll()
    }
}

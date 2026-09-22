import Foundation
import Carbon.HIToolbox
import AppKit

// Carbon RegisterEventHotKey 기반 전역 단축키 (추가 권한 불필요).
// 캡쳐 ⌥⌃P (keyCode 35), 선택 번역 ⌥⌃Z (keyCode 6). modifier ⌥+⌃ = 6144.
@MainActor
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

    var onCapture: (() -> Void)?
    var onTranslateSelection: (() -> Void)?

    private static var callbacks: [UInt32: () -> Void] = [:]
    private static var refs: [EventHotKeyRef?] = []
    private static var handlerRef: EventHandlerRef?
    private static var proc: EventHandlerUPP?

    private init() {}

    func registerDefaults() {
        installHandlerOnce()
        register(signature: 1, keyCode: 35, modifiers: 6144) { [weak self] in self?.onCapture?() }
        register(signature: 2, keyCode: 6, modifiers: 6144) { [weak self] in self?.onTranslateSelection?() }
        DebugLogger.shared.info(feature: "HotKey", "전역 단축키 등록 ⌥⌃P/⌥⌃Z")
    }

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

    private func register(signature: UInt32, keyCode: UInt32, modifiers: UInt32, _ cb: @escaping () -> Void) {
        var hid = EventHotKeyID(signature: signature, id: 0)
        var ref: EventHotKeyRef?
        let st = RegisterEventHotKey(keyCode, OptionBits(modifiers), hid,
                                     GetApplicationEventTarget(), 0, &ref)
        if st == noErr {
            Self.refs.append(ref)
            Self.callbacks[signature] = cb
        } else {
            DebugLogger.shared.error(code: "E-MAC-INPUT-0002", "핫키 등록 실패 key=\(keyCode) status=\(st)")
        }
    }
}

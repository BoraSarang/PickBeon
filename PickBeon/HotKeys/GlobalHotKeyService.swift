import Foundation
import Carbon.HIToolbox
import AppKit

// Carbon RegisterEventHotKey 기반 전역 단축키 (추가 권한 불필요).
// ⌘⇧X (7/768), ⌘⌥Z (6/2304), ⌥⌘G (5/2304), ⌥⌘C A2 (8/2304), ⌥⌘W B3 (13/2304).
@MainActor
final class GlobalHotKeyService {
    static let shared = GlobalHotKeyService()

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

    func registerDefaults() {
        installHandlerOnce()
        register(signature: 1, keyCode: 7, modifiers: 768) { [weak self] in self?.onCapture?() }
        register(signature: 2, keyCode: 6, modifiers: 2304) { [weak self] in self?.onTranslateSelection?() }
        register(signature: 3, keyCode: 5, modifiers: 2304) { [weak self] in self?.onGifCapture?() }
        register(signature: 4, keyCode: 8, modifiers: 2304) { [weak self] in self?.onQuickCopy?() }
        register(signature: 5, keyCode: 13, modifiers: 2304) { [weak self] in self?.onWindowCapture?() }
        DebugLogger.shared.info(feature: "HotKey", "전역 단축키 등록 ⌘⇧X/⌘⌥Z/⌥⌘G/⌥⌘C/⌥⌘W")
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
        let hid = EventHotKeyID(signature: signature, id: 0)
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

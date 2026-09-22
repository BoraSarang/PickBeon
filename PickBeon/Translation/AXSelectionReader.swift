import AppKit
import ApplicationServices
import Carbon.HIToolbox

// Bob 방식: 선택 후 단축키로 AXSelectedText 읽기. OCR 불필요.
// Safari 등 AX 미지원 앱 대비: 잠깐 시뮬 Cmd+C로 클립보드 읽은 뒤 원래대로 복원.
enum AXSelectionReader {
    static func readSelectedText() -> String? {
        let sys = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused else { return nil }
        var sel: AnyObject?
        guard AXUIElementCopyAttributeValue(el as! AXUIElement, kAXSelectedTextAttribute as CFString, &sel) == .success else { return nil }
        return sel as? String
    }

    /// AX 우선, 실패 시 Cmd+C 폴백 (Safari/Firefox 등). 비동기 대기 포함.
    static func readSelectedTextWithFallback() async -> String? {
        if let s = readSelectedText(), !s.isEmpty { return s }
        FileLog.log("AX 선택 없음, Cmd+C 폴백 시도")
        let saved = savePasteboard()
        postCommandC()
        try? await Task.sleep(nanoseconds: 180_000_000)
        let clip = NSPasteboard.general.string(forType: .string)
        restorePasteboard(saved)
        if let s = clip, !s.isEmpty {
            FileLog.log("폴백 성공 \(s.prefix(30))")
            return s
        }
        FileLog.log("폴백도 선택 텍스트 없음")
        return nil
    }

    // MARK: - 시뮬 Cmd+C
    private static func postCommandC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_C)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        DebugLogger.shared.info(feature: "AX", "시뮬 Cmd+C 전송")
    }

    // MARK: - 클립보드 보존 (폴백이 사용자 클립보드를 먹지 않도록)
    private struct SavedItem {
        let strings: [String: String]   // type -> content
        let datas: [String: Data]
    }
    private static let snapTypes: [NSPasteboard.PasteboardType] = [
        .string, .png, .tiff, .rtf, .rtfd, .URL, .fileURL,
    ]

    private static func savePasteboard() -> [SavedItem] {
        let pb = NSPasteboard.general
        guard let items = pb.pasteboardItems else { return [] }
        return items.map { item in
            var strings: [String: String] = [:]
            var datas: [String: Data] = [:]
            for t in snapTypes {
                if let s = item.string(forType: t) { strings[t.rawValue] = s }
                else if let d = item.data(forType: t) { datas[t.rawValue] = d }
            }
            return SavedItem(strings: strings, datas: datas)
        }
    }

    private static func restorePasteboard(_ saved: [SavedItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let items = saved.map { s -> NSPasteboardItem in
            let it = NSPasteboardItem()
            for (t, v) in s.strings { it.setString(v, forType: NSPasteboard.PasteboardType(t)) }
            for (t, d) in s.datas { it.setData(d, forType: NSPasteboard.PasteboardType(t)) }
            return it
        }
        if !items.isEmpty { pb.writeObjects(items) }
    }
}

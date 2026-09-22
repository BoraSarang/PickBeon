import AppKit
import ApplicationServices

// Bob 방식: 선택 후 단축키로 AXSelectedText 읽기. OCR 불필요.
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
}

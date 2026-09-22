import Foundation

// PLATFORM: macos
enum PickBeonError: Error {
    case capture(String, code: String = "E-MAC-CAPTURE-0001")
    case ocr(String, code: String = "E-MAC-OCR-0001")
    case trans(String, code: String = "E-MAC-TRANS-0001")
    case store(String, code: String = "E-MAC-STORE-0001")
    case perm(String, code: String = "E-MAC-PERM-0001")
}

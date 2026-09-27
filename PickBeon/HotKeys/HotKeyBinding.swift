import AppKit
import Carbon.HIToolbox

/// 전역 단축키 바인딩 (keyCode + Carbon modifier 비트).
/// 2026-09-27: 사용자가 전 기능의 단축키를 변경할 수 있게 하며,
/// 하드코딩 5종(⌘⇧X/⌘⌥Z/⌥⌘G/⌥⌘C/⌥⌘W) 을 기본값으로 대체한다.
struct HotKeyBinding: Equatable {
    /// Carbon modifier 비트
    static let cmd: UInt32 = 256
    static let shift: UInt32 = 512
    static let option: UInt32 = 2048
    static let control: UInt32 = 4096

    static let keyEscape: UInt32 = 53

    var keyCode: UInt32
    var modifiers: UInt32

    /// 순수 키만 눌렸으면 무효 (단독키는 OS 와 충돌하므로)
    var isValid: Bool {
        keyCode != Self.keyEscape
            && keyCode < 256
            && (modifiers & (Self.cmd | Self.option | Self.control | Self.shift)) != 0
    }

    // MARK: - 표시 문자열

    var display: String {
        var s = ""
        if modifiers & Self.control != 0 { s += "⌃" }
        if modifiers & Self.option != 0 { s += "⌥" }
        if modifiers & Self.shift != 0 { s += "⇧" }
        if modifiers & Self.cmd != 0 { s += "⌘" }
        s += (Self.symbol(for: keyCode) ?? "키\(keyCode)")
        return s
    }

    // MARK: - keyCode ↔ 표시 문자
    //
    // [중요] macOS Carbon keyCode 는 알파벳 순서가 아니라 **QWERTY 물리 위치** 기준이다.
    // 알파벳 인덱스로 매핑하면 전부 어긋난다. (7 = X, 4 = H 이며 7 = H 가 아니다)
    private static let keyNameTable: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "Q", 12: "W", 13: "E", 14: "R", 15: "Y", 16: "T",
        17: "1", 18: "2", 19: "3", 20: "4", 21: "6", 22: "5",
        23: "\\", 24: "¥",
        25: "7", 26: "8", 27: "9", 28: "0",
        29: "O", 30: "U", 31: "[", 32: "]", 33: "I", 34: "P", 35: "L", 36: "J",
        37: "'", 38: "K", 39: ";", 40: "\\", 41: ",", 42: "/", 43: "N", 44: "M", 45: ".",
        46: "`", 47: "?", 50: "`",
        48: "⇥", 49: "␣", 51: "⌫", 52: "-", 53: "esc",
        65: "⌧", 67: "⌦", 69: "+", 78: "=", 81: "⌫",
        76: "⏎", 82: "⌦",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
        113: "F15", 114: "help", 115: "home", 116: "pageup", 117: "fwd del",
        118: "F4", 119: "end", 120: "F2", 121: "pagedown", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    /// 표시 문자(A~Z) → keyCode. keyNameTable 을 역으로 뒤집어 파생시켜
    /// 정방향/역방향 매핑이 어긋날 여지를 없앤다.
    /// "F11"·"esc"·"home"·"pageup" 처럼 첫 글자가 알파벳인 항목이 섞여 있으므로
    /// **정확히 한 글자 대문자**인 항목만 사용한다.
    private static let letterCodeTable: [Character: UInt32] = {
        var t: [Character: UInt32] = [:]
        for (code, name) in keyNameTable {
            guard name.count == 1, let c = name.first, c.isUppercase, t[c] == nil else { continue }
            t[c] = code
        }
        return t
    }()

    /// 표시 문자(A~Z) → keyCode
    static func keyCode(forLetter c: Character) -> UInt32? {
        letterCodeTable[Character(c.uppercased())]
    }

    static func symbol(for keyCode: UInt32) -> String? {
        keyNameTable[keyCode]
    }

    // MARK: - 이벤트 → 바인딩

    /// macOS 14+ 는 NSEvent.keyCode 로 실제 키코드를 준다. 최소 macOS 26 이므로 폴백 불필요.
    static func from(_ event: NSEvent) -> HotKeyBinding? {
        HotKeyBinding(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers(from: event))
    }

    private static func carbonModifiers(from event: NSEvent) -> UInt32 {
        var m: UInt32 = 0
        let f = event.modifierFlags
        if f.contains(.command) { m |= cmd }
        if f.contains(.option) { m |= option }
        if f.contains(.control) { m |= control }
        if f.contains(.shift) { m |= shift }
        return m
    }

    // MARK: - 영속화 ("keyCode,modifiers" 문자열 — UserDefaults 용)

    static func encode(_ b: HotKeyBinding) -> String {
        "\(b.keyCode),\(b.modifiers)"
    }

    static func decode(_ raw: String) -> HotKeyBinding? {
        let parts = raw.split(separator: ",")
        guard parts.count == 2,
              let kc = UInt32(parts[0]), let m = UInt32(parts[1]) else { return nil }
        return HotKeyBinding(keyCode: kc, modifiers: m)
    }

    // MARK: - 충돌 검사

    /// macOS 가 점유한 조합. Carbon 핫키는 이를 덮어쓸 수 없어 겹치면 등록이 실패하거나
    /// 사용자가 기존 단축키를 못 쓴다. 경고용 목록(차단하지 않음).
    static let systemReserved: [String: String] = [
        "⌘␣": "스포트라이트", "⌃⌘␣": "문자 뷰어", "⌘⌥⎋": "강제 종료",
        "⌘⇧A": "전체 항목", "⌘⌥D": "사전", "⌘⌥N": "알림 센터",
        "⌘⌥/": "도움말 검색", "⌘⌥T": "음성 입력", "⌘⌥E": "이모티콘",
        "⌘⌥F": "전체 화면", "⌘⌥H": "가리기", "⌘⌥M": "최소화",
        "⌘⌥C": "복사 서식", "⌘⌥V": "붙여넣기 서식", "⌘⌥X": "잘라내기 서식",
        "⌘⌥⇧A": "글자 크기", "⌘⌥⇧4": "디스플레이 선택", "⌘⇧3": "미션 컨트롤",
        "⌘⌥G": "다음 항목 찾기", "⇧⌘H": "가린 항목 표시",
    ]
}

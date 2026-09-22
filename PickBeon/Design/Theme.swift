import SwiftUI
import AppKit

// PLATFORM: macos — custom 디자인 토큰 단일 소스 (docs/DESIGN.md와 1:1)
enum Theme {
    // MARK: 색 (dynamic: 다크 = 콘셉트 v2, 라이트 = 저채도 그레이)
    static let accent       = Color(light: 0x2563EB, dark: 0x60A5FA)
    static let hero1        = Color(light: 0x2563EB, dark: 0x2563EB)
    static let hero2        = Color(light: 0x3B82F6, dark: 0x60A5FA)
    static let hero         = LinearGradient(colors: [hero1, hero2], startPoint: .leading, endPoint: .trailing)

    static let bg           = Color(light: 0xF2F2F7, dark: 0x141416)
    static let surface      = Color(light: 0xFFFFFF, dark: 0x232327)
    static let surface2     = Color(light: 0xF5F5F7, dark: 0x2C2C31)
    static let row          = Color(light: 0xEBEBF0, dark: 0x303035)
    static let rowHover     = Color(light: 0xE2E2E8, dark: 0x38383E)

    static let textPrimary   = Color(light: 0x1C1C1E, dark: 0xF5F5F7)
    static let textSecondary = Color(light: 0x6E6E73, dark: 0x9A9AA2)
    static let line          = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.08)
    static let glassStroke  = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.12)

    static let ok       = Color(light: 0x1FAD32, dark: 0x30D158)
    static let danger   = Color(light: 0xD70015, dark: 0xFF453A)
    static let warn     = Color(light: 0xC93400, dark: 0xFF9F0A)
    static let pinColor = Color(light: 0xC93400, dark: 0xFF9F0A)

    static let transPanel     = Color(light: 0xEEF4FF, dark: 0x162033)
    static let transPanelLine = accent.opacity(0.35)
    static let heroKbd        = Color.black.opacity(0.25)
    static let kbdFill        = Color.primary.opacity(0.10)

    // MARK: 라운드
    static let rChip: CGFloat = 7
    static let rCard: CGFloat = 12
    static let rPanel: CGFloat = 16
    static let rBlock: CGFloat = 10
    static let rTab: CGFloat = 8

    // MARK: 간격
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 10
    static let s4: CGFloat = 12
    static let s5: CGFloat = 14
    static let s6: CGFloat = 16
    static let s8: CGFloat = 20

    // MARK: 폰트
    static func font(_ size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        mono ? .system(size: size, weight: weight, design: .monospaced)
             : .system(size: size, weight: weight)
    }

    // MARK: 모션
    static let popSpring = Animation.spring(response: 0.28, dampingFraction: 0.85)
    static let hoverFade = Animation.easeOut(duration: 0.12)
}

// MARK: - Color hex / dynamic
extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 라이트/다크 각각 다른 hex의 dynamic color
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

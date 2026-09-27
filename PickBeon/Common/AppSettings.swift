import Foundation
import SwiftUI

enum HistoryLimit: Int, CaseIterable, Identifiable {
    case n20 = 20, n50 = 50, n100 = 100, n200 = 200, unlimited = -1
    var id: Int { rawValue }
    var label: String { self == .unlimited ? String(localized: "무제한") : "\(rawValue)" }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    @AppStorage("uiLanguage") var uiLanguage: String = "system" // system, ko, en
    @AppStorage("srcLang") var srcLang: String = "auto"
    @AppStorage("tgtLang") var tgtLang: String = "system"
    @AppStorage("historyLimit") var historyLimitRaw: Int = 20
    @AppStorage("saveImages") var saveImages: Bool = true
    @AppStorage("encryptStore") var encryptStore: Bool = false
    @AppStorage("overlayOn") var overlayOn: Bool = true
    @AppStorage("transOverlayOn") var transOverlayOn: Bool = false
    @AppStorage("politeTone") var politeTone: Bool = true
    @AppStorage("afterCapture") var afterCapture: String = "card" // card, editor, clipboard
    @AppStorage("gifFps") var gifFps: Int = 10
    @AppStorage("gifMaxSeconds") var gifMaxSeconds: Int = 10 // 10 | 30 | 0=unlimited
    @AppStorage("gifAutoCopy") var gifAutoCopy: Bool = true
    /// C1: GIF 종료 후 주요 프레임 OCR→번역
    @AppStorage("gifFrameTranslate") var gifFrameTranslate: Bool = true

    // MARK: - 전역 단축키 (2026-09-27 전부 사용자 지정 가능)
    /// 슬롯별 바인딩. 키는 "hotkey.<action>" 형식, 값은 "keyCode,modifiers".
    /// 변경되면 올라가 관찰 중 UI(메뉴 KeyCap 등)가 갱신된다.
    @Published var hotKeyRevision = 0

    private func hotKeyKey(_ action: GlobalHotKeyService.Action) -> String { "hotkey.\(action.rawValue)" }

    func hotKey(for action: GlobalHotKeyService.Action) -> HotKeyBinding {
        if let raw = UserDefaults.standard.string(forKey: hotKeyKey(action)),
           let value = HotKeyBinding.decode(raw), value.isValid {
            return value
        }
        return action.defaultBinding
    }

    func setHotKey(_ binding: HotKeyBinding, for action: GlobalHotKeyService.Action) {
        UserDefaults.standard.set(HotKeyBinding.encode(binding), forKey: hotKeyKey(action))
        hotKeyRevision &+= 1
    }

    func resetHotKey(for action: GlobalHotKeyService.Action) {
        UserDefaults.standard.removeObject(forKey: hotKeyKey(action))
        hotKeyRevision &+= 1
    }

    func resetAllHotKeys() {
        for action in GlobalHotKeyService.Action.allCases { resetHotKey(for: action) }
    }

    var historyLimit: HistoryLimit { HistoryLimit(rawValue: historyLimitRaw) ?? .n20 }
    var gifMaxLabel: String {
        gifMaxSeconds <= 0 ? String(localized: "무제한") : "\(gifMaxSeconds)초"
    }

    func effectiveLocale() -> Locale {
        if uiLanguage == "system" { return Locale.autoupdatingCurrent }
        return Locale(identifier: uiLanguage == "ko" ? "ko" : "en")
    }
    func effectiveTargetID() -> String {
        if tgtLang == "system" {
            return Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "ko"
        }
        return tgtLang
    }
}

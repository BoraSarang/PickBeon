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
    @AppStorage("politeTone") var politeTone: Bool = true
    @AppStorage("afterCapture") var afterCapture: String = "editor" // clipboard, save, editor

    var historyLimit: HistoryLimit { HistoryLimit(rawValue: historyLimitRaw) ?? .n20 }

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

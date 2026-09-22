import Foundation
import os

final class DebugLogger: Sendable {
    static let shared = DebugLogger()
    private let log = Logger(subsystem: "com.borasarang.PickBeon", category: "app")
    private init() {}
    func info(feature: String, _ msg: String) { log.info("[INFO] [FEATURE] \(feature, privacy: .public) \(msg, privacy: .public)") }
    func perf(_ msg: String) { log.info("[PERF] \(msg, privacy: .public)") }
    func cache(_ msg: String) { log.info("[CACHE] \(msg, privacy: .public)") }
    func error(code: String, _ msg: String) { log.error("[ERROR] \(code, privacy: .public) \(msg, privacy: .public)") }
}

import Foundation
import os

/// [HARD] quality.md 규약: 신규 기능 진입점마다 `[INFO] [FEATURE] <기능명>`, 실패는
/// `[ERROR] E-...` + `[PERF]` / `[CACHE]` 레벨. os_log 와 AppLog(메모리 링버퍼)에 함께 남긴다.
final class DebugLogger: Sendable {
    static let shared = DebugLogger()
    private init() {}

    func info(feature: String, _ msg: String) { AppLog.log("[FEATURE] \(feature) \(msg)") }
    func perf(_ msg: String) { AppLog.perf(msg) }
    func cache(_ msg: String) { AppLog.cache(msg) }
    func error(code: String, _ msg: String) { AppLog.error(code: code, msg) }
}

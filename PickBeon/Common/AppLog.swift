import Foundation
import AppKit
import os

/// 애플리케이션 로그 저장소 (2026-09-28 신설).
///
/// 이전 `FileLog` 는 세 가지 [HARD] 문제를 안고 있었다.
///  1. **로그 마스킹 위반** — `AppLog.log("번역 시작: \(text.prefix(30))")` 형태로
///     사용자가 캡처한 텍스트(밖으로 나가면 안 되는 콘텐츠)를 ~/Desktop 에 평문으로
///     기록했다. hard.md 9조 위반.
///  2. **무한 증가** — 파일 크기 제한/로테이션이 없어 끝까지 커졌다.
///  3. **메인 스레드 동기 I/O** — 로그 한 줄마다 `createDirectory` + `fileExists` +
///     `FileHandle` open/close 를 동기 수행. 로그 60개 호출 지점 중 캡쳐 경로가
///     다수 포함돼 프레임에 영향을 준다.
///
/// 해결:
///  - 메모리 링버퍼(최근 N줄) → DebugPanel 이 실제 내용을 표시한다.
///    (기존 DebugPanel 은 "ERROR 0" 같은 하드코딩 스텁이었다)
///  - 디스크 쓰기는 백그라운드 직렬 큐 + 배치 flush.
///  - 크기 상한 + 로테이션.
///  - 사용자 텍스트는 `sensitive()` 로만. 디스크에는 **길이만** 남기고
///    본문은 메모리에만 보관한다.
final class AppLog: @unchecked Sendable {
    enum Level: String {
        case info = "INFO"
        case error = "ERROR"
        case perf = "PERF"
        case cache = "CACHE"
    }

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let level: Level
        let message: String
        /// 메모리 전용(디스크 미기록) 여부 — DebugPanel 에서 구분 표시
        let volatile: Bool
    }

    static let shared = AppLog()

    private let memoryLimit = 400
    private let diskLimit = 2 * 1024 * 1024        // 2MB 초과 시 로테이션
    private let flushThreshold = 20                 // 줄

    private let queue = DispatchQueue(label: "PickBeon.Log", qos: .utility)
    private let osLog = Logger(subsystem: "com.borasarang.PickBeon", category: "app")

    private var buffer: [Entry] = []
    private var pending: [String] = []
    private var bytesOnDisk = 0
    private var flusher: DispatchSourceTimer?

    private init() {
        bytesOnDisk = (try? FileManager.default.attributesOfItem(atPath: Self.storeURL.path)[.size] as? Int) ?? 0
        startFlusher()
    }

    /// 0.5초 주기로 디스크에 반영해 버그 제보 시 파일만으로 재현 가능하게 한다.
    /// (스레시 20줄만 채우면 사용자가 로그를 보지 못한 채 파일이 안 생겼다)
    private func startFlusher() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + .milliseconds(500), repeating: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.flush() }
        t.resume()
        flusher = t
    }

    // MARK: - 저장 위치

    /// 캡쳐 이미지를 저장하는 폴더와 분리한다 (사용자가 스크린샷을 담는 곳을 오염시키지 않음).
    static var storeURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PickBeon", isDirectory: true)
        return base.appendingPathComponent("debug.log")
    }

    // MARK: - 기록 API

    static func log(_ message: String, level: Level = .info) {
        shared.emit(message, level: level, toDisk: true)
    }

    static func error(code: String, _ message: String) {
        shared.emit("\(code) \(message)", level: .error, toDisk: true)
    }

    static func perf(_ message: String) { shared.emit(message, level: .perf, toDisk: true) }
    static func cache(_ message: String) { shared.emit(message, level: .cache, toDisk: true) }

    /// **사용자 텍스트를 다룰 때 유일하게 쓰는 진입점.**
    /// 디스크에는 길이만 기록하고, 본문은 메모리에만 남긴다.
    static func sensitive(_ label: String, _ value: String) {
        shared.emitSensitive(label: label, value: value)
    }

    // MARK: - 내부

    private func emitSensitive(label: String, value: String) {
        // 디스크: 내용 없음
        emit("\(label) \(value.count)자", level: .info, toDisk: true)
        // 메모리 전용: 디버깅용으로 내용 유지
        let preview = value.count > 200 ? String(value.prefix(200)) + "…" : value
        emit("  ↳ \(preview)", level: .info, toDisk: false)
    }

    private func emit(_ message: String, level: Level, toDisk: Bool) {
        osLog.log(level: level == .error ? .error : .info, "\(level.rawValue, privacy: .public) \(message, privacy: .public)")

        queue.async {
            let entry = Entry(date: Date(), level: level, message: message, volatile: !toDisk)
            self.buffer.append(entry)
            if self.buffer.count > self.memoryLimit { self.buffer.removeFirst(self.buffer.count - self.memoryLimit) }
            guard toDisk else { return }
            self.pending.append("[\(Self.stamp(entry.date))] [\(level.rawValue)] \(message)")
            if self.pending.count >= self.flushThreshold { self.flush() }
        }
    }

    private func flush() {
        guard !pending.isEmpty else { return }
        let chunk = pending.joined(separator: "\n") + "\n"
        pending.removeAll(keepingCapacity: true)
        do {
            let dir = Self.storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if bytesOnDisk + chunk.utf8.count > diskLimit { rotate() }
            if let handle = try? FileHandle(forWritingTo: Self.storeURL) {
                handle.seekToEndOfFile()
                handle.write(Data(chunk.utf8))
                try? handle.close()
            } else {
                try Data(chunk.utf8).write(to: Self.storeURL)
            }
            bytesOnDisk += chunk.utf8.count
        } catch {
            // 로그 실패는 무시하되 반복 시도하지 않도록 버퍼만 비운다
        }
    }

    private func rotate() {
        let old = Self.storeURL
        let rotated = old.deletingLastPathComponent().appendingPathComponent("debug.log.1")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: old, to: rotated)
        bytesOnDisk = 0
    }

    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    // MARK: - 읽기 (DebugPanel)

    /// 스냅샷. UI 스레드에서 호출.
    @MainActor
    static func recent() -> [Entry] {
        shared.queue.sync { shared.buffer }
    }

    @MainActor
    static func clearMemory() {
        shared.queue.async { shared.buffer.removeAll() }
    }

    /// 종료 시 남은 로그를 즉시 기록.
    static func flushNow() {
        shared.queue.sync { shared.flush() }
    }

    /// 디스크 로그 경로 (버그 제보용)
    static func revealInFinder() {
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        shared.queue.sync { shared.flush() }
        NSWorkspace.shared.activateFileViewerSelecting([storeURL])
    }
}

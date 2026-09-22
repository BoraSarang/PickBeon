import Foundation
import ScreenCaptureKit
import AppKit

extension SCDisplay: @unchecked @retroactive Sendable {}

// 캡쳐 엔진: 원샷은 SCScreenshotManager (스트림 라이프사이클 없음).
@MainActor
final class ScreenCaptureManager: ObservableObject {
    @Published var lastImage: NSImage?

    func captureArea(_ rect: CGRect, display: SCDisplay, pointSize: CGSize) async throws -> NSImage {
        FileLog.log("캡쳐 시작 \(rect) display=\(display.displayID)")
        let w = display.width, h = display.height
        FileLog.log("전체 캡쳐 요청 \(w)x\(h)")
        let full = try await Self.shot(display: display, width: w, height: h)
        FileLog.log("프레임 수신 \(full.width)x\(full.height) (포인트 \(pointSize))")
        // 실측 스케일로 크롭 (디스플레이 스케일 모드와 무관)
        let sx = CGFloat(full.width) / pointSize.width
        let sy = CGFloat(full.height) / pointSize.height
        var px = CGRect(x: rect.minX * sx, y: rect.minY * sy,
                        width: rect.width * sx, height: rect.height * sy)
        px = px.intersection(CGRect(x: 0, y: 0, width: full.width, height: full.height))
        FileLog.log("크롭 \(px) (sx=\(sx) sy=\(sy))")
        guard px.width > 4, px.height > 4,
              let cropped = full.cropping(to: px.integral) else {
            FileLog.log("크롭 실패 \(px)")
            throw PickBeonError.capture("영역 잘라내기 실패", code: "E-MAC-CAPTURE-0002")
        }
        let ns = NSImage(cgImage: cropped, size: rect.size)
        lastImage = ns
        FileLog.log("캡쳐 완료 \(Int(rect.width))x\(Int(rect.height))")
        return ns
    }

    // 8초 타임아웃 (메인 블로킹과 무관하게 동작)
    private nonisolated static func shot(display: SCDisplay, width: Int, height: Int) async throws -> CGImage {
        try await withThrowingTaskGroup(of: CGImage.self) { group in
            group.addTask {
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = width; config.height = height
                config.showsCursor = false
                return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 8_000_000_000)
                throw PickBeonError.capture("화면 프레임을 받지 못했습니다", code: "E-MAC-CAPTURE-0003")
            }
            guard let img = try await group.next() else {
                throw PickBeonError.capture("캡쳐 결과 없음", code: "E-MAC-CAPTURE-0004")
            }
            group.cancelAll()
            return img
        }
    }
}

// 파일 로그: ~/Desktop/PickBeon/debug.log ( unified 로그 미노출 대비 )
enum FileLog {
    static func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        print("[PickBeon] \(msg)")
        do {
            let dir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/PickBeon", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("debug.log")
            if FileManager.default.fileExists(atPath: url.path) {
                let h = try FileHandle(forWritingTo: url)
                h.seekToEndOfFile()
                h.write(Data(line.utf8))
                try h.close()
            } else {
                try Data(line.utf8).write(to: url)
            }
        } catch { /* 로그 실패는 무시 */ }
    }
}

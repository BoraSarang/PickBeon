import Foundation
import ScreenCaptureKit
import AppKit
import VideoToolbox
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import QuartzCore

// GIF 녹화: SCStream 프레임 → 영역 크롭 → 즉시 픽셀 복사 → ImageIO 증분 GIF.
// 영역: top-left points(오버레이 좌표) → 디스플레이 픽셀 top-left.
// surface pool 고황 방지: CGImage를 IOSurface에 묶인 채로 인코더에 보유 금지 — 항상 독립 비트맵으로 복사.
// 정적 화면 대응: wall-clock 고정 간격으로 마지막 성공 프레임을 중복 인코딩(재생 길이 = 프레임/fps).
final class GifRecorder: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var frameCount = 0

    private let fps: Int
    private let maxSeconds: Int // 0 = unlimited
    private let cropRectPx: CGRect
    private let display: SCDisplay
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let encodeQueue = DispatchQueue(label: "PickBeon.GifEncoder")
    private let stateLock = NSLock()
    private let tickQueue = DispatchQueue(label: "PickBeon.GifTick")

    private var stream: SCStream?
    private var encoder: GifEncoder?
    private var startDate: Date?
    private var maxTask: Task<Void, Never>?
    private var tickTimer: DispatchSourceTimer?
    private var elapsedTimer: DispatchSourceTimer?
    private var onStop: (@MainActor (Result<(data: Data, frames: Int, duration: TimeInterval), Error>) -> Void)?
    private var didStop = false
    private var lastAcceptedAt: CFTimeInterval = 0
    private var lastSourceAt: CFTimeInterval = 0
    private var lastGoodFrame: CGImage?
    private var frames = 0
    private var sourceFrames = 0
    private var staticTicks = 0
    private static let maxFrames = 10_000
    private static let maxStaticTicks = 600 // 무변경 프레임 최대 연속 복제 수 안전장치

    private init(display: SCDisplay, fps: Int, maxSeconds: Int, cropRectPx: CGRect) {
        self.display = display
        self.fps = max(4, min(30, fps))
        self.maxSeconds = maxSeconds
        self.cropRectPx = cropRectPx
        super.init()
    }

    /// areaPoints: top-left origin, 오버레이/스크린 points. pointSize: 전체 화면 points.
    static func prepare(areaPoints: CGRect, pointSize: CGSize, display: SCDisplay,
                        fps: Int, maxSeconds: Int) -> GifRecorder {
        let fullPixel = CGSize(width: CGFloat(display.width), height: CGFloat(display.height))
        let sx = fullPixel.width / max(pointSize.width, 1)
        let sy = fullPixel.height / max(pointSize.height, 1)
        var px = CGRect(x: areaPoints.minX * sx, y: areaPoints.minY * sy,
                        width: areaPoints.width * sx, height: areaPoints.height * sy)
        px = px.intersection(CGRect(origin: .zero, size: fullPixel))
        let w = max(2, Int(px.width.rounded()) & ~1)
        let h = max(2, Int(px.height.rounded()) & ~1)
        px = CGRect(x: px.minX.rounded(), y: px.minY.rounded(),
                    width: CGFloat(w), height: CGFloat(h))
        AppLog.log("GIF prepare areaTL=\(areaPoints) pointSize=\(pointSize) cropPx=\(px) scale=\(sx),\(sy)")
        return GifRecorder(display: display, fps: fps, maxSeconds: maxSeconds, cropRectPx: px)
    }

    private func resetState(onStop: @escaping @MainActor (Result<(data: Data, frames: Int, duration: TimeInterval), Error>) -> Void) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.onStop = onStop
        self.didStop = false
        self.lastAcceptedAt = 0
        self.lastSourceAt = 0
        self.lastGoodFrame = nil
        self.frames = 0
        self.sourceFrames = 0
        self.staticTicks = 0
    }

    func start(areaPoints: CGRect, pointSize: CGSize,
               fps: Int, maxSeconds: Int,
               onStop: @escaping @MainActor (Result<(data: Data, frames: Int, duration: TimeInterval), Error>) -> Void) async throws {
        resetState(onStop: onStop)

        let fullPixel = CGSize(width: CGFloat(display.width), height: CGFloat(display.height))
        let exclude: [SCWindow]
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let pid = ProcessInfo.processInfo.processIdentifier
            exclude = content.windows.filter { $0.owningApplication?.processID == pid }
        } catch {
            AppLog.log("SCShareableContent 실패, 제외 윈도우 없음 \(error)")
            exclude = []
        }
        let filter = SCContentFilter(display: display, excludingWindows: exclude)
        let config = SCStreamConfiguration()
        config.width = Int(fullPixel.width)
        config.height = Int(fullPixel.height)
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(fps, 4)))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        // surface pool: 앱이 프레임을 오래 보유하면 스트림이 스탬프 → 크게 잡되 핸들러는 즉시 복사
        config.queueDepth = 12
        config.captureDynamicRange = .SDR

        let enc = GifEncoder(fps: fps, capacity: Self.maxFrames)
        encodeQueue.sync { self.encoder = enc }

        let s = SCStream(filter: filter, configuration: config, delegate: self)
        try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: encodeQueue)
        try await s.startCapture()
        stream = s

        let start = Date()
        await MainActor.run {
            self.startDate = start
            self.isRecording = true
            self.elapsed = 0
            self.frameCount = 0
        }
        AppLog.log("GIF 녹화 시작 \(Int(cropRectPx.width))x\(Int(cropRectPx.height)) fps=\(fps) max=\(maxSeconds)s exclude=\(exclude.count) queueDepth=12")

        startTickTimer()
        startElapsedTimer()

        if maxSeconds > 0 {
            maxTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(maxSeconds) * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                AppLog.log("GIF 최대시간 \(maxSeconds)s 도달 → 자동 중지")
                await self.stop()
            }
        }
    }

    /// 고정 간격 틱: 소스 프레임이 오면 인코딩, 정적이면 마지막 프레임 복제 → 재생 길이 보장
    private func startTickTimer() {
        tickTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: tickQueue)
        let intervalNs = UInt64(1_000_000_000 / UInt64(fps))
        t.schedule(deadline: .now() + .milliseconds(50), repeating: .milliseconds(Int(intervalNs / 1_000_000)))
        t.setEventHandler { [weak self] in
            self?.tickEncode()
        }
        t.resume()
        tickTimer = t
    }

    private func startElapsedTimer() {
        elapsedTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        t.setEventHandler { [weak self] in
            guard let self, let s = self.startDate, self.isRecording else { return }
            self.elapsed = Date().timeIntervalSince(s)
        }
        t.resume()
        elapsedTimer = t
    }

    private func stopTimers() {
        tickTimer?.cancel()
        tickTimer = nil
        elapsedTimer?.cancel()
        elapsedTimer = nil
    }

    /// tickQueue에서 호출. 소스 신규 프레임이 있으면 사용, 없으면 lastGoodFrame 복제.
    private func tickEncode() {
        stateLock.lock()
        guard !didStop, frames < Self.maxFrames else {
            stateLock.unlock()
            return
        }
        let frame: CGImage?
        if lastSourceAt > lastAcceptedAt, let src = lastGoodFrame {
            // 새 소스 프레임이 도착했으면 이번 틱에서 인코딩
            lastAcceptedAt = CACurrentMediaTime()
            sourceFrames += 1
            staticTicks = 0
            frame = src
        } else if let src = lastGoodFrame, staticTicks < Self.maxStaticTicks {
            // 정적 화면: 동일 프레임 복제로 fps 유지
            lastAcceptedAt = CACurrentMediaTime()
            staticTicks += 1
            frame = src
        } else if let src = lastGoodFrame {
            lastAcceptedAt = CACurrentMediaTime()
            frame = src
        } else {
            stateLock.unlock()
            return
        }
        guard let frame, let enc = encoder else {
            stateLock.unlock()
            return
        }
        enc.add(frame)
        frames += 1
        let n = frames
        stateLock.unlock()
        let elapsedSec = startDate.map { Date().timeIntervalSince($0) } ?? 0
        Task { @MainActor in
            self.frameCount = n
            self.elapsed = elapsedSec
        }
    }

    /// 이미 중지 처리 중이면 false 반환
    private func markStopped() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        if didStop { return false }
        didStop = true
        return true
    }

    private func takeCompletion() -> (@MainActor (Result<(data: Data, frames: Int, duration: TimeInterval), Error>) -> Void)? {
        stateLock.lock()
        defer { stateLock.unlock() }
        let cb = onStop
        onStop = nil
        return cb
    }

    private func snapshotCounts() -> (frames: Int, src: Int, static: Int) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (frames, sourceFrames, staticTicks)
    }

    func stop() async {
        guard markStopped() else { return }
        AppLog.log("GIF stop 호출")

        stopTimers()
        await MainActor.run { self.isRecording = false }
        maxTask?.cancel()
        maxTask = nil
        do { try await stream?.stopCapture() } catch { AppLog.log("GIF stopCapture \(error)") }
        stream = nil

        let finished: Data? = await withCheckedContinuation { cont in
            encodeQueue.async {
                let d = self.encoder?.finalize()
                self.encoder = nil
                cont.resume(returning: d)
            }
        }
        let counts = snapshotCounts()
        let duration = startDate.map { Date().timeIntervalSince($0) } ?? 0
        AppLog.log("GIF 녹화 종료 frames=\(counts.frames) src=\(counts.src) static=\(counts.static) \(String(format: "%.1f", duration))s data=\(finished?.count ?? 0)B")
        guard let cb = takeCompletion() else { return }
        if let data = finished, counts.frames > 0 {
            await cb(.success((data, counts.frames, duration)))
        } else {
            await cb(.failure(PickBeonError.capture("GIF 인코딩 실패", code: "E-MAC-GIF-0002")))
        }
    }
}

// MARK: - SCStreamOutput (encodeQueue) — 프레임 수신 즉시 독립 비트맵 복사
extension GifRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, let pb = sampleBuffer.imageBuffer else {
            return
        }
        stateLock.lock()
        let stop = didStop
        stateLock.unlock()
        if stop { return }

        var cg: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pb, options: nil, imageOut: &cg)
        guard let full = cg else { return }

        let crop = cropRectPx.intersection(CGRect(x: 0, y: 0, width: full.width, height: full.height))
        guard crop.width > 4, crop.height > 4, let region = full.cropping(to: crop.integral) else {
            return
        }

        // 독립 비트맵으로 즉시 복사 — IOSurface(pb) 참조를 인코더가 들고 있지 않도록
        guard let owned = Self.detach(region) else { return }

        stateLock.lock()
        lastGoodFrame = owned
        lastSourceAt = CACurrentMediaTime()
        stateLock.unlock()
    }

    /// IOSurface/서브이메이지 참조에서 분리한 소유 CGImage
    private static func detach(_ image: CGImage) -> CGImage? {
        let w = image.width
        let h = image.height
        guard w > 0, h > 0 else { return nil }
        // 다운스케일: 최대변 800
        let maxSide = 800
        let scale = min(1.0, Double(maxSide) / Double(max(w, h)))
        let outW = max(2, Int(Double(w) * scale))
        let outH = max(2, Int(Double(h) * scale))
        guard let ctx = CGContext(
            data: nil,
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: outW, height: outH))
        return ctx.makeImage()
    }
}

// MARK: - SCStreamDelegate
extension GifRecorder: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        AppLog.log("GIF stream error \(error)")
        guard markStopped() else { return }
        stopTimers()
        maxTask?.cancel()
        let cb = takeCompletion()
        Task { @MainActor in
            self.isRecording = false
            self.stream = nil
            self.encodeQueue.async { self.encoder = nil }
            await cb?(.failure(PickBeonError.capture("GIF 녹화 중 오류", code: "E-MAC-GIF-0001")))
        }
    }
}

// MARK: - GIF 인코더 (ImageIO 증분 기록, encodeQueue/tickQueue 공유 — stateLock 내부에서만 호출 X, encode 직렬은 add가 상주)
final class GifEncoder: @unchecked Sendable {
    private let data = NSMutableData()
    private let dest: CGImageDestination?
    private let frameDelay: TimeInterval
    private let lock = NSLock()

    init(fps: Int, capacity: Int) {
        frameDelay = 1.0 / TimeInterval(max(fps, 4))
        dest = CGImageDestinationCreateWithData(
            data, UTType.gif.identifier as CFString, max(capacity, 2), nil)
        if let dest {
            let props: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
            ]
            CGImageDestinationSetProperties(dest, props as CFDictionary)
        }
    }

    func add(_ frame: CGImage) {
        lock.lock()
        defer { lock.unlock() }
        guard let dest else { return }
        let props: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime: frameDelay
            ]
        ]
        CGImageDestinationAddImage(dest, frame, props as CFDictionary)
    }

    func finalize() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard let dest, CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}

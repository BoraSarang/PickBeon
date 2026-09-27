import Foundation
import Vision
import AppKit
import QuartzCore

struct OCRLine: Identifiable {
    let id = UUID()
    let text: String
    let box: CGRect // top-left 정규화 좌표
    let confidence: Float
}

@MainActor
final class OCRService: ObservableObject {
    @Published var lines: [OCRLine] = []

    /// [FIX] Vision 의 `VNImageRequestHandler.perform` 는 동기·고비용 호출이다.
    /// 과거엔 `withCheckedThrowingContinuation` 본문(= 호출 스레드 = 메인)에서 그대로 실행돼
    /// **텍스트가 많은 화면을 캡처하면 OCR 이 54초 동안 메인 스레드를 정지시켰다.**
    /// 앱이 완전히 얼어 사용자가 "멍때리는" 원인이 이것이었으므로 전용 큐로 분리한다.
    private nonisolated static let queue = DispatchQueue(label: "PickBeon.OCR", qos: .userInitiated)
    /// Vision 은 language correction 모델 로딩 등으로 병적으로 오래 걸릴 수 있다.
    /// 무한 대기를 막기 위한 상한.
    private static let timeoutNs: UInt64 = 12_000_000_000

    /// 런타임 재현성 확보: Vision 기본 인식 언어는 환경 따라 달라져
    /// "왜 이 화면은 되고 저 화면은 안 되지" 가 되므로 지원 목록을 명시한다.
    private nonisolated static let recognitionLanguages: [String] = {
        let want = ["ko-KR", "en-US", "ja-JP", "zh-Hans", "zh-Hant", "de-DE", "fr-FR", "es-ES"]
        let available = Set((try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? [])
        let usable = want.filter { available.contains($0) }
        AppLog.log("OCR 인식 언어 \(usable.joined(separator: ",")) (지원 \(available.count)개)")
        return usable.isEmpty ? ["en-US"] : usable
    }()

    func recognize(_ image: NSImage) async throws -> [OCRLine] {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PickBeonError.ocr("이미지 변환 실패", code: "E-MAC-OCR-0002")
        }
        let started = CACurrentMediaTime()
        DebugLogger.shared.info(feature: "OCR", "Vision 인식 시작 \(cg.width)x\(cg.height)px")
        AppLog.log("OCR 시작 \(cg.width)x\(cg.height)px langs=\(Self.recognitionLanguages.joined(separator: ","))")

        let out = try await Self.perform(cg: cg)

        let ms = (CACurrentMediaTime() - started) * 1000
        AppLog.log("OCR 완료 \(out.count)줄 \(String(format: "%.0f", ms))ms")
        DebugLogger.shared.cache("OCR \(out.count)줄 \(String(format: "%.0f", ms))ms")
        lines = out
        return out
    }

    private static func perform(cg: CGImage) async throws -> [OCRLine] {
        // TranslationService.runWithTimeout 과 동일한 task-group 타임아웃 패턴
        try await withThrowingTaskGroup(of: [OCRLine].self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { cont in
                    queue.async {
                        let req = VNRecognizeTextRequest { req, error in
                            if let error {
                                AppLog.log("Vision 오류 \(error.localizedDescription)")
                                cont.resume(throwing: PickBeonError.ocr("Vision 인식 오류", code: "E-MAC-OCR-0001"))
                                return
                            }
                            var result: [OCRLine] = []
                            for o in (req.results as? [VNRecognizedTextObservation] ?? []) {
                                guard let top = o.topCandidates(1).first else { continue }
                                // Vision bottom-left → top-left 변환
                                let b = o.boundingBox
                                let conv = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
                                result.append(OCRLine(text: top.string, box: conv, confidence: top.confidence))
                            }
                            cont.resume(returning: result)
                        }
                        req.recognitionLevel = .accurate
                        req.usesLanguageCorrection = true
                        req.recognitionLanguages = recognitionLanguages
                        do {
                            try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
                        } catch {
                            cont.resume(throwing: PickBeonError.ocr("Vision 인식 실패", code: "E-MAC-OCR-0001"))
                        }
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNs)
                throw PickBeonError.ocr("텍스트 인식 시간이 초과되었습니다", code: "E-MAC-OCR-0003")
            }
            guard let first = try await group.next() else {
                throw PickBeonError.ocr("인식 결과가 없습니다", code: "E-MAC-OCR-0001")
            }
            group.cancelAll()
            return first
        }
    }
}

import Foundation
import Vision
import AppKit

struct OCRLine: Identifiable {
    let id = UUID()
    let text: String
    let box: CGRect // top-left 정규화 좌표
    let confidence: Float
}

@MainActor
final class OCRService: ObservableObject {
    @Published var lines: [OCRLine] = []

    func recognize(_ image: NSImage) async throws -> [OCRLine] {
        DebugLogger.shared.info(feature: "OCR", "Vision 인식 시작")
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PickBeonError.ocr("이미지 변환 실패", code: "E-MAC-OCR-0002")
        }
        return try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                var out: [OCRLine] = []
                for o in (req.results as? [VNRecognizedTextObservation] ?? []) {
                    guard let top = o.topCandidates(1).first else { continue }
                    // Vision bottom-left → top-left 변환
                    let b = o.boundingBox
                    let conv = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
                    out.append(OCRLine(text: top.string, box: conv, confidence: top.confidence))
                }
                Task { @MainActor in self.lines = out }
                DebugLogger.shared.cache("OCR \(out.count)줄")
                cont.resume(returning: out)
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            let h = VNImageRequestHandler(cgImage: cg, options: [:])
            do { try h.perform([req]) } catch { cont.resume(throwing: error) }
        }
    }
}

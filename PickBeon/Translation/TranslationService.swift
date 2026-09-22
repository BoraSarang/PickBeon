import Foundation
import Translation

// 번역 엔진: Apple Translation만 (MVP). BYOK 자리 예약.
// TranslationSession 블로킹 대비: 작업은 detached + 30초 타임아웃. 메인은 절대 안 막음.
@MainActor
final class TranslationService: ObservableObject {
    @Published var result: String = ""
    @Published var isTranslating = false

    func translate(_ text: String, polite: Bool) async throws -> String {
        FileLog.log("번역 시작: \(text.prefix(30))")
        isTranslating = true
        defer { isTranslating = false }
        let targetID = AppSettings.shared.effectiveTargetID()
        // 세션은 메인에서 (검증된 패턴). 타임아웃은 별도 Task.
        let out: String = try await withCheckedThrowingContinuation { cont in
            let box = TransBox()
            Task { @MainActor in
                do {
                    let s = try await Self.doTranslate(text: text, targetID: targetID)
                    if !box.done { box.done = true; cont.resume(returning: s) }
                } catch {
                    if !box.done { box.done = true; cont.resume(throwing: error) }
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !box.done {
                    box.done = true
                    FileLog.log("번역 시간 초과")
                    cont.resume(throwing: PickBeonError.trans("번역 시간 초과 — 언어팩 확인 필요", code: "E-MAC-TRANS-0003"))
                }
            }
        }
        var final = out
        if !polite { final = final.replacingOccurrences(of: "습니다", with: "어").replacingOccurrences(of: "입니다", with: "야") }
        result = final
        FileLog.log("번역 완료")
        return final
    }

    private static func doTranslate(text: String, targetID: String) async throws -> String {
        if #available(macOS 26, *) {
            let target = Locale.Language(identifier: targetID)
            let sourceID = targetID == "ko" ? "en" : "ko"
            let source = Locale.Language(identifier: sourceID)
            // 세션과 동일한 명시 쌍으로 확인 (자동감지 오판 방지)
            let avail = LanguageAvailability()
            let st = await avail.status(from: source, to: target)
            FileLog.log("언어팩 상태 \(sourceID)->\(targetID) \(st)")
            guard st == .installed else {
                throw PickBeonError.trans("번역 언어팩 필요", code: "E-MAC-TRANS-0005")
            }
            let session = TranslationSession(installedSource: source, target: target)
            try await session.prepareTranslation()
            FileLog.log("번역 세션 준비됨")
            let resp = try await session.translate(text)
            return resp.targetText
        } else {
            FileLog.log("번역 미지원 버전, 원문 반환")
            return text
        }
    }
}

private final class TransBox: @unchecked Sendable {
    var done = false
}

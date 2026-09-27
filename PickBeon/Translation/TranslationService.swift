import Foundation
import Translation

// 번역 엔진: Apple Translation만 (MVP). BYOK 자리 예약.
// TranslationSession 블로킹 대비: timeout은 withThrowingTaskGroup으로 격리. 메인은 절대 안 막음.
//
// [P0-1] SDK 감사 결과(Apple Swift 6.4 / macOS 27 SDK):
//   - TranslationSession 의 public init 은 `installedSource:target:` (macOS 26.0+) 두 개뿐.
//     → 앱처럼 백그라운드 파이프라인에서 세션을 직접 만들려면 macOS 26+ 가 필수.
//   - macOS 15 에서 세션을 얻는 유일한 경로는 SwiftUI `View.translationTask` (macOS 15.0+)
//     로, View 계층 안에서만 동작한다.
//   즉 `#available(macOS 26, *)` 게이트 자체는 불가피했으나, 과거 else 분기의
//   `return text` 가 "원문을 번역인 것처럼 성공"시켜差异化 기능이 통짜로 no-op 이었다.
// → 게이트는 유지하되 미지원 경로를 반드시 에러로 만든다(조용한 성공 금지).
@MainActor
final class TranslationService: ObservableObject {
    @Published var result: String = ""
    @Published var isTranslating = false

    private static let timeoutNs: UInt64 = 30_000_000_000

    /// 독립 세션 생성(백그라운드 파이프라인) 가능 여부. macOS 26+ 에서만 true.
    /// macOS 15~25 는 SwiftUI translationTask 경로가 필요하며 TODO-백로그다.
    static var isStandaloneSessionSupported: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// UI 게이팅용. 미지원이면 번역 진입점을 비활성화하고 사유를 노출한다.
    static var unsupportedReason: String? {
        isStandaloneSessionSupported ? nil : String(localized: "이 macOS 버전에서는 번역을 사용할 수 없습니다 (macOS 26 이상 필요)")
    }

    func translate(_ text: String, polite: Bool) async throws -> String {
        FileLog.log("번역 시작: \(text.prefix(30))")
        isTranslating = true
        defer { isTranslating = false }
        let targetID = AppSettings.shared.effectiveTargetID()
        let out = try await Self.runWithTimeout(
            timeoutNs: Self.timeoutNs,
            operation: { try await Self.doTranslate(text: text, targetID: targetID) }
        )
        let final = ToneShaper.apply(out, polite: polite)
        result = final
        FileLog.log("번역 완료")
        return final
    }

    /// 타임아웃은 별도 태스크로 격리. ScreenCaptureManager.shot 와 동일한 패턴.
    private static func runWithTimeout(
        timeoutNs: UInt64, operation: @escaping @Sendable () async throws -> String
    ) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNs)
                throw PickBeonError.trans("번역 시간 초과 — 언어팩 확인 필요", code: "E-MAC-TRANS-0003")
            }
            guard let first = try await group.next() else {
                throw PickBeonError.trans("번역 결과 없음", code: "E-MAC-TRANS-0003")
            }
            group.cancelAll()
            return first
        }
    }

    private static func doTranslate(text: String, targetID: String) async throws -> String {
        guard #available(macOS 26, *) else {
            // [P0-1] 과거엔 여기서 원문을 반환해 '번역 성공'으로 위장했다. 반드시 실패시킨다.
            FileLog.log("번역 미지원 버전 — 원문 반환 금지, 에러 처리")
            throw PickBeonError.trans(
                "이 macOS 버전에서는 번역을 사용할 수 없습니다 (macOS 26 이상 필요)",
                code: "E-MAC-TRANS-0002"
            )
        }
        let target = Locale.Language(identifier: targetID)
        // 소스는 대상 언어 반대편으로 가정 (ko↔en 전제). 자동 감지로 전환은 P1 백로그.
        let sourceID = targetID == "ko" ? "en" : "ko"
        let source = Locale.Language(identifier: sourceID)

        let status = await LanguageAvailability().status(from: source, to: target)
        FileLog.log("언어팩 상태 \(sourceID)->\(targetID) \(status)")
        guard status == .installed else {
            throw PickBeonError.trans("번역 언어팩 필요", code: "E-MAC-TRANS-0005")
        }

        let session = TranslationSession(installedSource: source, target: target)
        do {
            try await session.prepareTranslation()
        } catch {
            FileLog.log("prepareTranslation 실패 \(error)")
            throw PickBeonError.trans("번역 준비 실패", code: "E-MAC-TRANS-0004")
        }
        FileLog.log("번역 세션 준비됨")

        do {
            let resp = try await session.translate(text)
            return resp.targetText
        } catch {
            FileLog.log("session.translate 실패 \(error)")
            throw PickBeonError.trans("번역 실패", code: "E-MAC-TRANS-0001")
        }
    }
}

// MARK: - 말투 변환 (휴리스틱)
// 진정한 억양 변환이 아니라 한국어 존댓말 어미의 반말 대응 치환이다.
// 과거 구현은 "습니다"→"어" 로 바꿔.Exists/없습니다를 "있이어/없이어" 로 망가뜨렸다
// (correct: 있습니다→있어요, 문제입니다→문제이야, but 먹입니다→먹이야 오답).
// 아래 두 대응은 결합 규칙상 안전한 축만 건드린다.
//
// [P1 백로그 pickbeon-tnq] 진짜 반말/존댓말 전환이 필요해지면 규칙 치환을 접고
// 프롬프트 기반 재번역(또는 LLM/BYOK)으로 교체한다.
enum ToneShaper {
    /// (존댓말 어미, 반말 대응).
    ///  - 습니다 → 어요 : 있/없/그렇- 계열 전부 안전 (습 + 여)
    ///  - 입니다 → 이에요 : 명사·형용사 서술어. '-입니다' 자동사(먹입니다)만 오답이나 Rare.
    private static let pairs: [(String, String)] = [
        ("습니다", "어요"),
        ("입니다", "이에요"),
    ]

    static func apply(_ text: String, polite: Bool) -> String {
        guard !polite else { return text }
        var out = text
        for (from, to) in pairs {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out
    }
}

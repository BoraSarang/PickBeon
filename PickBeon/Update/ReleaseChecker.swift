import Foundation

// GitHub Releases 기반 업데이트 확인 (Sparkle 없이 — 가이드 채택: 확인 → 릴리스 페이지 이동)
public struct GitHubRelease: Codable, Sendable, Equatable {
    public let tagName: String
    public let htmlURL: String
    public let name: String?
    public let body: String?
    /// 프리릴리스 제외용 (익명 요청에서는 draft 는 안 보지만 prerelease 는 보인다)
    public let prerelease: Bool?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
        case prerelease
    }
}

public enum ReleaseError: Error {
    case notConfigured
    /// 저장소는 공개인데 게시된 릴리스가 없음 (정상적인 초기 상태)
    case noPublishedRelease
    /// 404/403 — 저장소가 비공개이거나 존재하지 않음
    case repoNotAccessible
    case fetchFailed
    case badStatus(Int)
}

public enum ReleaseChecker {
    /// GitHub 공개 저장소 "Owner/Repo". private 이면 공개 API 로 조회할 수 없어
    /// 항상 repoNotAccessible 이 된다. 설정>업데이트 에서 변경 가능.
    public static var repository: String {
        get {
            let saved = UserDefaults.standard.string(forKey: "updateRepoSlug") ?? ""
            return saved.isEmpty ? defaultRepository : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: "updateRepoSlug") }
    }
    public static let defaultRepository = "BoraSarang/PickBeon"

    public static var isConfigured: Bool { !repository.isEmpty && repository.contains("/") }

    /// 최신 게시 릴리스 1건.
    ///
    /// [2026-09-27] `/releases/latest` 대신 `/releases?per_page=1` 을 쓴다.
    /// latest 엔드포인트는 "릴리스 없음" 과 "저장소 비공개/없음" 둘 다 404 로 응답해
    /// 원인을 구분할 수 없었다. 목록 엔드포인트는
    ///   - 비공개/없음  → 404/403
    ///   - 릴리스 0건   → 200 + `[]`
    /// 로 명확히 갈린다.
    public static func fetchLatest() async throws -> GitHubRelease {
        guard isConfigured else { throw ReleaseError.notConfigured }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=5")!)
        request.timeoutInterval = 12
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        request.setValue("PickBeon/\(ver)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ReleaseError.fetchFailed
        }
        guard let http = response as? HTTPURLResponse else { throw ReleaseError.fetchFailed }
        // 404: 비공개 또는 없음 / 403: rate limit 등 접근 불가
        if http.statusCode == 404 || http.statusCode == 403 { throw ReleaseError.repoNotAccessible }
        guard (200...299).contains(http.statusCode) else { throw ReleaseError.badStatus(http.statusCode) }

        let list = (try? JSONDecoder().decode([GitHubRelease].self, from: data)) ?? []
        guard let latest = list.first(where: { $0.prerelease != true }) else {
            throw ReleaseError.noPublishedRelease
        }
        return latest
    }

    /// "v1.2.3" / "1.2.3" → [1,2,3]. 숫자 조각만 비교.
    public static func versionComponents(_ tag: String) -> [Int] {
        tag.drop(while: { $0 == "v" || $0 == "V" })
            .split(separator: ".")
            .compactMap { Int($0) }
    }

    /// 태그가 현재 번들 버전보다 크면 true.
    public static func isNewer(tag: String, than current: String) -> Bool {
        let a = versionComponents(tag)
        let b = versionComponents(current)
        guard !a.isEmpty, !b.isEmpty else { return false }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    public static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

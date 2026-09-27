import Foundation

// GitHub Releases 기반 업데이트 확인 (Sparkle 없이 — 가이드 채택: 확인 → 릴리스 페이지 이동)
public struct GitHubRelease: Codable, Sendable, Equatable {
    public let tagName: String
    public let htmlURL: String
    public let name: String?
    public let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
    }
}

public enum ReleaseError: Error {
    case notConfigured
    case noPublishedRelease
    /// 404 는 "존재하지 않음" 과 "권한 없음(private)" 이 구분되지 않는다.
    /// 저장소가 private 인데 공개 API 로 조회하면 항상 이 값이 된다.
    case repoNotAccessible
    case fetchFailed
    case badStatus(Int)
}

public enum ReleaseChecker {
    /// GitHub 공개 저장소 "Owner/Repo". private 저장소는 공개 API 로 조회할 수 없어
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

    public static func fetchLatest() async throws -> GitHubRelease {
        guard isConfigured else { throw ReleaseError.notConfigured }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
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
        // 404: 미존재 / 비공개(private) / 릴리스 없음 — 셋을 구분할 수 없다.
        if http.statusCode == 404 || http.statusCode == 403 { throw ReleaseError.repoNotAccessible }
        guard (200...299).contains(http.statusCode) else { throw ReleaseError.badStatus(http.statusCode) }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
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

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
    case fetchFailed
    case badStatus(Int)
}

public enum ReleaseChecker {
    /// GitHub 공개 저장소 "Owner/Repo" (미설정 시 확인 불가로 표시)
    public static let repository = "borasarang/PickBeon"

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
        if http.statusCode == 404 { throw ReleaseError.noPublishedRelease }
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

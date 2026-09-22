import Foundation
import SwiftUI
import AppKit

// 업데이트 상태 + 주기 + 마지막 확인 시각(UserDefaults 영속화)
public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable(tag: String, htmlURL: String, notes: String)
    case unavailable(String)
}

public enum UpdateCheckFrequency: String, CaseIterable, Identifiable, Sendable {
    case atLaunch
    case daily
    case weekly
    case never

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .atLaunch: String(localized: "실행 시")
        case .daily: String(localized: "매일")
        case .weekly: String(localized: "매주")
        case .never: String(localized: "안 함")
        }
    }
}

extension Notification.Name {
    static let showUpdateSheet = Notification.Name("PickBeon.showUpdateSheet")
    static let updateStateChanged = Notification.Name("PickBeon.updateStateChanged")
}

@MainActor
final class UpdateCenter: ObservableObject {
    static let shared = UpdateCenter()

    @Published var state: UpdateState = .idle
    @Published var lastCheckedAt: Date?
    @Published var frequencyRaw: String = UserDefaults.standard.string(forKey: "updateCheckFrequency") ?? UpdateCheckFrequency.weekly.rawValue {
        didSet { UserDefaults.standard.set(frequencyRaw, forKey: "updateCheckFrequency") }
    }

    private var launchDate = Date()
    private var checking = false

    var frequency: UpdateCheckFrequency {
        UpdateCheckFrequency(rawValue: frequencyRaw) ?? .weekly
    }

    var availableUpdate: (tag: String, htmlURL: String, notes: String)? {
        if case let .updateAvailable(tag, htmlURL, notes) = state {
            return (tag, htmlURL, notes)
        }
        return nil
    }

    private init() {
        if let t = UserDefaults.standard.object(forKey: "updateLastChecked") as? Date {
            lastCheckedAt = t
        }
        if UserDefaults.standard.string(forKey: "updateCheckFrequency") == nil {
            UserDefaults.standard.set(UpdateCheckFrequency.weekly.rawValue, forKey: "updateCheckFrequency")
        }
    }

    /// 주기에 맞으면 확인. 실행 시와 메뉴 팝오버 열 때 호출.
    func maybeAutoCheckForUpdate() async {
        guard frequency != .never else { return }
        if case .checking = state { return }
        guard ReleaseChecker.isConfigured else {
            if state == .idle {
                state = .unavailable(String(localized: "업데이트 리포지토리가 설정되지 않았습니다"))
            }
            return
        }
        let now = Date()
        let due: Bool
        switch frequency {
        case .never: due = false
        case .atLaunch:
            due = lastCheckedAt.map { $0 < launchDate } ?? true
        case .daily:
            due = lastCheckedAt.map { now.timeIntervalSince($0) >= 86_400 } ?? true
        case .weekly:
            due = lastCheckedAt.map { now.timeIntervalSince($0) >= 604_800 } ?? true
        }
        guard due else { return }
        await checkForUpdate()
    }

    func checkForUpdate() async {
        guard !checking else { return }
        checking = true
        state = .checking
        defer {
            checking = false
            NotificationCenter.default.post(name: .updateStateChanged, object: nil)
        }
        do {
            let release = try await ReleaseChecker.fetchLatest()
            markChecked()
            if ReleaseChecker.isNewer(tag: release.tagName, than: ReleaseChecker.currentVersion) {
                state = .updateAvailable(
                    tag: release.tagName,
                    htmlURL: release.htmlURL,
                    notes: release.body ?? ""
                )
            } else {
                state = .upToDate
            }
        } catch ReleaseError.noPublishedRelease {
            markChecked()
            state = .unavailable(String(localized: "게시된 릴리스가 없습니다"))
        } catch ReleaseError.notConfigured {
            state = .unavailable(String(localized: "업데이트 리포지토리가 설정되지 않았습니다"))
        } catch {
            markChecked()
            state = .unavailable(String(localized: "업데이트를 확인할 수 없습니다"))
        }
        NotificationCenter.default.post(name: .updateStateChanged, object: nil)
    }

    private func markChecked() {
        let now = Date()
        lastCheckedAt = now
        UserDefaults.standard.set(now, forKey: "updateLastChecked")
    }
}

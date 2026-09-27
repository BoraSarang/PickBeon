import SwiftUI

// GifJot식 사이드바 설정 (custom 토큰). 자동 저장. 검색 필터 동작.
struct SettingsView: View {
    @ObservedObject var s = AppSettings.shared
    @ObservedObject private var uc = UpdateCenter.shared
    @State private var sel = 0
    @State private var search = ""

    private let navs: [(Int, String, String)] = [
        (0, "scissors", "캡쳐"),
        (1, "globe", "번역"),
        (2, "keyboard", "단축키"),
        (3, "clock", "기록"),
        (4, "paintbrush", "외관"),
        (5, "arrow.down.circle", "업데이트"),
    ]

    private var visibleNavs: [(Int, String, String)] {
        guard !search.isEmpty else { return navs }
        return navs.filter { $0.2.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.line).frame(width: 1)
            content
        }
        .frame(width: 640, height: 430)
        .background(Theme.bg)
    }

    // MARK: 사이드바
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                Text("◈")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Theme.hero)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text("PickBeon").font(Theme.font(13, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(String(localized: "설정")).font(Theme.font(11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .padding(.top, 4)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                TextField(String(localized: "설정 검색"), text: $search)
                    .textFieldStyle(.plain)
                    .font(Theme.font(12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
            .padding(.horizontal, 2)
            .padding(.bottom, 8)

            ForEach(visibleNavs, id: \.0) { i, icon, title in
                Nav(i, icon, title)
            }
            if visibleNavs.isEmpty {
                Text(String(localized: "일치하는 메뉴 없음"))
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
            }
            Spacer()
        }
        .frame(width: 190)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.surface)
    }

    // MARK: 본문
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sel == 0 {
                SHead(String(localized: "캡쳐"), String(localized: "무엇을 캡쳐하고, 캡쳐 후 어떻게 끝낼지."))
                SCard(String(localized: "캡쳐 후 동작"), String(localized: "결과 카드 / 에디터 / 클립보드 중 선택")) {
                    Picker("", selection: $s.afterCapture) {
                        Text(String(localized: "번역 카드")).tag("card")
                        Text(String(localized: "에디터 열기")).tag("editor")
                        Text(String(localized: "클립보드만")).tag("clipboard")
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .tint(Theme.accent)
                }
                SCard(String(localized: "원본 이미지도 저장"), String(localized: "PNG 썸네일을 기록에 함께 보관")) {
                    Toggle("", isOn: $s.saveImages).labelsHidden().tint(Theme.accent)
                }
                SCard(String(localized: "번역 박스 기본 표시"), String(localized: "에디터에서 Vision 박스 켜기")) {
                    Toggle("", isOn: $s.overlayOn).labelsHidden().tint(Theme.accent)
                }
                SCard(String(localized: "GIF 프레임레이트"), String(localized: "⌥⌘G 녹화 fps (4~30)")) {
                    Picker("", selection: $s.gifFps) {
                        Text("8").tag(8)
                        Text("10").tag(10)
                        Text("15").tag(15)
                        Text("20").tag(20)
                    }
                    .labelsHidden()
                    .frame(width: 90)
                    .tint(Theme.accent)
                }
                SCard(String(localized: "GIF 최대 시간"), String(localized: "초과 시 자동 중지")) {
                    Picker("", selection: $s.gifMaxSeconds) {
                        Text(String(format: String(localized: "%d초"), 10)).tag(10)
                        Text(String(format: String(localized: "%d초"), 30)).tag(30)
                        Text(String(localized: "무제한")).tag(0)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    .tint(Theme.accent)
                }
                SCard(String(localized: "GIF 후 클립보드 복사"), String(localized: "끄면 저장만")) {
                    Toggle("", isOn: $s.gifAutoCopy).labelsHidden().tint(Theme.accent)
                }
                SCard(String(localized: "GIF 프레임 번역"), String(localized: "종료 후 주요 프레임 OCR→번역")) {
                    Toggle("", isOn: $s.gifFrameTranslate).labelsHidden().tint(Theme.accent)
                }
            } else if sel == 1 {
                SHead(String(localized: "번역"), String(localized: "언어와 말투, 엔진."))
                SCard(String(localized: "UI 언어"), String(localized: "기본은 시스템 언어 · 변경은 다음 실행 시 적용")) {
                    Picker("", selection: $s.uiLanguage) {
                        Text(String(localized: "시스템 기본")).tag("system")
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                    }
                    .labelsHidden().frame(width: 130).tint(Theme.accent)
                }
                SCard(String(localized: "번역 타겟"), String(localized: "기본은 시스템 언어")) {
                    Picker("", selection: $s.tgtLang) {
                        Text(String(localized: "시스템 언어")).tag("system")
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                    }
                    .labelsHidden().frame(width: 130).tint(Theme.accent)
                }
                SCard(String(localized: "정중한 말투"), String(localized: "끄면 반말에 가깝게")) {
                    Toggle("", isOn: $s.politeTone).labelsHidden().tint(Theme.accent)
                }
                Text(String(localized: "엔진: Apple Translation (온디바이스). BYOK는 추후 재검토."))
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            } else if sel == 2 {
                SHead(String(localized: "단축키"), String(localized: "전역 단축키 (Carbon, 추가 권한 없음)."))
                SCard(String(localized: "영역 Pick"), "") { KeyCap(text: "⌘⇧X") }
                SCard(String(localized: "텍스트 선택 번역"), "") { KeyCap(text: "⌘⌥Z") }
                SCard(String(localized: "GIF 녹화 / 중지"), "") { KeyCap(text: "⌥⌘G") }
                SCard(String(localized: "텍스트 바로 복사"), String(localized: "OCR → 클립보드")) { KeyCap(text: "⌥⌘C") }
                SCard(String(localized: "창 캡쳐"), String(localized: "창 클릭 선택")) { KeyCap(text: "⌥⌘W") }
                SCard(String(localized: "오버레이: 마지막 영역"), "") { KeyCap(text: "R") }
                SCard(String(localized: "오버레이: 확정(번역)"), "") { KeyCap(text: "Enter") }
                SCard(String(localized: "오버레이: 즉시 번역"), String(localized: "드래그 중 누르기")) { KeyCap(text: "⌥ + 드래그") }
                SCard(String(localized: "오버레이: 취소"), "") { KeyCap(text: "Esc") }
                SCard(String(localized: "기록 붙여넣기"), "") { KeyCap(text: "⌘1~5") }
            } else if sel == 3 {
                SHead(String(localized: "기록"), String(localized: "클립보드 + 번역 히스토리 보관."))
                SCard(String(localized: "저장 개수"), String(localized: "핀은 개수에서 제외")) {
                    Picker("", selection: $s.historyLimitRaw) {
                        Text("20").tag(20)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                        Text(String(localized: "무제한")).tag(-1)
                    }
                    .labelsHidden().frame(width: 110).tint(Theme.accent)
                }
                SCard(String(localized: "이미지 저장"), String(localized: "PNG 썸네일 보관")) {
                    Toggle("", isOn: $s.saveImages).labelsHidden().tint(Theme.accent)
                }
                SCard(String(localized: "암호화"), String(localized: "곧 지원 예정 (AES-256-GCM)")) {
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                        .disabled(true)
                        .opacity(0.4)
                }
            } else if sel == 5 {
                SHead(String(localized: "업데이트"), String(localized: "GitHub Releases에서 새 버전을 확인합니다."))
                SCard(String(localized: "현재 버전"), "PickBeon \(ReleaseChecker.currentVersion)") {
                    Text(ReleaseChecker.currentVersion)
                        .font(Theme.font(12, weight: .semibold, mono: true))
                        .foregroundStyle(Theme.textSecondary)
                }
                SCard(String(localized: "업데이트 확인 주기"), String(localized: "실행 시·팝오버 열 때 주기에 맞춰 자동 확인")) {
                    Picker("", selection: Binding(
                        get: { uc.frequencyRaw },
                        set: { uc.frequencyRaw = $0 }
                    )) {
                        ForEach(UpdateCheckFrequency.allCases) { f in
                            Text(f.label).tag(f.rawValue)
                        }
                    }
                    .labelsHidden().frame(width: 110).tint(Theme.accent)
                }
                SCard(String(localized: "마지막 확인"), "") {
                    if let d = uc.lastCheckedAt {
                        Text(d, style: .relative)
                            .font(Theme.font(12))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(String(localized: "아직 없음"))
                            .font(Theme.font(12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                HStack(spacing: 10) {
                    Button {
                        Task { await uc.checkForUpdate() }
                    } label: {
                        if case .checking = uc.state {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(String(localized: "지금 확인"), systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled({ if case .checking = uc.state { return true }; return false }())
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)

                    updateStatusLabel
                    Spacer()
                }
                .padding(.bottom, 4)

                if case let .updateAvailable(tag, htmlURL, notes) = uc.state {
                    Button(String(localized: "업데이트 시트 열기")) {
                        _ = tag; _ = htmlURL; _ = notes
                        AppCoordinator.shared.showUpdateSheet()
                    }
                    .font(Theme.font(12, weight: .semibold))
                }
                Text(String(localized: "인앱 자동 설치 없음 — 릴리스 페이지에서 내려받아 교체합니다."))
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            } else {
                SHead(String(localized: "외관"), String(localized: "카드와 오버레이 표시."))
                SCard(String(localized: "번역 박스 기본 표시"), String(localized: "에디터 OCR 박스")) {
                    Toggle("", isOn: $s.overlayOn).labelsHidden().tint(Theme.accent)
                }
                SCard(String(localized: "라이트/다크"), String(localized: "시스템 설정을 따릅니다")) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            HStack {
                Text(String(localized: "자동으로 저장됨."))
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button(String(localized: "설정 초기화")) {
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                }
                .font(Theme.font(12))
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg)
    }

    private var updateStatusLabel: some View {
        Group {
            switch uc.state {
            case .idle:
                Text(String(localized: "대기 중"))
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            case .checking:
                Text(String(localized: "확인 중…"))
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            case .upToDate:
                Label(String(localized: "최신 버전입니다"), systemImage: "checkmark.circle")
                    .font(Theme.font(12)).foregroundStyle(Theme.ok)
            case let .updateAvailable(tag, _, _):
                Button {
                    AppCoordinator.shared.showUpdateSheet()
                } label: {
                    Text(String(format: String(localized: "%@ 사용 가능"), tag))
                        .font(Theme.font(12, weight: .semibold))
                        .foregroundStyle(Theme.warn)
                }
                .buttonStyle(.plain)
            case let .unavailable(msg):
                Text(msg)
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func Nav(_ i: Int, _ icon: String, _ t: String) -> some View {
        Button {
            sel = i
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(sel == i ? Theme.accent : Theme.textSecondary)
                Text(t)
                    .font(Theme.font(13, weight: sel == i ? .semibold : .regular))
                    .foregroundStyle(sel == i ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sel == i ? Theme.accent.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func SHead(_ t: String, _ d: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(Theme.font(16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(d).font(Theme.font(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 14)
    }

    private func SCard<V: View>(_ t: String, _ d: String, @ViewBuilder _ c: () -> V) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !d.isEmpty {
                    Text(d).font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            c()
        }
        .padding(13)
        .background(Theme.row)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.line, lineWidth: 1))
        .padding(.bottom, 10)
    }
}

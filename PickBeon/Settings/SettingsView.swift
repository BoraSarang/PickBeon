import SwiftUI

// GifJot식 사이드바 설정 (custom 토큰). 자동 저장. 검색 필터 동작.
struct SettingsView: View {
    @ObservedObject var s = AppSettings.shared
    @ObservedObject private var uc = UpdateCenter.shared
    @State private var sel = 0
    @State private var search = ""
    /// 설정 초기화 확인 (파괴적)
    @State private var confirmReset = false
    /// 초기화 후 UI 를 강제로 다시 그리기 위한 트리거
    @State private var resetNonce = 0
    /// 업데이트 확인 대상 저장소 (기본값 = ReleaseChecker.defaultRepository)
    @State private var repoSlug = ReleaseChecker.repository
    /// 단축키 편집 상태
    @ObservedObject private var hotkeys = GlobalHotKeyService.shared
    @State private var recording: GlobalHotKeyService.Action?
    @State private var recorderFocus: GlobalHotKeyService.Action?
    @State private var hotKeyNonce = 0

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
        .frame(width: 640, height: 520)
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
    // [P0-4] ScrollView 로 감싸지 않아 창 높이(430, 내용 영역 390pt)를 넘는 탭은
    // 아래쪽이 잘려 접근 불가였다(캡쳐 7카드 ≈534pt, 단축키 10카드 ≈650pt).
    // → 스크롤 + 우측 스크롤바 노출.
    private var content: some View {
        ScrollView {
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
                SCard(String(localized: "GIF 프레임레이트"), String(localized: "\(s.hotKey(for: .gif).display) 녹화 fps (4~30)")) {
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
                Text(String(localized: "엔진: Apple Translation (온디바이스, macOS 26+). BYOK는 추후 재검토."))
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            } else if sel == 2 {
                SHead(String(localized: "단축키"), String(localized: "전역 단축키 (Carbon, 추가 권한 없음). 모두 직접 바꿀 수 있습니다."))
                hotKeyEditor
                SHead(String(localized: "오버레이 안에서만 동작"), String(localized: "캡쳐 중 오버레이가 떠 있을 때만 유효"))
                    .padding(.top, 6)
                SCard(String(localized: "마지막 영역"), "") { KeyCap(text: "R") }
                SCard(String(localized: "확정(번역)"), "") { KeyCap(text: "⏎") }
                SCard(String(localized: "즉시 번역"), String(localized: "드래그 중 누르기")) { KeyCap(text: "⌥ + 드래그") }
                SCard(String(localized: "취소"), "") { KeyCap(text: "esc") }
                SCard(String(localized: "기록 붙여넣기"), String(localized: "기록 팝업에서만")) { KeyCap(text: "⌘1~5") }

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
                SCard(String(localized: "암호화"), String(localized: "미지원 — 기록은 평문으로 저장됩니다")) {
                    // 조작처럼 보이지만 아무 동작도 하지 않는 비활성 토글을 두지 않는다.
                    // 기능이 없는 건 숨기고, 사실(평문 저장)을 그대로 알린다.
                    Text(String(localized: "지원 예정"))
                        .font(Theme.font(11.5, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Theme.surface2)
                        .clipShape(Capsule())
                }
            } else if sel == 5 {
                SHead(String(localized: "업데이트"), String(localized: "GitHub Releases에서 새 버전을 확인합니다."))
                SCard(String(localized: "저장소"), String(localized: "공개 저장소만 조회됩니다 (비공개면 확인 불가)")) {
                    TextField("Owner/Repo", text: $repoSlug)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.font(11.5, mono: true))
                        .frame(width: 150)
                        .onSubmit { ReleaseChecker.repository = repoSlug }
                }
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
                        ReleaseChecker.repository = repoSlug
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
            Spacer(minLength: 12)
            HStack {
                Text(String(localized: "자동으로 저장됨."))
                    .font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                // [HARD 파괴적 변경] 확인 없이 전 설정을 날리던 버튼 → 확인 다이얼로그 필수
                Button(String(localized: "설정 초기화")) { confirmReset = true }
                    .font(Theme.font(12))
            }
            .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .id(resetNonce)   // 초기화 직후 값 반영용 트리거
        .confirmationDialog(
            String(localized: "모든 설정을 기본값으로 되돌립니다."),
            isPresented: $confirmReset, titleVisibility: .visible
        ) {
            Button(String(localized: "초기화"), role: .destructive) { performReset() }
            Button(String(localized: "취소"), role: .cancel) { confirmReset = false }
        } message: {
            Text(String(localized: "번역 언어·단축키·기록 개수·GIF 설정이 모두 초기화됩니다. 되돌릴 수 없습니다. (히스토리 기록은 남습니다)"))
        }
    }

    /// UserDefaults 만 비운다. SwiftData 히스토리는 별도라 살아있음을 다이얼로그에 명시했다.
    private func performReset() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: id)
        // 제거된 단축키 슬롯을 기본값으로 되돌리고 Carbon 핸들도 다시 건다.
        // (UserDefaults 만 비우면 등록된 핫키가 옛 조합으로 남는다)
        GlobalHotKeyService.shared.apply(s)
        // 실행 중인 @AppStorage 값을 즉시 반영시키기 위해 뷰 트리거
        resetNonce &+= 1
        hotKeyNonce &+= 1
        search = ""
        sel = 0
        AppLog.log("설정 초기화 실행 (\(id)) nonce=\(resetNonce)")
    }

    // MARK: 단축키 편집 (2026-09-27 전부 사용자 지정 가능)
    @ViewBuilder
    private var hotKeyEditor: some View {
        VStack(spacing: 6) {
            ForEach(GlobalHotKeyService.Action.allCases) { action in
                hotKeyRow(action)
            }
            HStack {
                Button(String(localized: "모두 기본값으로")) {
                    s.resetAllHotKeys()
                    GlobalHotKeyService.shared.apply(s)
                    recording = nil
                    hotKeyNonce &+= 1
                }
                .font(Theme.font(11.5))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                Spacer()
                Text(String(localized: "변경을 누른 뒤 키 조합을 누르세요 · esc 취소"))
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 2)
        }
    }

    private func hotKeyRow(_ action: GlobalHotKeyService.Action) -> some View {
        let binding = s.hotKey(for: action)
        let isRecordingNow = (recording == action)
        let reserved = HotKeyBinding.systemReserved[binding.display]
        let duplicated = GlobalHotKeyService.Action.allCases
            .filter { $0 != action && s.hotKey(for: $0) == binding }
            .map(\.title)
        let failed = hotkeys.failedActions.contains(action)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if failed {
                    Label(String(localized: "등록 실패 — 다른 앱이 사용 중"), systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.font(10.5, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                } else if !duplicated.isEmpty {
                    Text("\(duplicated.joined(separator: ", ")) 와 중복")
                        .font(Theme.font(10.5, weight: .semibold))
                        .foregroundStyle(Theme.warn)
                } else if let reserved {
                    Text("macOS 기본 단축키(\(reserved)) 와 겹칠 수 있음")
                        .font(Theme.font(10.5))
                        .foregroundStyle(Theme.warn)
                } else {
                    Text(action.subtitle)
                        .font(Theme.font(11.5))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 6)
            ZStack {
                if isRecordingNow {
                    Text(String(localized: "키를 누르세요…"))
                        .font(Theme.font(11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 108, height: 26)
                        .background(Theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rChip))
                        .overlay(
                            HotKeyRecorderView(isRecording: true) { captured in
                                applyCaptured(captured, to: action)
                            }
                            .frame(width: 108, height: 26)
                        )
                        .onAppear { recorderFocus = action }
                } else {
                    HStack(spacing: 6) {
                        KeyCap(text: binding.display)
                        Button(String(localized: "변경")) { recording = action }
                            .font(Theme.font(11))
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent)
                            .onHover { h in NSCursor.pointingHand.set(); if !h { NSCursor.arrow.set() } }
                    }
                }
            }
            Button {
                s.resetHotKey(for: action)
                GlobalHotKeyService.shared.apply(s)
                hotKeyNonce &+= 1
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help(String(localized: "이 항목만 기본값으로"))
        }
        .padding(11)
        .background(failed ? Theme.danger.opacity(0.08) : Theme.row)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.line, lineWidth: 1))
        .padding(.bottom, 6)
        .id(hotKeyNonce)
    }

    private func applyCaptured(_ captured: HotKeyBinding?, to action: GlobalHotKeyService.Action) {
        defer { recording = nil }
        guard let captured else { return }   // esc 취소
        guard captured.isValid else { NSSound.beep(); return }
        // 앱 내 중복은 막는다 (동일 조합은 한쪽만 등록된다)
        if let other = GlobalHotKeyService.Action.allCases.first(where: {
            $0 != action && s.hotKey(for: $0) == captured
        }) {
            NSSound.beep()
            AppLog.log("단축키 중복 거부 \(captured.display) — \(other.rawValue) 와 동일")
            return
        }
        s.setHotKey(captured, for: action)
        GlobalHotKeyService.shared.apply(s)
        hotKeyNonce &+= 1
        AppLog.log("단축키 변경 \(action.rawValue) = \(captured.display)")
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

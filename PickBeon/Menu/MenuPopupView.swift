import SwiftUI
import AppKit

// Pick Hub: 2탭 경량 팝오버 (Pick / 설정) — 기록은 전체검색(⌘↔) 전담, 클립보드·번역·캡쳐와 이중 구조 제거
private enum HubTab: String, CaseIterable {
    case pick, settings
    var label: String {
        switch self {
        case .pick: String(localized: "Pick")
        case .settings: String(localized: "설정")
        }
    }
}

struct MenuPopupView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updateCenter = UpdateCenter.shared
    @State private var tab: HubTab = .pick
    @State private var justCopied = false

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Rectangle().fill(Theme.glassStroke).frame(height: 1)
            ScrollView {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .id(tab)
                    .transition(.opacity)
                    .animation(Theme.hoverFade, value: tab)
            }
            Rectangle().fill(Theme.glassStroke).frame(height: 1)
            footer
        }
        .frame(width: 340, height: 463)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rPanel))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rPanel)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .onAppear {
            Task { @MainActor in await updateCenter.maybeAutoCheckForUpdate() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateStateChanged)) { _ in
            _ = updateCenter.state
        }
    }

    // MARK: 헤더 + 탭
    private var tabBar: some View {
        HStack(spacing: 8) {
            Text("◈")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("PickBeon").font(Theme.font(14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HubTabBar(selected: $tab)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .pick: pickTab
        case .settings: settingsTab
        }
    }

    // MARK: Pick
    // [P0-5] 팝오버가 240pt 라 pickTab(≈454pt) 의 절반이 폴드 아래로 숨었다.
    // → 행을 압축하고 창을 키워 7개 항목이 스크롤 없이 모두 보이게 한다.
    private var pickTab: some View {
        VStack(spacing: 6) {
            primaryPickButton
            MRow(icon: "text.cursor", title: String(localized: "텍스트 선택 번역"),
                 sub: String(localized: "드래그한 문장으로 바로 번역"), kbd: "⌘⌥Z") {
                coordinator.menuAction { coordinator.translateSelection() }
            }
            MRow(icon: "doc.on.doc", title: String(localized: "텍스트 바로 복사"),
                 sub: String(localized: "영역 OCR → 클립보드"), kbd: "⌥⌘C") {
                coordinator.menuAction { coordinator.startQuickCopy() }
            }
            MRow(icon: "macwindow.on.rectangle", title: String(localized: "창 캡쳐"),
                 sub: String(localized: "창을 클릭해 캡쳐"), kbd: "⌥⌘W") {
                coordinator.menuAction { coordinator.startWindowCapture() }
            }
            MRow(icon: "rectangle.dashed", title: String(localized: "Same area"),
                 sub: coordinator.lastArea == .zero
                      ? String(localized: "아직 없음")
                      : "\(Int(coordinator.lastArea.width)) × \(Int(coordinator.lastArea.height)) · 이전 영역 복원",
                 kbd: nil) {
                coordinator.menuAction { coordinator.repeatLastArea() }
            }
            MRow(icon: "video", title: String(localized: "GIF 녹화"),
                 sub: String(localized: "영역 선택 후 녹화 버튼"),
                 kbd: "⌥⌘G") {
                coordinator.menuAction { coordinator.startGifCapture() }
            }
            latestRow
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// 주 액션 — 다른 행과 구분되는 실제 primary 처리(기존엔 전부 동일 스타일이라 우선순위가 없었다)
    private var primaryPickButton: some View {
        Button {
            coordinator.menuAction { coordinator.startCapture() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "scissors")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "영역 Pick"))
                        .font(Theme.font(13.5, weight: .bold))
                        .foregroundStyle(.white)
                    Text(String(localized: "드래그하고 바로 번역 · 붙여넣기"))
                        .font(Theme.font(11))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("⌘⇧X")
                    .font(Theme.font(11, weight: .semibold, mono: true))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rChip))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.rCard)
                    .fill(Theme.hero)
                    .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Color.white.opacity(0.18), lineWidth: 1))
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.rCard))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }

    // MARK: 최신 번역 한 줄
    private var latestRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            if coordinator.latestTranslated.isEmpty {
                Text(String(localized: "아직 없음 — 영역을 Pick하세요"))
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
            } else {
                Text(coordinator.latestTranslated)
                    .font(Theme.font(12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button {
                    copyLatest()
                } label: {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(justCopied ? Theme.ok : Theme.accent)
                        .frame(width: 24, height: 24)
                        .background(Theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(String(localized: "번역문 복사"))
                Button {
                    coordinator.menuAction { coordinator.showEditor() }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Theme.surface2.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(String(localized: "에디터 열기"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.surface2.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.rBlock))
        .overlay(RoundedRectangle(cornerRadius: Theme.rBlock).stroke(Theme.glassStroke, lineWidth: 1))
        .padding(.horizontal, 12)
        .onHover { h in if h { NSCursor.arrow.set() } }
    }

    private func copyLatest() {
        let text = coordinator.latestTranslated
        guard !text.isEmpty else { return }
        guard PasteboardService.write(text: text) else { return }
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { justCopied = false }
    }

    // MARK: 설정 탭
    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            PressableRow(action: { coordinator.menuAction { coordinator.openSettingsWindow() } }) {
                HStack(spacing: 11) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24, height: 24)
                        .background(Theme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "전체 설정 열기"))
                            .font(Theme.font(13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(String(localized: "상세는 전체 설정에서"))
                            .font(Theme.font(11.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(11)
                .padding(.horizontal, 1)
            }
            .padding(.horizontal, 12)

            quickToggle(String(localized: "정중한 말투"), $settings.politeTone)
            // 라벨과 실제 바인딩이 어긋나 있었다("번역 오버레이" → OCR 박스 on/off).
            quickToggle(String(localized: "OCR 박스"), $settings.overlayOn)
            quickToggle(String(localized: "번역 오버레이"), $settings.transOverlayOn)

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func quickToggle(_ title: String, _ bind: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(Theme.font(12.5, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Toggle("", isOn: bind)
                .labelsHidden()
                .tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Theme.row.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: Theme.rTab))
        .overlay(RoundedRectangle(cornerRadius: Theme.rTab).stroke(Theme.glassStroke, lineWidth: 1))
        .padding(.horizontal, 12)
    }

    // MARK: 행 (44pt 압축 — 팝오버가 스크롤 없이 모두 보이도록)
    private func MRow(icon: String, title: String, sub: String, kbd: String?, _ a: @escaping () -> Void) -> some View {
        PressableRow(action: a) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22, height: 22)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.font(12.5, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(sub).font(Theme.font(11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 2)
                if let kbd { KeyCap(text: kbd) }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
        }
        .padding(.horizontal, 12)
    }

    // MARK: 푸터
    private var footer: some View {
        HStack(spacing: 8) {
            Text("PickBeon v\(ReleaseChecker.currentVersion)")
                .font(Theme.font(11.5))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
            Spacer()
            if let u = updateCenter.availableUpdate {
                Button {
                    coordinator.menuAction { coordinator.showUpdateSheet() }
                } label: {
                    Text("v\(u.tag) \(String(localized: "사용 가능"))")
                        .font(Theme.font(11.5, weight: .semibold))
                        .foregroundStyle(Theme.warn)
                }
                .buttonStyle(.plain)
                .onHover { h in if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
                .help(String(localized: "새 버전 보기"))
            }
            Tap(String(localized: "전체 기록")) {
                coordinator.menuAction { coordinator.showHistory() }
            }
            Tap(String(localized: "종료")) { NSApplication.shared.terminate(nil) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func Tap(_ t: String, _ a: @escaping () -> Void) -> some View {
        Text(t)
            .font(Theme.font(12))
            .foregroundStyle(Theme.textSecondary)
            .contentShape(Rectangle())
            .onTapGesture(perform: a)
            .onHover { h in if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
    }
}

// MARK: - 탭 바 (accent 백그라운드)
private struct HubTabBar: View {
    @Binding var selected: HubTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HubTab.allCases, id: \.rawValue) { t in
                let isOn = selected == t
                Text(t.label)
                    .font(Theme.font(12, weight: isOn ? .semibold : .medium))
                    .foregroundStyle(isOn ? Color.white : Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isOn ? Theme.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rTab))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Theme.hoverFade) { selected = t }
                        NSCursor.arrow.set()
                    }
                    .onHover { h in
                        if h { NSCursor.pointingHand.set() } else if !isOn { NSCursor.arrow.set() }
                    }
            }
        }
        .animation(Theme.hoverFade, value: selected)
    }
}

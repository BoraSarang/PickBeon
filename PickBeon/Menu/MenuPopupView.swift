import SwiftUI
import AppKit

// GifJot 형식 메뉴 팝업: 히어로 1 + 행 2 + 최신 1(썸네일) + 푸터 (NSPopover 호스팅)
struct MenuPopupView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 8) {
            header
            hero
            MRow(icon: "text.cursor", title: String(localized: "텍스트 선택 번역"),
                 sub: String(localized: "드래그한 문장을 카드로"), kbd: "⌘⌥Z") {
                coordinator.menuAction { coordinator.translateSelection() }
            }
            MRow(icon: "rectangle.dashed", title: String(localized: "Same area"),
                 sub: coordinator.lastArea == .zero
                      ? String(localized: "아직 없음")
                      : "\(Int(coordinator.lastArea.width)) × \(Int(coordinator.lastArea.height)) · 다시 찍기",
                 kbd: nil) {
                coordinator.menuAction { coordinator.repeatLastArea() }
            }
            latestCard
            footer
        }
        .frame(width: 340)
        .padding(.vertical, 10)
        .background(Theme.bg)
    }

    // MARK: 헤더
    private var header: some View {
        HStack(spacing: 8) {
            Text("◈")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Theme.hero)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text("PickBeon").font(Theme.font(14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            IconToolButton(systemName: "gearshape", tip: String(localized: "설정")) {
                coordinator.openSettingsWindow()
            }
            IconToolButton(systemName: "ellipsis", tip: String(localized: "기록")) {
                coordinator.menuAction { coordinator.showHistory() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    // MARK: 히어로
    private var hero: some View {
        HeroButton {
            coordinator.menuAction { coordinator.startCapture() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scissors")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "영역 Pick"))
                        .font(Theme.font(14, weight: .bold))
                    Text(String(localized: "드래그하고 바로 번역 · 붙여넣기"))
                        .font(Theme.font(12))
                        .opacity(0.85)
                }
                Spacer()
                KeyCap(text: "⌘⇧X")
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
    }

    // MARK: 최신 번역 카드 (썸네일 포함)
    private var latestCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(String(localized: "최신 번역"))
                    .font(Theme.font(11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            if coordinator.latestTranslated.isEmpty {
                Text(String(localized: "아직 없음 — 영역을 Pick하세요"))
                    .font(Theme.font(12))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                HStack(alignment: .top, spacing: 9) {
                    if let img = coordinator.latestImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line, lineWidth: 1))
                    }
                    Text(coordinator.latestTranslated)
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                }
            }
            HStack(spacing: 0) {
                Rectangle().fill(Theme.line).frame(width: 1, height: 26)
                FooterButton(title: String(localized: "열기"), systemImage: "square.and.pencil") {
                    coordinator.menuAction { coordinator.showEditor() }
                }
                Rectangle().fill(Theme.line).frame(width: 1, height: 26)
                FooterButton(title: String(localized: "복사"), systemImage: "doc.on.doc") {
                    NSPasteboard.general.setString(coordinator.latestTranslated, forType: .string)
                }
                Rectangle().fill(Theme.line).frame(width: 1, height: 26)
                FooterButton(title: String(localized: "기록"), systemImage: "clock") {
                    coordinator.menuAction { coordinator.showHistory() }
                }
            }
            .background(Theme.surface2.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(Theme.row)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard).stroke(Theme.line, lineWidth: 1))
        .padding(.horizontal, 12)
    }

    // MARK: 푸터
    private var footer: some View {
        HStack {
            Tap(String(localized: "설정")) { coordinator.openSettingsWindow() }
            Spacer()
            Tap(String(localized: "종료")) { NSApplication.shared.terminate(nil) }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private func Tap(_ t: String, _ a: @escaping () -> Void) -> some View {
        Text(t)
            .font(Theme.font(12))
            .foregroundStyle(Theme.textSecondary)
            .contentShape(Rectangle())
            .onTapGesture(perform: a)
            .onHover { h in if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
    }

    // MARK: 행
    private func MRow(icon: String, title: String, sub: String, kbd: String?, _ a: @escaping () -> Void) -> some View {
        PressableRow(action: a) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24, height: 24)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.font(13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(sub).font(Theme.font(11.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if let kbd { KeyCap(text: kbd) }
            }
            .padding(11)
            .padding(.horizontal, 1)
        }
        .padding(.horizontal, 12)
    }
}

import SwiftUI

// GifJot 형식 메뉴 팝업: 히어로 1 + 행 2 + 최신 1 + 푸터 (NSPopover 호스팅)
struct MenuPopupView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("◈").foregroundColor(Color(red: 0.49, green: 0.49, blue: 0.96))
                Text("PickBeon").font(.system(size: 14, weight: .bold))
                Spacer()
                Tap("⚙") { coordinator.openSettingsWindow() }
            }.padding(.horizontal, 14).padding(.top, 12)

            // 히어로: 영역 Pick
            HStack(spacing: 12) {
                Text("◰").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "영역 Pick")).font(.system(size: 14, weight: .bold))
                    Text(String(localized: "드래그하고 바로 번역 · 붙여넣기")).font(.system(size: 12)).opacity(0.85)
                }
                Spacer()
                Text("⌥⌃P").font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.black.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(14).foregroundColor(.white)
            .background(LinearGradient(colors: [Color(red: 0.36, green: 0.36, blue: 0.94), Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture { coordinator.menuAction { coordinator.startCapture() } }

            MRow(icon: "◉", title: String(localized: "텍스트 선택 번역"), sub: String(localized: "드래그한 문장을 카드로"), kbd: "⌥⌃Z") {
                coordinator.menuAction { coordinator.translateSelection() }
            }
            MRow(icon: "↻", title: "Same area",
                 sub: coordinator.lastArea == .zero ? String(localized: "아직 없음") : "\(Int(coordinator.lastArea.width)) × \(Int(coordinator.lastArea.height)) · 다시 찍기",
                 kbd: nil) {
                coordinator.menuAction { coordinator.repeatLastArea() }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "최신 번역")).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Text(coordinator.latestTranslated.isEmpty ? String(localized: "아직 없음 — 영역을 Pick하세요") : coordinator.latestTranslated)
                    .font(.system(size: 12)).lineLimit(2)
                HStack(spacing: 0) {
                    FBtn(String(localized: "↗ 열기")) { coordinator.menuAction { coordinator.showEditor() } }
                    FBtn(String(localized: "⧉ 복사")) { NSPasteboard.general.setString(coordinator.latestTranslated, forType: .string) }
                    FBtn(String(localized: "🕘 기록")) { coordinator.menuAction { coordinator.showHistory() } }
                }
                .border(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)

            HStack {
                Tap(String(localized: "설정")) { coordinator.openSettingsWindow() }.foregroundColor(.secondary).font(.system(size: 12))
                Spacer()
                Tap(String(localized: "종료")) { NSApplication.shared.terminate(nil) }.foregroundColor(.secondary).font(.system(size: 12))
            }.padding(.horizontal, 14).padding(.bottom, 12)
        }.frame(width: 340)
    }

    private func Tap(_ t: String, _ a: @escaping () -> Void) -> some View {
        Text(t).contentShape(Rectangle()).onTapGesture(perform: a)
    }

    private func MRow(icon: String, title: String, sub: String, kbd: String?, _ a: @escaping () -> Void) -> some View {
        HStack(spacing: 11) {
            Text(icon).font(.system(size: 15)).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(sub).font(.system(size: 11.5)).foregroundColor(.secondary)
            }
            Spacer()
            if let kbd { Text(kbd).font(.system(size: 11, design: .monospaced)).padding(.horizontal, 7).padding(.vertical, 4).background(Color.black.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 6)) }
        }
        .padding(11)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: a)
    }

    private func FBtn(_ t: String, _ a: @escaping () -> Void) -> some View {
        Text(t).font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .contentShape(Rectangle()).onTapGesture(perform: a)
    }
}

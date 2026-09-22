import SwiftUI

// 첫 실행 권한 온보딩 카드. 이 1장만 표시, 에디터 창은 절대 안 뜸.
struct OnboardingView: View {
    @ObservedObject var coordinator: AppCoordinator
    @EnvironmentObject var perm: PermissionService

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Theme.hero
                VStack(spacing: 6) {
                    Text("◈")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .frame(height: 96)

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "PickBeon 시작하기"))
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(String(localized: "쓰는 기능의 권한만 허용하면 됩니다. 한 번만 허용하면 됩니다."))
                    .font(Theme.font(12.5))
                    .foregroundStyle(Theme.textSecondary)

                PermRow(done: perm.screenRecordingOK,
                        title: String(localized: "화면 기록"),
                        icon: "rectangle.dashed",
                        sub: String(localized: "영역 Pick(캡쳐)용 · 누르면 macOS 확인창이 뜸"),
                        btn: perm.screenRecordingOK ? nil : String(localized: "허용하기")) {
                    perm.requestScreenRecording()
                }
                PermRow(done: perm.axOK,
                        title: String(localized: "손쉬운 사용"),
                        icon: "accessibility",
                        sub: String(localized: "텍스트 선택 번역용 · 설정으로 이동"),
                        btn: perm.axOK ? nil : String(localized: "열기")) {
                    perm.requestAX()
                }

                HStack {
                    Button(String(localized: "다시 확인")) {
                        perm.refresh()
                        if perm.allOK { coordinator.closeOnboarding() }
                    }
                    .buttonStyle(.bordered)
                    .font(Theme.font(12))
                    Spacer()
                    Button(String(localized: "닫기")) { coordinator.closeOnboarding() }
                        .buttonStyle(.plain)
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .frame(width: 360)
        .background(Theme.surface)
        .onChange(of: perm.allOK) { _, ok in if ok { coordinator.closeOnboarding() } }
    }

    private func PermRow(done: Bool, title: String, icon: String, sub: String, btn: String?, _ a: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(done ? Theme.ok : Theme.accent)
                .frame(width: 30, height: 30)
                .background((done ? Theme.ok : Theme.accent).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.font(12.5, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(sub).font(Theme.font(11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if done {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 11, weight: .bold))
                    Text(String(localized: "허용됨")).font(Theme.font(11, weight: .bold))
                }
                .foregroundStyle(Theme.ok)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.ok.opacity(0.14))
                .clipShape(Capsule())
            } else if let btn {
                Button(btn, action: a)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .font(Theme.font(11.5, weight: .semibold))
            }
        }
        .padding(10)
        .background(Theme.row)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }
}

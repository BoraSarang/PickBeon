import SwiftUI

// 첫 실행 권한 온보딩 카드. 이 1장만 표시, 에디터 창은 절대 안 뜸.
struct OnboardingView: View {
    @ObservedObject var coordinator: AppCoordinator
    @EnvironmentObject var perm: PermissionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.36, green: 0.36, blue: 0.94), Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing)
                Text("◈").font(.system(size: 34)).foregroundColor(.white)
            }.frame(height: 86)
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "PickBeon 시작하기")).font(.system(size: 15, weight: .bold))
                Text(String(localized: "쓰는 기능의 권한만 허용하면 됩니다. 한 번만 허용하면 됩니다.")).font(.system(size: 12.5)).foregroundColor(.secondary)
                PermRow(done: perm.screenRecordingOK, title: String(localized: "⛶ 화면 기록"), sub: String(localized: "영역 Pick(캡쳐)용 · 누르면 macOS 확인창이 뜸"),
                        btn: perm.screenRecordingOK ? nil : String(localized: "허용하기")) {
                    perm.requestScreenRecording()
                }
                PermRow(done: perm.axOK, title: String(localized: "♿ 손쉬운 사용"), sub: String(localized: "텍스트 선택 번역용 · 설정으로 이동"),
                        btn: perm.axOK ? nil : String(localized: "열기")) {
                    perm.requestAX()
                }
                HStack {
                    Button(String(localized: "다시 확인")) { perm.refresh(); if perm.allOK { coordinator.closeOnboarding() } }
                        .buttonStyle(.bordered).font(.system(size: 12))
                    Spacer()
                    Button(String(localized: "닫기")) { coordinator.closeOnboarding() }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }.padding(16)
        }.frame(width: 360)
            .onChange(of: perm.allOK) { _, ok in if ok { coordinator.closeOnboarding() } }
    }

    private func PermRow(done: Bool, title: String, sub: String, btn: String?, _ a: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(sub).font(.system(size: 11.5)).foregroundColor(.secondary)
            }
            Spacer()
            if done { Text("✓").font(.system(size: 12, weight: .bold)).foregroundColor(.green).padding(.horizontal, 10).padding(.vertical, 5).background(Color.green.opacity(0.15)).clipShape(Capsule()) }
            else if let btn { Button(btn, action: a).buttonStyle(.borderedProminent).font(.system(size: 11.5)) }
        }
        .padding(10).background(Color.white.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

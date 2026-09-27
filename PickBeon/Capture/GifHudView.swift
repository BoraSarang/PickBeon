import SwiftUI

// GIF 녹화 HUD: ● REC + 경과 시간 + 프레임 + 중지
// 패널 260×52 고정 — elapsed은 독립 타이머(100ms)로 갱신되어 프레임과 무관하게 진행
struct GifHudView: View {
    @ObservedObject var recorder: GifRecorder
    var onStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .opacity(recorder.isRecording ? 1 : 0.35)
            Text("REC")
                .font(Theme.font(12, weight: .bold, mono: true))
                .foregroundStyle(Theme.textPrimary)
            Text(String(format: "%.1fs", recorder.elapsed))
                .font(Theme.font(12, weight: .medium, mono: true))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 42, alignment: .leading)
            Text("\(recorder.frameCount)f")
                .font(Theme.font(11, weight: .medium, mono: true))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 2)
            Button(action: onStop) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill").font(.system(size: 10, weight: .bold))
                    Text(String(localized: "중지")).font(Theme.font(12, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .onHover { h in if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 260, height: 52, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(radius: 12)
    }
}

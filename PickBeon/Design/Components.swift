import SwiftUI
import AppKit

// MARK: - 공용 표면 카드 (기본/호버 페이드)
struct SurfaceCard<Content: View>: View {
    var fill: Color = Theme.row
    var radius: CGFloat = Theme.rCard
    var hovered = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Theme.s3)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}

// MARK: - 키캡 (⌘⇧X 등) — 글래스 패널용 fill
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.font(11, weight: .medium, mono: true))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Theme.kbdFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rChip))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rChip)
                    .stroke(Theme.glassStroke, lineWidth: 1)
            )
            .foregroundStyle(Theme.textPrimary)
    }
}

// MARK: - 히어로 그라데이션 블록 (온보딩/설정 로고 전용 — 메뉴 팝오버에서 사용 금지)
struct HeroGradient<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(Theme.s4)
            .background(Theme.hero)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
            .foregroundStyle(.white)
    }
}

// MARK: - 히어로 버튼 (그라데이션 + 호버 오버레이)
struct HeroButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: () -> Label
    @State private var hovering = false
    @State private var pressing = false

    var body: some View {
        Button(action: action) {
            label()
                .padding(Theme.s4)
                .background {
                    RoundedRectangle(cornerRadius: Theme.rCard)
                        .fill(Theme.hero)
                        .overlay {
                            if hovering {
                                RoundedRectangle(cornerRadius: Theme.rCard)
                                    .fill(Color.white.opacity(pressing ? 0.14 : 0.08))
                            }
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.rCard))
                .scaleEffect(pressing ? 0.98 : 1)
                .contentShape(RoundedRectangle(cornerRadius: Theme.rCard))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in pressing = false }
        )
        .animation(Theme.hoverFade, value: hovering)
        .animation(Theme.hoverFade, value: pressing)
    }
}

// MARK: - 호버/프레스 피드백 행
struct PressableRow<Content: View>: View {
    var hoveredFill: Color = Theme.rowHover
    var pressedFill: Color = Theme.rowHover.opacity(0.7)
    var radius: CGFloat = Theme.rCard
    var fill: Color = Theme.row
    let action: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var hovering = false
    @State private var pressing = false

    var body: some View {
        content()
            .background(hovering ? hoveredFill : (pressing ? pressedFill : fill))
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Theme.line, lineWidth: 1))
            .scaleEffect(pressing ? 0.985 : 1)
            .animation(Theme.hoverFade, value: hovering)
            .animation(Theme.hoverFade, value: pressing)
            .onHover { hovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressing = true }
                    .onEnded { v in
                        pressing = false
                        if hovering { action() }
                    }
            )
    }
}

// MARK: - 하단 액션 버튼 (카드 푸터용)
struct FooterButton: View {
    let title: String
    var systemImage: String? = nil
    var prominent = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let s = systemImage { Image(systemName: s).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(Theme.font(12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
                    .foregroundStyle(prominent ? Color.white : Theme.textPrimary)
            .background(
                Rectangle()
                    .fill(prominent ? Theme.accent : (hovering ? Theme.rowHover : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hoverFade, value: hovering)
    }
}

// MARK: - 줌 컨트롤 (에디터 줌바)
struct ZoomButton: View {
    let systemName: String
    var tip: String = ""
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(hovering ? Theme.textPrimary : Theme.textSecondary)
                .frame(width: 22, height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Theme.rowHover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tip)
    }
}

// MARK: - 상태 원 (결과카드 헤더 ✓/!)
struct StatusDot: View {
    let symbol: String
    let color: Color
    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(color)
            .clipShape(Circle())
    }
}

// MARK: - 아이콘 툴바 버튼 (SF Symbols, 호버)
struct IconToolButton: View {
    let systemName: String
    var tip: String = ""
    var active = false
    var enabled = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Color.white : (hovering && enabled ? Theme.textPrimary : Theme.textSecondary))
                .frame(width: 30, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: Theme.rChip)
                        .fill(active ? Theme.accent : (hovering && enabled ? Color.primary.opacity(0.08) : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .onHover { hovering = $0 }
        .animation(Theme.hoverFade, value: hovering)
        .animation(Theme.hoverFade, value: active)
        .help(tip)
    }
}

// MARK: - 원문/번역 결과 박스
struct TransPanel<Content: View>: View {
    var filled = true
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(Theme.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(filled ? Theme.transPanel : Theme.row)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rBlock))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.rBlock)
                    .stroke(filled ? Theme.transPanelLine : Theme.line, lineWidth: 1)
            )
    }
}

// MARK: - 폴백: 컨테이너 배경 (팝업 루트)
struct PanelBackground: ViewModifier {
    var radius: CGFloat = Theme.rPanel
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
    }
}

extension View {
    func panelStyle(radius: CGFloat = Theme.rPanel) -> some View {
        modifier(PanelBackground(radius: radius))
    }
}

import SwiftUI
import AppKit

/// [HARD] quality.md: DebugPanel 이 실제 상태를 보여야 한다.
/// 이전 구현은 "ERROR 0" / "캐시 상태: 정상" 을 하드코딩한 스텁이라
/// 아무 정보도 제공하지 못했다. 지금은 AppLog 링버퍼를 실시간 표시한다.
struct DebugPanelView: View {
    @State private var entries: [AppLog.Entry] = []
    @State private var timer: Timer?
    @State private var filter: Filter = .all
    @State private var showVolatile = true
    @State private var showDiskPath = false

    private enum Filter: String, CaseIterable, Identifiable {
        case all, error, feature, cache
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "전체"
            case .error: return "ERROR"
            case .feature: return "FEATURE"
            case .cache: return "CACHE/PERF"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Theme.line).frame(height: 1)
            filterBar
            Rectangle().fill(Theme.line).frame(height: 1)
            list
            Rectangle().fill(Theme.line).frame(height: 1)
            footer
        }
        .frame(width: 520, height: 460)
        .background(Theme.bg)
        .onAppear {
            reload()
            timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
                Task { @MainActor in reload() }
            }
        }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    // MARK: 헤더

    private var header: some View {
        HStack(spacing: 8) {
            Text("DebugPanel")
                .font(Theme.font(13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            counts
            Spacer()
            Button {
                reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("새로고침")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var counts: some View {
        let errors = entries.filter { $0.level == .error }.count
        return HStack(spacing: 5) {
            Text("ERROR \(errors)")
                .font(Theme.font(10.5, weight: .semibold, mono: true))
                .foregroundStyle(errors == 0 ? Theme.ok : Theme.danger)
            Text("· \(entries.count)줄")
                .font(Theme.font(10.5, mono: true))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(Filter.allCases) { f in
                Text(f.label)
                    .font(Theme.font(11, weight: filter == f ? .semibold : .regular))
                    .foregroundStyle(filter == f ? Theme.accent : Theme.textSecondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(filter == f ? Theme.accent.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rTab))
                    .contentShape(Rectangle())
                    .onTapGesture { filter = f }
            }
            Spacer()
            Toggle("메모리 전용 표시", isOn: $showVolatile)
                .toggleStyle(.checkbox)
                .font(Theme.font(10.5))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: 목록

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filtered) { e in
                        row(e).id(e.id)
                    }
                    if filtered.isEmpty {
                        Text("기록 없음")
                            .font(Theme.font(11.5))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(12)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .onChange(of: entries.count) { _, _ in
                if let last = filtered.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
        .background(Theme.bg)
    }

    private var filtered: [AppLog.Entry] {
        entries.filter { e in
            if e.volatile && !showVolatile { return false }
            switch filter {
            case .all: return true
            case .error: return e.level == .error
            case .feature: return e.message.contains("[FEATURE]")
            case .cache: return e.level == .cache || e.level == .perf
            }
        }
    }

    private func row(_ e: AppLog.Entry) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text(Self.stamp(e.date))
                .font(Theme.font(9.5, mono: true))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
            Text(e.level.rawValue)
                .font(Theme.font(9, weight: .bold, mono: true))
                .foregroundStyle(color(for: e.level))
                .frame(width: 44, alignment: .leading)
            Text(e.message)
                .font(Theme.font(11, mono: true))
                .foregroundStyle(e.level == .error ? Theme.danger : Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if e.volatile {
                Image(systemName: "eye.slash")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.warn)
                    .help("메모리 전용 (디스크 미기록) — 사용자 텍스트 마스킹 처리")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(e.level == .error ? Theme.danger.opacity(0.07) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func color(for level: AppLog.Level) -> Color {
        switch level {
        case .error: return Theme.danger
        case .perf: return Theme.ok
        case .cache: return Theme.warn
        case .info: return Theme.accent
        }
    }

    // MARK: 푸터

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("[PERF] 예산: Cold Start ≤1.5s · 메모리 ≤300MB · GIF 60fps")
                .font(Theme.font(10))
                .foregroundStyle(Theme.textSecondary)
            Text("디스크: ~/Library/Application Support/PickBeon/debug.log (2MB 로테이션 · 사용자 텍스트 마스킹)")
                .font(Theme.font(9.5))
                .foregroundStyle(Theme.textSecondary.opacity(0.75))
                .lineLimit(showDiskPath ? 3 : 1)
                .onTapGesture { showDiskPath.toggle() }
            HStack {
                Button("기록 비우기") { AppLog.clearMemory(); reload() }
                    .font(Theme.font(10.5))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("로그 파일 열기") { AppLog.revealInFinder() }
                    .font(Theme.font(10.5))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func reload() {
        let all = AppLog.recent()
        if all.map(\.id) != entries.map(\.id) { entries = all }
    }

    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SS"
        return f.string(from: d)
    }
}

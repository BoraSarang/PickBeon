import SwiftUI
import AppKit

// Raycast식 히스토리 팝업: 검색 + 핀 고정 + 썸네일 + Cmd+1~5 + hover 삭제
struct ClipboardPopupView: View {
    @ObservedObject var store: ClipboardStore
    @State private var query = ""
    @State private var hoverID: UUID?
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool
    var onPaste: ((HistoryRecord) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Rectangle().fill(Theme.line).frame(height: 1)
            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: 440, height: 480)
        .background(Theme.bg)
        .onAppear { searchFocused = true }
        .onExitCommand { NSApp.keyWindow?.orderOut(nil) }
        .background(
            KeyObserver(query: $query, count: filtered.count, selectedIndex: $selectedIndex) { idx in
                paste(at: idx)
            }
            .frame(width: 0, height: 0)
        )
    }

    // MARK: 검색바
    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            TextField(String(localized: "검색 — 클립보드 + 번역 기록"), text: $query)
                .textFieldStyle(.plain)
                .font(Theme.font(13))
                .focused($searchFocused)
                .onChange(of: query) { _, _ in selectedIndex = 0 }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            KeyCap(text: "⌘1~5")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: 빈 상태
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.textSecondary)
            Text(query.isEmpty ? String(localized: "아직 기록이 없습니다") : String(localized: "검색 결과 없음"))
                .font(Theme.font(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 리스트
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { i, r in
                    row(r, index: i)
                }
            }
            .padding(8)
        }
        .background(Theme.bg)
    }

    private func row(_ r: HistoryRecord, index: Int) -> some View {
        let isSel = index == selectedIndex
        return HStack(alignment: .top, spacing: 10) {
            // 아이콘/썸네일
            Group {
                if r.isImage, let data = r.pngData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: r.translated.isEmpty ? "doc.text" : "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(r.translated.isEmpty ? Theme.textSecondary : Theme.accent)
                        .frame(width: 40, height: 32)
                        .background(Theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(r.translated.isEmpty ? r.text : r.translated)
                    .font(Theme.font(12.5, weight: isSel ? .semibold : .regular))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if !r.translated.isEmpty {
                    Text(r.text)
                        .font(Theme.font(11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Text(r.date, style: .time)
                    .font(Theme.font(10.5))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }
            Spacer(minLength: 4)

            if index < 5 {
                Text("\(index + 1)")
                    .font(Theme.font(10, weight: .bold, mono: true))
                    .foregroundStyle(isSel ? Theme.accent : Theme.textSecondary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(isSel ? Theme.accent.opacity(0.2) : Theme.surface2))
            }

            if r.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.pinColor)
            }

            if hoverID == r.id || isSel {
                Button {
                    delete(r)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.danger.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help(String(localized: "삭제"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSel ? Theme.rowHover : (hoverID == r.id ? Theme.row : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .onHover { hovering in hoverID = hovering ? r.id : nil }
        .onTapGesture { paste(at: index) }
        .contextMenu {
            Button(String(localized: r.pinned ? "핀 해제" : "핀 고정")) { togglePin(r) }
            Button(String(localized: "복사")) { copyItem(r) }
            Divider()
            Button(String(localized: "삭제"), role: .destructive) { delete(r) }
        }
        .animation(Theme.hoverFade, value: isSel)
    }

    // MARK: 동작
    var filtered: [HistoryRecord] {
        if query.isEmpty { return store.items }
        return store.items.filter {
            $0.text.localizedCaseInsensitiveContains(query) ||
            $0.translated.localizedCaseInsensitiveContains(query)
        }
    }

    private func paste(at index: Int) {
        guard filtered.indices.contains(index) else { return }
        pasteItem(filtered[index])
    }

    private func pasteItem(_ r: HistoryRecord) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if !r.translated.isEmpty { pb.setString(r.translated, forType: .string) }
        else if !r.text.isEmpty { pb.setString(r.text, forType: .string) }
        if r.isImage, let data = r.pngData { pb.setData(data, forType: .png) }
        onPaste?(r)
        NSApp.keyWindow?.orderOut(nil)
    }

    private func copyItem(_ r: HistoryRecord) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(r.translated.isEmpty ? r.text : r.translated, forType: .string)
    }

    private func togglePin(_ r: HistoryRecord) {
        guard let ctx = r.modelContext else { return }
        store.togglePin(r, context: ctx)
    }

    private func delete(_ r: HistoryRecord) {
        guard let ctx = r.modelContext else { return }
        store.delete(r, context: ctx)
    }
}

// MARK: - Cmd+1~5 / Enter / Esc / 방향키 (local monitor — 포커스 가로채지 않음)
private struct KeyObserver: NSViewRepresentable {
    @Binding var query: String
    let count: Int
    @Binding var selectedIndex: Int
    let onPaste: (Int) -> Void

    func makeNSView(context: Context) -> MonitorView {
        MonitorView(
            onDigit: { d in onPaste(d - 1) },
            onEnter: { onPaste(selectedIndex) },
            onEscape: { NSApp.keyWindow?.orderOut(nil) },
            onArrow: { up in
                if up { selectedIndex = max(0, selectedIndex - 1) }
                else { selectedIndex = min(max(count - 1, 0), selectedIndex + 1) }
            }
        )
    }
    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onDigit = { d in onPaste(d - 1) }
        nsView.onEnter = { onPaste(selectedIndex) }
        nsView.onArrow = { up in
            if up { selectedIndex = max(0, selectedIndex - 1) }
            else { selectedIndex = min(max(count - 1, 0), selectedIndex + 1) }
        }
    }
}

final class MonitorView: NSView {
    var onDigit: (Int) -> Void = { _ in }
    var onEnter: () -> Void = {}
    var onEscape: () -> Void = {}
    var onArrow: (Bool) -> Void = { _ in }
    private var monitor: Any?

    init(onDigit: @escaping (Int) -> Void,
         onEnter: @escaping () -> Void,
         onEscape: @escaping () -> Void,
         onArrow: @escaping (Bool) -> Void) {
        self.onDigit = onDigit
        self.onEnter = onEnter
        self.onEscape = onEscape
        self.onArrow = onArrow
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard monitor == nil, window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            let digitMap: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5]
            if e.modifierFlags.contains(.command), let d = digitMap[e.keyCode] {
                self.onDigit(d); return nil
            }
            switch e.keyCode {
            case 53: self.onEscape(); return nil
            case 36, 76: self.onEnter(); return nil
            case 126: self.onArrow(true); return nil
            case 125: self.onArrow(false); return nil
            default: return e
            }
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

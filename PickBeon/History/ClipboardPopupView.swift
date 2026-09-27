import SwiftUI
import AppKit

// 커맨드 팔레트식 히스토리 팝업(화면 중앙): 검색 + 호버 미리보기 + 핀 + Cmd+1~5
struct ClipboardPopupView: View {
    @ObservedObject var store: ClipboardStore
    private enum ScopeFilter: String, CaseIterable {
        case all, translated, clip
        var label: String {
            switch self {
            case .all: String(localized: "전체")
            case .translated: String(localized: "번역")
            case .clip: String(localized: "클립보드")
            }
        }
    }
    @State private var query = ""
    @State private var scope: ScopeFilter = .all
    @State private var hoverID: UUID?
    @State private var pinnedID: UUID?
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool
    var onPaste: ((HistoryRecord) -> Void)?
    /// 창 닫기. orderOut 이 아니라 close 로 끝내야 WindowDropper 수명주기 콜백이 돌아간다.
    var onDismiss: () -> Void = {}

    private var previewRecord: HistoryRecord? {
        if let id = pinnedID, let r = store.items.first(where: { $0.id == id }) { return r }
        if let id = hoverID, let r = store.items.first(where: { $0.id == id }) { return r }
        if filtered.indices.contains(selectedIndex) { return filtered[selectedIndex] }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(alignment: .top, spacing: 0) {
                if filtered.isEmpty {
                    emptyState
                } else {
                    list
                }
                if let p = previewRecord {
                    Rectangle().fill(Theme.line).frame(width: 1)
                    HistoryRecordPreview(record: p)
                        .frame(width: 176)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            footerHint
        }
        .frame(width: 610, height: 480)
        .background(Theme.bg)
        .animation(Theme.hoverFade, value: previewRecord?.id)
        .onAppear {
            searchFocused = true
            pinnedID = nil
            selectedIndex = 0
        }
        .onExitCommand { onDismiss() }
        .background(
            KeyObserver(
                query: $query, count: filtered.count,
                selectedIndex: $selectedIndex, pinnedID: $pinnedID,
                onDismiss: onDismiss
            ) { idx in
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

    // MARK: 필터
    private var filterBar: some View {
        HStack(spacing: 4) {
            ForEach(ScopeFilter.allCases, id: \.rawValue) { f in
                let isOn = scope == f
                Text(f.label)
                    .font(Theme.font(11.5, weight: isOn ? .semibold : .medium))
                    .foregroundStyle(isOn ? Theme.accent : Theme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(isOn ? Theme.accent.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rTab))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Theme.hoverFade) {
                            scope = f
                            selectedIndex = 0
                        }
                    }
                    .onHover { h in if h { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() } }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: 하단 힌트
    private var footerHint: some View {
        HStack(spacing: 6) {
            KeyCap(text: "⌘1")
            Text(String(localized: "복사"))
                .font(Theme.font(11))
                .foregroundStyle(Theme.textSecondary)
            KeyCap(text: "↵")
            Text(String(localized: "붙여넣기"))
                .font(Theme.font(11))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(String(format: String(localized: "%d건"), filtered.count))
                .font(Theme.font(11))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
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
        .frame(maxWidth: .infinity)
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
        .onTapGesture {
            if pinnedID == r.id { pinnedID = nil; paste(at: index) }
            else { pinnedID = r.id }
        }
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
        var rows = store.items
        switch scope {
        case .all: break
        case .translated: rows = rows.filter { !$0.translated.isEmpty }
        case .clip: rows = rows.filter { $0.translated.isEmpty }
        }
        if query.isEmpty { return rows }
        return rows.filter {
            $0.text.localizedCaseInsensitiveContains(query) ||
            $0.translated.localizedCaseInsensitiveContains(query)
        }
    }

    private func paste(at index: Int) {
        guard filtered.indices.contains(index) else { return }
        pasteItem(filtered[index])
    }

    private func pasteItem(_ r: HistoryRecord) {
        // 번역문(있으면 번역 우선) + 이미지를 한 item 에 함께 실어 기존 paste 도 동작을 보존.
        let text = r.translated.isEmpty ? r.text : r.translated
        PasteboardService.write(text: text, imagePNG: r.isImage ? r.pngData : nil)
        onPaste?(r)
        onDismiss()
    }

    private func copyItem(_ r: HistoryRecord) {
        PasteboardService.write(text: r.translated.isEmpty ? r.text : r.translated)
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

// MARK: - 호버 미리보기 (전체 검색 우측 + 팝오버 내장 공용)
struct HistoryRecordPreview: View {
    let record: HistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Text(String(localized: "미리보기"))
                    .font(Theme.font(10.5, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if record.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.pinColor)
                }
                Text(record.date, style: .time)
                    .font(Theme.font(10))
                    .foregroundStyle(Theme.textSecondary.opacity(0.75))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if record.isImage, let data = record.pngData, let img = NSImage(data: data) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                    }
                    if !record.text.isEmpty {
                        previewBlock(title: String(localized: "원문"), body: record.text, accent: false)
                    }
                    if !record.translated.isEmpty {
                        previewBlock(title: String(localized: "번역"), body: record.translated, accent: true)
                    }
                    if record.text.isEmpty && record.translated.isEmpty && !record.isImage {
                        Text(String(localized: "내용 없음"))
                            .font(Theme.font(11.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface)
    }

    private func previewBlock(title: String, body: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.font(10, weight: .bold))
                .foregroundStyle(accent ? Theme.accent : Theme.textSecondary)
            Text(body)
                .font(Theme.font(11.5))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(accent ? Theme.transPanel : Theme.surface2.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent ? Theme.transPanelLine : Theme.line, lineWidth: 1)
        )
    }
}

// MARK: - Cmd+1~5 / Enter / Esc / 방향키 (local monitor — 포커스 가로채지 않음)
private struct KeyObserver: NSViewRepresentable {
    @Binding var query: String
    let count: Int
    @Binding var selectedIndex: Int
    @Binding var pinnedID: UUID?
    var onDismiss: () -> Void = {}
    let onPaste: (Int) -> Void

    func makeNSView(context: Context) -> MonitorView {
        MonitorView(
            onDigit: { d in onPaste(d - 1) },
            onEnter: { onPaste(selectedIndex) },
            onEscape: {
                pinnedID = nil
                onDismiss()
            },
            onArrow: { up in
                if up { selectedIndex = max(0, selectedIndex - 1) }
                else { selectedIndex = min(max(count - 1, 0), selectedIndex + 1) }
            }
        )
    }
    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onDigit = { d in onPaste(d - 1) }
        nsView.onEnter = { onPaste(selectedIndex) }
        nsView.onEscape = {
            pinnedID = nil
            onDismiss()
        }
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

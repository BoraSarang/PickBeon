import Foundation
import SwiftData
import AppKit

@Model
final class HistoryRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    var translated: String = ""
    var isImage: Bool = false
    @Attribute(.externalStorage) var pngData: Data?
    var pinned: Bool = false
    init(text: String, translated: String = "", isImage: Bool = false, png: Data? = nil) {
        self.text = text; self.translated = translated; self.isImage = isImage; self.pngData = png
    }
}

// Maccy식: 0.5초 NSPasteboard 폴링, concealed 제외. 시작 시 DB 로드(영속화).
@MainActor
final class ClipboardStore: ObservableObject {
    @Published var items: [HistoryRecord] = []
    private var timer: Timer?
    private var lastChange = NSPasteboard.general.changeCount
    private var storedContext: ModelContext?

    func startPolling(context: ModelContext) {
        DebugLogger.shared.info(feature: "Clipboard", "폴링 시작 0.5s + DB 로드")
        storedContext = context
        load(context: context)
        timer = .scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollWithStored() }
        }
    }

    // 재실행 후 히스토리 소실 방지: DB에서 최근 순으로 로드
    func load(context: ModelContext) {
        do {
            var d = FetchDescriptor<HistoryRecord>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            d.fetchLimit = 500
            let rows = try context.fetch(d)
            items = rows
            DebugLogger.shared.cache("히스토리 로드 \(rows.count)건")
            enforceLimit(context: context)
        } catch {
            DebugLogger.shared.error(code: "E-MAC-STORE-0001", "히스토리 로드 실패 \(error)")
        }
    }

    func pollWithStored() {
        guard let ctx = storedContext else { return }
        poll(context: ctx)
    }

    func poll(context: ModelContext) {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount
        if let s = pb.string(forType: .string), !s.isEmpty {
            add(text: s, context: context)
        } else if let data = pb.data(forType: .png), AppSettings.shared.saveImages {
            add(text: String(localized: "이미지"), isImage: true, png: data, context: context)
        }
    }

    func add(text: String, translated: String = "", isImage: Bool = false, png: Data? = nil, context: ModelContext) {
        // 동일 내용 선두 중복 스킵
        if let first = items.first, first.text == text, first.translated == translated { 
            lastChange = NSPasteboard.general.changeCount
            return
        }
        let r = HistoryRecord(text: text, translated: translated, isImage: isImage, png: png)
        context.insert(r)
        items.insert(r, at: 0)
        enforceLimit(context: context)
        // 자기복사 중복 방지: 우리 복사로 바뀐 페이스트보드를 폴링이 다시 add하지 않도록 동기화
        lastChange = NSPasteboard.general.changeCount
        DebugLogger.shared.cache("히스토리 추가 \(items.count)개")
    }

    func delete(_ r: HistoryRecord, context: ModelContext) {
        items.removeAll { $0 === r }
        context.delete(r)
        try? context.save()
    }

    func togglePin(_ r: HistoryRecord, context: ModelContext) {
        r.pinned.toggle()
        try? context.save()
        // 핀은 상단 정렬 유지
        items.removeAll { $0 === r }
        if r.pinned { items.insert(r, at: 0) }
        else { items.append(r) }
    }

    // limit 초과분은 배열·DB 모두 삭제 (pinned 보존)
    func enforceLimit(context: ModelContext) {
        let lim = AppSettings.shared.historyLimitRaw
        guard lim > 0, items.count > lim else { return }
        let pinned = items.filter { $0.pinned }
        let keepCount = max(lim - pinned.count, 0)
        let rest = items.filter { !$0.pinned }
        let excess = Array(rest.dropFirst(keepCount))
        for r in excess { context.delete(r) }
        items = pinned + Array(rest.prefix(keepCount))
        try? context.save()
        DebugLogger.shared.cache("히스토리 limit 적용 \(items.count)개 (삭제 \(excess.count))")
    }
}

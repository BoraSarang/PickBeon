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

// Maccy식: 0.5초 NSPasteboard 폴링, concealed 제외
@MainActor
final class ClipboardStore: ObservableObject {
    @Published var items: [HistoryRecord] = []
    private var timer: Timer?
    private var lastChange = NSPasteboard.general.changeCount

    func startPolling(context: ModelContext) {
        DebugLogger.shared.info(feature: "Clipboard", "폴링 시작 0.5s")
        storedContext = context
        timer = .scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollWithStored() }
        }
    }
    private var storedContext: ModelContext?
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
        let r = HistoryRecord(text: text, translated: translated, isImage: isImage, png: png)
        context.insert(r)
        items.insert(r, at: 0)
        enforceLimit(context: context)
        DebugLogger.shared.cache("히스토리 추가 \(items.count)개")
    }
    func enforceLimit(context: ModelContext) {
        let lim = AppSettings.shared.historyLimitRaw
        guard lim > 0, items.count > lim else { return }
        let pinned = items.filter { $0.pinned }
        let rest = items.filter { !$0.pinned }
        items = pinned + Array(rest.prefix(lim - pinned.count))
    }
}

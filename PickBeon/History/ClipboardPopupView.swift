import SwiftUI

// Raycast식 팝업: 검색 + 혼합리스트 + Cmd+1~5
struct ClipboardPopupView: View {
    @ObservedObject var store: ClipboardStore
    @State private var query = ""
    var body: some View {
        VStack {
            TextField(String(localized: "검색"), text: $query).textFieldStyle(.roundedBorder).padding()
            List(filtered) { r in
                HStack {
                    if r.isImage { Image(systemName: "photo").foregroundColor(.blue) }
                    else { Image(systemName: "doc.text") }
                    VStack(alignment: .leading) {
                        Text(r.text).lineLimit(1)
                        if !r.translated.isEmpty { Text(r.translated).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                    }
                    Spacer()
                    if r.pinned { Image(systemName: "pin.fill").foregroundColor(.orange) }
                }
            }
        }.frame(width: 420, height: 480)
    }
    var filtered: [HistoryRecord] {
        if query.isEmpty { return store.items }
        return store.items.filter { $0.text.localizedCaseInsensitiveContains(query) || $0.translated.localizedCaseInsensitiveContains(query) }
    }
}

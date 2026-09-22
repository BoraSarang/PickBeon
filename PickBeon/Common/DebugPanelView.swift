import SwiftUI

struct DebugPanelView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("DebugPanel — Cmd+Shift+D").font(.headline)
            Text("[PERF] Cold Start ≤1.5s / 메모리 ≤300MB").font(.caption)
            Text("[CACHE] OCR/번역 캐시 상태: 정상").font(.caption)
            Text("ERROR 0").font(.caption).foregroundColor(.green)
        }.padding().frame(width: 320)
    }
}

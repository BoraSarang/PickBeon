import SwiftUI

// Jot 자리 경량 에디터: 주석 툴바 + 이미지/번호박스 + OCR/번역. 캡쳐 후에만 열림.
struct TranslationEditorView: View {
    var image: NSImage?
    @ObservedObject var ocr: OCRService
    @ObservedObject var translator: TranslationService
    @ObservedObject var coordinator: AppCoordinator
    @State private var selected: UUID?
    @State private var showBoxes = true
    @State private var tab = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Tool("✒️", tip: "P1").disabled(true)
                Tool("↗", tip: "P1").disabled(true)
                Tool("▢", tip: "P1").disabled(true)
                Tool("T", tip: "P1").disabled(true)
                Button("◰") { showBoxes.toggle() }
                    .buttonStyle(.plain).font(.system(size: 13)).padding(7)
                    .background(showBoxes ? Color.accentColor : Color.clear).foregroundColor(showBoxes ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .help(String(localized: "번역 박스 표시"))
                Spacer()
                Button(String(localized: "⧉ 복사")) { NSPasteboard.general.setString(translator.result.isEmpty ? coordinator.latestTranslated : translator.result, forType: .string) }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
                Button("📌") { }.buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
                    .help(String(localized: "핀 (P1: 화면 상주)"))
            }.padding(.horizontal, 12).padding(.vertical, 9)
            Divider()
            HStack(spacing: 0) {
                ZStack {
                    if let img = image {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                        if showBoxes {
                            GeometryReader { geo in
                                let iw = max(img.size.width, 1), ih = max(img.size.height, 1)
                                let s = min(geo.size.width / iw, geo.size.height / ih)
                                let rw = iw * s, rh = ih * s
                                let ox = (geo.size.width - rw) / 2, oy = (geo.size.height - rh) / 2
                                ForEach(Array(ocr.lines.enumerated()), id: \.element.id) { i, l in
                                    let r = CGRect(x: ox + l.box.minX * rw, y: oy + l.box.minY * rh,
                                                   width: l.box.width * rw, height: l.box.height * rh)
                                    ZStack(alignment: .topLeading) {
                                        Rectangle().stroke(selected == l.id ? Color.white : Color(red: 0.49, green: 0.49, blue: 0.96), lineWidth: 1.5)
                                            .frame(width: max(r.width, 8), height: max(r.height, 8))
                                        Text("\(i + 1)").font(.system(size: 10, weight: .bold))
                                            .frame(width: 18, height: 18).background(selected == l.id ? Color.accentColor : Color.black.opacity(0.75))
                                            .foregroundColor(.white).clipShape(Circle()).offset(x: -9, y: -9)
                                    }
                                    .position(x: r.midX, y: r.midY)
                                    .onTapGesture { selected = l.id }
                                }
                            }
                        }
                    } else { Color.gray.opacity(0.15) }
                }.frame(minWidth: 300)
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        TTab(0, "OCR"); TTab(1, String(localized: "번역"))
                    }.padding(3).background(Color.black.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 9))
                    if tab == 0 {
                        List(ocr.lines, selection: $selected) { l in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.text).font(.system(size: 12.5))
                                Text(String(format: String(localized: "신뢰도 %.0f%%"), l.confidence * 100)).font(.system(size: 11)).foregroundColor(.secondary)
                            }.padding(2)
                        }.listStyle(.plain)
                    } else {
                        Text(translator.result.isEmpty ? coordinator.latestTranslated : translator.result)
                            .font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9).background(Color(red: 0.1, green: 0.11, blue: 0.15)).clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.accentColor.opacity(0.35)))
                        Button(translator.isTranslating ? String(localized: "번역 중…") : String(localized: "다시 번역")) {
                            Task {
                                let joined = ocr.lines.map(\.text).joined(separator: "\n")
                                if !joined.isEmpty { _ = try? await translator.translate(joined, polite: AppSettings.shared.politeTone) }
                            }
                        }.buttonStyle(.borderedProminent).font(.system(size: 12)).disabled(translator.isTranslating)
                    }
                    Spacer()
                }.frame(minWidth: 210).padding(12)
            }.frame(minHeight: 280)
        }.frame(width: 640, height: 420)
    }

    private func Tool(_ t: String, tip: String) -> some View {
        Button(t) {}.buttonStyle(.plain).font(.system(size: 13)).padding(7).foregroundColor(.secondary).help(tip)
    }
    private func TTab(_ i: Int, _ t: String) -> some View {
        Button(t) { tab = i }.buttonStyle(.plain).font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(tab == i ? Color.white.opacity(0.14) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

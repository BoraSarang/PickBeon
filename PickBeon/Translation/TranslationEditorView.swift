import SwiftUI
import AppKit

// 에디터: 좌 이미지(OCR박스+번역오버레이+주석) / 우 OCR·번역+말투토글. 캡쳐 후에만 열림.
enum AnnotTool { case browse, pen, arrow, rect, text }
enum AnnotKind { case pen, arrow, rect, note }

struct Annotation: Identifiable {
    let id = UUID()
    var kind: AnnotKind
    var points: [CGPoint] // 정규화 top-left 좌표. pen=경로, arrow/rect=[시작,끝], note=[앵커]
    var text: String = ""
}

// aspect-fit 매핑: 화면 픽셀 ↔ 이미지 정규화 좌표
struct FitMap {
    var s: CGFloat; var ox: CGFloat; var oy: CGFloat; var rw: CGFloat; var rh: CGFloat
    static func make(geo: CGSize, img: CGSize) -> FitMap {
        let iw = max(img.width, 1), ih = max(img.height, 1)
        let s = min(geo.width / iw, geo.height / ih)
        let rw = iw * s, rh = ih * s
        return FitMap(s: s, ox: (geo.width - rw) / 2, oy: (geo.height - rh) / 2, rw: rw, rh: rh)
    }
    func rect(_ box: CGRect) -> CGRect {
        CGRect(x: ox + box.minX * rw, y: oy + box.minY * rh, width: box.width * rw, height: box.height * rh)
    }
    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * rw, y: oy + p.y * rh) }
    func unpoint(_ px: CGPoint) -> CGPoint {
        CGPoint(x: min(1, max(0, (px.x - ox) / rw)), y: min(1, max(0, (px.y - oy) / rh)))
    }
}

struct TranslationEditorView: View {
    var image: NSImage?
    @ObservedObject var ocr: OCRService
    @ObservedObject var translator: TranslationService
    @ObservedObject var coordinator: AppCoordinator
    @State private var selected: UUID?
    @AppStorage("overlayOn") private var showBoxes = true
    @AppStorage("transOverlayOn") private var showTransOverlay = false
    @AppStorage("politeTone") private var politeTone = true
    @State private var tab = 1
    @State private var tool: AnnotTool = .browse
    @State private var annotations: [Annotation] = []
    @State private var draft: [CGPoint]? // 진행 중 스트로크 (정규화 좌표)
    @State private var pendingNote: CGPoint?
    @State private var pendingText = ""
    @State private var overlayMap: [UUID: String] = [:]
    @State private var overlayBusy = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                imagePane.frame(minWidth: 420)
                rightPanel.frame(width: 300)
            }.frame(minHeight: 420)
        }.frame(minWidth: 800, minHeight: 520)
    }

    // MARK: - 툴바
    private var toolbar: some View {
        HStack(spacing: 2) {
            toolBtn("☝️", tip: String(localized: "선택"), active: tool == .browse) { tool = .browse }
            toolBtn("✒️", tip: String(localized: "펜"), active: tool == .pen) { toggleTool(.pen) }
            toolBtn("↗", tip: String(localized: "화살표"), active: tool == .arrow) { toggleTool(.arrow) }
            toolBtn("▢", tip: String(localized: "박스"), active: tool == .rect) { toggleTool(.rect) }
            toolBtn("T", tip: String(localized: "텍스트 (탭して 입력)"), active: tool == .text) { toggleTool(.text) }
            toolBtn("◰", tip: String(localized: "OCR 박스 표시"), active: showBoxes) { showBoxes.toggle() }
            toolBtn(String(localized: "역"), tip: String(localized: "번역 오버레이"), active: showTransOverlay) { showTransOverlay.toggle() }
            toolBtn("↩", tip: String(localized: "실행 취소"), active: false, enabled: !annotations.isEmpty) { _ = annotations.popLast() }
            toolBtn("🗑", tip: String(localized: "주석 지우기"), active: false, enabled: !annotations.isEmpty) { annotations.removeAll() }
            Spacer()
            Button(String(localized: "⧉ 복사")) { copyAll() }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
            Button("📌") { pinCurrent() }.buttonStyle(.plain).font(.system(size: 12)).foregroundColor(.secondary)
                .help(String(localized: "핀 (화면 상주)"))
        }.padding(.horizontal, 12).padding(.vertical, 9)
    }

    private func toggleTool(_ t: AnnotTool) {
        tool = (tool == t) ? .browse : t
        if tool != .text { pendingNote = nil }
    }

    private func toolBtn(_ t: String, tip: String, active: Bool, enabled: Bool = true, _ act: @escaping () -> Void) -> some View {
        Button(t, action: act)
            .buttonStyle(.plain).font(.system(size: 13)).padding(7)
            .background(active ? Color.accentColor : Color.clear)
            .foregroundColor(active ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(!enabled).opacity(enabled ? 1 : 0.4)
            .help(tip)
    }

    // MARK: - 이미지 영역
    private var imagePane: some View {
        ZStack {
            if let img = image {
                GeometryReader { geo in
                    let map = FitMap.make(geo: geo.size, img: img.size)
                    ZStack {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                        if showBoxes { boxesLayer(map) }
                        if showTransOverlay { overlayLayer(map) }
                        annotLayer(map)
                        if let d = draft, d.count >= 1 { draftLayer(map, d) }
                        // 제스처 수신층 (선택 모드에서는 투명 통과 → 박스 탭 살아있음)
                        Color.clear.contentShape(Rectangle())
                            .gesture(drawGesture(map))
                            .allowsHitTesting(tool != .browse)
                        if let anchor = pendingNote { noteField(map, anchor) }
                    }.frame(width: geo.size.width, height: geo.size.height)
                }
            } else { Color.gray.opacity(0.15) }
        }
    }

    private func boxesLayer(_ map: FitMap) -> some View {
        ZStack {
            ForEach(Array(ocr.lines.enumerated()), id: \.element.id) { i, l in
                let r = map.rect(l.box)
                ZStack(alignment: .topLeading) {
                    Rectangle().stroke(selected == l.id ? Color.white : Color(red: 0.49, green: 0.49, blue: 0.96), lineWidth: 1.5)
                        .frame(width: max(r.width, 8), height: max(r.height, 8))
                    Text("\(i + 1)").font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18).background(selected == l.id ? Color.accentColor : Color.black.opacity(0.75))
                        .foregroundColor(.white).clipShape(Circle()).offset(x: -9, y: -9)
                }
                .position(x: r.midX, y: r.midY)
                .onTapGesture { selected = l.id }
                .help(l.text)
            }
        }.allowsHitTesting(tool == .browse)
    }

    private func overlayLayer(_ map: FitMap) -> some View {
        ZStack {
            ForEach(ocr.lines) { l in
                if let t = overlayMap[l.id] {
                    let r = map.rect(l.box)
                    Text(t)
                        .font(.system(size: max(9, min(26, r.height * 0.5))))
                        .lineLimit(3).minimumScaleFactor(0.4)
                        .foregroundColor(.white).padding(3)
                        .frame(width: max(r.width, 30), height: max(r.height, 14))
                        .background(Color.black.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .position(x: r.midX, y: r.midY)
                }
            }
        }.allowsHitTesting(false)
    }

    private func annotLayer(_ map: FitMap) -> some View {
        ZStack {
            ForEach(annotations) { a in annotView(map, a) }
        }.allowsHitTesting(false)
    }

    private func annotView(_ map: FitMap, _ a: Annotation) -> some View {
        let pts = a.points.map { map.point($0) }
        return Group {
            switch a.kind {
            case .pen:
                pathOf(pts).stroke(Color.red, lineWidth: 2.5)
            case .rect:
                if pts.count >= 2 { rectPath(pts).stroke(Color.red, lineWidth: 2.5) }
            case .arrow:
                if pts.count >= 2 {
                    ZStack {
                        pathOf(pts).stroke(Color.red, lineWidth: 2.5)
                        pathOf([pts[1]] + arrowHead(from: pts[0], to: pts[1], len: 14)).stroke(Color.red, lineWidth: 2.5)
                    }
                }
            case .note:
                if let p = pts.first {
                    Text(a.text).font(.system(size: 12)).padding(5)
                        .background(Color.red).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 6))
                        .position(p)
                }
            }
        }
    }

    private func draftLayer(_ map: FitMap, _ d: [CGPoint]) -> some View {
        let pts = d.map { map.point($0) }
        return Group {
            switch tool {
            case .pen: pathOf(pts).stroke(Color.red.opacity(0.8), lineWidth: 2.5)
            case .rect: if pts.count >= 2 { rectPath(pts).stroke(Color.red.opacity(0.8), lineWidth: 2.5) }
            case .arrow:
                if pts.count >= 2 {
                    ZStack {
                        pathOf(pts).stroke(Color.red.opacity(0.8), lineWidth: 2.5)
                        pathOf([pts[1]] + arrowHead(from: pts[0], to: pts[1], len: 14)).stroke(Color.red.opacity(0.8), lineWidth: 2.5)
                    }
                }
            default: EmptyView()
            }
        }.allowsHitTesting(false)
    }

    private func pathOf(_ pts: [CGPoint]) -> Path {
        Path { p in
            guard let f = pts.first else { return }
            p.move(to: f); pts.dropFirst().forEach { p.addLine(to: $0) }
        }
    }

    private func rectPath(_ pts: [CGPoint]) -> Path {
        let x0 = min(pts[0].x, pts[1].x), y0 = min(pts[0].y, pts[1].y)
        return Path(CGRect(x: x0, y: y0, width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y)))
    }

    private func arrowHead(from p1: CGPoint, to p2: CGPoint, len: CGFloat) -> [CGPoint] {
        let ang = atan2(p2.y - p1.y, p2.x - p1.x)
        return [CGPoint(x: p2.x - len * cos(ang - .pi / 6), y: p2.y - len * sin(ang - .pi / 6)),
                CGPoint(x: p2.x - len * cos(ang + .pi / 6), y: p2.y - len * sin(ang + .pi / 6))]
    }

    private func drawGesture(_ map: FitMap) -> some Gesture {
        let drag = DragGesture(minimumDistance: 2)
            .onChanged { v in
                let p = map.unpoint(v.location)
                switch tool {
                case .pen:
                    if draft == nil { draft = [p] } else { draft?.append(p) }
                case .arrow, .rect:
                    if draft == nil { draft = [p, p] } else if draft!.count >= 2 { draft?[1] = p }
                case .text:
                    break
                case .browse:
                    break
                }
            }
            .onEnded { v in
                let p = map.unpoint(v.location)
                switch tool {
                case .pen:
                    if var d = draft, d.count >= 2 { d.append(p); annotations.append(Annotation(kind: .pen, points: d)) }
                    draft = nil
                case .arrow, .rect:
                    if let d = draft, d.count >= 2 {
                        let kind: AnnotKind = (tool == .arrow) ? .arrow : .rect
                        if hypot(d[1].x - d[0].x, d[1].y - d[0].y) > 0.005 {
                            annotations.append(Annotation(kind: kind, points: [d[0], p]))
                        }
                    }
                    draft = nil
                default:
                    draft = nil
                }
            }
            .simultaneously(with: SpatialTapGesture().onEnded { v in
                // 텍스트 도구: 탭 위치에 입력창
                if tool == .text { pendingNote = map.unpoint(v.location); pendingText = "" }
            })
        return drag
    }

    private func noteField(_ map: FitMap, _ anchor: CGPoint) -> some View {
        let px = map.point(anchor)
        let cx = map.rw > 200 ? min(max(px.x, 95), map.ox + map.rw - 95) : px.x
        return TextField(String(localized: "메모 입력"), text: $pendingText)
            .textFieldStyle(.roundedBorder).font(.system(size: 12)).frame(width: 180)
            .position(x: cx, y: px.y)
            .onSubmit {
                let t = pendingText.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { annotations.append(Annotation(kind: .note, points: [anchor], text: t)) }
                pendingNote = nil; pendingText = ""
            }
            .onExitCommand { pendingNote = nil; pendingText = "" }
    }

    // MARK: - 우측 패널
    private var rightPanel: some View {
        VStack(spacing: 8) {
            Picker("", selection: $politeTone) {
                Text(String(localized: "존댓말")).tag(true)
                Text(String(localized: "캐주얼")).tag(false)
            }.pickerStyle(.segmented)
            .onChange(of: politeTone) { _, _ in Task { await retranslate() } }
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
                if showTransOverlay {
                    if overlayBusy {
                        ProgressView(String(localized: "줄 매핑 중…")).font(.system(size: 11)).foregroundColor(.secondary)
                    } else {
                        Text(String(format: String(localized: "오버레이 %d/%d줄"), overlayMap.count, ocr.lines.count))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                Button(translator.isTranslating ? String(localized: "번역 중…") : String(localized: "다시 번역")) {
                    Task { await retranslate() }
                }.buttonStyle(.borderedProminent).font(.system(size: 12)).disabled(translator.isTranslating)
            }
            Spacer()
        }.frame(minWidth: 210).padding(12)
        .onChange(of: showTransOverlay) { _, on in
            if on { Task { overlayBusy = true; await refreshOverlay(); overlayBusy = false } }
        }
        .onChange(of: ocr.lines.count) { _, _ in
            if showTransOverlay { Task { overlayBusy = true; await refreshOverlay(); overlayBusy = false } }
        }
    }

    private func TTab(_ i: Int, _ t: String) -> some View {
        Button(t) { tab = i }.buttonStyle(.plain).font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(tab == i ? Color.white.opacity(0.14) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - 동작
    private func retranslate() async {
        let joined = ocr.lines.map(\.text).joined(separator: "\n")
        guard !joined.isEmpty else { return }
        if let out = try? await translator.translate(joined, polite: politeTone) {
            coordinator.latestTranslated = out
        }
        if showTransOverlay { await refreshOverlay() }
    }

    private func refreshOverlay() async {
        let lines = ocr.lines
        guard !lines.isEmpty else { overlayMap = [:]; return }
        var full = !translator.result.isEmpty ? translator.result : coordinator.latestTranslated
        if full.isEmpty {
            let joined = lines.map(\.text).joined(separator: "\n")
            full = (try? await translator.translate(joined, polite: politeTone)) ?? ""
        }
        let parts = full.components(separatedBy: "\n")
        var map: [UUID: String] = [:]
        for (i, l) in lines.enumerated() where i < parts.count {
            let t = parts[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { map[l.id] = t }
        }
        overlayMap = map
    }

    private func copyAll() {
        let text = translator.result.isEmpty ? coordinator.latestTranslated : translator.result
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        if !annotations.isEmpty, let img = image {
            NSPasteboard.general.writeObjects([renderAnnotated(img)])
        }
    }

    private func pinCurrent() {
        guard let img = image else { return }
        coordinator.pinImage(annotations.isEmpty ? img : renderAnnotated(img))
    }

    // 주석 합성: 원본 크기로 렌더 (복사·핀용)
    private func renderAnnotated(_ img: NSImage) -> NSImage {
        let size = img.size
        let out = NSImage(size: size)
        out.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: size))
        let red = NSColor.systemRed
        red.setStroke(); red.setFill()
        let lw = max(2, size.width / 500)
        for a in annotations {
            let pts = a.points.map { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) }
            switch a.kind {
            case .pen:
                let bp = NSBezierPath(); bp.lineWidth = lw; bp.lineCapStyle = .round; bp.lineJoinStyle = .round
                if let f = pts.first { bp.move(to: f); pts.dropFirst().forEach { bp.line(to: $0) }; bp.stroke() }
            case .rect:
                if pts.count >= 2 {
                    let r = NSRect(x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                                   width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y))
                    let bp = NSBezierPath(rect: r); bp.lineWidth = lw; bp.stroke()
                }
            case .arrow:
                if pts.count >= 2 {
                    let bp = NSBezierPath(); bp.lineWidth = lw; bp.lineCapStyle = .round
                    bp.move(to: pts[0]); bp.line(to: pts[1]); bp.stroke()
                    let heads = arrowHead(from: pts[0], to: pts[1], len: 10 + lw * 4)
                    let hp = NSBezierPath(); hp.lineWidth = lw; hp.lineCapStyle = .round
                    hp.move(to: pts[1]); hp.line(to: heads[0]); hp.move(to: pts[1]); hp.line(to: heads[1]); hp.stroke()
                }
            case .note:
                if let p = pts.first, !a.text.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: lw * 7), .foregroundColor: NSColor.white]
                    let ts = (a.text as NSString).size(withAttributes: attrs)
                    let bg = NSBezierPath(roundedRect: NSRect(x: p.x, y: p.y - ts.height - 8, width: ts.width + 16, height: ts.height + 12), xRadius: 6, yRadius: 6)
                    NSColor.systemRed.setFill(); bg.fill()
                    (a.text as NSString).draw(at: NSPoint(x: p.x + 8, y: p.y - ts.height - 2), withAttributes: attrs)
                }
            }
        }
        out.unlockFocus()
        return out
    }
}

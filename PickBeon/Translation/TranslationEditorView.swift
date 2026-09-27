import SwiftUI
import AppKit
import CoreImage

// 에디터: 좌 이미지(OCR박스+번역오버레이+주석) / 우 OCR·번역+말투토글. 캡쳐 후에만 열림.
enum AnnotTool { case browse, pen, arrow, rect, text, blur, mosaic }
enum AnnotKind: Equatable { case pen, arrow, rect, note, blur, mosaic }

struct Annotation: Identifiable, Equatable {
    let id = UUID()
    var kind: AnnotKind
    var points: [CGPoint] // 정규화 top-left 좌표. pen=경로, arrow/rect/blur/mosaic=[시작,끝], note=[앵커]
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
    /// [P0-3] 주석 id → 감열 렌더 결과. body 가 여러 번 평가돼도 CoreImage 를 다시 돌리지 않는다.
    @State private var redactCache: [UUID: Redactor.Output] = [:]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(Theme.line).frame(height: 1)
            HStack(spacing: 0) {
                imagePane.frame(minWidth: 420)
                Rectangle().fill(Theme.line).frame(width: 1)
                rightPanel.frame(width: 300)
            }.frame(minHeight: 420)
        }
        .frame(minWidth: 800, minHeight: 520)
        .background(Theme.bg)
        .onChange(of: annotations) { _, _ in rebuildRedactCache() }
        .onChange(of: image) { _, _ in rebuildRedactCache() }
        .onAppear { rebuildRedactCache() }
    }

    /// 감열 주석의 렌더 결과를 한 번만 계산해 캐시한다.
    /// 캐시가 없으면 preview 가 비어 보이므로 imagePane 의 else 폴백으로 영역 표시를 대체한다.
    private func rebuildRedactCache() {
        guard let image else { redactCache = [:]; return }
        var next: [UUID: Redactor.Output] = [:]
        for a in annotations {
            guard a.kind == .blur || a.kind == .mosaic, a.points.count >= 2 else { continue }
            let x0 = min(a.points[0].x, a.points[1].x), y0 = min(a.points[0].y, a.points[1].y)
            let w = abs(a.points[1].x - a.points[0].x), h = abs(a.points[1].y - a.points[0].y)
            guard w > 0.004, h > 0.004 else { continue }
            if let out = Redactor.apply(CGRect(x: x0, y: y0, width: w, height: h),
                                        in: image, style: a.kind == .blur ? .blur : .mosaic) {
                next[a.id] = out
            }
        }
        if next.count != redactCache.count { redactCache = next; return }
        for (k, v) in next where redactCache[k]?.image !== v.image { redactCache = next; return }
    }

    // MARK: - 툴바
    private var toolbar: some View {
        HStack(spacing: 4) {
            IconToolButton(systemName: "cursorarrow", tip: String(localized: "선택"), active: tool == .browse) { tool = .browse }
            IconToolButton(systemName: "pencil.tip", tip: String(localized: "펜"), active: tool == .pen) { toggleTool(.pen) }
            IconToolButton(systemName: "arrow.up.right", tip: String(localized: "화살표"), active: tool == .arrow) { toggleTool(.arrow) }
            IconToolButton(systemName: "rectangle", tip: String(localized: "박스"), active: tool == .rect) { toggleTool(.rect) }
            IconToolButton(systemName: "drop.halffull", tip: String(localized: "블러"), active: tool == .blur) { toggleTool(.blur) }
            IconToolButton(systemName: "checkerboard.rectangle", tip: String(localized: "모자이크"), active: tool == .mosaic) { toggleTool(.mosaic) }
            IconToolButton(systemName: "textformat", tip: String(localized: "텍스트 (탭して 입력)"), active: tool == .text) { toggleTool(.text) }
            Rectangle().fill(Theme.line).frame(width: 1, height: 18).padding(.horizontal, 4)
            IconToolButton(systemName: "square.dashed", tip: String(localized: "OCR 박스 표시"), active: showBoxes) { showBoxes.toggle() }
            IconToolButton(systemName: "character.bubble", tip: String(localized: "번역 오버레이"), active: showTransOverlay) { showTransOverlay.toggle() }
            IconToolButton(systemName: "arrow.uturn.backward", tip: String(localized: "실행 취소"), enabled: !annotations.isEmpty) { _ = annotations.popLast() }
            IconToolButton(systemName: "trash", tip: String(localized: "주석 지우기"), enabled: !annotations.isEmpty) { annotations.removeAll() }
            Spacer()
            // [P0-2] 복사가 무엇을 담았는지 명시 (텍스트만인지, 주석 포함 합성인지)
            if let toast = coordinator.copyToast {
                Text(toast)
                    .font(Theme.font(11, weight: .semibold))
                    .foregroundStyle(Theme.ok)
                    .fixedSize()
                    .transition(.opacity)
            }
            Button {
                copyAll()
            } label: {
                Label(String(localized: "복사"), systemImage: "doc.on.doc")
                    .font(Theme.font(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: Theme.rChip).fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            Button {
                pinCurrent()
            } label: {
                Image(systemName: "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: Theme.rChip).fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(String(localized: "핀 (화면 상주)"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.surface)
        .animation(Theme.hoverFade, value: coordinator.copyToast)
    }

    private func toggleTool(_ t: AnnotTool) {
        tool = (tool == t) ? .browse : t
        if tool != .text { pendingNote = nil }
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
            } else { Theme.surface2 }
        }
    }

    private func boxesLayer(_ map: FitMap) -> some View {
        ZStack {
            ForEach(Array(ocr.lines.enumerated()), id: \.element.id) { i, l in
                let r = map.rect(l.box)
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .stroke(selected == l.id ? Color.white : Theme.accent, lineWidth: 1.5)
                        .frame(width: max(r.width, 8), height: max(r.height, 8))
                    Text("\(i + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(selected == l.id ? Theme.accent : Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .offset(x: -9, y: -9)
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
            case .blur:
                if pts.count >= 2 {
                    if let r = redactCache[a.id] { redactedView(r, map: map) }
                    else { redactFallback(pts, map: map) }   // 캐시 전(첫 프레임) 영역만 표시
                }
            case .mosaic:
                if pts.count >= 2 {
                    if let r = redactCache[a.id] { redactedView(r, map: map) }
                    else { redactFallback(pts, map: map) }
                }
            }
        }
    }

    /// [P0-3] 미리보기 = 실제 결과. Redactor 출력(정규화 rect + 이미지)을 그대로 그린다.
    private func redactedView(_ out: Redactor.Output, map: FitMap) -> some View {
        Image(nsImage: out.image)
            .resizable()
            .interpolation(.high)
            .frame(width: max(map.rw * out.rect.width, 1), height: max(map.rh * out.rect.height, 1))
            .position(x: map.ox + out.rect.midX * map.rw, y: map.oy + out.rect.midY * map.rh)
            .allowsHitTesting(false)
    }

    /// 캐시 미완성 시 대체 표시. 감열이 사라진 것처럼 보이면 안 되므로 영역을 항상 드러낸다.
    private func redactFallback(_ pts: [CGPoint], map: FitMap) -> some View {
        let x0 = min(pts[0].x, pts[1].x), y0 = min(pts[0].y, pts[1].y)
        let w = abs(pts[1].x - pts[0].x), h = abs(pts[1].y - pts[0].y)
        return Rectangle()
            .fill(Color.black.opacity(0.45))
            .overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
            .frame(width: w, height: h)
            .position(x: x0 + w / 2, y: y0 + h / 2)
            .allowsHitTesting(false)
    }

    /// 드래그 중(아직 확정 전) 전용: 프레임마다 CoreImage 를 돌리지 않고 영역만 표시.
    /// 확정 직후 redactedView 로 실제 결과로 교체된다.
    private func redactDraft(_ pts: [CGPoint]) -> some View {
        let x0 = min(pts[0].x, pts[1].x), y0 = min(pts[0].y, pts[1].y)
        let w = abs(pts[1].x - pts[0].x), h = abs(pts[1].y - pts[0].y)
        return Rectangle()
            .fill(Color.black.opacity(0.45))
            .overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
            .frame(width: w, height: h)
            .position(x: x0 + w / 2, y: y0 + h / 2)
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
            case .blur:
                if pts.count >= 2 { redactDraft(pts) }
            case .mosaic:
                if pts.count >= 2 { redactDraft(pts) }
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
                case .arrow, .rect, .blur, .mosaic:
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
                case .arrow, .rect, .blur, .mosaic:
                    if let d = draft, d.count >= 2 {
                        let kind: AnnotKind
                        switch tool {
                        case .arrow: kind = .arrow
                        case .blur: kind = .blur
                        case .mosaic: kind = .mosaic
                        default: kind = .rect
                        }
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

    // MARK: - 우측 패널 (세로 분배: 탭 고정 → 본문 확장 → 액션 고정)
    private var rightPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                TTab(0, "OCR"); TTab(1, String(localized: "번역"))
            }
            .padding(3)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            if tab == 0 {
                List(ocr.lines, selection: $selected) { l in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.text).font(Theme.font(12.5))
                            .foregroundStyle(Theme.textPrimary)
                        Text(String(format: String(localized: "신뢰도 %.0f%%"), l.confidence * 100))
                            .font(Theme.font(11))
                            .foregroundStyle(Theme.textSecondary)
                    }.padding(2)
                }.listStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                toneToggle
                TransPanel {
                    ScrollView {
                        Text(currentTranslation)
                            .font(Theme.font(13))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.vertical, 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showTransOverlay {
                    if overlayBusy {
                        ProgressView(String(localized: "줄 매핑 중…")).font(Theme.font(11))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(String(format: String(localized: "오버레이 %d/%d줄"), overlayMap.count, ocr.lines.count))
                            .font(Theme.font(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                bottomActions
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(12)
        .background(Theme.bg)
        .onChange(of: showTransOverlay) { _, on in
            if on { Task { overlayBusy = true; await refreshOverlay(); overlayBusy = false } }
        }
        .onChange(of: ocr.lines.count) { _, _ in
            if showTransOverlay { Task { overlayBusy = true; await refreshOverlay(); overlayBusy = false } }
        }
    }

    private var currentTranslation: String {
        translator.result.isEmpty ? coordinator.latestTranslated : translator.result
    }

    private var bottomActions: some View {
        VStack(spacing: 8) {
            Button(translator.isTranslating ? String(localized: "번역 중…") : String(localized: "다시 번역")) {
                Task { await retranslate() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .font(Theme.font(12, weight: .semibold))
            .frame(maxWidth: .infinity)
            .disabled(translator.isTranslating)
            HStack(spacing: 8) {
                Button {
                    copyAll()
                } label: {
                    Label(String(localized: "복사"), systemImage: "doc.on.doc")
                        .font(Theme.font(11.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    coordinator.showHistory()
                } label: {
                    Label(String(localized: "기록"), systemImage: "clock")
                        .font(Theme.font(11.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            HStack {
                Spacer()
                Text(String(format: String(localized: "%d자"), currentTranslation.count))
                    .font(Theme.font(10.5))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var toneToggle: some View {
        Picker("", selection: $politeTone) {
            Text(String(localized: "존댓말")).tag(true)
            Text(String(localized: "캐주얼")).tag(false)
        }.pickerStyle(.segmented)
        .labelsHidden()
        .tint(Theme.accent)
        .onChange(of: politeTone) { _, _ in Task { await retranslate() } }
    }

    private func TTab(_ i: Int, _ t: String) -> some View {
        Button { tab = i } label: {
            Text(t)
                .font(Theme.font(12, weight: .semibold))
                .foregroundStyle(tab == i ? Theme.textPrimary : Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 26)
                .contentShape(Rectangle())
                .background(tab == i ? Color.primary.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
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
        // [P0-2] 과거엔 setString(번역문) 뒤에 writeObjects(합성이미지)를 불러 텍스트가 소실됐다.
        // 주석이 없으면 원본 이미지, 있으면 합성 이미지가 번역문과 함께 한 NSPasteboardItem 에 실린다.
        let text = translator.result.isEmpty ? coordinator.latestTranslated : translator.result
        let composite = annotations.isEmpty ? image : image.map { renderAnnotated($0) }
        let ok = PasteboardService.write(text: text, image: composite)
        coordinator.notifyCopy(ok: ok, extra: annotations.isEmpty ? nil : String(localized: "주석 포함"))
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
            case .blur, .mosaic:
                if pts.count >= 2 {
                    // [P0-3] 미리보기와 동일한 Redactor 결과를 쓴다.
                    // 과거엔 AppKit 하단원점 rect 를 CGImage(top-left)에 그대로 넣어
                    // 세로 대칭 영역을 감췄다. 여기선 정규화 rect → points 로만 변환한다.
                    guard let out = redactCache[a.id] else { break }
                    let dest = NSRect(
                        x: out.rect.minX * size.width,
                        y: (1 - out.rect.maxY) * size.height,
                        width: out.rect.width * size.width,
                        height: out.rect.height * size.height
                    )
                    guard dest.width > 1, dest.height > 1 else { break }
                    out.image.draw(in: dest)
                    red.setStroke()
                    let outline = NSRect(x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                                        width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y))
                    let bp = NSBezierPath(rect: outline); bp.lineWidth = 1; bp.stroke()
                }
            }
        }
        out.unlockFocus()
        return out
    }
}

import AppKit
import UniformTypeIdentifiers

// 클립보드 단일 진입점.
//
// [P0-2] NSPasteboard 는 선언 기반(writeObjects)과 데이터 기반(declareTypes/setData)을
// 혼용할 수 없다. writeObjects 는 내부에서 클립보드를 비우므로, 먼저 setString/setData 로
// 넣어 둔 값이 소실된다. 과거 이 파일이 없던 시점 두 곳에서 그대로 발생했다:
//   - TranslationEditorView.copyAll  : 번역문 setString → writeObjects(합성이미지) → 텍스트 사라짐
//   - AppCoordinator.finishGif       : GIF setData    → writeObjects(파일 URL) → GIF 사라짐
// 모두 하나의 NSPasteboardItem 에 타입을 모아 writeObjects 1회로 끝낸다.
@MainActor
enum PasteboardService {
    static var gifType: NSPasteboard.PasteboardType { NSPasteboard.PasteboardType("com.compuserve.gif") }

    // MARK: 쓰기 (항상 단일 NSPasteboardItem)

    /// 여러 item 을 그대로 복원해야 할 때의 탈출구 (AX 폴백의 클립보드 보존).
    /// writeObjects 를 1회만 호출하므로 setData 와 섞지 않는다.
    @discardableResult
    static func writeItems(_ items: [NSPasteboardItem]) -> Bool {
        guard !items.isEmpty else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(items)
        return true
    }

    /// - Parameters:
    ///   - text: 문자열 (번역문·OCR 텍스트)
    ///   - image: 이미지 (PNG 로 직렬화해 추가)
    ///   - gifData: GIF 바이트 (com.compuserve.gif 로 추가)
    ///   - fileURL: 파일 URL (.fileURL 로 추가, GIF 저장본 등)
    ///   - imagePNG: 이미 미리 PNG Data 로 변환된 경우 image 대신 사용 (재인코딩 방지)
    @discardableResult
    static func write(
        text: String? = nil,
        image: NSImage? = nil,
        imagePNG: Data? = nil,
        gifData: Data? = nil,
        fileURL: URL? = nil
    ) -> Bool {
        var wroteAnything = false
        let item = NSPasteboardItem()

        if let text, !text.isEmpty {
            item.setString(text, forType: .string)
            wroteAnything = true
        }
        if let png = imagePNG ?? image.flatMap(pngData(of:)) {
            item.setData(png, forType: .png)
            wroteAnything = true
        }
        if let gifData, !gifData.isEmpty {
            item.setData(gifData, forType: gifType)
            wroteAnything = true
        }
        if let fileURL {
            item.setString(fileURL.absoluteString, forType: .fileURL)
            wroteAnything = true
        }
        guard wroteAnything else {
            FileLog.log("Pasteboard 쓰기 대상 없음 — 무시")
            return false
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([item])
        FileLog.log("Pasteboard 기록: text=\(text != nil) png=\(imagePNG != nil || image != nil) gif=\(gifData != nil) file=\(fileURL != nil)")
        return true
    }

    // MARK: 읽기

    static var string: String? { NSPasteboard.general.string(forType: .string) }

    static func data(_ type: NSPasteboard.PasteboardType) -> Data? { NSPasteboard.general.data(forType: type) }

    static var changeCount: Int { NSPasteboard.general.changeCount }

    /// 폴백 동작처럼 클립보드를 잠시 빌려 써야 할 때의 스냅샷/복원용 타입 스냅샷.
    struct Snapshot {
        let strings: [String: String]   // pasteboardType rawValue -> content
        let datas: [String: Data]
    }

    static func snapshot(types: [NSPasteboard.PasteboardType]) -> [Snapshot] {
        guard let items = NSPasteboard.general.pasteboardItems else { return [] }
        return items.map { item in
            var strings: [String: String] = [:]
            var datas: [String: Data] = [:]
            for t in types {
                if let s = item.string(forType: t) { strings[t.rawValue] = s }
                else if let d = item.data(forType: t) { datas[t.rawValue] = d }
            }
            return Snapshot(strings: strings, datas: datas)
        }
    }

    // MARK: 공통 변환

    /// NSImage → PNG. savePNG / ImageTransferable / 클립보드 경로가 중복하던 것을 단일화.
    /// 순수 변환이므로 nonisolated (Transferable 정적 컨텍스트에서도 호출된다).
    nonisolated static func pngData(of image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

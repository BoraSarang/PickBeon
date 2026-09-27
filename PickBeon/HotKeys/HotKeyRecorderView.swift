import SwiftUI
import AppKit

/// 단축키 녹음 뷰. "변경" 을 누르면 다음에 누른 키 조합을 그대로 캡처한다.
/// 수정자 키는 조합에 포함되고, 단독 키는 거부된다(OS 전역 충돌 방지).
struct HotKeyRecorderView: NSViewRepresentable {
    var isRecording: Bool
    var onCapture: (HotKeyBinding?) -> Void

    func makeNSView(context: Context) -> HotKeyCaptureView {
        let v = HotKeyCaptureView()
        v.onCapture = onCapture
        v.isRecording = isRecording
        return v
    }

    func updateNSView(_ nsView: HotKeyCaptureView, context: Context) {
        nsView.onCapture = onCapture
        if nsView.isRecording != isRecording {
            nsView.isRecording = isRecording
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class HotKeyCaptureView: NSView {
    var onCapture: ((HotKeyBinding?) -> Void)?
    var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()
    }

    override func keyDown(with e: NSEvent) {
        // esc 취소
        if e.keyCode == 53 {
            onCapture?(nil)
            return
        }
        guard var binding = HotKeyBinding.from(e), binding.isValid else {
            NSSound.beep()
            return
        }
        // 실제 문자 기준으로 보정 (shift 를 썼는데 문자가 소문자로 오는 경우)
        if let ch = e.charactersIgnoringModifiers?.uppercased().first, ch.isLetter {
            if let code = HotKeyBinding.keyCode(forLetter: ch) { binding.keyCode = code }
        }
        onCapture?(binding)
    }
}

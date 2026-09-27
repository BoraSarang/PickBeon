import SwiftUI
import AppKit

/// 에디터 Undo/Redo (스냅샷 방식).
/// 주석은 경량 값 타입이라 전체 스냅샷을 저장해도 부담이 없다.
/// [P1 pickbeon-zpy] 기존엔 "실행 취소"가 `annotations.popLast()` 한 번뿐이라
/// 되돌리면 되돌린 것까지 다시 잃었다.
@MainActor
final class HistoryStack<Element: Equatable>: ObservableObject {
    private(set) var undoStack: [Element] = []
    private(set) var redoStack: [Element] = []
    private var present: Element
    private let limit = 50

    init(_ initial: Element) { present = initial }

    var current: Element { present }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// 변경 전 호출. 직전 상태를 undo 스택에 넣는다.
    func checkpoint() {
        undoStack.append(present)
        if undoStack.count > limit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    func commit(_ new: Element) {
        guard new != present else { return }
        undoStack.append(present)
        if undoStack.count > limit { undoStack.removeFirst() }
        redoStack.removeAll()
        present = new
    }

    @discardableResult
    func undo() -> Element {
        guard let prev = undoStack.popLast() else { return present }
        redoStack.append(present)
        present = prev
        return present
    }

    @discardableResult
    func redo() -> Element {
        guard let next = redoStack.popLast() else { return present }
        undoStack.append(present)
        present = next
        return next
    }

    func reset(to value: Element) {
        present = value
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

// MARK: - 에디터 키 단축키 (로컬 NSEvent 모니터)
//
// SwiftUI `.commands` 는 Scene modifier 라, NSWindow + NSHostingController 로 띄우는
// 에디터 창에서는 적용되지 않는다. 이 창이 키일 때만 이벤트를 가로챈다.
struct KeyCommandMonitor: NSViewRepresentable {
    /// true 를 반환하면 이벤트를 소비한다
    var handler: (NSEvent) -> Bool

    func makeNSView(context: Context) -> Monitor {
        let v = Monitor()
        v.handler = handler
        return v
    }

    func updateNSView(_ nsView: Monitor, context: Context) {
        nsView.handler = handler
    }

    final class Monitor: NSView {
        var handler: (NSEvent) -> Bool = { _ in false }
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                    guard let self else { return e }
                    // 텍스트 입력 중(메모 입력창 등)은 단축키를 가로채지 않는다
                    if self.window?.firstResponder is NSTextView,
                       !(e.modifierFlags.contains(.command)) { return e }
                    return self.handler(e) ? nil : e
                }
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        }
    }
}

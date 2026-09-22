import SwiftUI
import SwiftData
import AppKit

// 메뉴바 전용: NSStatusItem + NSPopover (MenuBarExtra 창 레이아웃 이슈 회피).
// 실행 시 창 없음 — 온보딩(권한 미비 시)만 뜰 수 있음.
@main
struct PickBeonApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate

    var body: some Scene {
        Settings { SettingsView() }
    }

    @MainActor
    final class Delegate: NSObject, NSApplicationDelegate {
        let container: ModelContainer
        private var statusItem: NSStatusItem?
        private var popover = NSPopover()

        override init() {
            if let c = try? ModelContainer(for: HistoryRecord.self) { container = c }
            else {
                let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try! ModelContainer(for: HistoryRecord.self, configurations: cfg)
            }
        }

        func applicationDidFinishLaunching(_ notification: Notification) {let co = AppCoordinator.shared
            co.configure(context: ModelContext(container))
            co.dismissMenu = { [weak self] in self?.popover.performClose(nil) }

            popover.contentViewController = NSHostingController(
                rootView: MenuPopupView(coordinator: co).modelContainer(container))
            popover.behavior = .transient
            popover.animates = true

            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let btn = statusItem?.button {
                if let img = NSImage(named: "menubar-18") {
                    img.isTemplate = true
                    btn.image = img
                } else {
                    btn.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "PickBeon")
                }
                btn.action = #selector(togglePopover(_:))
                btn.target = self
                btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            co.checkPermissionsOnLaunch()
            let hk = GlobalHotKeyService.shared
            hk.onCapture = { Task { @MainActor in AppCoordinator.shared.startCapture() } }
            hk.onTranslateSelection = { Task { @MainActor in AppCoordinator.shared.translateSelection() } }
            hk.registerDefaults()
            DebugLogger.shared.info(feature: "App", "메뉴바 상주 시작")
        }

        func applicationDidBecomeActive(_ notification: Notification) {
            // 설정 앱에서 돌아오면 자동 재확인
            let co = AppCoordinator.shared
            co.permissions.refresh()
            if co.permissions.allOK { co.closeOnboarding() }
        }

        @objc private func togglePopover(_ sender: AnyObject?) {
            if NSApp.currentEvent?.type == .rightMouseUp {
                AppCoordinator.shared.showDebug()
                return
            }
            guard let btn = statusItem?.button else { return }
            if popover.isShown { popover.performClose(sender) }
            else {
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            }
        }
    }
}

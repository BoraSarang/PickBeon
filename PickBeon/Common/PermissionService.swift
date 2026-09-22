import AppKit
import ApplicationServices
import ScreenCaptureKit

// 첫 실행 권한 검사 + 요청. 없으면 온보딩 카드만 표시.
@MainActor
final class PermissionService: ObservableObject {
    @Published var screenRecordingOK = false
    @Published var axOK = false
    var allOK: Bool { screenRecordingOK && axOK }

    func refresh() {
        screenRecordingOK = CGPreflightScreenCaptureAccess()
        axOK = AXIsProcessTrusted()
        DebugLogger.shared.info(feature: "Perm", "권한 상태 SR=\(screenRecordingOK) AX=\(axOK)")
    }

    // 시스템 확인창 유도. 콜백 없음 — 돌아오면 refresh()로 재확인.
    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        DebugLogger.shared.info(feature: "Perm", "화면 기록 요청 전송")
    }

    nonisolated func requestAX() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        Task { @MainActor in self.axOK = trusted }
        DebugLogger.shared.info(feature: "Perm", "손쉬운 사용 요청 전송")
    }

    func openAXSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // MARK: - 자동 확인 (온보딩 표시 중 폴링)
    private var pollTimer: Timer?
    var onAllGranted: (() -> Void)?

    func startAutoCheck() {
        stopAutoCheck()
        refresh()
        pollTimer = .scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                if self?.allOK == true {
                    self?.stopAutoCheck()
                    self?.onAllGranted?()
                }
            }
        }
        DebugLogger.shared.info(feature: "Perm", "자동 확인 시작 1.5s")
    }
    func stopAutoCheck() { pollTimer?.invalidate(); pollTimer = nil }
}

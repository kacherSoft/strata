import AppKit

@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published private(set) var isAccessibilityEnabled: Bool = false
    
    private init() {
        isAccessibilityEnabled = AXIsProcessTrusted()
    }
    
    // MARK: - Permission Check
    
    @discardableResult
    func checkPermission() -> Bool {
        isAccessibilityEnabled = AXIsProcessTrusted()
        return isAccessibilityEnabled
    }
    
    // MARK: - Permission Request
    
    func requestPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        startPermissionPolling()
    }
    
    // MARK: - Polling
    
    private func startPermissionPolling() {
        let task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                if AXIsProcessTrusted() {
                    self.isAccessibilityEnabled = true
                    self.pollingTask = nil
                    return
                }
            }
        }
        pollingTask = task
    }
    
    private var pollingTask: Task<Void, Never>? {
        willSet { pollingTask?.cancel() }
    }
}

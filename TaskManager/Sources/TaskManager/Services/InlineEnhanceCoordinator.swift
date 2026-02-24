import AppKit
import SwiftUI

@MainActor
final class InlineEnhanceCoordinator: ObservableObject {
    static let shared = InlineEnhanceCoordinator()
    
    private var hudPanel: InlineEnhanceHUDPanel?
    private var hudViewModel: HUDViewModel?
    private var autoDismissTask: Task<Void, Never>?
    private var enhanceTask: Task<Void, Never>?
    
    // New engines
    private let captureEngine = TextCaptureEngine.shared
    private let replaceEngine = TextReplacementEngine.shared
    
    // Debug mode
    var enableDebugMode: Bool = false {
        didSet {
            captureEngine.enableDebugLogging = enableDebugMode
            replaceEngine.enableDebugLogging = enableDebugMode
            ElectronSpecialist.shared.enableDebugLogging = enableDebugMode
            AppCategoryDetector.shared.enableDebugLogging = enableDebugMode
        }
    }
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    func performInlineEnhance() {
        enhanceTask?.cancel()
        
        let aiService = AIService.shared
        
        // 1. Check Accessibility permission
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            AccessibilityManager.shared.requestPermission()
            return
        }
        
        // 2. Capture text using new engine
        guard let captured = captureEngine.capture(), !captured.content.isEmpty else {
            // Fallback to panel
            WindowManager.shared.showEnhanceMe()
            return
        }
        
        log("Captured \(captured.content.count) chars via \(captured.captureMethod.rawValue) from \(captured.appCategory.rawValue)")
        
        // 3. Check AI mode
        guard let mode = aiService.currentMode else {
            showHUD(modeName: "—", state: .error("No AI mode configured"))
            scheduleDismiss(after: 3.0)
            return
        }
        
        // 4. Check subscription
        guard SubscriptionService.shared.hasFullAccess else {
            showHUD(modeName: mode.name, state: .error("Pro required"))
            scheduleDismiss(after: 3.0)
            return
        }
        
        // 5. Show HUD
        let fieldRect = getFieldRect(for: captured)
        showHUD(modeName: mode.name, state: .enhancing, nearRect: fieldRect)
        
        // 6. Enhance
        enhanceTask = Task { @MainActor in
            do {
                let result = try await aiService.enhance(text: captured.content, mode: mode)
                guard !Task.isCancelled else { return }
                
                // Replace using new engine
                let replaceResult = replaceEngine.replace(captured: captured, newText: result.enhancedText)
                
                if replaceResult.success {
                    log("Replacement succeeded via \(replaceResult.strategy.rawValue), verified=\(replaceResult.verified)")
                    updateHUD(modeName: mode.name, state: .success)
                    scheduleDismiss(after: 1.0)
                } else {
                    log("Replacement failed: \(replaceResult.error ?? "unknown")")
                    updateHUD(modeName: mode.name, state: .error(replaceResult.error ?? "Failed to replace"))
                    scheduleDismiss(after: 3.0)
                }
                
            } catch {
                guard !Task.isCancelled else { return }
                updateHUD(modeName: mode.name, state: .error(error.localizedDescription))
                scheduleDismiss(after: 3.0)
            }
        }
    }
    
    // MARK: - HUD Lifecycle
    
    private func showHUD(modeName: String, state: InlineEnhanceHUD.HUDState, nearRect: NSRect? = nil) {
        autoDismissTask?.cancel()
        
        if hudPanel == nil {
            hudPanel = InlineEnhanceHUDPanel()
        }
        
        if hudViewModel == nil {
            hudViewModel = HUDViewModel()
        }
        
        let vm = hudViewModel!
        vm.modeName = modeName
        vm.state = state
        
        let view = InlineEnhanceHUD(viewModel: vm)
        hudPanel?.setContent(view)
        positionHUD(nearRect: nearRect)
        hudPanel?.orderFrontRegardless()
    }
    
    private func updateHUD(modeName: String, state: InlineEnhanceHUD.HUDState) {
        guard let vm = hudViewModel else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            vm.modeName = modeName
            vm.state = state
        }
    }
    
    private func getFieldRect(for captured: CapturedText) -> NSRect? {
        let element = captured.sourceElement
        
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        
        guard let posRef = positionValue, let sizeRef = sizeValue else { return nil }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        guard CFGetTypeID(posRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else {
            return nil
        }

        let posAX = unsafeDowncast(posRef, to: AXValue.self)
        let sizeAX = unsafeDowncast(sizeRef, to: AXValue.self)
        guard AXValueGetValue(posAX, .cgPoint, &position),
              AXValueGetValue(sizeAX, .cgSize, &size) else {
            return nil
        }
        
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let convertedRect = NSRect(
            x: position.x,
            y: screenHeight - position.y - size.height,
            width: size.width,
            height: size.height
        )
        
        let isOnScreen = NSScreen.screens.contains { $0.frame.intersects(convertedRect) }
        guard isOnScreen else { return nil }
        
        return convertedRect
    }
    
    private func positionHUD(nearRect: NSRect?) {
        guard let panel = hudPanel else { return }
        let hudSize = panel.frame.size
        
        if let rect = nearRect {
            var x = rect.midX - hudSize.width / 2
            var y = rect.maxY + 8
            
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                x = max(screenFrame.minX, min(x, screenFrame.maxX - hudSize.width))
                y = max(screenFrame.minY, min(y, screenFrame.maxY - hudSize.height))
            }
            
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
    }
    
    private func scheduleDismiss(after seconds: TimeInterval) {
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            dismissHUD()
        }
    }
    
    private func dismissHUD() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            hudPanel?.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.hudPanel?.orderOut(nil)
                self?.hudPanel?.alphaValue = 1.0
                self?.hudViewModel = nil
            }
        }
    }
    
    // MARK: - Debug
    
    private func log(_ message: String) {
        if enableDebugMode {
            print("[InlineEnhanceCoordinator] \(message)")
        }
    }
}

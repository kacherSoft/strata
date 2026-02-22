import AppKit
import SwiftUI

@MainActor
final class InlineEnhanceCoordinator: ObservableObject {
    static let shared = InlineEnhanceCoordinator()
    
    private var hudPanel: InlineEnhanceHUDPanel?
    private var autoDismissTask: Task<Void, Never>?
    private var enhanceTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    func performInlineEnhance() {
        enhanceTask?.cancel()
        
        let focusManager = TextFocusManager.shared
        let aiService = AIService.shared
        
        // 1. Check Accessibility permission
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            AccessibilityManager.shared.requestPermission()
            return
        }
        
        // 2. Capture text from focused field (any app)
        guard let text = focusManager.captureText(), !text.isEmpty else {
            WindowManager.shared.showEnhanceMe()
            return
        }
        
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
        let fieldRect = focusManager.getSourceFieldRect()
        focusManager.currentModeName = mode.name
        showHUD(modeName: mode.name, state: .enhancing, nearRect: fieldRect)
        
        // 6. Enhance
        enhanceTask = Task { @MainActor in
            do {
                let result = try await aiService.enhance(text: text, mode: mode)
                guard !Task.isCancelled else { return }
                
                if focusManager.replaceText(result.enhancedText) {
                    updateHUD(modeName: mode.name, state: .success)
                    scheduleDismiss(after: 1.0)
                } else {
                    updateHUD(modeName: mode.name, state: .error("Focus changed — try again"))
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
        
        let view = InlineEnhanceHUD(modeName: modeName, state: state)
        hudPanel?.setContent(view)
        positionHUD(nearRect: nearRect)
        hudPanel?.orderFrontRegardless()
    }
    
    private func updateHUD(modeName: String, state: InlineEnhanceHUD.HUDState) {
        let view = InlineEnhanceHUD(modeName: modeName, state: state)
        hudPanel?.setContent(view)
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
        hudPanel?.orderOut(nil)
        TextFocusManager.shared.reset()
    }
}

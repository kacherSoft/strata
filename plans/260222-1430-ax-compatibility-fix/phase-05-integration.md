# Phase 5: Integration

**Goal**: Integrate new engines into InlineEnhanceCoordinator, deprecate TextFocusManager.

**Time**: ~1 hour

---

## Overview

Replace the existing `TextFocusManager` with the new `TextCaptureEngine` and `TextReplacementEngine` in the coordinator.

## Changes to InlineEnhanceCoordinator

### Before (Current)

```swift
func performInlineEnhance() {
    // ...
    guard let text = focusManager.captureText(), !text.isEmpty else { ... }
    // ...
    if focusManager.replaceText(result.enhancedText) { ... }
}
```

### After (New)

```swift
func performInlineEnhance() {
    // ...
    guard let captured = captureEngine.capture(), !captured.content.isEmpty else { ... }
    // ...
    let result = replaceEngine.replace(captured: captured, newText: enhancedText)
    // ...
}
```

## Implementation

### File: `InlineEnhanceCoordinator.swift` (Updated)

```swift
import AppKit
import SwiftUI

@MainActor
final class InlineEnhanceCoordinator: ObservableObject {
    static let shared = InlineEnhanceCoordinator()
    
    private var hudPanel: InlineEnhanceHUDPanel?
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
                    log("Replacement succeeded via \(replaceResult.strategy.rawValue)")
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
        
        let view = InlineEnhanceHUD(modeName: modeName, state: state)
        hudPanel?.setContent(view)
        positionHUD(nearRect: nearRect)
        hudPanel?.orderFrontRegardless()
    }
    
    private func updateHUD(modeName: String, state: InlineEnhanceHUD.HUDState) {
        let view = InlineEnhanceHUD(modeName: modeName, state: state)
        hudPanel?.setContent(view)
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
        
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
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
        hudPanel?.orderOut(nil)
    }
    
    // MARK: - Debug
    
    private func log(_ message: String) {
        if enableDebugMode {
            print("[InlineEnhanceCoordinator] \(message)")
        }
    }
}
```

## Deprecation

### TextFocusManager.swift

Mark as deprecated, keep for reference but remove from build:

```swift
@available(*, deprecated, message: "Use TextCaptureEngine and TextReplacementEngine instead")
final class TextFocusManager { ... }
```

Or simply delete the file and remove from Xcode project.

## Settings Update

Add debug toggle in GeneralSettingsView:

```swift
// In GeneralSettingsView
Section("Debug") {
    Toggle("Enable Debug Logging", isOn: Binding(
        get: { InlineEnhanceCoordinator.shared.enableDebugMode },
        set: { InlineEnhanceCoordinator.shared.enableDebugMode = $0 }
    ))
}
```

## Acceptance Criteria

- [ ] Coordinator uses new capture engine
- [ ] Coordinator uses new replacement engine
- [ ] TextFocusManager deprecated/removed
- [ ] Debug toggle in settings
- [ ] All existing functionality preserved
- [ ] Error messages show capture/replace method used

## Dependencies

- [Phase 2: Text Capture Engine](phase-02-text-capture-engine.md)
- [Phase 3: Text Replacement Engine](phase-03-text-replacement-engine.md)
- [Phase 4: Electron Support](phase-04-electron-support.md)

## Next Phase

[Phase 6: Testing Matrix](phase-06-testing-matrix.md)

# Phase 4: InlineEnhanceCoordinator

## Context Links
- Parent: [plan.md](plan.md)
- Depends on: [phase-02-text-focus-manager.md](phase-02-text-focus-manager.md), [phase-03-inline-enhance-hud.md](phase-03-inline-enhance-hud.md)

## Overview
| Property | Value |
|----------|-------|
| Priority | P1 |
| Status | Pending |
| Effort | 1.5h |

Create a coordinator that orchestrates the full inline enhancement flow: permission check → text capture → HUD display → AI call → text replacement → HUD dismiss. Keeps `ShortcutManager` as a clean action dispatcher.

## Requirements

### Functional
- Single entry point: `performInlineEnhance()`
- Check Accessibility permission → prompt if not granted
- Capture text from any app → fallback to panel if no text field
- Check AI mode is configured
- Check subscription/entitlement
- Show HUD near source field
- Call AIService with current mode
- Replace text in source field with `result.enhancedText`
- Show success → auto-dismiss after 1s
- Show error → auto-dismiss after 3s

### Non-Functional
- All work on MainActor
- Cancellable auto-dismiss tasks
- No state pollution of ShortcutManager

## Architecture

```
performInlineEnhance()
    ↓
enhanceTask?.cancel()  ← cancel any in-flight task
    ↓
AccessibilityManager.isAccessibilityEnabled?
    ↓ NO → requestPermission() → return
    ↓ YES
TextFocusManager.captureText()  ← captures PID + selected range
    ↓ nil → WindowManager.showEnhanceMe() → return
    ↓ text
AIService.currentMode
    ↓ nil → showHUD(.error) → return
    ↓ mode
SubscriptionService.shared.hasFullAccess?
    ↓ NO → showHUD(.error("Pro required")) → return
    ↓ YES
showHUD(.enhancing, modeName, nearRect)
    ↓
enhanceTask = Task { await AIService.enhance(text, mode) }
    ↓ cancelled → return (no-op)
    ↓ success
TextFocusManager.replaceText(result.enhancedText)  ← validates PID
    ↓ false → showHUD(.error("Focus changed"))
    ↓ true
updateHUD(.success) → scheduleDismiss(1s)
    ↓ error
updateHUD(.error(message)) → scheduleDismiss(3s)
```

## Related Code Files

### Dependencies
- `TaskManager/Sources/TaskManager/Services/AccessibilityManager.swift` (Phase 1)
- `TaskManager/Sources/TaskManager/Services/TextFocusManager.swift` (Phase 2)
- `TaskManager/Sources/TaskManager/Windows/InlineEnhanceHUDPanel.swift` (Phase 3)
- `TaskManager/Sources/TaskManager/Views/Components/InlineEnhanceHUD.swift` (Phase 3)
- `TaskManager/Sources/TaskManager/AI/Services/AIService.swift` — `enhance()` method
- `TaskManager/Sources/TaskManager/Windows/WindowManager.swift` — `showEnhanceMe()` fallback

### New File
- `TaskManager/Sources/TaskManager/Services/InlineEnhanceCoordinator.swift`

## Implementation Steps

### 1. Create InlineEnhanceCoordinator.swift

```swift
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
        // Cancel any in-flight enhancement
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
                
                // 7. Replace text (validates focus hasn't changed)
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
            // Position centered above the text field
            var x = rect.midX - hudSize.width / 2
            var y = rect.maxY + 8
            
            // Clamp to screen bounds
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
```

### 2. Key Design Notes

- **`orderFrontRegardless()`** — shows panel even when our app is in background (system-wide)
- **Screen-bound clamping** — prevents HUD from appearing off-screen on multi-monitor setups
- **Cancellable `enhanceTask`** — cancels in-flight AI call on re-trigger, prevents concurrent enhancements
- **Cancellable `autoDismissTask`** — prevents stale timers if user triggers again quickly
- **`Task.isCancelled` checks** — prevents stale results from applying after cancellation
- **Reconstructs SwiftUI view** on state change — simple, avoids binding complexity with NSPanel
- **Calls `focusManager.reset()`** on dismiss — clears captured element reference and PID
- **`replaceText()` returns Bool** — validates focus PID hasn't changed before replacing text
- **Subscription check** — uses `SubscriptionService.shared.hasFullAccess`

## Todo List

- [ ] Create InlineEnhanceCoordinator.swift in Services/
- [ ] Implement performInlineEnhance() main flow
- [ ] Implement showHUD() with positioning
- [ ] Implement updateHUD() for state transitions
- [ ] Implement positionHUD() with screen-bound clamping
- [ ] Implement scheduleDismiss() with cancellation
- [ ] Wire subscription check (TODO marker placed)
- [ ] Implement enhanceTask cancellation for reentrancy
- [ ] Add Task.isCancelled checks before applying results
- [ ] Handle replaceText() returning false (focus changed)
- [ ] Test full flow end-to-end

## Success Criteria

- [ ] Full flow works: capture → HUD → enhance → replace → dismiss
- [ ] Falls back to panel when no text field focused
- [ ] Shows error HUD when no AI mode configured
- [ ] Auto-dismisses success after 1s, error after 3s
- [ ] HUD positioned near the source text field
- [ ] HUD doesn't go off-screen
- [ ] No stale timers on rapid re-triggering
- [ ] Rapid re-trigger cancels previous enhancement
- [ ] Focus change during processing shows error instead of replacing wrong field
- [ ] Subscription check blocks non-Pro users

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| AI call slow (>5s) | Medium | HUD shows loading state; user sees progress |
| User triggers again during enhancement | Low | Cancel previous auto-dismiss; HUD updates |
| `orderFrontRegardless()` may not work in all contexts | Low | Standard NSPanel API, well-tested |
| User switches app during AI processing | Medium | PID validation in replaceText(); error HUD if changed |
| User triggers again during enhancement | Medium | enhanceTask.cancel() + Task.isCancelled checks |

## Next Steps

After completion, proceed to [Phase 5: Shortcut Integration](phase-05-shortcut-integration.md)

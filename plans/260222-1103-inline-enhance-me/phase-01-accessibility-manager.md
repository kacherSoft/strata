# Phase 1: AccessibilityManager

## Context Links
- Parent: [plan.md](plan.md)
- Depends on: [phase-00-branch-entitlements.md](phase-00-branch-entitlements.md)

## Overview
| Property | Value |
|----------|-------|
| Priority | P1 |
| Status | Pending |
| Effort | 1h |

Create a singleton manager to check and request macOS Accessibility permissions. This is the prerequisite for all system-wide text access.

## Requirements

### Functional
- Check if app has Accessibility permission (`AXIsProcessTrusted()`)
- Prompt user to grant permission (opens System Settings)
- Auto-detect when permission is granted (polling)
- Expose reactive `@Published` property for UI binding

### Non-Functional
- Thread-safe for MainActor
- Minimal CPU usage for polling (2-second interval)
- Clean stop when permission granted

## Related Code Files

### Reference Files
- `TaskManager/Sources/TaskManager/Services/SubscriptionService.swift` — singleton pattern
- `TaskManager/Sources/TaskManager/Views/Settings/GeneralSettingsView.swift` — settings UI target

### New File
- `TaskManager/Sources/TaskManager/Services/AccessibilityManager.swift`

## Implementation Steps

### 1. Create AccessibilityManager.swift

```swift
import AppKit

@MainActor
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published private(set) var isAccessibilityEnabled: Bool = false
    
    private var pollingTimer: Timer?
    
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
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        
        // Start polling — macOS doesn't provide a callback for this
        startPermissionPolling()
    }
    
    // MARK: - Polling
    
    private func startPermissionPolling() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }
                if AXIsProcessTrusted() {
                    self.isAccessibilityEnabled = true
                    timer.invalidate()
                    self.pollingTimer = nil
                }
            }
        }
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
}
```

### 2. Key Design Notes

- **`kAXTrustedCheckOptionPrompt`** — tells macOS to show the system prompt dialog directing user to System Settings
- **Polling** — necessary because macOS provides no notification/callback when the user toggles Accessibility permission. 2-second interval is minimal CPU cost
- **`takeUnretainedValue()`** — correct for global constant CFString references (Get-rule: we don't own the constant, so no retain/release needed)
- **`@Published`** — allows SwiftUI views to reactively update when permission changes

## Todo List

- [ ] Create AccessibilityManager.swift in Services/
- [ ] Implement checkPermission()
- [ ] Implement requestPermission() with system prompt
- [ ] Implement polling for permission detection
- [ ] Wire into app initialization (optional — lazy init via `.shared`)

## Success Criteria

- [ ] `checkPermission()` returns correct boolean
- [ ] `requestPermission()` opens System Settings accessibility pane
- [ ] `isAccessibilityEnabled` updates to `true` after user grants permission
- [ ] Polling timer stops after permission is granted
- [ ] No memory leaks (weak self, timer invalidation)

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| User never grants permission | Medium | Clear UI prompt + settings status |
| Polling continues indefinitely | Low | Timer invalidates on permission grant or deinit |
| `takeUnretainedValue()` usage | Low | Correct Get-rule pattern for global constants |

## Next Steps

After completion, proceed to [Phase 2: TextFocusManager](phase-02-text-focus-manager.md)

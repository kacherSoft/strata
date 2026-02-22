# Phase 5: Shortcut Integration + Settings UI

## Context Links
- Parent: [plan.md](plan.md)
- Depends on: [phase-04-coordinator.md](phase-04-coordinator.md)

## Overview
| Property | Value |
|----------|-------|
| Priority | P1 |
| Status | Pending |
| Effort | 2h |

Wire the ⌘⌥E shortcut to `InlineEnhanceCoordinator`, add Accessibility permission status to Settings, and add the new shortcut to the shortcuts settings UI.

## Requirements

### Functional
- Register `⌘⌥E` as new global shortcut for inline enhancement
- Add handler that calls `InlineEnhanceCoordinator.performInlineEnhance()`
- Add shortcut to reset defaults
- Add shortcut row in ShortcutsSettingsView
- Add Accessibility permission status + "Grant Access" button in GeneralSettingsView
- User can customize the shortcut in Settings

### Non-Functional
- Follows existing shortcut patterns exactly
- No changes to existing shortcut behavior

## Related Code Files

### Files to Modify
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/ShortcutsSettingsView.swift`
- `TaskManager/Sources/TaskManager/Views/Settings/GeneralSettingsView.swift`

### Dependencies
- `TaskManager/Sources/TaskManager/Services/InlineEnhanceCoordinator.swift` (Phase 4)
- `TaskManager/Sources/TaskManager/Services/AccessibilityManager.swift` (Phase 1)

## Implementation Steps

### 1. Add Shortcut Name (ShortcutNames.swift)

```diff
 extension KeyboardShortcuts.Name {
     // Global shortcuts (work system-wide)
     static let quickEntry = Self("quickEntry")
     static let enhanceMe = Self("enhanceMe")
     static let mainWindow = Self("mainWindow")
+    static let inlineEnhanceMe = Self("inlineEnhanceMe")
     
     // Local shortcuts (work only when app is focused)
     static let settings = Self("settings")
     static let newTask = Self("newTask")
 }
```

### 2. Register Default Shortcut (ShortcutManager.swift)

Add to `registerDefaultShortcuts()`:
```swift
if KeyboardShortcuts.getShortcut(for: .inlineEnhanceMe) == nil {
    KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .option]), for: .inlineEnhanceMe)
}
```

### 3. Add Handler (ShortcutManager.swift)

Add to `setupHandlers()`:
```swift
KeyboardShortcuts.onKeyUp(for: .inlineEnhanceMe) { [weak self] in
    self?.performInlineEnhance()
}
```

> **Note:** Follows existing `[weak self]` convention. Add corresponding action method in ShortcutManager:
> ```swift
> func performInlineEnhance() {
>     InlineEnhanceCoordinator.shared.performInlineEnhance()
> }
> ```

### 4. Update Reset Defaults (ShortcutManager.swift)

Add to `resetAllToDefaults()`:
```swift
// In the reset call:
KeyboardShortcuts.reset(.quickEntry, .enhanceMe, .mainWindow, .settings, .newTask, .inlineEnhanceMe)

// In the set defaults section:
KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .option]), for: .inlineEnhanceMe)
```

### 5. Add Shortcut Row (ShortcutsSettingsView.swift)

Add after the "Enhance Me" row in the Global Shortcuts section:

```swift
Divider()
    .padding(.horizontal, 20)

ShortcutRow(
    name: .inlineEnhanceMe,
    title: "Inline Enhance",
    description: "Enhance text in any app's text field",
    icon: "sparkles"
)
```

### 6. Add Accessibility Status (GeneralSettingsView.swift)

Add an Accessibility section (requires `@ObservedObject` or `@StateObject` for `AccessibilityManager`):

```swift
@ObservedObject private var accessibilityManager = AccessibilityManager.shared

// In body, add section:
VStack(alignment: .leading, spacing: 8) {
    Text("System-Wide Enhancement")
        .font(.headline)
    
    HStack {
        Image(systemName: accessibilityManager.isAccessibilityEnabled
              ? "checkmark.shield.fill" : "exclamationmark.shield")
            .foregroundStyle(accessibilityManager.isAccessibilityEnabled ? .green : .orange)
            .frame(width: 24)
        
        VStack(alignment: .leading, spacing: 2) {
            Text(accessibilityManager.isAccessibilityEnabled
                 ? "Accessibility Enabled" : "Accessibility Required")
                .font(.body)
            Text("Required to enhance text in other applications")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        if !accessibilityManager.isAccessibilityEnabled {
            Button("Grant Access") {
                accessibilityManager.requestPermission()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
}
.liquidGlass(.settingsCard)
```

## Todo List

- [ ] Add `.inlineEnhanceMe` to ShortcutNames.swift
- [ ] Add registration in ShortcutManager.registerDefaultShortcuts()
- [ ] Add handler in ShortcutManager.setupHandlers()
- [ ] Update ShortcutManager.resetAllToDefaults()
- [ ] Add shortcut row in ShortcutsSettingsView.swift
- [ ] Add Accessibility status section in GeneralSettingsView.swift

## Success Criteria

- [ ] ⌘⌥E triggers inline enhancement globally
- [ ] Shortcut appears in Settings → Shortcuts under "Global Shortcuts"
- [ ] User can customize the shortcut
- [ ] "Reset All to Defaults" resets inline enhance shortcut to ⌘⌥E
- [ ] Settings → General shows Accessibility permission status
- [ ] "Grant Access" button opens System Settings → Accessibility
- [ ] Status updates to "Enabled" after user grants permission

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| ⌘⌥E conflicts with another app | Low | User can customize in Settings |
| AccessibilityManager as @StateObject on singleton | Low | Works — ObservableObject + shared |

## Next Steps

After completion, proceed to [Phase 6: Testing](phase-06-testing.md)

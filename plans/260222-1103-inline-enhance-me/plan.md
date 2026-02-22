---
title: "Inline Enhance Me (System-Wide)"
description: "Enable AI text enhancement in any app's text field via ⌘⌥E shortcut using Accessibility API"
status: in-progress
priority: P1
effort: 10-12h
branch: feature/inline-enhance-system-wide
distribution: direct (Developer ID, not App Store)
tags: [ai, feature, ux, shortcuts, accessibility, system-wide]
created: 2026-02-22
revised: 2026-02-22
---

# Inline Enhance Me (System-Wide)

## Overview

Add system-wide inline AI enhancement that works in **any app's text field** (like Grammarly), using the macOS Accessibility API (`AXUIElement`).

> ⚠️ **Distribution:** This version is distributed **outside the App Store** (Developer ID) because Accessibility API is incompatible with App Sandbox. The App Store version continues without this feature.

**Current Workflow** (5 steps):
1. Open panel (⌘⇧E) → 2. Paste text → 3. Enhance → 4. Copy → 5. Return & paste

**New Workflow** (1 step):
1. Press ⌘⌥E while in any text field in any app → Text enhanced inline

## Requirements

| Requirement | Decision |
|-------------|----------|
| Trigger | ⌘⌥E global shortcut (avoids ⌘E system conflict) |
| Output | Replace text inline in the source app |
| Scope | Any text field in any application (system-wide) |
| AI Mode | Syncs with Enhance Me settings |
| Feedback | Floating HUD indicator (NSPanel, non-activating) |
| Architecture | Dual mode — coexists with panel (⌘⇧E) |
| Permission | macOS Accessibility (user grants in System Settings) |
| Distribution | Developer ID (direct, not App Store) |

## Implementation Phases

| Phase | Description | Status | Time |
|-------|-------------|--------|------|
| [Phase 0](phase-00-branch-entitlements.md) | Branch & entitlements setup | Pending | 0.5h |
| [Phase 1](phase-01-accessibility-manager.md) | AccessibilityManager — permission flow | Pending | 1h |
| [Phase 2](phase-02-text-focus-manager.md) | TextFocusManager — AXUIElement text capture/replace | Pending | 2-3h |
| [Phase 3](phase-03-inline-enhance-hud.md) | InlineEnhanceHUD — floating NSPanel | Pending | 1.5h |
| [Phase 4](phase-04-coordinator.md) | InlineEnhanceCoordinator — flow orchestration | Pending | 1.5h |
| [Phase 5](phase-05-shortcut-integration.md) | Shortcut integration + Settings UI | Pending | 2h |
| [Phase 6](phase-06-testing.md) | Manual testing across apps + edge cases | Pending | 1.5-2h |

**Total Effort**: ~10–12 hours

## Architecture

```
User typing in ANY app → ⌘⌥E pressed
    ↓
ShortcutManager → InlineEnhanceCoordinator.performInlineEnhance()
    ↓
AccessibilityManager.isAccessibilityEnabled?
    ↓ NO → requestPermission() (System Settings prompt)
    ↓ YES
TextFocusManager.captureText()  ← AXUIElement (system-wide)
    ↓ nil → fallback: WindowManager.showEnhanceMe()
    ↓ text
Show HUD (NSPanel, non-activating) → AIService.enhance()
    ↓
TextFocusManager.replaceText()  ← AXUIElement (writes back to source app)
    ↓
Dismiss HUD (success/error)
```

## Files

### Create (5 new files)
- `TaskManager/Sources/TaskManager/Services/AccessibilityManager.swift`
- `TaskManager/Sources/TaskManager/Services/TextFocusManager.swift`
- `TaskManager/Sources/TaskManager/Services/InlineEnhanceCoordinator.swift`
- `TaskManager/Sources/TaskManager/Windows/InlineEnhanceHUDPanel.swift`
- `TaskManager/Sources/TaskManager/Views/Components/InlineEnhanceHUD.swift`

### Modify (5 existing files)
- `TaskManager/Sources/TaskManager/TaskManager.entitlements` — disable sandbox
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift` — add `.inlineEnhanceMe`
- `TaskManager/Sources/TaskManager/Shortcuts/ShortcutManager.swift` — add handler
- `TaskManager/Sources/TaskManager/Views/Settings/ShortcutsSettingsView.swift` — add shortcut row
- `TaskManager/Sources/TaskManager/Views/Settings/GeneralSettingsView.swift` — Accessibility status UI

## Key Decisions

1. **Accessibility API (AXUIElement)** — system-wide text access, the Grammarly approach
2. **⌘⌥E shortcut** — avoids conflict with macOS ⌘E "Use Selection for Find"
3. **NSPanel with .nonactivatingPanel** — HUD doesn't steal focus from source app
4. **InlineEnhanceCoordinator** — separate coordinator keeps ShortcutManager clean
5. **Developer ID distribution** — separate branch, not App Store compatible
6. **Dual Mode** — ⌘⌥E for inline system-wide, ⌘⇧E for panel — both available

## Success Criteria

- [ ] ⌘⌥E triggers enhancement in any app's text field
- [ ] Selected text OR full field content enhanced
- [ ] HUD shows during processing without stealing focus
- [ ] Text replaced inline in the source application
- [ ] Works with all AI modes
- [ ] Accessibility permission flow works smoothly
- [ ] Error handling with fallback to panel
- [ ] Settings show Accessibility status + shortcut customization

## Known Limitations

- Electron apps (VS Code, Slack) may not fully support AX text attributes
- Rich text formatting is not preserved (plain text replacement only)
- `AXUIElementSetAttributeValue` may fail silently in some apps
- Some Java/custom-rendered apps won't expose standard AX roles

## References

- [Implementation Plan](../../.gemini/antigravity/brain/0a273ea9-ee87-4b32-aa6a-1f43fecd62d2/implementation_plan.md)
- [Brainstorm Report](../reports/brainstorm-260222-1103-inline-enhance-me.md)
- [Research Report](../reports/researcher-260222-1112-inline-text-enhancement.md)
- [Validation Report](../../.gemini/antigravity/brain/0a273ea9-ee87-4b32-aa6a-1f43fecd62d2/walkthrough.md)

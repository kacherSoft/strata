---
title: "UI Mode Settings - Light/Dark Theme Support"
description: "Add comprehensive light/dark mode support with user-selectable appearance preference"
status: pending
priority: P2
effort: 4h
branch: main
tags: [feature, frontend, ui]
created: 2026-02-19
---

## Overview

Add proper light mode support and a UI Mode settings panel allowing users to choose between System, Light, and Dark appearances. Currently the app uses hardcoded `.white.opacity()` colors that assume dark mode.

## Current State Analysis

### What Works (80%)
- Semantic text colors (`.primary`, `.secondary`, `.tertiary`)
- Material backgrounds (`.ultraThinMaterial`, `.thinMaterial`)
- System accent colors (`.blue`, `.red`, `.green`, `.accentColor`)

### What Needs Fixing (20%)
- **12 instances** of `.white.opacity(X)` borders in ~8 files
- No centralized color tokens
- No user preference for appearance mode

## Affected Files

| File | Action | Changes |
|------|--------|---------|
| `TaskManagerUIComponents/.../Extensions/Color+Adaptive.swift` | create | Adaptive color extensions |
| `TaskManagerUIComponents/.../Inputs/SearchBar.swift` | modify | Border colors |
| `TaskManagerUIComponents/.../Inputs/TextareaField.swift` | modify | Border colors |
| `TaskManagerUIComponents/.../Buttons/FloatingActionButton.swift` | modify | Border, shadow colors |
| `TaskManagerUIComponents/.../Buttons/PrimaryButton.swift` | modify | Foreground color |
| `TaskManagerUIComponents/.../ReminderActionPopover.swift` | modify | Border colors |
| `TaskManagerUIComponents/.../TaskList/TaskRow.swift` | modify | Border colors |
| `TaskManager/.../Views/Kanban/KanbanCardView.swift` | modify | Border, background colors |
| `TaskManager/.../Views/Kanban/KanbanColumnView.swift` | modify | Drop target background |
| `TaskManager/.../Views/Settings/SettingsView.swift` | modify | Add Appearance section |
| `TaskManager/.../Services/AppSettings.swift` | modify | Add appearance preference |
| `TaskManager/.../TaskManagerApp.swift` | modify | Apply appearance override |

## Implementation Phases

### Phase 1: Adaptive Color System (30 min)
**Goal:** Create centralized adaptive color extensions

Create `Color+Adaptive.swift`:
```swift
import SwiftUI

extension Color {
    /// Subtle border - adapts to light/dark
    static var adaptiveBorder: Color {
        .primary.opacity(0.1)
    }
    
    /// Prominent border for focus/selection
    static var adaptiveBorderProminent: Color {
        .primary.opacity(0.2)
    }
    
    /// Subtle background overlay
    static var adaptiveOverlay: Color {
        .primary.opacity(0.05)
    }
}
```

**Files:**
- Create: `TaskManagerUIComponents/Sources/TaskManagerUIComponents/Extensions/Color+Adaptive.swift`

---

### Phase 2: Update Hardcoded Colors (1.5 hrs)
**Goal:** Replace all `.white.opacity()` with adaptive colors

**Replacement pattern:**
| Before | After |
|--------|-------|
| `.white.opacity(0.1)` | `.adaptiveBorder` |
| `.white.opacity(0.15)` | `.adaptiveBorderProminent` |
| `.white.opacity(0.2)` | `.adaptiveBorderProminent` |
| `Color.white.opacity(0.06)` | `.adaptiveOverlay` |

**Files to update:**
1. `SearchBar.swift` - border stroke
2. `TextareaField.swift` - border stroke
3. `FloatingActionButton.swift` - border, shadow
4. `PrimaryButton.swift` - verify foreground (likely OK)
5. `ReminderActionPopover.swift` - border
6. `TaskRow.swift` - card border
7. `KanbanCardView.swift` - border, hover background
8. `KanbanColumnView.swift` - drop target background

---

### Phase 3: Appearance Settings (1 hr)
**Goal:** Add UI preference for System/Light/Dark mode

**AppSettings.swift** - add property:
```swift
enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

@AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .system
```

**SettingsView.swift** - add Appearance section:
```swift
Section("Appearance") {
    Picker("Mode", selection: $appSettings.appearanceMode) {
        ForEach(AppearanceMode.allCases, id: \.self) { mode in
            Text(mode.displayName).tag(mode)
        }
    }
    .pickerStyle(.radioGroup)
}
```

**TaskManagerApp.swift** - apply override:
```swift
.onAppear {
    applyAppearanceMode(appSettings.appearanceMode)
}
.onChange(of: appSettings.appearanceMode) { _, mode in
    applyAppearanceMode(mode)
}

func applyAppearanceMode(_ mode: AppearanceMode) {
    switch mode {
    case .system:
        NSApp.appearance = nil
    case .light:
        NSApp.appearance = NSAppearance(named: .aqua)
    case .dark:
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
```

---

### Phase 4: Testing & Polish (1 hr)
**Goal:** Verify all views render correctly in both modes

**Test checklist:**
- [ ] Task list view (light/dark)
- [ ] Kanban board (light/dark)
- [ ] Task detail panel (light/dark)
- [ ] Settings window (light/dark)
- [ ] Enhance Me panel (light/dark)
- [ ] All buttons and inputs
- [ ] Tag chips (contrast check)
- [ ] Floating action button
- [ ] Quick entry window

**Adjust if needed:**
- Border opacity values
- Material thickness
- Tag background colors

---

## Effort Summary

| Phase | Time |
|-------|------|
| Phase 1: Color System | 30 min |
| Phase 2: Update Colors | 1.5 hrs |
| Phase 3: Settings UI | 1 hr |
| Phase 4: Testing | 1 hr |
| **Total** | **4 hrs** |

## Success Criteria

1. ✅ App renders correctly in light mode
2. ✅ App renders correctly in dark mode
3. ✅ System mode follows macOS preference
4. ✅ User can override in Settings
5. ✅ Preference persists across launches
6. ✅ No hardcoded dark-mode assumptions remain

## Risks

| Risk | Mitigation |
|------|------------|
| Some colors too faint in light mode | Adjust opacity values in Phase 4 |
| Tag colors lose contrast | May need tag-specific adjustments |
| Materials too transparent | Test `.thinMaterial` alternatives |

## Out of Scope

- Custom color themes/palettes
- Per-view appearance override
- Accent color customization

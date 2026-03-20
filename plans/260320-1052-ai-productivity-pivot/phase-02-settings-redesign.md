# Phase 2: Settings Redesign (Raycast-style)

**Priority:** Critical | **Effort:** Large | **Status:** Pending
**Depends on:** Phase 1 (AI Provider Data Model)

---

## Context Links
- [Plan Overview](plan.md) | [Phase 1](phase-01-ai-provider-data-model.md)
- Current settings: `Views/Settings/GeneralSettingsView.swift` (611 LOC)
- Current AI config: `Views/Settings/AIConfigSettingsView.swift` (205 LOC)
- Current AI modes: `Views/Settings/AIModesSettingsView.swift` (334 LOC)
- Window: `WindowManager.swift` → `showSettings()`

---

## Overview

Replace the current 6-tab `TabView` settings with a Raycast/macOS System Settings-style layout: sidebar navigation (icon + label) on the left, detail content on the right. Each section is its own view file.

---

## Key Insights

- Current settings tabs: General, AI Config, AI Modes, Custom Fields, Shortcuts, Manage Devices
- `GeneralSettingsView` at 611 LOC needs splitting
- AI Config and AI Modes should merge into "AI Providers" and "AI Modes" sections
- Task-specific settings (custom fields, default priority) grouped under "Tasks"
- Account/devices grouped under "Account"

---

## Requirements

### New Settings Sections

| Section | Icon | Contents |
|---------|------|----------|
| **General** | `gear` | Appearance, always-on-top, launch at login, reduced motion |
| **Chat** | `bubble.left.and.bubble.right` | Chat behavior, default model, auto-title, history limit |
| **AI Providers** | `cpu` | Provider list (add/edit/remove), API keys, model lists, test connection |
| **AI Modes** | `sparkles` | Enhancement modes (Correct Me, Explain, etc.), system prompts |
| **Tasks** | `checklist` | Default priority, show completed, custom fields, reminder sound |
| **Shortcuts** | `keyboard` | Global + local keyboard shortcuts |
| **Account** | `person.circle` | Subscription status, device management, sign in/out |

### Layout
- Sidebar: 200px wide, icons + labels, single selection
- Detail: scrollable content area, fills remaining width
- Window: ~700×500 min, resizable
- Sidebar uses `.sidebar` list style for native macOS vibrancy

---

## Architecture

### Settings Container

```swift
struct SettingsView: View {
    @State private var selectedSection: SettingsSection = .general

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general, chat, aiProviders, aiModes, tasks, shortcuts, account
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            settingsDetail(for: selectedSection)
        }
    }
}
```

### AI Providers Section (new — replaces AIConfigSettingsView)

```
┌─────────────────────────────────────────────┐
│ AI Providers                                │
│                                             │
│ ┌─ Google Gemini ──── ✅ Configured ──────┐ │
│ │ API Key: ••••••••••  [👁] [Test] [Save] │ │
│ │ Models: gemini-flash-lite-latest        │ │
│ │         gemini-flash-latest             │ │
│ │         gemini-3-flash-preview          │ │
│ │         [+ Add Model]                   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─ z.ai ──────────── ✅ Configured ──────┐ │
│ │ API Key: ••••••••••  [👁] [Test] [Save] │ │
│ │ Models: glm-4.6-flash, glm-4.7-flash   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─ My OpenRouter ─── ✅ Configured ──────┐ │
│ │ Base URL: https://openrouter.ai/api/v1  │ │
│ │ API Key: ••••••••••  [👁] [Test] [Save] │ │
│ │ Models: gpt-4o, claude-3.5-sonnet       │ │
│ │         [+ Add Model]    [🗑 Remove]    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ [+ Add Provider]          3/10 providers    │
└─────────────────────────────────────────────┘
```

---

## Related Code Files

### Create
- `Views/Settings/SettingsContainerView.swift` — Sidebar + detail layout (~60 LOC)
- `Views/Settings/SettingsSection.swift` — Enum with title/icon (~30 LOC)
- `Views/Settings/ChatSettingsView.swift` — Chat behavior settings (~80 LOC)
- `Views/Settings/AIProvidersSettingsView.swift` — Provider management (~180 LOC)
- `Views/Settings/AIProviderCardView.swift` — Single provider card (~120 LOC)
- `Views/Settings/TasksSettingsView.swift` — Task-related settings (~100 LOC)
- `Views/Settings/AccountSettingsView.swift` — Account/devices (~80 LOC)

### Modify
- `Views/Settings/GeneralSettingsView.swift` — Strip task settings, trim to ~200 LOC
- `Views/Settings/AIModesSettingsView.swift` — Update model picker to use AIProviderModel
- `Views/Settings/ShortcutsSettingsView.swift` — No changes needed
- `Windows/WindowManager.swift` — Update `showSettings()` to use SettingsContainerView
- `TaskManagerApp.swift` — Remove old Settings scene if applicable

### Delete
- `Views/Settings/AIConfigSettingsView.swift` — Replaced by AIProvidersSettingsView

---

## Implementation Steps

1. Create `SettingsSection` enum with all sections, titles, SF Symbol icons
2. Create `SettingsContainerView` with NavigationSplitView sidebar + detail routing
3. Extract task settings from GeneralSettingsView → `TasksSettingsView`
4. Create `ChatSettingsView` (default model, auto-title, history settings)
5. Create `AIProvidersSettingsView` — list of provider cards, add button
6. Create `AIProviderCardView` — expandable card with API key, models, test
7. Create `AccountSettingsView` — extract from ManageDevicesView + add subscription info
8. Update `AIModesSettingsView` — model picker fetches from `AIProviderModel.models`
9. Update `WindowManager.showSettings()` to use new container
10. Delete old `AIConfigSettingsView`
11. Build and verify all settings sections render correctly

---

## Todo List

- [ ] Create SettingsSection enum
- [ ] Create SettingsContainerView (sidebar + detail)
- [ ] Create ChatSettingsView
- [ ] Create AIProvidersSettingsView + AIProviderCardView
- [ ] Create TasksSettingsView (extract from General)
- [ ] Create AccountSettingsView
- [ ] Update AIModesSettingsView model picker
- [ ] Trim GeneralSettingsView
- [ ] Update WindowManager
- [ ] Delete AIConfigSettingsView
- [ ] Build verification

---

## Success Criteria

- [ ] Settings opens with sidebar navigation (7 sections)
- [ ] Each section renders its content correctly
- [ ] AI Providers section shows all configured providers
- [ ] Can add/remove custom OpenAI-compatible providers
- [ ] Can add/remove models per provider
- [ ] Test connection works per provider and per model
- [ ] AI Mode editor shows models from selected provider
- [ ] Window size and layout match Raycast quality

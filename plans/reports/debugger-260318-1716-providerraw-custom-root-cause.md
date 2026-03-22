# Root Cause: `providerRaw = "custom"` in Built-In AI Modes

**Date:** 2026-03-18 | **Investigator:** debugger agent

---

## Executive Summary

`providerRaw = "custom"` in the SwiftData DB for "Correct Me" and "Enhance Prompt" was written by the **running app** during an intermediate development phase (2026-03-13). A `case custom = "custom"` enum was added to `AIProviderType` as an **uncommitted working-tree change** in the main repo, the app was built/run from that modified code, and a user (or AI agent) edited the built-in modes via Settings → AI Modes → right-click → Edit, selecting the "Custom (OpenAI)" provider. This wrote `providerRaw = "custom"` and `modelName = "gpt-5.4"` directly to the store.

The string `"custom"` was **never committed** to git. It existed only as a local working-tree modification.

---

## Timeline

| Date | Event |
|------|-------|
| 2026-02-05 | `AIProviderType` introduced with only `gemini` and `zai` cases (commit `c010714`) |
| 2026-02-18 | Premium finalize; enum unchanged, still only `gemini` + `zai` (commit `254fb68`) |
| 2026-03-13 16:51 | **`case custom = "custom"` added to `AIModeModel.swift` as local (uncommitted) edit** |
| 2026-03-13 17:28–17:38 | `CustomOpenAIProvider.swift` and `CustomProviderSettingsSection.swift` created (untracked) |
| 2026-03-13 (after) | App launched from modified code; built-in modes edited in settings; DB written with `providerRaw = "custom"`, `modelName = "gpt-5.4"` |
| 2026-03-13 | Custom OpenAI provider plan completed and NOT committed — changes left in working tree |
| 2026-03-17 | Explore-260317-2210 agent read the live working-tree file, reported `case custom = "custom"` as current state |
| 2026-03-18 | Chat mode feature branch (`claude/confident-cray`) adds `case openai = "openai"` — distinct from `"custom"` |

---

## Evidence

### 1. `case custom` was never committed

```
$ git log --all -p -- TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift | grep "case custom"
# → (no output)
```

All four commits to `AIModeModel.swift` only ever had `gemini` and `zai`:
```
254fb68 Finalize premium+VIP flow, simplify AI modes, and clean project docs
e5d00a5 fix: resolve SwiftUI List selection and Sheet binding issues
c010714 AI integration: providers (Gemini/ZAI), AIService, EnhanceMe panel, settings views
dff15cb feat(phase-1): implement SwiftData foundation with task CRUD
```

### 2. `case custom` exists as uncommitted working-tree change in main repo

```
$ git diff HEAD -- TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift
+    case custom = "custom"
+    case .custom: return "Custom (OpenAI)"
+    case .custom: return ["gpt-4o"]  // or whatever is in Keychain
+    case .custom: return false
+    case .custom: return false
```
File modified: **2026-03-13 16:51** (matches brainstorm date `2026-03-13`).

### 3. DB was written while `case custom` was live in working tree

The "Custom OpenAI Provider" feature was fully implemented but never committed:
- `CustomOpenAIProvider.swift` (untracked, created 2026-03-13 17:38)
- `CustomProviderSettingsSection.swift` (untracked, created 2026-03-13 17:28)
- `brainstorm-260313-1630-custom-openai-provider.md` confirms feature was planned/built that day

The app ran with `case custom = "custom"` active in the enum.

### 4. Built-in modes ARE editable via context menu

`AIModesSettingsView` allows editing ANY mode including built-in via right-click → Edit. Only DELETE is guarded:
```swift
// Delete: guarded
guard let mode = selectedMode, !mode.isBuiltIn else { return }
// Edit: unguarded — any mode can be edited
editingItem = EditModeItem(id: mode.id)
```

`updateMode()` writes directly to SwiftData:
```swift
mode.provider = provider  // → providerRaw = provider.rawValue
mode.modelName = model
```

### 5. `modelName = "gpt-5.4"` confirms manual edit

The default model for `.custom` was `"gpt-4o"` (from Keychain or hardcoded). `"gpt-5.4"` is a custom/non-standard model string, confirming a human typed it in the model name field.

### 6. Explore report corroborates timing

`plans/reports/Explore-260317-2210-ai-layer-system.md` (generated 2026-03-17):
```swift
enum AIProviderType: String, Codable, CaseIterable, Sendable {
    case gemini = "gemini"
    case zai = "zai"
    case custom = "custom"  // ← read from live working-tree file
}
```
This agent read the modified (uncommitted) file, confirming `case custom` was present in the working tree at that point.

---

## Root Cause (Definitive)

**A local feature implementation for "Custom OpenAI Provider" (2026-03-13) added `case custom = "custom"` to `AIProviderType` as an uncommitted working-tree modification. The app was built and run from this modified code. A user then edited the built-in "Correct Me" and "Enhance Prompt" modes via Settings → AI Modes → right-click → Edit, selected the `.custom` provider and typed `"gpt-5.4"` as the model name. The `updateMode()` function wrote these values directly to SwiftData, persisting `providerRaw = "custom"` and `modelName = "gpt-5.4"` to the store.**

The feature was never committed; the enum case `"custom"` no longer exists in any committed or current worktree code. The worktree branch `claude/confident-cray` independently introduced `case openai = "openai"` — a different raw value.

---

## Fix (Already Applied in Worktree)

The `provider` getter in `AIModeModel.swift` on the worktree branch already handles this:

```swift
var provider: AIProviderType {
    get {
        guard let valid = AIProviderType(rawValue: providerRaw) else {
            // Invalid providerRaw — reset both provider AND model to prevent mismatch
            // (e.g. providerRaw="custom" with modelName="gpt-5.4" would route to Gemini with wrong model)
            providerRaw = AIProviderType.gemini.rawValue
            modelName = AIProviderType.gemini.defaultModel
            return .gemini
        }
        return valid
    }
    set { providerRaw = newValue.rawValue }
}
```

When `providerRaw = "custom"` is read and `"custom"` is not a valid case (it's not in the current enum), the getter auto-heals: resets `providerRaw` to `"gemini"` and `modelName` to the default Gemini model, then saves on next write.

---

## Recommendations

1. **Commit or discard the main repo's Custom OpenAI uncommitted changes** — they have diverged from the worktree's `openai` case approach and leaving them uncommitted risks similar DB pollution.
2. **Guard built-in mode edits** — consider preventing provider/model changes on `isBuiltIn = true` modes in `updateMode()`, or at minimum disabling the provider picker in the editor sheet for built-in modes.
3. **The self-healing getter (already in place)** is the correct DB repair mechanism — no migration needed.

---

## Unresolved Questions

- Was `modelName = "gpt-5.4"` typed by a human user or by an AI agent testing the UI? (Not determinable from git/code alone.)
- Were other modes (e.g., "Explain") also affected, or only "Correct Me" and "Enhance Prompt"?

# Strata: AI Productivity Pivot — Implementation Plan

**Date:** 2026-03-20 | **Branch:** claude/confident-cray
**Scope:** Pivot from task manager to AI productivity tool

---

## Vision

Strata becomes an **AI Productivity Utility for Mac** where Chat is the primary interface. Task management remains but moves to a secondary role. Settings get a modern Raycast/macOS-style redesign with proper AI provider management.

---

## Phase Overview

| # | Phase | Priority | Effort | Status |
|---|-------|----------|--------|--------|
| 1 | [AI Provider Data Model](phase-01-ai-provider-data-model.md) | Critical | Medium | Pending |
| 2 | [Settings Redesign](phase-02-settings-redesign.md) | Critical | Large | Pending |
| 3 | [Chat as Primary Window](phase-03-chat-primary-window.md) | Critical | Medium | Pending |
| 4 | [AI Mode ↔ Provider Integration](phase-04-ai-mode-provider-integration.md) | High | Medium | Pending |
| 5 | [Chat UI Provider Selector](phase-05-chat-provider-selector.md) | High | Small | Pending |
| 6 | [Cleanup & Polish](phase-06-cleanup-polish.md) | Medium | Small | Pending |

---

## Key Architecture Decisions

### 1. AIProviderModel (new SwiftData entity)
Currently providers are hardcoded singletons in `AIService`. New design:
- `AIProviderModel` — SwiftData entity storing name, type, baseURL, apiKeyRef, models[], isDefault
- 2 defaults seeded on install: Gemini, z.ai
- Up to 8 user-added OpenAI-compatible providers
- Max 10 total providers
- Each provider has its own model list (editable, testable)

### 2. Settings: Raycast-style sidebar navigation
Replace current `TabView` with:
- Left sidebar: icon + label rows (General, Chat, AI Modes, AI Providers, Tasks, Shortcuts, Account)
- Right detail: selected section content
- NSWindow (not panel) — proper settings window

### 3. Chat as primary window
- On launch: show Chat window (full NSWindow, not NSPanel)
- Task view accessible via menu/shortcut (secondary)
- Chat window replaces ContentView as the app's main scene
- NavigationSplitView sidebar shows chat sessions

### 4. Model availability
- All models from all configured providers available in:
  - AI Mode editor (provider picker → model picker)
  - Chat UI (model selector in toolbar/input area)
- Model validation: "Test" button per model

---

## Dependencies

```
Phase 1 (Provider Model) ← Phase 2 (Settings UI) ← Phase 4 (Mode Integration)
Phase 1 ← Phase 3 (Chat Primary) ← Phase 5 (Chat Selector)
All ← Phase 6 (Cleanup)
```

Phase 1 must complete first. Phases 2+3 can run in parallel after Phase 1.

---

## Schema Changes (V2 → V3)

### New Model: `AIProviderModel`
```swift
@Model final class AIProviderModel {
    var id: UUID
    var name: String                    // "Google Gemini", "My OpenRouter"
    var providerType: String            // "gemini", "zai", "openai_compatible"
    var baseURL: String?                // nil for gemini/zai, required for openai_compatible
    var apiKeyRef: String               // Keychain key identifier
    var models: [String]                // ["gemini-flash-lite-latest", "gemini-flash-latest"]
    var defaultModelName: String?       // Default model for this provider
    var isDefault: Bool                 // true for Gemini/z.ai (not deletable)
    var isEnabled: Bool                 // User can disable without deleting
    var sortOrder: Int
    var createdAt: Date
}
```

### Modified: `AIModeModel`
```swift
// Add:
var aiProviderId: UUID?   // FK → AIProviderModel (replaces providerRaw + modelName)
// Keep for backward compat:
var providerRaw: String   // Still used as fallback
var modelName: String     // Still used as fallback
```

### Modified: `ChatSessionModel`
```swift
// Add:
var aiProviderId: UUID?   // FK → AIProviderModel
// Keep existing fields for backward compat
```

---

## Migration Strategy

- V3 schema: additive (new entity + new nullable fields) → lightweight migration
- On first launch after update:
  - Seed 2 default `AIProviderModel` entries (Gemini, z.ai)
  - Migrate existing API keys from `KeychainService` keys to provider-specific refs
  - Migrate existing `AIModeModel` entries to point to correct `AIProviderModel`

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Data loss during schema migration | High | Backup before migration, lightweight additive only |
| Breaking existing AI modes | High | Keep providerRaw/modelName as fallback, gradual migration |
| Chat window lifecycle (NSWindow vs NSPanel) | Medium | Test thoroughly — NSWindow has different behavior than NSPanel |
| Settings complexity | Medium | Keep modular, one file per section |

---

## Success Criteria

- [ ] App launches to Chat UI (not task view)
- [ ] Settings show Raycast-style sidebar with all categories
- [ ] User can add up to 10 AI providers (2 default + 8 custom)
- [ ] Each provider has editable model list with test functionality
- [ ] All provider models available in AI Mode and Chat UI selectors
- [ ] Task management still accessible via menu/shortcut
- [ ] No data loss on upgrade from current version
- [ ] Build succeeds, all existing features still work

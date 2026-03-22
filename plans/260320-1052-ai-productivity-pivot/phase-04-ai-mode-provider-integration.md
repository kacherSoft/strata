# Phase 4: AI Mode ↔ Provider Integration

**Priority:** High | **Effort:** Medium | **Status:** Pending
**Depends on:** Phase 1 (Provider Model), Phase 2 (Settings)

---

## Context Links
- [Plan Overview](plan.md) | [Phase 1](phase-01-ai-provider-data-model.md) | [Phase 2](phase-02-settings-redesign.md)
- AI modes: `Data/Models/AIModeModel.swift`, `Views/Settings/AIModesSettingsView.swift`
- AI service: `AI/Services/AIService.swift`

---

## Overview

Wire `AIModeModel` to `AIProviderModel` so each mode selects its provider and model from the user's configured providers. The mode editor shows a provider picker → model picker chain populated from `AIProviderModel.models`.

---

## Requirements

- AI Mode editor: Provider picker lists all enabled `AIProviderModel` entries
- Model picker dynamically shows models from the selected provider
- Mode stores `aiProviderId` (UUID reference to AIProviderModel)
- Backward compat: modes without `aiProviderId` fall back to `providerRaw` + `modelName`
- When a provider is deleted, its modes fall back to default Gemini provider
- `AIService.enhance()` and `streamChat()` resolve provider from `AIProviderModel`

---

## Architecture

### Mode → Provider Resolution

```swift
// In AIService or a resolver helper:
func resolveProvider(for mode: AIModeModel, context: ModelContext) -> AIProviderProtocol {
    // 1. Try aiProviderId → fetch AIProviderModel → create provider
    if let providerId = mode.aiProviderId,
       let providerModel = fetchProvider(providerId, context) {
        return providerFor(providerModel)
    }
    // 2. Fallback: legacy providerRaw + modelName
    return legacyProviderFor(mode.provider, customBaseURL: mode.customBaseURL)
}
```

### Mode Editor Flow

```
[Provider Picker: "Google Gemini" ▼]
    ↓ onChange → load provider.models
[Model Picker: "gemini-flash-lite-latest" ▼]
    ↓ both saved to mode
```

---

## Related Code Files

### Modify
- `Data/Models/AIModeModel.swift` — Use `aiProviderId` for provider resolution
- `Views/Settings/AIModesSettingsView.swift` — Provider picker → model picker from AIProviderModel
- `AI/Services/AIService.swift` — `enhance()` and `streamChat()` use AIProviderModel resolution
- `Views/Chat/ChatView.swift` — `resolveChatMode()` passes provider context

---

## Implementation Steps

1. Update `ModeEditorSheet`: replace `AIProviderType` Picker with `AIProviderModel` Picker
2. Model picker: `ForEach(selectedProvider.models)` instead of `provider.availableModels`
3. On save: store `aiProviderId` + `modelName` (model name still stored for offline/fallback)
4. Update `AIService.enhance()`: resolve provider via `AIProviderModel` first, fallback to legacy
5. Update `ChatView.sendMessage()`: same resolution chain
6. Handle orphaned modes: if provider deleted, show warning in mode list + use Gemini fallback
7. Build and verify enhance + chat both work with new resolution

---

## Todo List

- [ ] Update ModeEditorSheet with provider picker from AIProviderModel
- [ ] Dynamic model picker from selected provider
- [ ] Store aiProviderId on save
- [ ] Update AIService provider resolution
- [ ] Update ChatView provider resolution
- [ ] Handle orphaned modes (deleted provider)
- [ ] Build verification

---

## Success Criteria

- [ ] Mode editor shows all enabled providers in picker
- [ ] Model picker updates when provider changes
- [ ] Enhance feature uses correct provider/model from AIProviderModel
- [ ] Chat feature uses correct provider/model from AIProviderModel
- [ ] Legacy modes (no aiProviderId) still work via fallback
- [ ] Deleting a provider doesn't crash modes that reference it

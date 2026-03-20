# Phase 1: AI Provider Data Model

**Priority:** Critical | **Effort:** Medium | **Status:** Pending

---

## Context Links
- [Plan Overview](plan.md)
- Current AI layer: `AI/Services/AIService.swift`, `AI/Providers/`
- Current models: `Data/Models/AIModeModel.swift`
- Schema: `Data/SchemaVersioning.swift`
- Container: `Data/ModelContainer+Config.swift`

---

## Overview

Replace hardcoded provider singletons with a SwiftData-backed `AIProviderModel` entity. Users can configure up to 10 providers (2 defaults + 8 custom OpenAI-compatible). Each provider stores its own base URL, API key reference, and model list.

---

## Key Insights

- Currently `AIService` holds 2 singletons (`geminiProvider`, `zaiProvider`) and creates `OpenAICompatibleProvider` on-the-fly
- API keys stored in Keychain via `KeychainService` with hardcoded keys (`.geminiAPIKey`, `.zaiAPIKey`, `.openaiAPIKey`)
- `AIModeModel.provider` is an enum (`AIProviderType`) — needs to reference `AIProviderModel` instead
- Provider-specific logic (Gemini multimodal, SSE streaming) must remain in typed provider classes

---

## Requirements

### Functional
- New `AIProviderModel` SwiftData entity
- 2 default providers seeded on first launch (Gemini, z.ai)
- Up to 8 user-added OpenAI-compatible providers (10 total max)
- Each provider stores: name, type, baseURL, API key ref, model list, default model
- Models are user-editable strings (not enum-restricted)
- API key per provider (stored in Keychain, referenced by provider ID)
- Test connection per provider + per model
- Providers can be enabled/disabled without deletion
- Default providers cannot be deleted (only disabled)

### Non-Functional
- Schema V3: lightweight additive migration (no data loss)
- Backward compatibility: existing `providerRaw`/`modelName` fields kept as fallback
- Keychain keys: `"provider-{uuid}"` pattern for dynamic providers

---

## Architecture

### New SwiftData Model

```swift
@Model final class AIProviderModel: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String                      // Display name
    var providerTypeRaw: String           // "gemini" | "zai" | "openai_compatible"
    var baseURL: String?                  // Required for openai_compatible
    var apiKeyRef: String                 // Keychain key: "provider-{uuid}"
    var modelsRaw: String                 // JSON array: ["model-a", "model-b"]
    var defaultModelName: String?         // Default model for new modes/sessions
    var isDefault: Bool                   // true = seeded, not deletable
    var isEnabled: Bool                   // User toggle
    var sortOrder: Int
    var createdAt: Date

    // Computed
    var providerType: AIProviderType { ... }
    var models: [String] { get/set → JSON encode/decode modelsRaw }
    var isConfigured: Bool { KeychainService.shared.has(apiKeyRef) }
}
```

### Modified: AIService

```swift
// Before: hardcoded singletons
private let geminiProvider = GeminiProvider()
private let zaiProvider = ZAIProvider()

// After: dynamic provider resolution
func providerFor(_ model: AIProviderModel) -> AIProviderProtocol {
    switch model.providerType {
    case .gemini: return GeminiProvider(apiKeyRef: model.apiKeyRef)
    case .zai: return ZAIProvider(apiKeyRef: model.apiKeyRef)
    case .openai: return OpenAICompatibleProvider(
        name: model.name,
        baseURL: model.baseURL ?? "",
        apiKeyRef: model.apiKeyRef
    )
    }
}
```

### Keychain Key Strategy

```
Default providers:  "gemini-api-key", "zai-api-key"  (keep existing keys)
Custom providers:   "provider-{uuid}"                 (new pattern)
```

Migration: Map existing Keychain entries to default provider `apiKeyRef` fields.

---

## Related Code Files

### Create
- `Data/Models/AIProviderModel.swift` — New SwiftData entity (~80 LOC)
- `Data/Repositories/AIProviderRepository.swift` — CRUD + validation (~60 LOC)

### Modify
- `Data/SchemaVersioning.swift` — Add V3 schema with AIProviderModel
- `Data/ModelContainer+Config.swift` — Add AIProviderModel to schema, seed defaults
- `AI/Services/AIService.swift` — Replace singletons with dynamic provider resolution
- `AI/Services/KeychainService.swift` — Add dynamic key support
- `AI/Providers/GeminiProvider.swift` — Accept apiKeyRef parameter
- `AI/Providers/ZAIProvider.swift` — Accept apiKeyRef parameter
- `AI/Providers/OpenAICompatibleProvider.swift` — Accept apiKeyRef parameter
- `Data/Models/AIModeModel.swift` — Add aiProviderId field
- `Data/Models/ChatSessionModel.swift` — Add aiProviderId field

---

## Implementation Steps

1. Create `AIProviderModel.swift` with all fields and computed properties
2. Create `AIProviderRepository.swift` with fetchAll, create, update, delete, fetchEnabled
3. Update `SchemaVersioning.swift`: define V3 schema including AIProviderModel
4. Update `ModelContainer+Config.swift`:
   - Add AIProviderModel to schema list
   - Add `seedDefaultProviders()` function (Gemini + z.ai)
   - Map existing Keychain keys to provider apiKeyRef
5. Update `KeychainService.swift`: add `get(ref:)` and `set(ref:value:)` for dynamic keys
6. Update provider constructors to accept apiKeyRef instead of hardcoded keys
7. Update `AIService.swift`: replace singletons with `providerFor(AIProviderModel)` resolution
8. Add `aiProviderId: UUID?` to `AIModeModel` and `ChatSessionModel`
9. Add migration helper: link existing modes to their matching default provider
10. Build and verify compilation

---

## Todo List

- [ ] Create AIProviderModel SwiftData entity
- [ ] Create AIProviderRepository
- [ ] Update SchemaVersioning for V3
- [ ] Update ModelContainer+Config with seeding
- [ ] Update KeychainService for dynamic keys
- [ ] Refactor provider constructors
- [ ] Refactor AIService provider resolution
- [ ] Add aiProviderId to AIModeModel + ChatSessionModel
- [ ] Migration helper for existing data
- [ ] Build verification

---

## Success Criteria

- [ ] `AIProviderModel` persists in SwiftData
- [ ] 2 default providers seeded on fresh install
- [ ] Existing API keys migrate to provider-based refs
- [ ] `AIService.providerFor(AIProviderModel)` resolves correctly for all 3 types
- [ ] Existing enhance and chat features still work
- [ ] Build succeeds with no warnings

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Keychain key migration breaks existing keys | High | Keep old keys as aliases, map to new pattern |
| Schema V3 migration fails | High | Lightweight additive only, pre-migration backup |
| Provider resolution changes break enhance/chat | High | Keep fallback to old `providerRaw` logic |

---

## Security Considerations

- API keys remain in Keychain (never in SwiftData)
- `apiKeyRef` is just a Keychain key name, not the actual secret
- Custom provider base URLs validated (https:// required for non-localhost)

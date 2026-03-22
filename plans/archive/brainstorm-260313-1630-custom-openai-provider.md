# Brainstorm: Custom OpenAI-Compatible AI Provider

**Date:** 2026-03-13
**Decision:** Option A — Standalone `CustomOpenAIProvider`

## Problem Statement

Strata currently supports 2 AI providers (Gemini, z.ai). Users want to connect their own OpenAI-compatible endpoint (OpenAI, Ollama, LM Studio, OpenRouter, Groq, etc.) with custom `base_url`, `api_key`, and `model_name`.

## Requirements

- Single custom provider slot (not multiple)
- User-configurable: base URL, API key, model name
- Text-only (no image/PDF attachments)
- OpenAI-compatible `POST /v1/chat/completions` format
- Secure credential storage via Keychain

## Evaluated Approaches

### Option A — New `CustomOpenAIProvider` (CHOSEN)

Clone `ZAIProvider` with configurable `baseURL` instead of hardcoded z.ai URL.

**Pros:**
- Simple, isolated, ~130 lines
- No risk of breaking existing z.ai flow
- Clear separation of concerns
- Easy to test independently

**Cons:**
- Some code duplication with ZAIProvider (~80% similar)

### Option B — Generalize `ZAIProvider` into `OpenAICompatibleProvider`

Refactor ZAIProvider to accept config, use it for both z.ai and custom.

**Pros:**
- DRY — single implementation for all OpenAI-compatible APIs
- Future providers are trivial to add

**Cons:**
- Risk breaking working z.ai integration
- Over-engineering for current needs (only 2 consumers)
- Couples z.ai and custom provider lifecycle

## Final Recommended Solution — Option A

**Rationale:** YAGNI + KISS. Duplication is acceptable when it buys isolation and safety. If a third OpenAI-compatible provider is needed later, refactor then.

## Implementation Scope (7 files)

### New Files
1. **`AI/Providers/CustomOpenAIProvider.swift`** — Clone of ZAIProvider with configurable baseURL, apiKey, modelName from KeychainService

### Modified Files
2. **`Data/Models/AIModeModel.swift`** — Add `case custom = "custom"` to `AIProviderType`, update `displayName`, `availableModels` (returns user model), `defaultModel`, `supportsImageAttachments` (false), `supportsPDFAttachments` (false)
3. **`AI/Services/KeychainService.swift`** — Add keys: `.customAPIKey`, `.customBaseURL`, `.customModelName`
4. **`AI/Services/AIService.swift`** — Add `customProvider` property, update `providerFor()` switch, update `hasAnyProviderConfigured`
5. **`Views/Settings/AIConfigSettingsView.swift`** — Add custom provider section with base URL + API key + model name fields

### No Changes Needed
- `AIProviderProtocol` — interface unchanged
- `GeminiProvider` — unaffected
- `ZAIProvider` — unaffected
- Backend — no backend changes required

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Provider slots | Single custom slot | KISS; multiple slots adds UI complexity for rare use case |
| Model selection | Manual text input | No auto-discovery; `/models` endpoint not universal |
| Attachment support | Text-only | OpenAI attachments vary by provider; defer to future |
| Credential storage | Keychain (3 keys) | Consistent with existing Gemini/z.ai pattern |
| Base URL format | User enters full base (e.g. `https://api.openai.com/v1`) | Provider appends `/chat/completions` |
| Test connection | `GET {baseURL}/models` | Same as ZAIProvider; graceful failure if unsupported |

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| User enters wrong URL format | Validate URL, show placeholder example |
| Provider doesn't support `/models` | testConnection catches error gracefully |
| API key exposure | Keychain storage, never logged |
| Breaking existing providers | Fully isolated — no shared code paths |

## Success Criteria

- User can configure custom base URL + API key + model name in Settings
- Text enhancement works through custom provider
- Existing Gemini and z.ai providers unaffected
- Credentials stored securely in Keychain
- testConnection validates the endpoint

## Next Steps

Create implementation plan with phased approach if user wants to proceed.

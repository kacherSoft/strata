# Custom OpenAI-Compatible AI Provider

**Status:** Complete
**Priority:** High
**Brainstorm:** `plans/reports/brainstorm-260313-1630-custom-openai-provider.md`

## Overview

Add a custom OpenAI-compatible provider slot so users can connect any OpenAI-compatible API (OpenAI, Ollama, LM Studio, OpenRouter, Groq, etc.) with configurable base URL, API key, and model name.

**Approach:** Option A — standalone `CustomOpenAIProvider` (clone of ZAIProvider). YAGNI: no shared abstraction until a third OpenAI-compatible provider justifies it.

## Phases

| # | Phase | Files | Status |
|---|-------|-------|--------|
| 1 | Data layer — KeychainService keys + AIProviderType enum | 2 | [x] |
| 2 | Provider — CustomOpenAIProvider.swift | 1 (new) | [x] |
| 3 | Service — AIService integration | 1 | [x] |
| 4 | UI — AIConfigSettingsView custom provider section | 1 | [x] |
| 5 | Build & test | — | [x] |

**Total:** 1 new file, 4 modified files. No backend changes.

## Dependencies

- Phase 2 depends on Phase 1 (needs Keychain keys)
- Phase 3 depends on Phase 2 (needs provider class)
- Phase 4 depends on Phase 1 (needs Keychain keys)
- Phases 1→2→3 sequential. Phase 4 can start after Phase 1.

## Success Criteria

- User configures base URL + API key + model in Settings
- Text enhancement works via custom provider
- testConnection validates endpoint
- Existing Gemini/z.ai providers unaffected
- Build compiles with zero errors

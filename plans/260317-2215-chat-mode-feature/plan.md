---
title: "Chat Mode — Conversational AI Interface"
description: "Add ChatGPT-like multi-turn conversational AI with streaming, persistent sessions, and dedicated window"
status: pending
priority: P1
effort: 20h
branch: claude/confident-cray
tags: [ai, chat, streaming, swiftdata, ui]
created: 2026-03-17
---

# Chat Mode — Implementation Plan

## Summary

Add a ChatGPT-like conversational AI interface as a new AI mode in Strata. Multi-turn streaming chat with persistent sessions, sidebar navigation, markdown rendering, and file attachments. Coexists with EnhanceMe (not mutually exclusive).

## Architecture Decisions

1. **Separate window** — Chat is multi-turn; EnhanceMe is single-shot. No code sharing beyond AIProviderProtocol.
2. **Streaming via protocol extension** — New `streamChat()` on AIProviderProtocol with default fallback.
3. **OpenAI-compatible provider** — Extract SSE streaming into reusable `OpenAICompatibleProvider`. z.ai becomes thin config. New `.openai` provider type lets users plug in ANY OpenAI-compatible endpoint (OpenRouter, Groq, Ollama, Together AI, etc.) with custom base URL.
4. **ChatService** — New service separate from AIService. Owns streaming, history, cancellation.
5. **No new dependencies** — Markdown via AttributedString. No MarkdownUI package.
6. **Schema V2** — Additive-only migration (new tables, new `customBaseURL` column on AIModeModel).
7. **Chat window NOT mutually exclusive** — WindowManager gains `showChat()`/`hideChat()` without `closeAllFloatingWindows()`.

## Phases

| # | Phase | Status | Effort | Dependency |
|---|-------|--------|--------|------------|
| 1 | [Data models & schema](phase-01-data-models-and-schema.md) | pending | 3h | none |
| 2 | [Streaming provider protocol](phase-02-streaming-provider-protocol.md) | pending | 4h | none |
| 3 | [Chat window & layout](phase-03-chat-window-and-layout.md) | pending | 3h | P1 |
| 4 | [Message display & streaming UI](phase-04-message-display-and-streaming-ui.md) | pending | 4h | P2, P3 |
| 5 | [Input & attachments](phase-05-input-and-attachments.md) | pending | 3h | P3 |
| 6 | [Session management](phase-06-session-management.md) | pending | 2h | P1, P3 |
| 7 | [Integration & polish](phase-07-integration-and-polish.md) | pending | 1h | P1-P6 |

## Key Risks

- **Gemini SDK streaming API** — `Chat.sendMessageStream()` returns `AsyncThrowingStream`. Verify exact API in google-generative-ai-swift 0.5.x.
- **SwiftData V2 migration** — Additive-only should be safe, but must test with existing stores.
- **AttributedString markdown** — Limited built-in support; code block highlighting needs custom parsing.

## Files Created (new)

- `Data/Models/ChatSessionModel.swift`
- `Data/Models/ChatMessageModel.swift`
- `Data/Repositories/ChatSessionRepository.swift`
- `Data/Repositories/ChatMessageRepository.swift`
- `AI/Services/ChatService.swift`
- `AI/Models/ChatStreamTypes.swift`
- `AI/Providers/OpenAICompatibleProvider.swift` — Reusable SSE streaming for any OpenAI-compatible endpoint
- `Windows/ChatPanel.swift`
- `Views/Chat/ChatView.swift`
- `Views/Chat/ChatSessionListView.swift`
- `Views/Chat/ChatMessageBubble.swift`
- `Views/Chat/ChatInputView.swift`
- `Views/Chat/ChatMarkdownRenderer.swift`
- `Views/Chat/ChatEmptyStateView.swift`

## Files Modified

- `Data/Models/AIModeModel.swift` — Add `customBaseURL` property, add `.openai` to `AIProviderType`
- `Data/SchemaVersioning.swift` — Add V2 schema + migration stage
- `Data/ModelContainer+Config.swift` — Seed "Chat" AI mode, update schema reference
- `AI/Protocols/AIProvider.swift` — Add `streamChat()` protocol method
- `AI/Providers/GeminiProvider.swift` — Implement streaming
- `AI/Providers/ZAIProvider.swift` — Delegate to OpenAICompatibleProvider
- `AI/Services/AIService.swift` — Handle `.openai` provider type
- `Views/Settings/AIModesSettingsView.swift` — Show base URL field for `.openai` provider
- `Windows/WindowManager.swift` — Add `showChat()`/`hideChat()`
- `Shortcuts/ShortcutNames.swift` — Add `.chatWindow` shortcut name

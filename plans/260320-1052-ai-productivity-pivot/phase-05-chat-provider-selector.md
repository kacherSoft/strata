# Phase 5: Chat UI Provider/Model Selector

**Priority:** High | **Effort:** Small | **Status:** Pending
**Depends on:** Phase 1 (Provider Model), Phase 3 (Chat Primary)

---

## Context Links
- [Plan Overview](plan.md) | [Phase 1](phase-01-ai-provider-data-model.md) | [Phase 3](phase-03-chat-primary-window.md)
- Chat views: `Views/Chat/ChatView.swift`, `Views/Chat/ChatInputView.swift`

---

## Overview

Add a model selector to the Chat UI so users can switch provider/model mid-conversation or per-session. Similar to how ChatGPT shows a model dropdown in the toolbar area.

---

## Requirements

- Model selector in chat toolbar (dropdown showing all available models grouped by provider)
- Changing model applies to the current session (persisted to ChatSessionModel)
- New sessions use the default model from Chat AI mode settings
- Selector shows provider name + model name: "Gemini › gemini-flash-latest"
- Only enabled providers with configured API keys shown

---

## Architecture

### UI Layout

```
┌─────────────────────────────────────────────┐
│ [≡] New Chat    [Gemini › flash-lite ▼]     │
│─────────────────────────────────────────────│
│                                             │
│          Chat messages area                 │
│                                             │
│─────────────────────────────────────────────│
│ [+] Type a message...              [↑]      │
└─────────────────────────────────────────────┘
```

### Model Picker Data

```swift
struct ProviderModelOption: Identifiable {
    let id: String           // "providerUUID:modelName"
    let providerName: String // "Google Gemini"
    let modelName: String    // "gemini-flash-lite-latest"
    let providerId: UUID
}

// Built from: AIProviderModel.fetchEnabled() → flatMap models
```

---

## Related Code Files

### Create
- `Views/Chat/ChatModelSelectorView.swift` — Dropdown picker (~80 LOC)

### Modify
- `Views/Chat/ChatView.swift` — Add model selector to toolbar area, pass selection to sendMessage
- `Data/Models/ChatSessionModel.swift` — Update aiProviderId/modelName on model change
- `AI/Services/ChatService.swift` — Accept provider model in sendMessage

---

## Implementation Steps

1. Create `ChatModelSelectorView`: Menu-style picker grouped by provider
2. Add to ChatView toolbar (between sidebar toggle and spacer)
3. On selection change: update `ChatSessionModel.aiProviderId` + `modelName`
4. `sendMessage()` uses session's current provider/model (not just Chat mode default)
5. New sessions: inherit default from Chat AI mode
6. Build and verify model switching works mid-session

---

## Todo List

- [ ] Create ChatModelSelectorView
- [ ] Integrate in ChatView toolbar
- [ ] Persist selection to ChatSessionModel
- [ ] Update sendMessage to use session provider/model
- [ ] Build verification

---

## Success Criteria

- [ ] Model selector visible in chat toolbar
- [ ] Shows all models from all enabled providers
- [ ] Switching model persists to session
- [ ] New messages use the selected model
- [ ] New sessions default to Chat mode's model

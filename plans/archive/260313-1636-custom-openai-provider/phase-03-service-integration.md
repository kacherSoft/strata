# Phase 3: Service — AIService Integration

**Priority:** High | **Status:** Complete
**Depends on:** Phase 2 (CustomOpenAIProvider class)

## Context

- [AIService.swift](../../TaskManager/Sources/TaskManager/AI/Services/AIService.swift) — singleton coordinator (119 lines)

## Overview

Add `customProvider` to AIService, update `providerFor()` switch, update `hasAnyProviderConfigured`.

## Changes

File: `TaskManager/Sources/TaskManager/AI/Services/AIService.swift`

### 1. Add provider property (line ~15)

```swift
private let geminiProvider = GeminiProvider()
private let zaiProvider = ZAIProvider()
private let customProvider = CustomOpenAIProvider()  // ADD
```

### 2. Update `providerFor()` switch (line ~20)

```swift
func providerFor(_ type: AIProviderType) -> AIProviderProtocol {
    switch type {
    case .gemini: return geminiProvider
    case .zai: return zaiProvider
    case .custom: return customProvider  // ADD
    }
}
```

### 3. Update `hasAnyProviderConfigured` (line ~30)

```swift
var hasAnyProviderConfigured: Bool {
    geminiProvider.isConfigured || zaiProvider.isConfigured || customProvider.isConfigured
}
```

## Todo

- [ ] Add `customProvider` property
- [ ] Add `.custom` case to `providerFor()` switch
- [ ] Add `customProvider.isConfigured` to `hasAnyProviderConfigured`

## Success Criteria

- `AIService.shared.providerFor(.custom)` returns CustomOpenAIProvider
- `hasAnyProviderConfigured` includes custom provider check
- No other AIService logic needs changes (enhance, testProvider, cycleMode all work generically)

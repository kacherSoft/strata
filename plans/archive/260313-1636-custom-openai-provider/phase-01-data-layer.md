# Phase 1: Data Layer — Keychain Keys + AIProviderType

**Priority:** High | **Status:** Complete
**Depends on:** Nothing

## Context

- [KeychainService.swift](../../TaskManager/Sources/TaskManager/AI/Services/KeychainService.swift) — credential storage
- [AIModeModel.swift](../../TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift) — provider enum + mode model

## Overview

Add 3 new Keychain keys for custom provider credentials and extend `AIProviderType` enum with `.custom` case.

## Implementation Steps

### 1. KeychainService — Add 3 keys

File: `TaskManager/Sources/TaskManager/AI/Services/KeychainService.swift`

Add to `Key` enum after `.zaiAPIKey`:

```swift
case customProviderAPIKey = "custom-provider-api-key"
case customProviderBaseURL = "custom-provider-base-url"
case customProviderModelName = "custom-provider-model-name"
```

### 2. AIModeModel — Add `.custom` case

File: `TaskManager/Sources/TaskManager/Data/Models/AIModeModel.swift`

**2a.** Add enum case:
```swift
case custom = "custom"
```

**2b.** Update `displayName`:
```swift
case .custom: return "Custom (OpenAI)"
```

**2c.** Update `availableModels` — return user-configured model from Keychain:
```swift
case .custom:
    if let model = KeychainService.shared.get(.customProviderModelName), !model.isEmpty {
        return [model]
    }
    return ["gpt-4o"]
```

**2d.** Update `supportsImageAttachments`:
```swift
case .custom: return false
```

**2e.** Update `supportsPDFAttachments`:
```swift
case .custom: return false
```

## Todo

- [ ] Add 3 Keychain keys
- [ ] Add `AIProviderType.custom` case
- [ ] Update all switch statements in AIProviderType

## Success Criteria

- Code compiles with no errors
- All switch statements exhaustive (no compiler warnings)

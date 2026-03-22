# Phase 2: Provider — CustomOpenAIProvider

**Priority:** High | **Status:** Complete
**Depends on:** Phase 1 (Keychain keys)

## Context

- [ZAIProvider.swift](../../TaskManager/Sources/TaskManager/AI/Providers/ZAIProvider.swift) — template to clone
- [AIProvider.swift](../../TaskManager/Sources/TaskManager/AI/Protocols/AIProvider.swift) — protocol to conform to

## Overview

Create `CustomOpenAIProvider.swift` — clone of ZAIProvider with user-configurable baseURL, apiKey, and modelName from KeychainService instead of hardcoded values.

## New File

`TaskManager/Sources/TaskManager/AI/Providers/CustomOpenAIProvider.swift`

### Key Differences from ZAIProvider

| Aspect | ZAIProvider | CustomOpenAIProvider |
|--------|-------------|---------------------|
| `name` | `"z.ai"` | `"Custom (OpenAI)"` |
| `baseURL` | Hardcoded `https://api.z.ai/v1` | `KeychainService.get(.customProviderBaseURL)` |
| `apiKey` | `.zaiAPIKey` | `.customProviderAPIKey` |
| `defaultModel` | `"GLM-4.6"` | `KeychainService.get(.customProviderModelName) ?? "gpt-4o"` |
| `isConfigured` | `hasKey(.zaiAPIKey)` | `hasKey(.customProviderAPIKey) && hasKey(.customProviderBaseURL)` |

### Implementation

```swift
import Foundation

final class CustomOpenAIProvider: AIProviderProtocol, @unchecked Sendable {
    var name: String { "Custom (OpenAI)" }

    private let keychain = KeychainService.shared
    private let timeout: TimeInterval = 30

    var isConfigured: Bool {
        keychain.hasKey(.customProviderAPIKey) && keychain.hasKey(.customProviderBaseURL)
    }

    private var baseURL: String? {
        keychain.get(.customProviderBaseURL)
    }

    private var modelName: String {
        keychain.get(.customProviderModelName) ?? "gpt-4o"
    }

    // enhance() — same as ZAIProvider but uses dynamic baseURL/apiKey/model
    // testConnection() — same as ZAIProvider but uses dynamic baseURL/apiKey
}
```

### URL Handling

- User enters base URL like `https://api.openai.com/v1`
- Provider appends `/chat/completions` for enhance
- Provider appends `/models` for testConnection
- Strip trailing slash before appending

## Todo

- [ ] Create CustomOpenAIProvider.swift
- [ ] Implement `enhance()` with dynamic config from Keychain
- [ ] Implement `testConnection()` with dynamic config
- [ ] Strip trailing slash from baseURL

## Success Criteria

- Conforms to `AIProviderProtocol`
- `isConfigured` requires both API key AND base URL
- Reads all config from Keychain at call time (no stale cache)
- ~130 lines, under 200 LOC limit

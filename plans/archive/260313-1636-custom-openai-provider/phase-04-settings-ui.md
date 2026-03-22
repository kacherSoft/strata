# Phase 4: UI — AIConfigSettingsView Custom Provider Section

**Priority:** High | **Status:** Complete
**Depends on:** Phase 1 (Keychain keys)

## Context

- [AIConfigSettingsView.swift](../../TaskManager/Sources/TaskManager/Views/Settings/AIConfigSettingsView.swift) — 206 lines, has reusable `providerRow()` builder

## Overview

Add custom provider section with 3 fields: base URL, API key, model name. Reuse existing `providerRow()` for API key, add separate fields for base URL and model name.

## Changes

File: `TaskManager/Sources/TaskManager/Views/Settings/AIConfigSettingsView.swift`

### 1. Add state properties (lines 4-11)

```swift
@State private var customKey = ""
@State private var customBaseURL = ""
@State private var customModelName = ""
@State private var showCustomKey = false
@State private var testingCustom = false
@State private var customTestResult: TestResult?
```

### 2. Add custom provider section in `body` (after z.ai providerRow)

```swift
Divider()

// Custom OpenAI-compatible provider
VStack(alignment: .leading, spacing: 8) {
    HStack {
        Text("Custom (OpenAI-Compatible)")
            .font(.headline)
        Spacer()
        if keychain.hasKey(.customProviderAPIKey) && keychain.hasKey(.customProviderBaseURL) {
            Label("Configured", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    // Base URL field
    VStack(alignment: .leading, spacing: 4) {
        Text("Base URL")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextField("https://api.openai.com/v1", text: $customBaseURL)
            .textFieldStyle(.roundedBorder)
    }

    // API Key field (reuse visual pattern)
    VStack(alignment: .leading, spacing: 4) {
        Text("API Key")
            .font(.caption)
            .foregroundStyle(.secondary)
        HStack {
            Group {
                if showCustomKey {
                    TextField("API Key", text: $customKey)
                } else {
                    SecureField("API Key", text: $customKey)
                }
            }
            .textFieldStyle(.roundedBorder)
            Button(action: { showCustomKey.toggle() }) {
                Image(systemName: showCustomKey ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
        }
    }

    // Model Name field
    VStack(alignment: .leading, spacing: 4) {
        Text("Model Name")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextField("gpt-4o", text: $customModelName)
            .textFieldStyle(.roundedBorder)
    }

    // Action buttons
    HStack(spacing: 12) {
        Button("Save") { saveCustomProvider() }
            .disabled(customBaseURL.trimmed.isEmpty || customKey.trimmed.isEmpty)
        Button("Test") { testCustom() }
            .disabled(customBaseURL.trimmed.isEmpty || customKey.trimmed.isEmpty || testingCustom)
        if testingCustom { ProgressView().scaleEffect(0.7) }
        // test result label...
        Spacer()
        if keychain.hasKey(.customProviderAPIKey) {
            Button("Remove", role: .destructive) { removeCustomProvider() }
                .foregroundStyle(.red)
        }
    }
}
```

### 3. Add helper methods

```swift
private func saveCustomProvider() {
    do {
        try keychain.save(customBaseURL.trimmingCharacters(in: .whitespaces), for: .customProviderBaseURL)
        try keychain.save(customKey.trimmingCharacters(in: .whitespaces), for: .customProviderAPIKey)
        if !customModelName.trimmingCharacters(in: .whitespaces).isEmpty {
            try keychain.save(customModelName.trimmingCharacters(in: .whitespaces), for: .customProviderModelName)
        }
    } catch {
        customTestResult = .failure(error.localizedDescription)
    }
}

private func removeCustomProvider() {
    keychain.delete(.customProviderAPIKey)
    keychain.delete(.customProviderBaseURL)
    keychain.delete(.customProviderModelName)
    customKey = ""
    customBaseURL = ""
    customModelName = ""
}

private func testCustom() {
    testingCustom = true
    customTestResult = nil
    Task {
        do {
            saveCustomProvider()  // save first so provider reads from keychain
            _ = try await AIService.shared.testProvider(.custom)
            customTestResult = .success
        } catch let error as AIError {
            customTestResult = .failure(error.localizedDescription)
        } catch {
            customTestResult = .failure(error.localizedDescription)
        }
        testingCustom = false
    }
}
```

### 4. Update `loadKeys()` — add custom provider loading

```swift
if let url = keychain.get(.customProviderBaseURL) { customBaseURL = url }
if let key = keychain.get(.customProviderAPIKey) { customKey = key }
if let model = keychain.get(.customProviderModelName) { customModelName = model }
```

### 5. Update `saveKey()` — add custom case to switch

```swift
case .customProviderAPIKey:
    customTestResult = .failure(error.localizedDescription)
```

## Modularization Note

After changes, AIConfigSettingsView will be ~280 lines — exceeds 200 LOC limit. Extract custom provider section into `CustomProviderSettingsSection.swift` subview.

## Todo

- [ ] Add state properties
- [ ] Add custom provider section UI
- [ ] Add saveCustomProvider/removeCustomProvider/testCustom methods
- [ ] Update loadKeys() for custom provider
- [ ] Extract custom section to separate file if >200 LOC

## Success Criteria

- Base URL, API key, model name fields visible in Settings
- Save persists all 3 values to Keychain
- Test validates connection via AIService
- Remove clears all 3 Keychain entries
- Placeholder text guides user (e.g., `https://api.openai.com/v1`)

# Code Review: Custom OpenAI-Compatible AI Provider

**Date:** 2026-03-13
**Reviewer:** code-reviewer
**Feature:** Custom OpenAI-compatible provider (configurable base URL, API key, model)

## Scope

- Files reviewed: 6 (2 new, 4 modified)
- LOC added: ~315
- Focus: New feature addition
- Reference: ZAIProvider.swift (existing template, 124 LOC)

## Overall Assessment

Clean, well-structured implementation that follows existing patterns closely. The custom provider is a near-clone of ZAIProvider with dynamic config -- exactly what KISS dictates. Extraction of CustomProviderSettingsSection into its own file is the right call for file-size compliance. No secrets are logged. Keychain usage is consistent with existing providers.

**Verdict: APPROVE with minor items below.**

---

## Critical Issues

None.

## High Priority

### H1. `attachments` parameter silently ignored in CustomOpenAIProvider

**File:** `CustomOpenAIProvider.swift:26`

The `enhance` method accepts `attachments: [AIAttachment]` but never uses them. This is identical to ZAIProvider behavior, so not a regression. However, once a user selects a custom provider that supports vision (e.g., GPT-4o), they will silently lose attachment content.

**Impact:** User data silently dropped.
**Recommendation:** Acceptable for v1 since `supportsAnyAttachments` returns `false` for `.custom` (AIModeModel.swift:49). The UI should prevent attachment submission. Log or assert if attachments are passed anyway:
```swift
if !attachments.isEmpty {
    // Future: add multimodal content parts
    assertionFailure("CustomOpenAIProvider does not support attachments yet")
}
```
Low-effort safety net. Not blocking.

### H2. URL injection via user-supplied baseURL

**File:** `CustomOpenAIProvider.swift:47`

`resolvedBaseURL` strips trailing slash but does no scheme validation. A user could enter `file:///etc/passwd` or `javascript:...` -- though `URLSession` would reject non-HTTP schemes, the error message may leak path info.

**Recommendation:** Add scheme validation in `resolvedBaseURL`:
```swift
private var resolvedBaseURL: String? {
    guard let url = keychain.get(.customProviderBaseURL), !url.isEmpty else { return nil }
    let trimmed = url.hasSuffix("/") ? String(url.dropLast()) : url
    guard trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://") else { return nil }
    return trimmed
}
```
This also prevents `ftp://`, `ws://`, etc.

### H3. `testConnection` in CustomOpenAIProvider lacks error handling for URLError

**File:** `CustomOpenAIProvider.swift:127`

Unlike `enhance()` which catches `URLError.timedOut` and wraps other errors, `testConnection()` lets raw URLErrors propagate. ZAIProvider has the same gap, so not a regression, but worth fixing in both.

**Recommendation:** Wrap in do/catch like `enhance()` does, or at minimum add `throws` documentation noting raw URLErrors can escape.

---

## Medium Priority

### M1. Duplicated TestResult enum

**Files:** `AIConfigSettingsView.swift:15` and `CustomProviderSettingsSection.swift:15`

Both define identical `TestResult { case success; case failure(String) }`. DRY violation.

**Recommendation:** Extract to a shared type (e.g., `ProviderTestResult` in a shared file or as a top-level type).

### M2. `saveValues()` non-atomic -- partial save on keychain failure

**File:** `CustomProviderSettingsSection.swift:128-138`

If the second `keychain.save` throws, baseURL is saved but apiKey is not. User sees an error but config is partially written.

**Recommendation:** Either save all-or-nothing (collect values, save in a do block with rollback on failure), or at minimum document that partial saves are possible. Given Keychain failures are rare, this is low-risk but worth noting.

### M3. `saveValues()` called inside `testConnection()` without error propagation

**File:** `CustomProviderSettingsSection.swift:157`

`saveValues()` sets `testResult` on failure but `testConnection()` then overwrites `testResult` with the test outcome. If save fails silently, the test runs against stale keychain values.

**Recommendation:** Make `saveValues()` return a Bool or throw, and short-circuit the test if save fails:
```swift
private func testConnection() {
    isTesting = true
    testResult = nil
    do {
        try saveValuesOrThrow()
    } catch {
        testResult = .failure("Save failed: \(error.localizedDescription)")
        isTesting = false
        return
    }
    Task { ... }
}
```

### M4. `availableModels` in AIModeModel reads Keychain on every access

**File:** `AIModeModel.swift:21-26`

`AIProviderType.availableModels` for `.custom` calls `KeychainService.shared.get()` each time. This is a computed property on an enum likely called from UI (picker). Keychain reads are syscalls.

**Impact:** Minor perf concern if called in tight loops (e.g., List rendering). Not critical but worth noting.

### M5. No URL format validation in settings UI

**File:** `CustomProviderSettingsSection.swift:26`

User can type anything in the Base URL field. No validation before save.

**Recommendation:** Add basic validation (URL parseable, starts with http/https) on the Save button or as a field validation. Could disable Save if URL is malformed.

---

## Low Priority

### L1. Magic default "gpt-4o" in two places

**Files:** `CustomOpenAIProvider.swift:23` and `AIModeModel.swift:25`

Default model name "gpt-4o" is hardcoded in both `resolvedModelName` and `availableModels`. Should be a shared constant.

### L2. `.custom` case returns `false` for `supportsImageAttachments` / `supportsPDFAttachments`

**File:** `AIModeModel.swift:37,43`

Reasonable for v1 but future-proofing thought: once multimodal support lands, these will need updating. Consider a TODO comment.

### L3. `@unchecked Sendable` on CustomOpenAIProvider

**File:** `CustomOpenAIProvider.swift:6`

Same pattern as ZAIProvider. The class is stateless (reads keychain per-call), so this is safe. But `@unchecked` suppresses compiler checking -- if state is added later, race conditions could sneak in. Acceptable for now.

---

## Positive Observations

- File extraction strategy is sound -- AIConfigSettingsView stays under 200 LOC
- Consistent error handling pattern matching ZAIProvider exactly
- API key stored in Keychain, not UserDefaults -- correct security practice
- Trailing slash normalization on base URL -- good defensive coding
- Clean `fieldSection` ViewBuilder helper reduces UI boilerplate
- `String.trimmedIsEmpty` extension is private to file scope -- no namespace pollution
- Token usage extraction is optional-safe (nil if provider doesn't return it)
- Mode-level model override (`mode.modelName.isEmpty ? resolvedModelName : mode.modelName`) gives good flexibility

## Recommended Actions (Priority Order)

1. **[H2]** Add HTTP/HTTPS scheme validation to `resolvedBaseURL` (5 min fix)
2. **[M1]** Extract shared `TestResult` enum (5 min refactor)
3. **[M3]** Fix `saveValues()` error propagation in `testConnection()` flow
4. **[M5]** Add basic URL validation in settings UI
5. **[L1]** Extract "gpt-4o" default to a constant

## Metrics

- File size compliance: All files under 200 LOC (largest: CustomProviderSettingsSection at 175)
- Type safety: Good -- Keychain keys are enum-typed, provider types are enum-typed
- Error handling: Comprehensive in `enhance()`, incomplete in `testConnection()`
- Security: No secrets logged, Keychain-only storage, no plaintext persistence

## Unresolved Questions

1. Should `testConnection()` hit `/models` for all OpenAI-compatible providers? Some (Ollama, LM Studio) may not implement this endpoint. Consider falling back to a minimal `/chat/completions` call with a short prompt.
2. Should the custom provider eventually support multimodal (vision) content parts? If so, worth adding a TODO now.
3. Is HTTP (non-TLS) acceptable for local providers like Ollama (`http://localhost:11434`)? The H2 recommendation allows it -- confirm this is intentional.

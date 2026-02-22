---
title: "AX Compatibility Fix — Universal Text Field Access"
description: "Fix inline enhancement to work across ALL apps: native, browsers, Electron, and custom frameworks"
status: in-progress
priority: P0
effort: 16-24h
branch: feature/inline-enhance-system-wide
created: 2026-02-22
revised: 2026-02-22
oracle-reviewed: true
---

# AX Compatibility Fix — Universal Text Field Access

## Problem Statement

The inline enhancement feature works in **native apps** (Telegram, Notes) but fails in:
- **Browsers**: Chrome, Safari, Firefox, Edge
- **Electron apps**: Slack, VS Code, Discord
- **Some webviews**: Notion, Figma

## Root Cause Analysis

### 1. Accessibility Hierarchy Differences

| App Type | AX Hierarchy Pattern | Current Code Behavior |
|----------|---------------------|----------------------|
| Native (Cocoa) | Direct `AXTextField` / `AXTextArea` | ✅ Works — direct hit |
| Browsers | `AXWebArea` → `AXGroup` → `AXTextField` | ❌ Fails — only walks UP |
| Electron | `AXWebArea` or non-standard roles | ❌ Fails — role mismatch |
| Custom | May have no standard role | ❌ Fails — attribute check fails |

### 2. Attribute Availability Differences

| Attribute | Native | Browsers | Electron |
|-----------|--------|----------|----------|
| `kAXSelectedTextAttribute` | ✅ | ❌ Often missing | ❌ Missing |
| `kAXSelectedTextRangeAttribute` | ✅ | ✅ | ⚠️ Sometimes |
| `kAXValueAttribute` (String) | ✅ | ✅ | ✅ |
| `kAXValueAttribute` (settable) | ✅ | ❌ Often read-only | ❌ Read-only |
| `AXPlaceholderValue` | ❌ | ✅ | ⚠️ |

### 3. Current Implementation Flaws

```swift
// PROBLEM 1: Only walks UP parent chain
private func findTextElement(from start: AXUIElement) -> AXUIElement {
    // Walks up to 8 parents but never searches DOWN into children
    // Browser focused element is often a container, not the text field
}

// PROBLEM 2: Role check too restrictive
let textRoles: Set<String> = [
    kAXTextFieldRole, kAXTextAreaRole,
    "AXComboBox", "AXSearchField",
]
// Missing: AXWebArea, AXGroup (browser containers)

// PROBLEM 3: Only checks kAXSelectedTextAttribute
if let selectedText = getStringAttribute(textElement, kAXSelectedTextAttribute as String) { ... }
// Browsers often don't expose this but DO expose kAXSelectedTextRangeAttribute

// PROBLEM 4: 50ms Electron pause too short
usleep(50_000)  // Some Electron apps need 100-200ms
```

## Solution Architecture

### Strategy: Multi-Layer Detection with Fallbacks

```
┌─────────────────────────────────────────────────────────────────┐
│                    TextCaptureEngine                             │
│  (Replaces TextFocusManager with layered detection strategy)    │
├─────────────────────────────────────────────────────────────────┤
│ Layer 1: Direct Detection                                        │
│   - Check focused element directly for text attributes           │
│   - Works for: Native apps                                       │
├─────────────────────────────────────────────────────────────────┤
│ Layer 2: Parent Traversal                                        │
│   - Walk UP parent chain looking for text-capable element       │
│   - Works for: Some wrapped native controls                      │
├─────────────────────────────────────────────────────────────────┤
│ Layer 3: Child Descent (NEW)                                     │
│   - For container roles (AXWebArea, AXGroup), search DOWN       │
│   - Works for: Browsers, some Electron                          │
├─────────────────────────────────────────────────────────────────┤
│ Layer 4: Web Content Extraction (NEW)                            │
│   - Use AXSelectedTextRange + AXValue to extract selection      │
│   - Works for: Browsers without AXSelectedText                  │
├─────────────────────────────────────────────────────────────────┤
│ Layer 5: Clipboard Fallback (Enhanced)                          │
│   - Copy (⌘C) → Enhance → Paste (⌘V) with selection handling   │
│   - Works for: Everything (last resort)                         │
└─────────────────────────────────────────────────────────────────┘
```

### Text Replacement Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                   TextReplacementEngine                          │
├─────────────────────────────────────────────────────────────────┤
│ Strategy 1: Direct AX Value Set                                  │
│   - AXUIElementSetAttributeValue(kAXValueAttribute)             │
│   - Works when attribute is settable                             │
├─────────────────────────────────────────────────────────────────┤
│ Strategy 2: Selection Replacement                                │
│   - AXUIElementSetAttributeValue(kAXSelectedTextAttribute)      │
│   - Works for selected text replacement                          │
├─────────────────────────────────────────────────────────────────┤
│ Strategy 3: Range-Based Value Update                             │
│   - Get full AXValue, replace range, set back                   │
│   - Works for browsers with read-only selectedText              │
├─────────────────────────────────────────────────────────────────┤
│ Strategy 4: Clipboard Paste (with verification)                 │
│   - Save clipboard → Set new text → ⌘A + ⌘V → Verify → Restore │
│   - Works for everything as fallback                             │
├─────────────────────────────────────────────────────────────────┤
│ VERIFICATION: Re-read value after replacement to confirm success │
└─────────────────────────────────────────────────────────────────┘
```

> **Note:** Typing simulation removed per Oracle review - unreliable for unicode/emoji

## Implementation Phases

| Phase | Description | Status | Time |
|-------|-------------|--------|------|
| [Phase 1](phase-01-app-detection.md) | AppCategoryDetector — classify app type | Pending | 1.5h |
| [Phase 2](phase-02-text-capture-engine.md) | TextCaptureEngine — layered capture | Pending | 4h |
| [Phase 3](phase-03-text-replacement-engine.md) | TextReplacementEngine — multi-strategy with verification | Pending | 4h |
| [Phase 4](phase-04-electron-support.md) | ElectronSpecialist — AXManualAccessibility + timing | Pending | 3h |
| [Phase 5](phase-05-integration.md) | Integration — update coordinator | Pending | 2h |
| [Phase 6](phase-06-testing-matrix.md) | Testing Matrix — comprehensive app coverage | Pending | 4-6h |

**Total Effort**: ~18-20 hours

## Files

### Create (4 new files)
- `TaskManager/Sources/TaskManager/Services/AppCategoryDetector.swift`
- `TaskManager/Sources/TaskManager/Services/TextCaptureEngine.swift`
- `TaskManager/Sources/TaskManager/Services/TextReplacementEngine.swift`
- `TaskManager/Sources/TaskManager/Services/ElectronSpecialist.swift`

### Modify (1 existing file)
- `TaskManager/Sources/TaskManager/Services/InlineEnhanceCoordinator.swift` — use new engines

### Deprecate
- `TaskManager/Sources/TaskManager/Services/TextFocusManager.swift` — replaced by new engines

## Key Decisions

1. **Layered Detection** — Try multiple strategies in order of reliability
2. **App Category Detection** — Optimize strategy based on app type
3. **Separate Capture/Replace Engines** — Single responsibility, testable independently
4. **Comprehensive Logging** — Debug mode to trace which strategy succeeds
5. **Graceful Degradation** — Always have fallback; never leave user stuck

## Testing Matrix

| App | Category | Capture | Replace | Notes |
|-----|----------|---------|---------|-------|
| Notes | Native | ✅ | ✅ | Baseline |
| Telegram | Native | ✅ | ✅ | Baseline |
| Safari | Browser | Phase 2 L3/L4 | Phase 3 S3 | Web content |
| Chrome | Browser | Phase 2 L3/L4 | Phase 3 S3/S4 | Web content |
| Firefox | Browser | Phase 2 L3/L4 | Phase 3 S3/S4 | Web content |
| Slack | Electron | Phase 2 L3 | Phase 3 S4 | AXManualAccessibility |
| VS Code | Electron | Phase 2 L3 | Phase 3 S4/S5 | Custom editor |
| Discord | Electron | Phase 2 L3 | Phase 3 S4 | AXManualAccessibility |
| Notion | Webview | Phase 2 L3/L4 | Phase 3 S4 | Contenteditable |
| Figma | Webview | Phase 2 L3 | Phase 3 S4/S5 | Canvas-based |

## Success Criteria

- [ ] Works in all 10+ tested apps from matrix
- [ ] Captures both selected text and full field content
- [ ] Replaces text without losing focus
- [ ] Falls back gracefully when AX fails
- [ ] Provides debug logging for troubleshooting
- [ ] No regression in currently working apps
- [ ] **Verification step confirms replacement success**
- [ ] **Clipboard restored synchronously (no race conditions)**

## Oracle Review Recommendations Applied

| Recommendation | Status |
|----------------|--------|
| Remove typing simulation (Strategy 5) | ✅ Applied |
| Add success verification after replacement | ✅ Applied |
| Increase child descent depth to 10-15 | ✅ To implement |
| Synchronous clipboard restore | ✅ To implement |
| Revised effort estimate (8h → 16-24h) | ✅ Applied |

## Out of Scope

- Rich text / formatting preservation
- Password fields (intentionally blocked)
- Canvas-based editors without AX support
- iOS/iPadOS version

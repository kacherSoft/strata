# Phase 6: Testing Matrix

**Goal**: Comprehensive testing across app types to validate all fixes.

**Time**: ~1 hour

---

## Overview

Systematic testing across different app categories to ensure the fix works universally.

## Test Categories

### 1. Native macOS Apps (Baseline)

| App | Field Type | Capture | Replace | Notes |
|-----|-----------|---------|---------|-------|
| Notes | TextArea | ✅ | ✅ | Should work already |
| TextEdit | TextArea | ✅ | ✅ | Should work already |
| Finder | Search | ✅ | ✅ | Search field |
| Safari (URL) | TextField | ✅ | ✅ | Address bar |
| Mail | TextArea | ✅ | ✅ | Compose window |
| Messages | TextArea | ✅ | ✅ | Message field |

### 2. Browsers (Target Fix)

| App | Field Type | Capture | Replace | Expected Layer/Strategy |
|-----|-----------|---------|---------|------------------------|
| Safari (web) | WebArea | ✅ | ✅ | L3/L4 → S3 or S4 |
| Chrome | WebArea | ✅ | ✅ | L3/L4 → S3 or S4 |
| Firefox | WebArea | ✅ | ✅ | L3/L4 → S3 or S4 |
| Edge | WebArea | ✅ | ✅ | L3/L4 → S3 or S4 |
| Brave | WebArea | ✅ | ✅ | L3/L4 → S3 or S4 |

**Test Sites:**
- Google search box
- Gmail compose
- Twitter/X tweet box
- GitHub comment field
- Notion page

### 3. Electron Apps (Target Fix)

| App | Field Type | Capture | Replace | Expected Layer/Strategy |
|-----|-----------|---------|---------|------------------------|
| Slack | WebArea | ✅ | ✅ | L3 → S4 |
| VS Code | Editor | ⚠️ | ⚠️ | May need S5 |
| Discord | WebArea | ✅ | ✅ | L3 → S4 |
| Spotify | Search | ✅ | ✅ | L3 → S4 |
| Postman | TextArea | ✅ | ✅ | L3 → S4 |

### 4. Webview Apps

| App | Field Type | Capture | Replace | Notes |
|-----|-----------|---------|---------|-------|
| Notion | ContentEdit | ✅ | ✅ | Contenteditable |
| Figma | Canvas | ⚠️ | ⚠️ | May not work |
| Linear | WebArea | ✅ | ✅ | Web-based |

### 5. Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Empty field | Show Enhance Me panel |
| Password field | Skip (no capture) |
| Read-only field | Skip or notify |
| Multi-monitor | HUD on correct screen |
| App switches during enhance | Abort with error |
| Very long text (>10KB) | Should still work |
| Unicode/emoji text | Should preserve |
| Rich text field | Convert to plain text |

## Test Script

```swift
// Manual test procedure
struct TestProcedure {
    // 1. Open target app
    // 2. Click on text field
    // 3. Type some text or select existing text
    // 4. Press ⌘⌥E
    // 5. Verify:
    //    - HUD appears
    //    - Text is captured (check debug log)
    //    - AI enhancement runs
    //    - Text is replaced in field
    //    - HUD shows success
}
```

## Debug Checklist

Enable debug mode and check logs for:

```
[TextCaptureEngine] App category: browser, PID: 12345
[TextCaptureEngine] Layer 1: Trying direct capture
[TextCaptureEngine] Layer 3: Trying child descent
[TextCaptureEngine] Layer 3: Found text element in children
[TextCaptureEngine] Layer 4: Extracted selection via range
[TextReplacementEngine] Trying strategy: rangeBasedUpdate
[TextReplacementEngine] Strategy rangeBasedUpdate succeeded
```

## Failure Investigation

If a test fails:

1. **Capture fails**: Check which layer returned nil
   - Enable debug logging
   - Run with `/tmp/test_ax` to inspect element attributes
   
2. **Replace fails**: Check which strategy failed
   - Check if attribute is settable
   - Try clipboard fallback manually (⌘A, ⌘V)
   
3. **Electron specific**: Check AX flags
   - Verify `AXManualAccessibility` is set
   - Try increasing delay

## Test Report Template

```markdown
## Test Report: [Date]

### Environment
- macOS: [version]
- App Version: [version]
- Debug Mode: [on/off]

### Results Summary
| App | Capture | Replace | Method | Notes |
|-----|---------|---------|--------|-------|
| Notes | ✅ | ✅ | directValue | - |
| Chrome | ✅ | ✅ | rangeBased | - |
| Slack | ✅ | ✅ | clipboard | - |

### Issues Found
1. [Description]
   - Steps to reproduce
   - Expected vs actual
   - Debug log excerpt

### Recommendations
- [Action items]
```

## Acceptance Criteria

- [ ] All 6 native apps pass
- [ ] At least 4/5 browsers pass
- [ ] At least 3/4 Electron apps pass
- [ ] No regression in previously working apps
- [ ] Debug logging reveals capture/replace path
- [ ] Edge cases handled gracefully

## Sign-off

After all tests pass:
1. Update plan.md with final status
2. Commit changes
3. Create PR or merge to main

## Dependencies

- [Phase 5: Integration](phase-05-integration.md)

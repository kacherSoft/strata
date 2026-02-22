# Phase 6: Testing

## Context Links
- Parent: [plan.md](plan.md)
- Depends on: All previous phases

## Overview
| Property | Value |
|----------|-------|
| Priority | P1 |
| Status | Pending |
| Effort | 1.5-2h |

Comprehensive manual testing of the system-wide inline enhancement across multiple applications and edge cases.

## Requirements

### Prerequisites
- App built successfully on `feature/inline-enhance-system-wide` branch
- Accessibility permission granted in System Settings
- At least one AI mode configured with valid API key

### Test Categories
1. Permission flow
2. Happy path (text enhancement in other apps)
3. Selection vs no selection
4. Different applications (native, web, Electron)
5. Error scenarios
6. Fallback behavior
7. Settings UI
8. Edge cases

## Test Matrix

### 1. Permission Flow

| Step | Action | Expected |
|------|--------|----------|
| 1 | Launch app (no Accessibility permission) | Settings shows "Accessibility Required" with "Grant Access" |
| 2 | Press ⌘⌥E | System prompt appears OR permission request prompt |
| 3 | Click "Grant Access" in Settings | System Settings opens to Accessibility pane |
| 4 | Toggle app ON in System Settings | App detects permission within ~2-4 seconds |
| 5 | Settings updates | Shows "Accessibility Enabled" with green checkmark |

### 2. Happy Path — Text Enhancement

| App | Field Type | Test |
|-----|-----------|------|
| **TextEdit** | NSTextView | Type "helo wrold", select all, press ⌘⌥E |
| **Notes.app** | NSTextView | Type text, select portion, press ⌘⌥E |
| **Safari** | Web form input | Navigate to any form, type text, press ⌘⌥E |
| **Strata (own app)** | Task title field | Type text, press ⌘⌥E |
| **Strata (own app)** | Task notes field | Type text, press ⌘⌥E |

For each:
- [ ] HUD appears near the text field
- [ ] HUD shows "Enhancing with [mode]..."
- [ ] Text is replaced after AI responds
- [ ] HUD shows ✓ "Enhanced" then auto-dismisses (~1s)

### 3. Selection Scenarios

| Scenario | Input | Expected |
|----------|-------|----------|
| Text selected | "Hello **world**" (world selected) | Only "world" enhanced |
| No selection, cursor in field | "Hello world" (cursor at end) | Full text enhanced |
| Empty field | "" (empty) | Fallback to Enhance Me panel |
| All text selected | "Hello world" (⌘A) | Full text enhanced |

### 4. Cross-App Testing

| App | AX Support | Expected Behavior |
|-----|-----------|-------------------|
| **TextEdit** | ✅ Full | Works perfectly |
| **Notes.app** | ✅ Full | Works perfectly |
| **Safari** (URL bar) | ✅ Full | Works |
| **Safari** (web form) | ⚠️ Varies | May work for standard inputs |
| **Mail.app** (compose) | ✅ Full | Works |
| **VS Code** | ⚠️ Electron | May not expose AX text attributes |
| **Slack** | ⚠️ Electron | May not expose AX text attributes |
| **Terminal.app** | ⚠️ Limited | Terminal emulators have custom text handling |

Document actual behavior for each in results.

### 5. AI Mode Testing

| Mode | Test Input | Expected |
|------|-----------|----------|
| Correct Me | "helo wrold, this is tset" | Grammar/spelling corrected |
| Enhance Prompt | Rough draft idea | Detailed prompt returned |
| Custom modes | Various | Mode-specific behavior |

### 6. Error Scenarios

| Scenario | Expected |
|----------|----------|
| No AI mode configured | Error HUD: "No AI mode configured" (3s dismiss) |
| Network disconnected | Error HUD with network error message (3s dismiss) |
| Invalid API key | Error HUD with auth error (3s dismiss) |
| AI provider timeout | Error HUD with timeout message (3s dismiss) |

### 7. Fallback Behavior

| Scenario | Expected |
|----------|----------|
| Click on desktop (no text field), press ⌘⌥E | Enhance Me panel opens |
| Click on Finder icon view, press ⌘⌥E | Enhance Me panel opens |
| Focus non-text UI element, press ⌘⌥E | Enhance Me panel opens |

### 8. Settings Testing

| Test | Expected |
|------|----------|
| Open Settings → Shortcuts | "Inline Enhance" visible in Global Shortcuts |
| Change shortcut to ⌘⌥I | New shortcut works, ⌘⌥E no longer works |
| Click "Reset All to Defaults" | Shortcut resets to ⌘⌥E |
| Open Settings → General | Accessibility status visible |

### 9. Edge Cases

| Case | Expected |
|------|----------|
| Very long text (1000+ chars) | Enhancement may take longer; HUD stays visible |
| Special characters (emoji, CJK, RTL) | Replaced correctly |
| Rapid double-press ⌘⌥E | First enhancement completes; second doesn't duplicate |
| Press ⌘⌥E during enhancement | No crash; existing enhancement continues |
| Multi-monitor setup | HUD appears on correct screen near text field |
| Full-screen app | HUD appears over full-screen app |

## Build Verification

```bash
cd /Volumes/OCW-2TB/LocalProjects/TaskManager/TaskManager
swift build
```

Expected: compiles without errors or warnings related to new files.

## Bug Report Template

If issues found, document:
```
**App**: [TextEdit/Safari/etc]
**Field Type**: [text area/text field/search/etc]
**Selection**: [yes/no/partial text]
**AI Mode**: [Correct Me/Enhance Prompt/etc]
**Expected**: [what should happen]
**Actual**: [what happened]
**HUD Behavior**: [appeared/didn't appear/wrong position/etc]
**Steps to reproduce**:
1. ...
2. ...
```

## Final Checklist

Before marking feature complete:
- [ ] Build compiles without errors
- [ ] Permission flow works end-to-end
- [ ] Enhancement works in at least 3 native macOS apps
- [ ] HUD appears, shows progress, auto-dismisses
- [ ] Text replacement works (selected + full text)
- [ ] Fallback to panel works
- [ ] Error states display properly
- [ ] Settings UI complete (shortcut + Accessibility status)
- [ ] No console errors or crashes
- [ ] HUD animations feel smooth and native
- [ ] Known limitations documented

## Sign-off

After all tests pass, update [plan.md](plan.md) status to `complete`.

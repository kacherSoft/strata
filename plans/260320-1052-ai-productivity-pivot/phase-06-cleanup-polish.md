# Phase 6: Cleanup & Polish

**Priority:** Medium | **Effort:** Small | **Status:** Pending
**Depends on:** All previous phases

---

## Context Links
- [Plan Overview](plan.md)
- Code review: `plans/reports/code-reviewer-260319-2150-chat-mode-full-review.md`

---

## Overview

Address remaining code review issues, delete dead code, update docs, and polish UX before merging to main.

---

## Tasks

### Dead Code Removal
- [ ] Delete `SessionRow.swift` (unused — ChatSessionListView has inline row)
- [ ] Delete `StopGenerationButton.swift` (unused — ChatInputView has inline stop)
- [ ] Remove `StrataMigrationPlan` if not using `migrationPlan:` parameter
- [ ] Remove old `AIConfigSettingsView.swift` (replaced by AIProvidersSettingsView)

### Code Quality Fixes from Review
- [ ] Fix H2: Set `streamTask` before creating Task (race condition)
- [ ] Fix H3: Implement conversation history sliding window (last 50 messages or 32K tokens)
- [ ] Fix H4: `providerFor(.openai)` — throw `AIError.notConfigured` instead of falling back to z.ai
- [ ] Fix H5: Clean up temp files in `StrataChatAttachments/` on app launch
- [ ] Fix M4: Apply provider repair pattern to `ChatSessionModel.provider` getter
- [ ] Fix M7: Log errors in repository catch blocks instead of swallowing
- [ ] Fix M8: Replace hardcoded dark colors with semantic `Color(nsColor:)` values

### Documentation Updates
- [ ] Update `docs/system-architecture.md` — new provider model, chat as primary
- [ ] Update `docs/project-changelog.md` — Chat Mode, Settings redesign, provider system
- [ ] Update `docs/codebase-summary.md` — new file listing, updated LOC counts
- [ ] Update `README.md` — app description pivot

### Polish
- [ ] Add Escape key handler to close Task panel
- [ ] Add keyboard shortcut hint in menu bar for "Show Tasks"
- [ ] Chat sidebar: show model name under session title (subtle, secondary text)
- [ ] Settings: add "Reset to Defaults" for each section
- [ ] Test light mode — verify all Chat UI colors work

---

## Success Criteria

- [ ] No dead code files remain
- [ ] All Critical/High review issues resolved
- [ ] Documentation reflects new architecture
- [ ] Light mode and dark mode both look correct
- [ ] Clean git diff — no commented-out code or TODO markers

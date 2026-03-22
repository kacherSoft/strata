# Code Review: Chat Attachment Fixes & EnhanceMe Comparison

**Date:** 2026-03-18 | **Scope:** ChatAttachmentHelper, ChatTextInput rewrite, ChatInputView/ChatView DRY refactor

## Build Status
- **ARCHIVE SUCCEEDED** — all changes compile clean

## What Changed

| File | Change |
|------|--------|
| `ChatAttachmentHelper.swift` | **NEW** — shared helper enum (DRY extraction) |
| `ChatTextInput.swift` | **REWRITTEN** — 8 drag types, paste interception, uses helper |
| `ChatInputView.swift` | **REFACTORED** — `addAttachment` now delegates to helper, removed duplicate `handleDrop` |
| `ChatView.swift` | **REFACTORED** — `addAttachmentFromURL` delegates to helper, removed duplicate code |

## Improvements Over Previous Version

1. **Drag types**: 1 → 8 types registered (matches EnhanceMe)
2. **Paste support**: Added — handles Cmd+V for screenshots (TIFF→PNG), copied images, PDFs
3. **HEIC support**: Added (was missing)
4. **DRY**: `addAttachment` logic centralized in `ChatAttachmentHelper.makeAttachment()`
5. **Temp directory**: `StrataChatAttachments` for pasted image/screenshot data
6. **TIFF→PNG conversion**: Via `NSBitmapImageRep` (matches EnhanceMe pattern)

## Issues Found

### Critical (0)
None — all critical drag/drop issues from previous review are now addressed.

### High (2)

**H1. `paste()` intercepts text-with-file-URL-in-clipboard incorrectly**
- `hasAttachableContent()` checks for `.fileURL` presence in pasteboard types
- macOS often has `.fileURL` type even for plain text copies from Finder path bar
- If `fileURLs()` returns empty AND `savePastedImageData()` returns nil, it falls through correctly
- **Verdict:** Actually safe — the fallthrough to `super.paste()` handles this. Low risk.

**H2. SwiftUI `onDrop` on ChatInputView still uses inline `loadItem` instead of helper**
- Lines 68-82 in ChatInputView have a reimplemented drop handler
- Should delegate to a helper method or share with ChatView's `handleFileDrop`
- Minor DRY violation remains — but both call `addAttachment(from:)` which uses the helper
- **Impact:** Cosmetic duplication, not a bug

### Medium (3)

**M1. No temp file cleanup for pasted attachments**
- `savePastedImageData()` writes to `~/tmp/StrataChatAttachments/` but never cleans up
- EnhanceMe has `cleanupAttachments()` called on dismiss and mode change
- **Recommendation:** Add cleanup on ChatView disappear or session delete

**M2. Session sort uses `.distantFuture` for nil `lastMessageAt` — fragile**
- `ChatSessionRepository.fetchAll()` sorts nil dates as `.distantFuture` to push "New Chat" to top
- Works correctly but semantically odd — a session with no messages shouldn't be "in the future"
- **Verdict:** Functional, revisit if sort behavior changes

**M3. `fileURLs()` filter may reject valid non-file URLs from drag**
- `urls.filter { $0.isFileURL && supportedExtensions.contains(...) }` — correct for file drops
- But `.URL` type registered may produce non-file URLs that are silently dropped
- **Verdict:** Safe — non-file URLs should be ignored for attachment purposes

### Low (2)

**L1. `ChatAttachmentHelper.dragTypes` includes `"public.file-url"` which may duplicate `.fileURL`**
- `.fileURL` is already `"public.file-url"` in most contexts
- Registering both is harmless (NSTextView deduplicates)

**L2. No user feedback when attachment rejected (too large, wrong type, max count)**
- `makeAttachment()` silently returns nil — user gets no error message
- EnhanceMe shows error text for rejections
- **Recommendation:** Add optional error callback to surface rejection reasons

## EnhanceMe vs Chat Comparison

| Feature | EnhanceMe | Chat (After Fix) |
|---------|-----------|-------------------|
| Drag types registered | 8 | 8 ✅ |
| Paste support (Cmd+V) | Yes | Yes ✅ |
| TIFF→PNG conversion | Yes | Yes ✅ |
| HEIC support | Yes | Yes ✅ |
| Temp directory | `EnhanceMeAttachments` | `StrataChatAttachments` ✅ |
| Temp cleanup | On dismiss/mode change | **Missing** ⚠️ |
| Error feedback | Shows error text | Silent rejection ⚠️ |
| Provider capability gate | Checks `supportsAnyAttachments` | Checks `supportsAttachments` ✅ |
| `readObjects` for URLs | No (uses `handleFileURL`) | Yes ✅ |
| Max attachments | 4 | 4 ✅ |
| Max file size | 10 MB | 10 MB ✅ |

## Verdict
**PASS** — The attachment implementation now matches EnhanceMe's capability surface. The two medium items (temp cleanup, error feedback) are polish issues, not blockers. Build compiles clean.

## Unresolved Questions
1. Should `ChatAttachmentHelper` be shared with EnhanceMe to further reduce duplication? (Currently they use separate but parallel implementations)
2. Should temp file cleanup be session-scoped or app-wide on quit?

# Phase 7 — Integration & Polish

## Context
- [plan.md](plan.md)
- [ShortcutNames.swift](../../TaskManager/Sources/TaskManager/Shortcuts/ShortcutNames.swift)
- [TaskManagerApp.swift](../../TaskManager/Sources/TaskManager/TaskManagerApp.swift)

## Overview
- **Priority:** P3
- **Status:** pending
- **Effort:** 1h
- **Depends on:** Phases 1-6

Register global keyboard shortcut, add menu bar item, wire up settings for chat defaults, and run final build verification.

## Key Insights

- `KeyboardShortcuts` package already used for QuickEntry, EnhanceMe, MainWindow, InlineEnhanceMe. Adding `.chatWindow` follows the exact same pattern.
- App menu bar likely has an "AI" or "Window" menu — add "Chat" item there.
- Settings page for AI modes already exists. Chat-specific settings (default model for chat) can piggyback on the existing AI mode system — the "Chat" built-in mode's provider/model IS the chat default. No separate settings page needed (YAGNI).

## Modified Files

### `Shortcuts/ShortcutNames.swift`

Add chat window shortcut name:

```swift
extension KeyboardShortcuts.Name {
    // ... existing shortcuts ...
    static let chatWindow = Self("chatWindow")  // NEW
}
```

### `TaskManagerApp.swift` (or wherever shortcuts are registered)

Add shortcut listener for chat window — follow existing pattern for `enhanceMe`:

```swift
KeyboardShortcuts.onKeyUp(for: .chatWindow) { [weak windowManager] in
    windowManager?.showChat()
}
```

### Menu Bar Integration

Add "Chat" command to the app menu. Find existing `.commands` modifier or menu bar setup:

```swift
// In the commands block (CommandMenu or CommandGroup)
Button("Open Chat") {
    WindowManager.shared.showChat()
}
.keyboardShortcut("j", modifiers: [.command, .option])  // ⌘⌥J — distinct from existing shortcuts
```

**Default shortcut: ⌘⌥J** — chosen to avoid conflicts with:
- ⌘⌥E = EnhanceMe
- ⌘⌥Q = QuickEntry (or system)
- ⌘⌥N = various system uses

User can reconfigure via KeyboardShortcuts settings.

### Settings — Shortcuts Tab

Add `.chatWindow` to the shortcuts settings list. Reference `ShortcutsSettingsView.swift`:

```swift
// Add to the shortcut configuration list
ShortcutRow(name: .chatWindow, label: "Chat Window", icon: "bubble.left.and.bubble.right")
```

No separate "Chat Settings" page needed — the built-in "Chat" AI mode's configuration (provider, model, system prompt) in the existing AI Modes settings IS the chat configuration.

## Final Build Verification Checklist

Run after all phases are integrated:

1. `cd TaskManager && ./scripts/build-debug.sh` — must compile clean
2. Launch app with existing V1 store — verify V2 migration succeeds
3. Verify "Chat" mode appears in AI modes list
4. Open Chat window via menu and via shortcut
5. Open EnhanceMe — verify chat window stays open (coexistence)
6. Open QuickEntry — verify chat window stays open
7. Create new chat session
8. Send a message — verify streaming response
9. Check auto-title after first message
10. Rename and delete sessions
11. Attach a file (Gemini only) and send
12. Stop generation mid-stream
13. Copy an assistant message
14. Scroll up during streaming — verify auto-scroll stops
15. Close and reopen chat — verify sessions persist

## Implementation Steps

1. Add `.chatWindow` to `ShortcutNames.swift`
2. Register shortcut listener in app startup
3. Add menu bar command for Chat
4. Add shortcut row in Settings > Shortcuts
5. Run full build
6. Run through verification checklist

## Todo

- [ ] Shortcut name registration
- [ ] Shortcut listener wiring
- [ ] Menu bar "Open Chat" command
- [ ] Settings shortcuts row
- [ ] Debug build passes
- [ ] Manual verification checklist (15 items above)

## Success Criteria

- Global shortcut opens/focuses chat window from anywhere
- Menu bar has "Chat" item with shortcut hint
- Shortcut is configurable in Settings
- Debug build compiles with zero errors
- All 15 verification items pass

## Risk Assessment

- **Shortcut conflict** — ⌘⌥J is unlikely to conflict, but verify against system and other app shortcuts during testing.
- **Menu bar structure** — Need to read `TaskManagerApp.swift` to find the exact commands structure. If no commands block exists, add one.

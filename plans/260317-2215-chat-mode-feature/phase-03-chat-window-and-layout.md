# Phase 3 — Chat Window & Layout

## Context
- [plan.md](plan.md)
- [EnhanceMePanel.swift](../../TaskManager/Sources/TaskManager/Windows/EnhanceMePanel.swift)
- [WindowManager.swift](../../TaskManager/Sources/TaskManager/Windows/WindowManager.swift)
- [View+AppEnvironment.swift](../../TaskManager/Sources/TaskManager/Extensions/View+AppEnvironment.swift)

## Overview
- **Priority:** P1 (blocks phases 4, 5, 6)
- **Status:** pending
- **Effort:** 3h
- **Depends on:** Phase 1 (data models)

Create the ChatPanel (NSPanel), integrate it into WindowManager as a non-mutually-exclusive window, and build the main ChatView layout with sidebar + message area + input placeholder.

## Key Insights

- EnhanceMePanel pattern: NSPanel subclass, `setContent()` with NSHostingView, `.withAppEnvironment(container:)`.
- Chat panel should NOT be mutually exclusive — `showChat()` must NOT call `closeAllFloatingWindows()`.
- WindowManager.dismissVisibleFloatingWindow() needs to include chat panel.
- Chat window is larger than EnhanceMe: default 900x600, min 700x500, max 1400x900.
- Sidebar width: 240px fixed, collapsible.

## New Files

### `Windows/ChatPanel.swift`

```swift
import AppKit
import SwiftUI

final class ChatPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        title = "Strata Chat"
        isFloatingPanel = false
        level = .normal
        collectionBehavior = [.fullScreenAuxiliary]
        isMovableByWindowBackground = false  // has sidebar, dragging would conflict
        hidesOnDeactivate = false

        minSize = NSSize(width: 700, height: 500)
        maxSize = NSSize(width: 1400, height: 900)
    }

    func setContent<V: View>(_ view: V) {
        contentView = NSHostingView(rootView: view)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

**Follows EnhanceMePanel exactly** — same pattern, different dimensions and title.

### `Views/Chat/ChatView.swift`

Main container view — sidebar + message area.

```swift
import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var chatService = ChatService()
    @State private var selectedSessionId: UUID?
    @State private var isSidebarVisible = true

    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if isSidebarVisible {
                ChatSessionListView(
                    selectedSessionId: $selectedSessionId,
                    onNewChat: { createNewSession() }
                )
                .frame(width: 240)

                Divider()
            }

            // Main content area
            VStack(spacing: 0) {
                // Toolbar
                chatToolbar

                // Messages + input
                if let sessionId = selectedSessionId {
                    chatContent(sessionId: sessionId)
                } else {
                    ChatEmptyStateView(onNewChat: { createNewSession() })
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color(hex: "#0A0E17"))
    }
}
```

**Subview breakdown (keeps each under ~50 lines):**
- `chatToolbar` — computed property with sidebar toggle, session title, close button
- `chatContent(sessionId:)` — messages list + input area (delegates to Phase 4 & 5 views)

### `Views/Chat/ChatEmptyStateView.swift`

Shown when no session is selected or no sessions exist.

```swift
struct ChatEmptyStateView: View {
    let onNewChat: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Start a conversation")
                .font(.title2)
                .foregroundStyle(.primary)

            Text("Ask questions, get help, or just chat with AI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("New Chat") { onNewChat() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

## Modified Files

### `Windows/WindowManager.swift`

Add chat panel management — NOT mutually exclusive with other windows:

```swift
// Add property
private var chatPanel: ChatPanel?

// Add methods
func showChat() {
    // NOTE: intentionally does NOT call closeAllFloatingWindows()
    if chatPanel == nil {
        chatPanel = ChatPanel()
    }

    guard let panel = chatPanel, let container = modelContainer else { return }

    let view = ChatView(
        onDismiss: { [weak self] in self?.hideChat() }
    )
    .withAppEnvironment(container: container)

    panel.collectionBehavior.insert(.moveToActiveSpace)
    panel.setContent(view)
    panel.center()

    if !panel.isVisible || !panel.isOnActiveSpace {
        panel.orderOut(nil)
    }
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

func hideChat() {
    chatPanel?.orderOut(nil)
}
```

Also update `dismissVisibleFloatingWindow()` to include chat:

```swift
func dismissVisibleFloatingWindow() -> Bool {
    // ... existing checks ...
    if let panel = chatPanel, panel.isVisible {
        hideChat()
        return true
    }
    return false
}
```

**Important:** Do NOT add `hideChat()` to `closeAllFloatingWindows()`. Chat window persists independently.

## Architecture — Window Coexistence

```
┌──────────────────────────────────────────┐
│ WindowManager                            │
│                                          │
│  Mutually exclusive group:               │
│    quickEntryPanel ─┐                    │
│    settingsWindow  ─┤ closeAllFloating() │
│    enhanceMePanel  ─┘                    │
│                                          │
│  Independent:                            │
│    chatPanel ──── NOT in the group       │
│                                          │
│  dismissVisibleFloatingWindow():         │
│    checks ALL panels including chat      │
└──────────────────────────────────────────┘
```

## Implementation Steps

1. Create `ChatPanel.swift` (NSPanel subclass)
2. Create `ChatEmptyStateView.swift`
3. Create `ChatView.swift` with sidebar + content layout
4. Update `WindowManager.swift` — add chatPanel property, showChat(), hideChat()
5. Update `dismissVisibleFloatingWindow()` to include chat panel
6. Build and verify compile
7. Manual test: open chat window, verify it coexists with EnhanceMe

## Todo

- [ ] ChatPanel NSPanel subclass
- [ ] ChatEmptyStateView
- [ ] ChatView main layout (sidebar + content area)
- [ ] WindowManager.showChat() / hideChat()
- [ ] Verify non-mutually-exclusive behavior
- [ ] Build verification

## Success Criteria

- Chat window opens and displays empty state
- Chat window can coexist with EnhanceMe (both visible simultaneously)
- Opening QuickEntry/Settings/EnhanceMe does NOT close chat
- Sidebar toggle works
- Window respects min/max size constraints
- `.withAppEnvironment(container:)` provides SwiftData context

## Risk Assessment

- **NSPanel focus conflicts** — Two panels visible simultaneously may compete for key status. Each panel has `canBecomeKey: true` — clicking either should make it key. Test this.
- **Memory** — Chat panel is retained by WindowManager like other panels. `orderOut(nil)` hides but doesn't deallocate. Acceptable for a single instance.

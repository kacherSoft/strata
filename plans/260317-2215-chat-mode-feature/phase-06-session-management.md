# Phase 6 — Session Management

## Context
- [plan.md](plan.md)
- [phase-01-data-models-and-schema.md](phase-01-data-models-and-schema.md)
- [phase-03-chat-window-and-layout.md](phase-03-chat-window-and-layout.md)

## Overview
- **Priority:** P2
- **Status:** pending
- **Effort:** 2h
- **Depends on:** Phase 1 (data models), Phase 3 (sidebar layout)

Build the sidebar session list: create new sessions, rename, delete, search/filter, auto-title generation, and empty state handling.

## Key Insights

- Sidebar was scaffolded in Phase 3 as `ChatSessionListView` placeholder. This phase implements it fully.
- Sessions sorted by `lastMessageAt` descending (most recent first). Nil `lastMessageAt` = new empty session, sort to top.
- Auto-title: use first user message, truncated to 50 chars. AI-generated title is YAGNI for v1 — adds latency, API cost, complexity.
- Context menu on session row: Rename, Delete. SwiftUI `.contextMenu` handles this natively.

## New/Modified Files

### `Views/Chat/ChatSessionListView.swift` (new, scaffolded in Phase 3)

```swift
struct ChatSessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedSessionId: UUID?
    let onNewChat: () -> Void

    @State private var searchText = ""
    @State private var sessions: [ChatSessionModel] = []
    @State private var editingSessionId: UUID?
    @State private var editingTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with new chat button
            sidebarHeader

            // Search field
            if sessions.count > 5 {
                searchField
            }

            // Session list
            if filteredSessions.isEmpty {
                sidebarEmptyState
            } else {
                sessionList
            }
        }
        .background(Color(hex: "#111827"))
        .onAppear { loadSessions() }
    }

    private var filteredSessions: [ChatSessionModel] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }
}
```

**Subviews (computed properties, each <30 lines):**

#### `sidebarHeader`
```swift
private var sidebarHeader: some View {
    HStack {
        Text("Chats")
            .font(.headline)
            .foregroundStyle(.primary)
        Spacer()
        Button(action: onNewChat) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .help("New Chat (⌘N)")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
}
```

#### `searchField`
```swift
private var searchField: some View {
    HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextField("Search chats...", text: $searchText)
            .textFieldStyle(.plain)
            .font(.caption)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(Color(hex: "#1F2937"))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
}
```

#### `sessionList`
```swift
private var sessionList: some View {
    List(filteredSessions, selection: $selectedSessionId) { session in
        SessionRow(
            session: session,
            isEditing: editingSessionId == session.id,
            editingTitle: $editingTitle,
            onCommitRename: { commitRename(session) },
            onCancelRename: { editingSessionId = nil }
        )
        .tag(session.id)
        .contextMenu {
            Button("Rename") { startRename(session) }
            Divider()
            Button("Delete", role: .destructive) { deleteSession(session) }
        }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
}
```

### `Views/Chat/SessionRow.swift` (new)

Individual row in the session list.

```swift
struct SessionRow: View {
    let session: ChatSessionModel
    let isEditing: Bool
    @Binding var editingTitle: String
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void

    var body: some View {
        if isEditing {
            TextField("Chat title", text: $editingTitle, onCommit: onCommitRename)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .onExitCommand(perform: onCancelRename)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let lastMessage = session.lastMessageAt {
                    Text(lastMessage, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
```

## Session Operations

Implemented as methods on `ChatSessionListView` or extracted to a helper:

### Create New Session
```swift
func createNewSession() {
    let repo = ChatSessionRepository(modelContext: modelContext)
    let session = repo.create(
        title: "New Chat",
        provider: currentProvider,  // from active AI mode or default
        modelName: currentModelName,
        aiModeId: chatModeId
    )
    selectedSessionId = session.id
    loadSessions()
}
```

### Auto-Title on First Message
```swift
/// Called after first user message is sent in a session
func autoTitle(session: ChatSessionModel, firstMessage: String) {
    let title = String(firstMessage.prefix(50))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if title.count == 50 {
        session.title = title + "..."
    } else {
        session.title = title
    }
    session.touch()
    // saveContext via repository
}
```

**Why not AI-generated titles:** Adds an extra API call per conversation start, introduces latency, consumes tokens. First-message truncation is instant and free. Can add AI titles later if users want.

### Rename
```swift
func startRename(_ session: ChatSessionModel) {
    editingSessionId = session.id
    editingTitle = session.title
}

func commitRename(_ session: ChatSessionModel) {
    let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        editingSessionId = nil
        return
    }
    session.title = trimmed
    session.touch()
    editingSessionId = nil
    // saveContext via repository
}
```

### Delete
```swift
func deleteSession(_ session: ChatSessionModel) {
    let repo = ChatSessionRepository(modelContext: modelContext)
    let wasSelected = selectedSessionId == session.id
    repo.delete(session)  // cascades to messages
    loadSessions()
    if wasSelected {
        selectedSessionId = sessions.first?.id
    }
}
```

### Load Sessions
```swift
func loadSessions() {
    let repo = ChatSessionRepository(modelContext: modelContext)
    do {
        sessions = try repo.fetchAll()  // sorted by lastMessageAt desc
    } catch {
        sessions = []
    }
}
```

## Data Flow

```
ChatView
  ├── selectedSessionId: UUID? (State)
  ├── ChatSessionListView
  │     ├── reads sessions from repository
  │     ├── writes: create, rename, delete
  │     └── binds selectedSessionId
  └── chatContent(sessionId:)
        ├── reads messages for selectedSessionId
        ├── on send: creates ChatMessageModel, updates lastMessageAt
        └── on first message: calls autoTitle()
```

## Implementation Steps

1. Create `SessionRow.swift`
2. Implement `ChatSessionListView.swift` fully (header, search, list, context menu)
3. Implement session operations (create, rename, delete, auto-title)
4. Wire `loadSessions()` to refresh on create/delete/rename
5. Connect session selection to ChatView message display
6. Build and verify compile
7. Manual test: create sessions, rename, delete, search, auto-title

## Todo

- [ ] SessionRow with inline rename
- [ ] ChatSessionListView with search and context menu
- [ ] Create new session
- [ ] Auto-title from first message
- [ ] Rename via context menu
- [ ] Delete with cascade confirmation
- [ ] Selection syncs to message display
- [ ] Build verification

## Success Criteria

- New Chat creates a session and selects it
- First user message auto-sets session title (truncated to 50 chars)
- Right-click context menu shows Rename and Delete
- Inline rename commits on Enter, cancels on Escape
- Delete removes session and all messages (cascade)
- Search filters session list by title
- Search field only appears when >5 sessions (reduce clutter)
- Selecting a session loads its messages in the main area

## Risk Assessment

- **List selection binding** — SwiftUI `List(selection:)` with `@Binding` can be finicky. If issues arise, fall back to manual selection state with `onTapGesture`.
- **Refresh timing** — After create/delete, `loadSessions()` must run before UI updates. Since everything is `@MainActor`, this is synchronous and safe.

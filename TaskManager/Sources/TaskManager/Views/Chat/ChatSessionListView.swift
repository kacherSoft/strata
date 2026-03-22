import SwiftUI
import SwiftData

/// Sidebar session list — native macOS sidebar matching main app design.
/// Vibrancy provided by NavigationSplitView in ChatView.
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
            if sessions.count > 5 {
                searchField
            }

            sessionList
        }
        .onAppear { loadSessions() }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Search chats...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// Session list with "+ New session" at top, then date-grouped sessions
    private var sessionList: some View {
        List(selection: $selectedSessionId) {
            // "+ New session" button at top of sidebar, above date sections
            Button(action: { onNewChat(); loadSessions() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("New session")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if filteredSessions.isEmpty {
                Text(searchText.isEmpty ? "No chats yet" : "No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let grouped = groupedByDate(filteredSessions)

                ForEach(grouped, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.sessions) { session in
                            sessionRowContent(session)
                                .tag(session.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sessionRowContent(_ session: ChatSessionModel) -> some View {
        Group {
            if editingSessionId == session.id {
                TextField("Chat title", text: $editingTitle, onCommit: { commitRename(session) })
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onExitCommand { editingSessionId = nil }
            } else {
                Text(session.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button("Rename") { startRename(session) }
            Divider()
            Button("Delete", role: .destructive) { deleteSession(session) }
        }
    }

    // MARK: - Date Grouping

    private struct SessionGroup {
        let title: String
        let sessions: [ChatSessionModel]
    }

    private func groupedByDate(_ sessions: [ChatSessionModel]) -> [SessionGroup] {
        let calendar = Calendar.current

        var today: [ChatSessionModel] = []
        var yesterday: [ChatSessionModel] = []
        var older: [ChatSessionModel] = []

        for session in sessions {
            let date = session.lastMessageAt ?? session.createdAt
            if calendar.isDateInToday(date) {
                today.append(session)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(session)
            } else {
                older.append(session)
            }
        }

        var groups: [SessionGroup] = []
        if !today.isEmpty { groups.append(SessionGroup(title: "Today", sessions: today)) }
        if !yesterday.isEmpty { groups.append(SessionGroup(title: "Yesterday", sessions: yesterday)) }
        if !older.isEmpty { groups.append(SessionGroup(title: "Older", sessions: older)) }
        return groups
    }

    // MARK: - Computed

    private var filteredSessions: [ChatSessionModel] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Operations

    func loadSessions() {
        let repo = ChatSessionRepository(modelContext: modelContext)
        do { sessions = try repo.fetchAll() } catch { sessions = [] }
    }

    private func startRename(_ session: ChatSessionModel) {
        editingSessionId = session.id
        editingTitle = session.title
    }

    private func commitRename(_ session: ChatSessionModel) {
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { editingSessionId = nil; return }
        session.title = trimmed
        session.touch()
        do { try modelContext.save() } catch {}
        editingSessionId = nil
        loadSessions()
    }

    private func deleteSession(_ session: ChatSessionModel) {
        let repo = ChatSessionRepository(modelContext: modelContext)
        let wasSelected = selectedSessionId == session.id
        repo.delete(session)
        loadSessions()
        if wasSelected {
            selectedSessionId = sessions.first?.id
        }
    }
}

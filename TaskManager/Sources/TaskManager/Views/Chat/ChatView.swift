import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Main chat container using NavigationSplitView for native macOS sidebar vibrancy.
/// This matches the main app's ContentView pattern (NavigationSplitView + .listStyle(.sidebar)).
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var chatService = ChatService()
    @State private var selectedSessionId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sessions: [ChatSessionModel] = []
    @State private var messages: [ChatMessageModel] = []
    @State private var inputText = ""
    @State private var attachments: [AIAttachment] = []
    @State private var errorMessage: String?
    @State private var selectedProviderId: UUID?
    @State private var selectedModelName: String = ""

    /// Reference to sidebar for triggering reloads after ChatView-level operations
    @State private var sidebarKey = UUID()

    let onDismiss: () -> Void

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar — native macOS vibrancy handled by NavigationSplitView
            ChatSessionListView(
                selectedSessionId: $selectedSessionId,
                onNewChat: { createNewSession() }
            )
            .id(sidebarKey)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            VStack(spacing: 0) {
                chatContentArea
            }
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                handleFileDrop(providers)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { ensureSessionExists() }
        .onDisappear { chatService.cancelStream() }
        .onChange(of: selectedSessionId) { _, newValue in
            if let id = newValue { loadMessages(for: id) }
            else { messages = [] }
        }
    }

    // MARK: - Chat Content Area

    private var chatContentArea: some View {
        VStack(spacing: 0) {
            if messages.isEmpty && !chatService.isStreaming {
                ChatEmptyStateView()
            } else {
                ChatMessageListView(
                    messages: messages,
                    streamingText: chatService.currentStreamText,
                    isStreaming: chatService.isStreaming,
                    onCopy: { copyToClipboard($0) },
                    onStopGeneration: { chatService.cancelStream() }
                )
            }

            // Error banner
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { errorMessage = nil }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            ChatInputView(
                text: $inputText,
                attachments: $attachments,
                selectedProviderId: $selectedProviderId,
                selectedModelName: $selectedModelName,
                isStreaming: chatService.isStreaming,
                supportsAttachments: currentModeSupportsAttachments,
                onSend: { sendMessage() },
                onStop: { chatService.cancelStream() }
            )
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Handle files dropped anywhere on the chat content area
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard currentModeSupportsAttachments else { return false }
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async { addAttachmentFromURL(url) }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async { addAttachmentFromURL(url) }
                    }
                }
                handled = true
            }
        }
        return handled
    }

    /// Shared attachment creation using ChatAttachmentHelper (DRY)
    private func addAttachmentFromURL(_ url: URL) {
        if let attachment = ChatAttachmentHelper.makeAttachment(from: url, currentCount: attachments.count) {
            attachments.append(attachment)
        }
    }

    private var currentModeSupportsAttachments: Bool {
        resolveChatMode()?.supportsAttachments ?? true
    }

    // MARK: - Data Operations

    /// On appear: load sessions, reuse blank "New Chat" or create one automatically
    private func ensureSessionExists() {
        loadSessions()
        if let blank = sessions.first(where: { $0.title == "New Chat" }) {
            selectedSessionId = blank.id
        } else {
            createNewSession()
        }
        // Initialize model selector from Chat mode defaults
        if selectedModelName.isEmpty, let chatMode = resolveChatMode() {
            selectedModelName = chatMode.modelName
            selectedProviderId = chatMode.aiProviderId
        }
    }

    private func loadSessions() {
        let repo = ChatSessionRepository(modelContext: modelContext)
        do { sessions = try repo.fetchAll() } catch { sessions = [] }
    }

    private func loadMessages(for sessionId: UUID) {
        let repo = ChatMessageRepository(modelContext: modelContext)
        do { messages = try repo.fetchForSession(sessionId) } catch { messages = [] }
    }

    private func createNewSession() {
        if let blank = sessions.first(where: { $0.title == "New Chat" }) {
            selectedSessionId = blank.id
            messages = []
            return
        }

        let chatMode = resolveChatMode()

        let repo = ChatSessionRepository(modelContext: modelContext)
        let session = repo.create(
            title: "New Chat",
            provider: chatMode?.provider ?? .gemini,
            modelName: chatMode?.modelName ?? "gemini-flash-lite-latest",
            aiModeId: chatMode?.id,
            customBaseURL: chatMode?.customBaseURL
        )
        loadSessions()
        sidebarKey = UUID()
        selectedSessionId = session.id
        messages = []
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chatService.isStreaming, let sessionId = selectedSessionId else { return }
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }

        errorMessage = nil
        inputText = ""
        let sentAttachments = attachments
        attachments = []

        let history: [ChatMessage] = messages.compactMap { msg in
            guard msg.role != .system else { return nil }
            return ChatMessage(role: msg.role, content: msg.content)
        }

        let attachmentFilePaths = sentAttachments.map { $0.fileURL.path }
        let msgRepo = ChatMessageRepository(modelContext: modelContext)
        msgRepo.create(session: session, role: .user, content: text, attachmentPaths: attachmentFilePaths)

        if session.title == "New Chat" {
            let title = String(text.prefix(50))
            session.title = title.count == 50 ? title + "..." : title
            session.touch()
            do { try modelContext.save() } catch {}
            loadSessions()
            sidebarKey = UUID()
        }

        loadMessages(for: sessionId)

        // Resolve provider/model: toolbar selection > chat mode > session fallback
        let chatMode = resolveChatMode()
        let resolvedProvider: AIProviderType
        let resolvedModel: String
        let resolvedBaseURL: String?

        if let pid = selectedProviderId, !selectedModelName.isEmpty,
           let provModel = resolveProviderModel(pid) {
            resolvedProvider = provModel.providerType
            resolvedModel = selectedModelName
            resolvedBaseURL = provModel.baseURL
        } else {
            resolvedProvider = chatMode?.provider ?? session.provider
            resolvedModel = chatMode?.modelName ?? session.modelName
            resolvedBaseURL = chatMode?.customBaseURL ?? session.customBaseURL
        }

        let modeData = AIModeData(
            name: chatMode?.name ?? "Chat",
            systemPrompt: chatMode?.systemPrompt ?? resolveSystemPrompt(for: session),
            provider: resolvedProvider,
            modelName: resolvedModel,
            supportsAttachments: true,
            customBaseURL: resolvedBaseURL
        )

        // Set streamTask BEFORE task body starts (both @MainActor, so safe)
        chatService.streamTask = Task {
            do {
                let response = try await chatService.sendMessage(
                    userMessage: text,
                    attachments: sentAttachments,
                    history: history,
                    mode: modeData
                )
                msgRepo.create(session: session, role: .assistant, content: response)
                session.touch()
                do { try modelContext.save() } catch {}
                loadMessages(for: sessionId)
                loadSessions()
                sidebarKey = UUID()
            } catch is CancellationError {
                let partial = chatService.currentStreamText
                if !partial.isEmpty {
                    msgRepo.create(session: session, role: .assistant, content: partial)
                    do { try modelContext.save() } catch {}
                    loadMessages(for: sessionId)
                }
            } catch {
                print("[Chat] Error: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resolveChatMode() -> AIModeModel? {
        let descriptor = FetchDescriptor<AIModeModel>(
            predicate: #Predicate { $0.isBuiltIn && $0.name == "Chat" }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func resolveProviderModel(_ id: UUID) -> AIProviderModel? {
        let descriptor = FetchDescriptor<AIProviderModel>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func resolveSystemPrompt(for session: ChatSessionModel) -> String {
        if let modeId = session.aiModeId {
            let descriptor = FetchDescriptor<AIModeModel>(predicate: #Predicate { $0.id == modeId })
            if let mode = try? modelContext.fetch(descriptor).first {
                return mode.systemPrompt
            }
        }
        return "You are a helpful, knowledgeable assistant. Respond conversationally. Use markdown formatting for code blocks, lists, and emphasis when appropriate."
    }
}

import SwiftUI
import SwiftData

/// Chat behavior settings — editable default model and system prompt.
struct ChatSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var providers: [AIProviderModel] = []
    @State private var selectedProviderId: UUID?
    @State private var selectedModel = ""
    @State private var systemPrompt = ""
    @State private var saveMessage: String?

    private var chatMode: AIModeModel? {
        let descriptor = FetchDescriptor<AIModeModel>(
            predicate: #Predicate { $0.isBuiltIn && $0.name == "Chat" }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Chat")
                    .font(.title2.bold())
                    .padding(.bottom, 4)

                GroupBox("Default Model") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Provider", selection: $selectedProviderId) {
                            Text("Select…").tag(nil as UUID?)
                            ForEach(providers) { p in
                                Text(p.name).tag(p.id as UUID?)
                            }
                        }
                        .onChange(of: selectedProviderId) { _, _ in
                            if let p = providers.first(where: { $0.id == selectedProviderId }) {
                                if !p.models.contains(selectedModel) {
                                    selectedModel = p.defaultModelName ?? p.models.first ?? ""
                                }
                            }
                        }

                        if let p = providers.first(where: { $0.id == selectedProviderId }) {
                            Picker("Model", selection: $selectedModel) {
                                ForEach(p.models, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.body)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Button("Save") { saveChanges() }
                        .buttonStyle(.borderedProminent)
                    if let msg = saveMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .onAppear { loadState() }
    }

    private func loadState() {
        let repo = AIProviderRepository(modelContext: modelContext)
        providers = (try? repo.fetchEnabled()) ?? []

        if let mode = chatMode {
            systemPrompt = mode.systemPrompt
            selectedModel = mode.modelName
            // Match provider
            if let pid = mode.aiProviderId, providers.contains(where: { $0.id == pid }) {
                selectedProviderId = pid
            } else {
                selectedProviderId = providers.first { $0.providerType == mode.provider }?.id
            }
        }
    }

    private func saveChanges() {
        guard let mode = chatMode else { return }
        mode.systemPrompt = systemPrompt
        mode.modelName = selectedModel
        if let pid = selectedProviderId, let p = providers.first(where: { $0.id == pid }) {
            mode.provider = p.providerType
            mode.aiProviderId = pid
            mode.customBaseURL = p.baseURL
        }
        do {
            try modelContext.save()
            saveMessage = "Saved ✓"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveMessage = nil }
        } catch {
            saveMessage = "Error: \(error.localizedDescription)"
        }
    }
}

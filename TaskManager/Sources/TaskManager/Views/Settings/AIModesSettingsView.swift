import SwiftUI
import SwiftData

private struct EditModeItem: Identifiable {
    let id: UUID
}

struct AIModesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIModeModel.sortOrder) private var modes: [AIModeModel]

    @State private var selectedModeId: UUID?
    @State private var showAddSheet = false
    @State private var editingItem: EditModeItem?
    @State private var saveErrorMessage: String?

    private var selectedMode: AIModeModel? {
        guard let id = selectedModeId else { return nil }
        return modes.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedModeId) {
                ForEach(modes) { mode in
                    ModeRow(mode: mode)
                        .tag(mode.id)
                        .contextMenu {
                            Button("Edit") {
                                editingItem = EditModeItem(id: mode.id)
                            }
                            if !mode.isBuiltIn {
                                Button("Delete", role: .destructive) {
                                    deleteMode(mode)
                                }
                            }
                        }
                }
                .onMove(perform: moveMode)
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }

                Button(action: deleteSelected) {
                    Image(systemName: "minus")
                }
                .disabled(selectedMode == nil || selectedMode?.isBuiltIn == true)

                Spacer()

                Text("\(modes.count) modes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(.bar)
        }
        .sheet(isPresented: $showAddSheet) {
            ModeEditorSheet(mode: nil, onSave: addMode)
        }
        .sheet(item: $editingItem) { item in
            if let mode = modes.first(where: { $0.id == item.id }) {
                ModeEditorSheet(mode: mode) { name, prompt, provider, model, viewType, autoCopy, baseURL, providerId in
                    updateMode(mode, name: name, prompt: prompt, provider: provider, model: model, viewType: viewType, autoCopyOutput: autoCopy, customBaseURL: baseURL, aiProviderId: providerId)
                }
            }
        }
        .alert("Unable to Save Mode", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private func addMode(name: String, prompt: String, provider: AIProviderType, model: String, viewType: AIModeViewType, autoCopyOutput: Bool, customBaseURL: String?, aiProviderId: UUID?) {
        let mode = AIModeModel(name: name, systemPrompt: prompt, provider: provider, modelName: model, isBuiltIn: false, viewType: viewType, autoCopyOutput: autoCopyOutput, customBaseURL: customBaseURL)
        mode.aiProviderId = aiProviderId
        mode.sortOrder = modes.count
        modelContext.insert(mode)
        saveModes()
    }

    private func updateMode(_ mode: AIModeModel, name: String, prompt: String, provider: AIProviderType, model: String, viewType: AIModeViewType, autoCopyOutput: Bool, customBaseURL: String?, aiProviderId: UUID?) {
        if !mode.isBuiltIn {
            mode.name = name
            mode.systemPrompt = prompt
        }
        mode.provider = provider
        mode.modelName = model
        mode.viewType = viewType
        mode.autoCopyOutput = autoCopyOutput
        mode.customBaseURL = customBaseURL
        mode.aiProviderId = aiProviderId
        saveModes()
    }

    private func deleteMode(_ mode: AIModeModel) {
        modelContext.delete(mode)
        saveModes()
    }

    private func deleteSelected() {
        guard let mode = selectedMode, !mode.isBuiltIn else { return }
        deleteMode(mode)
        selectedModeId = nil
    }

    private func moveMode(from source: IndexSet, to destination: Int) {
        var orderedModes = modes
        orderedModes.move(fromOffsets: source, toOffset: destination)
        for (index, mode) in orderedModes.enumerated() {
            mode.sortOrder = index
        }
        saveModes()
    }

    private func saveModes() {
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Mode Row

private struct ModeRow: View {
    let mode: AIModeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(mode.name)
                    .font(.body)

                if mode.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }

                // View type indicator
                Image(systemName: mode.viewType.iconName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(mode.provider.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }

            HStack {
                Text(mode.modelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(mode.systemPrompt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Mode Editor Sheet

private struct ModeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: AIModeModel?
    let onSave: (String, String, AIProviderType, String, AIModeViewType, Bool, String?, UUID?) -> Void

    @State private var name = ""
    @State private var systemPrompt = ""
    @State private var selectedProviderId: UUID?
    @State private var selectedModel = ""
    @State private var viewType: AIModeViewType = .enhance
    @State private var autoCopyOutput = false
    @State private var providers: [AIProviderModel] = []

    private var isBuiltIn: Bool { mode?.isBuiltIn ?? false }

    private var selectedProvider: AIProviderModel? {
        providers.first { $0.id == selectedProviderId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode == nil ? "Add Mode" : (isBuiltIn ? "Edit Built-in Mode" : "Edit Mode"))
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                // Name — read-only for built-in
                if isBuiltIn {
                    LabeledContent("Name", value: name)
                } else {
                    TextField("Name", text: $name)
                }

                // Provider & Model — always editable
                Section("AI Provider") {
                    Picker("Provider", selection: $selectedProviderId) {
                        Text("Select…").tag(nil as UUID?)
                        ForEach(providers) { p in
                            Text(p.name).tag(p.id as UUID?)
                        }
                    }
                    .onChange(of: selectedProviderId) { _, _ in
                        if let p = selectedProvider {
                            let models = p.models
                            if !models.contains(selectedModel) {
                                selectedModel = p.defaultModelName ?? models.first ?? ""
                            }
                        }
                    }

                    if let p = selectedProvider {
                        Picker("Model", selection: $selectedModel) {
                            ForEach(p.models, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                }

                // View type & auto-copy — editable for custom, shown for built-in
                Section("Behavior") {
                    if isBuiltIn {
                        LabeledContent("View", value: viewType.displayName)
                    } else {
                        Picker("View", selection: $viewType) {
                            ForEach(AIModeViewType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.iconName).tag(type)
                            }
                        }
                    }

                    if viewType == .enhance {
                        Toggle("Auto-copy output to clipboard", isOn: $autoCopyOutput)
                            .controlSize(.small)
                    }
                }

                // System prompt — read-only for built-in
                Section("System Prompt") {
                    if isBuiltIn {
                        Text(systemPrompt)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 80, alignment: .topLeading)
                            .padding(8)
                    } else {
                        TextEditor(text: $systemPrompt)
                            .font(.body)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    let provType = selectedProvider?.providerType ?? .gemini
                    let baseURL = selectedProvider?.baseURL
                    onSave(name, systemPrompt, provType, selectedModel, viewType, autoCopyOutput, baseURL, selectedProviderId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isBuiltIn && (name.trimmingCharacters(in: .whitespaces).isEmpty || systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty || selectedProviderId == nil))
            }
            .padding()
        }
        .frame(width: 500, height: 520)
        .onAppear { loadState() }
    }

    private func loadState() {
        let repo = AIProviderRepository(modelContext: modelContext)
        providers = (try? repo.fetchEnabled()) ?? []

        if let mode {
            name = mode.name
            systemPrompt = mode.systemPrompt
            viewType = mode.viewType
            autoCopyOutput = mode.autoCopyOutput

            if let pid = mode.aiProviderId, providers.contains(where: { $0.id == pid }) {
                selectedProviderId = pid
            } else {
                selectedProviderId = providers.first { $0.providerType == mode.provider }?.id
            }
            selectedModel = mode.modelName
        } else {
            selectedProviderId = providers.first?.id
            selectedModel = providers.first?.defaultModelName ?? ""
            viewType = .enhance
            autoCopyOutput = false
        }
    }
}

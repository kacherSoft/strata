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
            ModeEditorSheet(mode: nil) { name, prompt, provider, model, supportsAttachments, baseURL in
                addMode(name: name, prompt: prompt, provider: provider, model: model, supportsAttachments: supportsAttachments, customBaseURL: baseURL)
            }
        }
        .sheet(item: $editingItem) { item in
            if let mode = modes.first(where: { $0.id == item.id }) {
                ModeEditorSheet(mode: mode) { name, prompt, provider, model, supportsAttachments, baseURL in
                    updateMode(mode, name: name, prompt: prompt, provider: provider, model: model, supportsAttachments: supportsAttachments, customBaseURL: baseURL)
                }
            }
        }
        .alert("Unable to Save Mode", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }
    
    private func addMode(name: String, prompt: String, provider: AIProviderType, model: String, supportsAttachments: Bool, customBaseURL: String?) {
        let canSupportAttachments = provider.supportsAnyAttachments
        let mode = AIModeModel(name: name, systemPrompt: prompt, provider: provider, modelName: model, isBuiltIn: false, supportsAttachments: supportsAttachments && canSupportAttachments, customBaseURL: customBaseURL)
        mode.sortOrder = modes.count
        modelContext.insert(mode)
        saveModes()
    }

    private func updateMode(_ mode: AIModeModel, name: String, prompt: String, provider: AIProviderType, model: String, supportsAttachments: Bool, customBaseURL: String?) {
        mode.name = name
        mode.systemPrompt = prompt
        mode.provider = provider
        mode.modelName = model
        mode.supportsAttachments = supportsAttachments && provider.supportsAnyAttachments
        mode.customBaseURL = customBaseURL
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

private struct ModeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementService.self) var entitlementService

    let mode: AIModeModel?
    let onSave: (String, String, AIProviderType, String, Bool, String?) -> Void

    @State private var name = ""
    @State private var systemPrompt = ""
    @State private var selectedProvider: AIProviderType = .gemini
    @State private var selectedModel: String
    @State private var customModelName = ""
    @State private var customBaseURL = ""
    @State private var supportsAttachments = false

    init(mode: AIModeModel?, onSave: @escaping (String, String, AIProviderType, String, Bool, String?) -> Void) {
        self.mode = mode
        self.onSave = onSave
        let provider: AIProviderType = mode?.provider ?? .gemini
        let validModel: String = if let mode, provider.availableModels.contains(mode.modelName) {
            mode.modelName
        } else if provider.supportsCustomModel, let mode {
            mode.modelName
        } else {
            provider.defaultModel
        }
        _selectedModel = State(initialValue: validModel)
        _selectedProvider = State(initialValue: provider)
        if let mode {
            _name = State(initialValue: mode.name)
            _systemPrompt = State(initialValue: mode.systemPrompt)
            _customModelName = State(initialValue: provider.supportsCustomModel ? mode.modelName : "")
            _customBaseURL = State(initialValue: mode.customBaseURL ?? "")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode == nil ? "Add Mode" : "Edit Mode")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            Form {
                TextField("Name", text: $name)

                Section("AI Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProviderType.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) { _, newValue in
                        if !newValue.supportsCustomModel {
                            if !newValue.availableModels.contains(selectedModel) {
                                selectedModel = newValue.defaultModel
                            }
                            customModelName = ""
                            customBaseURL = ""
                        }
                        if !newValue.supportsAnyAttachments {
                            supportsAttachments = false
                        }
                    }

                    if selectedProvider.supportsCustomModel {
                        TextField("Model Name", text: $customModelName, prompt: Text("e.g. gpt-4o, llama-3.1-70b"))
                    } else {
                        Picker("Model", selection: $selectedModel) {
                            ForEach(selectedProvider.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }

                    if selectedProvider.requiresBaseURL {
                        TextField("Base URL", text: $customBaseURL, prompt: Text("e.g. https://openrouter.ai/api/v1"))
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if entitlementService.hasFullAccess {
                    Section("Input") {
                        Toggle("Allow Attachments (Images & PDF)", isOn: $supportsAttachments)
                            .controlSize(.small)
                            .disabled(!selectedProvider.supportsAnyAttachments)
                        if !selectedProvider.supportsAnyAttachments {
                            Label("Attachments are currently not supported for this provider.", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .font(.body)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary)
                        )
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Spacer()
                Button("Save") {
                    let resolvedModel = selectedProvider.supportsCustomModel ? customModelName : selectedModel
                    let resolvedURL: String? = selectedProvider.requiresBaseURL && !customBaseURL.isEmpty ? customBaseURL : nil
                    onSave(name, systemPrompt, selectedProvider, resolvedModel, supportsAttachments, resolvedURL)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 480)
        .onAppear {
            if let mode {
                name = mode.name
                systemPrompt = mode.systemPrompt
                selectedProvider = mode.provider
                supportsAttachments = mode.supportsAttachments && selectedProvider.supportsAnyAttachments
                customBaseURL = mode.customBaseURL ?? ""
                if selectedProvider.supportsCustomModel {
                    customModelName = mode.modelName
                } else {
                    let valid = selectedProvider.availableModels.contains(mode.modelName)
                    selectedModel = valid ? mode.modelName : selectedProvider.defaultModel
                }
            } else {
                selectedModel = selectedProvider.defaultModel
                supportsAttachments = false
            }
        }
    }
}

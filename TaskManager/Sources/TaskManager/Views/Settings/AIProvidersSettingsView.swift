import SwiftUI
import SwiftData

/// AI Provider management — add/edit/remove providers, API keys, model lists, test connection.
struct AIProvidersSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIProviderModel.sortOrder) private var providers: [AIProviderModel]
    @State private var showAddSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("AI Providers")
                        .font(.title2.bold())
                    Spacer()
                    Text("\(providers.count)/\(AIProviderModel.maxProviderCount) providers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                ForEach(providers) { provider in
                    AIProviderCardView(provider: provider)
                }

                if providers.count < AIProviderModel.maxProviderCount {
                    Button(action: { showAddSheet = true }) {
                        Label("Add Provider", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(24)
        }
        .sheet(isPresented: $showAddSheet) {
            AddProviderSheet { name, baseURL, apiKey, models in
                addProvider(name: name, baseURL: baseURL, apiKey: apiKey, models: models)
            }
        }
    }

    private func addProvider(name: String, baseURL: String, apiKey: String, models: [String]) {
        let ref = "provider-\(UUID().uuidString)"
        try? KeychainService.shared.saveValue(apiKey, forRef: ref)
        let provider = AIProviderModel(
            name: name,
            providerType: .openai,
            baseURL: baseURL,
            apiKeyRef: ref,
            models: models,
            isDefault: false,
            sortOrder: providers.count
        )
        modelContext.insert(provider)
        try? modelContext.save()
    }
}

// MARK: - Provider Card

struct AIProviderCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var provider: AIProviderModel
    @State private var apiKeyText = ""
    @State private var showAPIKey = false
    @State private var newModelName = ""
    @State private var testResult: TestResult?
    @State private var isTesting = false

    enum TestResult { case success, failure(String) }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(provider.name)
                        .font(.headline)
                    if provider.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    configuredBadge
                }

                // API Key
                HStack(spacing: 8) {
                    Text("API Key")
                        .frame(width: 60, alignment: .leading)
                    if showAPIKey {
                        TextField("API Key", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $apiKeyText)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    Button("Save") { saveAPIKey() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Test") { testConnection() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTesting)
                }

                // Test result
                if let result = testResult {
                    testResultView(result)
                }

                // Base URL (custom providers only)
                if provider.requiresBaseURL {
                    HStack(spacing: 8) {
                        Text("Base URL")
                            .frame(width: 60, alignment: .leading)
                        TextField("https://api.example.com/v1", text: Binding(
                            get: { provider.baseURL ?? "" },
                            set: { provider.baseURL = $0.isEmpty ? nil : $0; try? modelContext.save() }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }

                // Models
                modelsSection

                // Delete button (custom only)
                if !provider.isDefault {
                    HStack {
                        Spacer()
                        Button("Remove Provider", role: .destructive) { deleteProvider() }
                            .controlSize(.small)
                    }
                }
            }
            .padding(8)
        }
        .onAppear { loadAPIKey() }
    }

    @ViewBuilder
    private var configuredBadge: some View {
        if provider.isConfigured {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Configured")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.orange)
                Text("Not configured")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Models")
                .font(.subheadline.bold())
            ForEach(provider.models, id: \.self) { model in
                HStack {
                    Text(model)
                        .font(.system(.body, design: .monospaced))
                    if model == provider.defaultModelName {
                        Text("default")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if !provider.isDefault || provider.models.count > 1 {
                        Button(action: { removeModel(model) }) {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            HStack {
                TextField("Add model name", text: $newModelName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addModel() }
                Button(action: addModel) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .disabled(newModelName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func testResultView(_ result: TestResult) -> some View {
        switch result {
        case .success:
            Label("Connection successful", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(.caption).foregroundStyle(.red)
        }
    }

    // MARK: - Actions

    private func loadAPIKey() {
        apiKeyText = KeychainService.shared.getValue(forRef: provider.apiKeyRef) ?? ""
    }

    private func saveAPIKey() {
        guard !apiKeyText.isEmpty else { return }
        try? KeychainService.shared.saveValue(apiKeyText, forRef: provider.apiKeyRef)
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let prov = AIService.shared.providerFor(provider)
                let success = try await prov.testConnection()
                testResult = success ? .success : .failure("Test returned false")
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }

    private func addModel() {
        let name = newModelName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var models = provider.models
        guard !models.contains(name) else { return }
        models.append(name)
        provider.models = models
        if provider.defaultModelName == nil { provider.defaultModelName = name }
        try? modelContext.save()
        newModelName = ""
    }

    private func removeModel(_ model: String) {
        var models = provider.models
        models.removeAll { $0 == model }
        provider.models = models
        if provider.defaultModelName == model {
            provider.defaultModelName = models.first
        }
        try? modelContext.save()
    }

    private func deleteProvider() {
        let repo = AIProviderRepository(modelContext: modelContext)
        try? repo.delete(provider)
    }
}

// MARK: - Add Provider Sheet

private struct AddProviderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String, String, [String]) -> Void

    @State private var name = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var modelsText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add OpenAI-Compatible Provider")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            Form {
                TextField("Name", text: $name, prompt: Text("e.g. OpenRouter, Ollama"))
                TextField("Base URL", text: $baseURL, prompt: Text("https://openrouter.ai/api/v1"))
                SecureField("API Key", text: $apiKey)
                TextField("Models (comma-separated)", text: $modelsText,
                          prompt: Text("gpt-4o, claude-3.5-sonnet"))
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Add") {
                    let models = modelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    onSave(name, baseURL, apiKey, models)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || baseURL.isEmpty || apiKey.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 340)
    }
}

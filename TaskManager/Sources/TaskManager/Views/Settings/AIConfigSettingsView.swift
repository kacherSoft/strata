import SwiftUI

struct AIConfigSettingsView: View {
    @State private var geminiKey = ""
    @State private var anthropicKey = ""
    @State private var showGeminiKey = false
    @State private var showAnthropicKey = false
    @State private var testingGemini = false
    @State private var testingAnthropic = false
    @State private var geminiTestResult: TestResult?
    @State private var anthropicTestResult: TestResult?

    private let keychain = KeychainService.shared

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    providerRow(
                        name: "Google Gemini",
                        key: $geminiKey,
                        showKey: $showGeminiKey,
                        isTesting: testingGemini,
                        testResult: geminiTestResult,
                        keychainKey: .geminiAPIKey,
                        onTest: testGemini
                    )

                    Divider()

                    providerRow(
                        name: "Anthropic",
                        key: $anthropicKey,
                        showKey: $showAnthropicKey,
                        isTesting: testingAnthropic,
                        testResult: anthropicTestResult,
                        keychainKey: .anthropicAPIKey,
                        onTest: testAnthropic
                    )
                }
            } header: {
                Text("AI Providers")
            } footer: {
                Text("API keys are stored securely in your macOS Keychain. You pay for usage directly to the provider.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadKeys()
        }
    }

    @ViewBuilder
    private func providerRow(
        name: String,
        key: Binding<String>,
        showKey: Binding<Bool>,
        isTesting: Bool,
        testResult: TestResult?,
        keychainKey: KeychainService.Key,
        onTest: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                Spacer()
                if keychain.hasKey(keychainKey) {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Group {
                    if showKey.wrappedValue {
                        TextField("API Key", text: key)
                    } else {
                        SecureField("API Key", text: key)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button(action: { showKey.wrappedValue.toggle() }) {
                    Image(systemName: showKey.wrappedValue ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 12) {
                Button("Save") {
                    saveKey(key.wrappedValue, for: keychainKey)
                }
                .disabled(key.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Test") { onTest() }
                    .disabled(key.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty || isTesting)

                if isTesting { ProgressView().scaleEffect(0.7) }

                if let result = testResult {
                    switch result {
                    case .success:
                        Label("Connected", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle")
                            .font(.caption).foregroundStyle(.red)
                    }
                }

                Spacer()

                if keychain.hasKey(keychainKey) {
                    Button("Remove", role: .destructive) {
                        removeKey(keychainKey)
                        key.wrappedValue = ""
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private func loadKeys() {
        if let key = keychain.get(.geminiAPIKey) { geminiKey = key }
        if let key = keychain.get(.anthropicAPIKey) { anthropicKey = key }
    }

    private func saveKey(_ value: String, for key: KeychainService.Key) {
        do {
            try keychain.save(value.trimmingCharacters(in: .whitespaces), for: key)
        } catch {
            switch key {
            case .geminiAPIKey:
                geminiTestResult = .failure(error.localizedDescription)
            case .anthropicAPIKey:
                anthropicTestResult = .failure(error.localizedDescription)
            default: break
            }
        }
    }

    private func removeKey(_ key: KeychainService.Key) { keychain.delete(key) }

    private func testGemini() {
        testingGemini = true
        geminiTestResult = nil
        Task {
            do {
                try keychain.save(geminiKey.trimmingCharacters(in: .whitespaces), for: .geminiAPIKey)
                _ = try await AIService.shared.testProvider(.gemini)
                geminiTestResult = .success
            } catch {
                geminiTestResult = .failure(error.localizedDescription)
            }
            testingGemini = false
        }
    }

    private func testAnthropic() {
        testingAnthropic = true
        anthropicTestResult = nil
        Task {
            do {
                try keychain.save(anthropicKey.trimmingCharacters(in: .whitespaces), for: .anthropicAPIKey)
                _ = try await AIService.shared.testProvider(.anthropic)
                anthropicTestResult = .success
            } catch {
                anthropicTestResult = .failure(error.localizedDescription)
            }
            testingAnthropic = false
        }
    }
}

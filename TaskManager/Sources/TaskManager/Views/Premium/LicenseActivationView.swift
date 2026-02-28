import SwiftUI

struct LicenseActivationView: View {
    @Environment(EntitlementService.self) var entitlementService
    @Environment(\.dismiss) private var dismiss
    @State private var licenseKey = ""
    @State private var activationState: ActivationState = .idle

    enum ActivationState: Equatable {
        case idle
        case activating
        case success
        case error(String)

        static func == (lhs: ActivationState, rhs: ActivationState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.activating, .activating), (.success, .success): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)

            Text("Activate VIP License")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter the license key you received after purchase.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: 360)
                .disabled(activationState == .activating)

            switch activationState {
            case .idle:
                EmptyView()
            case .activating:
                ProgressView("Activating…")
            case .success:
                Label("License activated!", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Activate") {
                    activate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || activationState == .activating)
                .keyboardShortcut(.return)
            }
        }
        .padding(30)
        .frame(width: 440)
    }

    private func activate() {
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        activationState = .activating

        Task {
            do {
                try await entitlementService.activateLicense(key: trimmedKey)
                activationState = .success
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch {
                activationState = .error(error.localizedDescription)
            }
        }
    }
}

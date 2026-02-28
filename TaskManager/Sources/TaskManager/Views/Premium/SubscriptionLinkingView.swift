import SwiftUI

struct SubscriptionLinkingView: View {
    @Environment(EntitlementService.self) var entitlementService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var includeLicenseKey = false
    @State private var licenseKey = ""
    @State private var restoreState: RestoreState = .idle

    enum RestoreState: Equatable {
        case idle
        case restoring
        case restored(String)
        case failed(String)

        static func == (lhs: RestoreState, rhs: RestoreState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.restoring, .restoring):
                return true
            case (.restored(let a), .restored(let b)):
                return a == b
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Restore Purchases")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Restore Pro subscription or VIP lifetime purchase on this install.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("you@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
                .disabled(restoreState == .restoring)
                .textContentType(.emailAddress)

            Toggle("Include VIP license key", isOn: $includeLicenseKey)
                .toggleStyle(.switch)
                .frame(maxWidth: 360, alignment: .leading)
                .disabled(restoreState == .restoring)

            if includeLicenseKey {
                TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 360)
                    .disabled(restoreState == .restoring)
            }

            switch restoreState {
            case .idle:
                EmptyView()
            case .restoring:
                ProgressView("Restoring…")
            case .restored(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            case .failed(let message):
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

                Button("Restore Purchases") {
                    restore()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidEmail || restoreState == .restoring)
                .keyboardShortcut(.return)
            }
        }
        .padding(30)
        .frame(width: 460)
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func restore() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLicenseKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        restoreState = .restoring

        Task {
            do {
                let outcome = try await entitlementService.restorePurchases(
                    email: trimmedEmail,
                    licenseKey: includeLicenseKey && !trimmedLicenseKey.isEmpty ? trimmedLicenseKey : nil
                )

                switch outcome {
                case .subscription:
                    restoreState = .restored("Subscription restored")
                case .lifetime:
                    restoreState = .restored("VIP lifetime restored")
                case .none:
                    restoreState = .failed("No purchases found for this email")
                    return
                }

                try? await Task.sleep(for: .seconds(1.2))
                dismiss()
            } catch {
                restoreState = .failed(error.localizedDescription)
            }
        }
    }
}

import SwiftUI

struct SubscriptionLinkingView: View {
    @Environment(EntitlementService.self) var entitlementService
    @Environment(\.dismiss) private var dismiss

    @State private var includeLicenseKey = false
    @State private var licenseKey = ""
    @State private var restoreState: RestoreState = .idle
    @State private var showAccountSignIn = false
    @State private var showManageDevices = false

    enum RestoreState: Equatable {
        case idle
        case restoring
        case restored(String)
        case failed(String)
        case deviceLimitReached

        static func == (lhs: RestoreState, rhs: RestoreState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.restoring, .restoring), (.deviceLimitReached, .deviceLimitReached):
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

            if entitlementService.isAccountSignedIn {
                if let email = entitlementService.accountEmail {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundStyle(.green)
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Label("Sign in is required before restore", systemImage: "person.badge.key")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Button("Sign In") {
                        showAccountSignIn = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(restoreState == .restoring)
                }
            }

            Toggle("Include VIP license key", isOn: $includeLicenseKey)
                .toggleStyle(.switch)
                .frame(maxWidth: 360, alignment: .leading)
                .disabled(restoreState == .restoring || !entitlementService.isAccountSignedIn)

            if includeLicenseKey {
                TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 360)
                    .disabled(restoreState == .restoring || !entitlementService.isAccountSignedIn)
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
            case .deviceLimitReached:
                VStack(spacing: 8) {
                    Label("Device limit reached for your plan.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Text("Remove an unused device to activate on this one.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Manage Devices") {
                        showManageDevices = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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
                .disabled(!entitlementService.isAccountSignedIn || restoreState == .restoring)
                .keyboardShortcut(.return)
            }
        }
        .padding(30)
        .frame(width: 460)
        .sheet(isPresented: $showAccountSignIn) {
            AccountSignInView()
        }
        .sheet(isPresented: $showManageDevices) {
            ManageDevicesView()
        }
    }

    private func restore() {
        let trimmedLicenseKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        restoreState = .restoring

        Task {
            do {
                let outcome = try await entitlementService.restorePurchases(
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
                if isDeviceLimitError(error) {
                    restoreState = .deviceLimitReached
                } else {
                    restoreState = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Returns true if the error is a DEVICE_LIMIT_REACHED backend error.
    private func isDeviceLimitError(_ error: Error) -> Bool {
        guard case let BackendError.httpError(statusCode, body) = error,
              statusCode == 403 else {
            return false
        }
        return body.contains("DEVICE_LIMIT_REACHED")
    }
}

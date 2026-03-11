import SwiftUI

struct AccountSignInView: View {
    @Environment(EntitlementService.self) private var entitlementService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var challenge: EntitlementService.EmailAuthChallenge?
    @State private var state: AuthState = .idle

    enum AuthState: Equatable {
        case idle
        case sendingCode
        case awaitingCode
        case verifying
        case success
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("Sign In")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Verify account ownership to restore purchases and manage subscription access.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if case .awaitingCode = state {
                Text(emailDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("you@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .disabled(isBusy || challenge != nil)

            if challenge != nil {
                TextField("6-digit code", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.oneTimeCode)
                    .disabled(isBusy)
            }

            switch state {
            case .idle:
                EmptyView()
            case .sendingCode:
                ProgressView("Sending code…")
            case .awaitingCode:
                if let challenge {
                    Text("Code sent via \(challenge.delivery). Expires \(formattedExpiry(challenge.expiresAt)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .verifying:
                ProgressView("Verifying…")
            case .success:
                Label("Signed in successfully", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                if challenge == nil {
                    Button("Send Code") {
                        sendCode()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidEmail || isBusy)
                } else {
                    Button("Verify") {
                        verifyCode()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 || isBusy)
                }
            }
        }
        .padding(28)
        .frame(width: 460)
    }

    private var isBusy: Bool {
        switch state {
        case .sendingCode, .verifying:
            return true
        default:
            return false
        }
    }

    private var isValidEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private var emailDisplay: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func formattedExpiry(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func sendCode() {
        state = .sendingCode
        let currentEmail = emailDisplay

        Task {
            do {
                let started = try await entitlementService.startEmailAuth(email: currentEmail)
                challenge = started
                state = .awaitingCode
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func verifyCode() {
        guard let challenge else { return }
        state = .verifying
        let enteredCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                try await entitlementService.verifyEmailAuth(
                    email: challenge.email,
                    challengeId: challenge.challengeId,
                    code: enteredCode
                )
                state = .success
                try? await Task.sleep(for: .seconds(0.8))
                dismiss()
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

import SwiftUI

/// Account settings — subscription status with tasteful premium treatment, device management.
struct AccountSettingsView: View {
    @Environment(EntitlementService.self) var entitlementService
    @State private var showSignIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Account")
                    .font(.title)
                    .fontWeight(.semibold)

                // Plan card
                if entitlementService.hasFullAccess {
                    premiumPlanCard
                } else {
                    freePlanCard
                }

                // Sign in / Sign out
                if entitlementService.isAccountSignedIn {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entitlementService.accountEmail ?? "Signed in")
                                .font(.body)
                            Text("Signed in to your Strata account")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Sign Out") {
                            Task { await entitlementService.signOutAccount() }
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .liquidGlass(.settingsCard)
                } else {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Not signed in")
                                .font(.body)
                            Text("Sign in to sync your subscription")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Button("Sign In") { showSignIn = true }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .liquidGlass(.settingsCard)
                }

                // Devices section
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Devices")
                                .font(.body)
                            Text("Manage registered devices")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    ManageDevicesView()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }
                .liquidGlass(.settingsCard)

                Spacer()
            }
            .padding(24)
        }
        .sheet(isPresented: $showSignIn) {
            AccountSignInView()
        }
    }

    // MARK: - Premium Plan Card (Restrained elegance)

    private var premiumPlanCard: some View {
        HStack(spacing: 16) {
            // Left: plan info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("Strata")
                        .font(.title3.weight(.semibold))

                    // Warm gold badge — single color, no animation
                    Text("VIP")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.50))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.85, green: 0.72, blue: 0.50).opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(red: 0.85, green: 0.72, blue: 0.50).opacity(0.25), lineWidth: 0.5)
                        )
                }

                Text("Lifetime access to all features")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right: status
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("Active")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }
                Text("Lifetime")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(red: 0.85, green: 0.72, blue: 0.50).opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Free Plan Card

    private var freePlanCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Free Plan")
                    .font(.title3.weight(.semibold))
                Text("Upgrade to unlock AI chat, attachments, and more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Upgrade") {
                // TODO: open purchase flow
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(20)
        .liquidGlass(.settingsCard)
    }
}

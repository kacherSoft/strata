import SwiftUI

/// Account settings — subscription status, device management.
/// Uses same row pattern as GeneralSettingsView: icon + label + control + .liquidGlass.
struct AccountSettingsView: View {
    @Environment(EntitlementService.self) var entitlementService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Account")
                    .font(.title)
                    .fontWeight(.semibold)

                VStack(spacing: 0) {
                    // Subscription status row
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Plan")
                                .font(.body)
                            Text("Your subscription status")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(entitlementService.hasFullAccess ? "VIP (Lifetime)" : "Free")
                            .foregroundStyle(entitlementService.hasFullAccess ? .green : .secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 20)

                    // Devices section
                    VStack(alignment: .leading, spacing: 8) {
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
                }
                .liquidGlass(.settingsCard)

                Spacer()
            }
            .padding(24)
        }
    }
}

import SwiftUI

/// Account settings — subscription status, device management.
/// Matches GeneralSettingsView row pattern: icon + label + control.
struct AccountSettingsView: View {
    @Environment(EntitlementService.self) var entitlementService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Account")
                    .font(.title)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 0) {
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
                    .padding(.vertical, 12)

                    Divider()

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
                        .padding(.top, 12)

                        ManageDevicesView()
                            .padding(.leading, 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                Spacer()
            }
            .padding(24)
        }
    }
}

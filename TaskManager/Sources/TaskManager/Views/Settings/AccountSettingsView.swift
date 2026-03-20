import SwiftUI

/// Account settings — subscription status, device management, sign in/out.
struct AccountSettingsView: View {
    @Environment(EntitlementService.self) var entitlementService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Account")
                    .font(.title2.bold())
                    .padding(.bottom, 4)

                GroupBox("Subscription") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(entitlementService.hasFullAccess ? "Active" : "Free")
                                .foregroundStyle(entitlementService.hasFullAccess ? .green : .secondary)
                        }
                    }
                    .padding(8)
                }

                GroupBox("Devices") {
                    ManageDevicesView()
                        .frame(minHeight: 150)
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

import SwiftUI

/// Device management — inline view for embedding in Account settings.
/// Shows registered devices with revoke capability.
struct ManageDevicesView: View {
    @Environment(EntitlementService.self) private var entitlementService

    @State private var devices: [DeviceInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var revokingInstallId: String?
    @State private var deviceToRevoke: DeviceInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Registered Devices")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.6) }
                Button("Refresh") { Task { await reload() } }
                    .controlSize(.small)
                    .disabled(isLoading || revokingInstallId != nil)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }

            if devices.isEmpty && !isLoading {
                Text("No devices registered")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(devices.enumerated()), id: \.element.install_id) { index, device in
                        if index > 0 { Divider().padding(.horizontal, 12) }
                        deviceRow(device)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
        .task { await reload() }
        .alert("Revoke Device Access",
               isPresented: Binding(
                   get: { deviceToRevoke != nil },
                   set: { if !$0 { deviceToRevoke = nil } }
               )
        ) {
            Button("Cancel", role: .cancel) { deviceToRevoke = nil }
            Button("Revoke & Sign Out", role: .destructive) {
                if let device = deviceToRevoke {
                    Task { await revokeAndSignOut(device) }
                }
            }
        } message: {
            if deviceToRevoke?.install_id == entitlementService.installId {
                Text("This will revoke access on this Mac, sign you out, and move you to the Free plan. You'll need to restore your purchase to re-activate.")
            } else {
                Text("This will revoke access on that device. The device will lose premium features.")
            }
        }
    }

    @ViewBuilder
    private func deviceRow(_ device: DeviceInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.nickname ?? "Unnamed Device")
                        .font(.body)
                    if device.install_id == entitlementService.installId {
                        Text("This Mac")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 8) {
                    Text(shortInstallID(device.install_id))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Text(statusText(for: device))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if device.active {
                Button("Revoke") { deviceToRevoke = device }
                    .controlSize(.small)
                    .disabled(revokingInstallId != nil)
            } else {
                Text("Revoked")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func statusText(for device: DeviceInfo) -> String {
        if let revokedAt = device.revoked_at {
            return "Revoked \(formattedUnix(revokedAt))"
        }
        return "Last seen \(formattedUnix(device.last_seen_at))"
    }

    private func formattedUnix(_ value: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(value))
            .formatted(date: .abbreviated, time: .shortened)
    }

    private func shortInstallID(_ installId: String) -> String {
        if installId.count <= 12 { return installId }
        return "\(installId.prefix(8))…\(installId.suffix(4))"
    }

    private func reload() async {
        guard entitlementService.isAccountSignedIn else {
            errorMessage = "Sign in required"
            devices = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            devices = try await entitlementService.listAccountDevices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Revoke device via API, then if it's this Mac, sign out + clear all entitlements → Free plan
    private func revokeAndSignOut(_ device: DeviceInfo) async {
        revokingInstallId = device.install_id
        errorMessage = nil
        defer { revokingInstallId = nil }

        do {
            try await entitlementService.revokeAccountDevice(installId: device.install_id)

            // If revoking own device → full sign out + clear entitlements
            if device.install_id == entitlementService.installId {
                await entitlementService.signOutAccount()
            }

            devices = try await entitlementService.listAccountDevices()
        } catch {
            // If signed out, can't list devices anymore — just clear the list
            if !entitlementService.isAccountSignedIn {
                devices = []
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

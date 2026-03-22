import SwiftUI

/// Device management — inline view for embedding in Account settings.
/// Shows registered devices with revoke capability.
struct ManageDevicesView: View {
    @Environment(EntitlementService.self) private var entitlementService

    @State private var devices: [DeviceInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var revokingInstallId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Registered Devices")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.6)
                }
                Button("Refresh") {
                    Task { await reload() }
                }
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
                Button("Revoke") {
                    Task { await revoke(device) }
                }
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

    private func revoke(_ device: DeviceInfo) async {
        revokingInstallId = device.install_id
        errorMessage = nil
        defer { revokingInstallId = nil }
        do {
            try await entitlementService.revokeAccountDevice(installId: device.install_id)
            devices = try await entitlementService.listAccountDevices()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

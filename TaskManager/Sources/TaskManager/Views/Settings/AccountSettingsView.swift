import SwiftUI

/// Account settings — subscription status with premium badge, device management.
struct AccountSettingsView: View {
    @Environment(EntitlementService.self) var entitlementService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Account")
                    .font(.title)
                    .fontWeight(.semibold)

                // Plan card — special treatment for premium tiers
                if entitlementService.hasFullAccess {
                    premiumPlanCard
                } else {
                    freePlanCard
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
    }

    // MARK: - Premium Plan Card

    private var premiumPlanCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                // Animated crown icon
                PremiumIconView()

                VStack(alignment: .leading, spacing: 4) {
                    Text("VIP Plan")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Lifetime Access")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                PremiumBadgeView(text: "ACTIVE")
            }

            Divider().overlay(Color.white.opacity(0.15))

            // Features list
            HStack(spacing: 20) {
                featureChip(icon: "sparkles", text: "AI Chat")
                featureChip(icon: "wand.and.stars", text: "Enhance")
                featureChip(icon: "paperclip", text: "Attachments")
                featureChip(icon: "rectangle.3.group", text: "Kanban")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.08, blue: 0.30),
                            Color(red: 0.08, green: 0.12, blue: 0.28),
                            Color(red: 0.05, green: 0.15, blue: 0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.5),
                            Color.blue.opacity(0.3),
                            Color.cyan.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func featureChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.08), in: Capsule())
    }

    // MARK: - Free Plan Card

    private var freePlanCard: some View {
        HStack {
            Image(systemName: "person.circle")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Free Plan")
                    .font(.body.bold())
                Text("Upgrade to unlock all features")
                    .font(.caption)
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

// MARK: - Premium Badge with shimmer

private struct PremiumBadgeView: View {
    let text: String
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.7), Color.cyan.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset * 60)
                    .mask(Capsule())
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1
                }
            }
    }
}

// MARK: - Animated Premium Icon

private struct PremiumIconView: View {
    @State private var glow = false

    var body: some View {
        ZStack {
            // Glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(glow ? 0.4 : 0.1), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 24
                    )
                )
                .frame(width: 48, height: 48)

            // Crown icon
            Image(systemName: "crown.fill")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .orange.opacity(0.5), radius: glow ? 6 : 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

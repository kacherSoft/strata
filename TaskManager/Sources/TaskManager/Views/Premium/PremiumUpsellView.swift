import SwiftUI

struct PremiumUpsellView: View {
    let featureName: String
    let featureDescription: String

    @Environment(EntitlementService.self) var entitlementService
    @State private var showLicenseActivation = false
    @State private var showSubscriptionLinking = false
    @State private var showCheckoutEmailSheet = false
    @State private var pendingCheckoutProductId: String?
    @State private var checkoutEmailInput = ""
    @State private var checkoutInFlight = false
    @State private var checkoutError: String?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.yellow)

            Text("Unlock \(featureName)")
                .font(.title2)
                .fontWeight(.semibold)

            Text(featureDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                Button {
                    prepareCheckout(for: DodoPaymentsClient.proMonthlyProductId)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pro Monthly")
                                .font(.headline)
                            Text("$4.99/month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Subscribe")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(12)
                    .liquidGlass(.init(thickness: .ultraThin, variant: .default, cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(checkoutInFlight)

                Button {
                    prepareCheckout(for: DodoPaymentsClient.proYearlyProductId)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pro Yearly")
                                .font(.headline)
                            Text("$39.99/year — save 33%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Subscribe")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(12)
                    .liquidGlass(.init(thickness: .ultraThin, variant: .default, cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(checkoutInFlight)

                Divider()
                    .padding(.vertical, 4)

                Button {
                    prepareCheckout(for: DodoPaymentsClient.vipLifetimeProductId)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("VIP Lifetime")
                                    .font(.headline)
                                Text("One-Time")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.yellow.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Text("$99.99 — lifetime access")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Buy Once")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(12)
                    .liquidGlass(.init(thickness: .ultraThin, variant: .default, cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(checkoutInFlight)
            }

            if checkoutInFlight {
                ProgressView("Preparing secure checkout…")
                    .font(.caption)
            }

            if let checkoutError {
                Label(checkoutError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button("Activate license key") {
                    showLicenseActivation = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.caption)

                Button("Restore purchases") {
                    showSubscriptionLinking = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.caption)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: 420)
        .sheet(isPresented: $showLicenseActivation) {
            LicenseActivationView()
        }
        .sheet(isPresented: $showSubscriptionLinking) {
            SubscriptionLinkingView()
        }
        .sheet(isPresented: $showCheckoutEmailSheet) {
            checkoutEmailSheet
        }
    }

    private var checkoutEmailSheet: some View {
        VStack(spacing: 16) {
            Text("Checkout Email")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Use this purchase email for checkout and automatic restore.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("you@example.com", text: $checkoutEmailInput)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .disabled(checkoutInFlight)
            HStack(spacing: 12) {
                Button("Cancel") {
                    showCheckoutEmailSheet = false
                }
                .keyboardShortcut(.escape)

                Button("Continue") {
                    guard let productId = pendingCheckoutProductId else { return }
                    showCheckoutEmailSheet = false
                    startCheckout(for: productId, email: checkoutEmailInput)
                }
                .buttonStyle(.borderedProminent)
                .disabled(checkoutInFlight)
                .keyboardShortcut(.return)
            }
        }
        .padding(22)
        .frame(width: 420)
    }

    private func prepareCheckout(for productId: String) {
        pendingCheckoutProductId = productId
        checkoutEmailInput = entitlementService.linkedCustomerEmail ?? ""
        showCheckoutEmailSheet = true
    }

    private func startCheckout(for productId: String, email: String) {
        checkoutInFlight = true
        checkoutError = nil

        Task {
            do {
                let checkoutURL = try await entitlementService.beginCheckout(
                    productId: productId,
                    email: email
                )
                NSWorkspace.shared.open(checkoutURL)
            } catch {
                checkoutError = error.localizedDescription
            }
            checkoutInFlight = false
        }
    }
}

#Preview {
    PremiumUpsellView(
        featureName: "Kanban View",
        featureDescription: "Visualize your tasks as drag-and-drop columns."
    )
    .environment(EntitlementService.shared)
}

import SwiftUI
import StoreKit

struct PremiumUpsellView: View {
    let featureName: String
    let featureDescription: String

    @EnvironmentObject private var subscriptionService: SubscriptionService

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

            if let errorMessage = subscriptionService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                Button("Retry") {
                    Task {
                        await subscriptionService.fetchProducts()
                    }
                }
                .buttonStyle(.bordered)
            }

            if subscriptionService.isLoading {
                ProgressView("Loading subscriptions…")
            } else if subscriptionService.products.isEmpty {
                Button("Load Subscription Options") {
                    Task {
                        await subscriptionService.fetchProducts()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                let subscriptionProducts = subscriptionService.products.filter {
                    ["taskmanager_monthly", "taskmanager_yearly"].contains($0.id)
                }
                let vipProduct = subscriptionService.products.first {
                    $0.id == "taskmanager_vip_purchase"
                }

                VStack(spacing: 10) {
                    ForEach(subscriptionProducts, id: \.id) { product in
                        Button {
                            Task {
                                await subscriptionService.purchase(product)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text(product.displayPrice)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Start Free Trial")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            .padding(12)
                            .liquidGlass(.init(thickness: .ultraThin, variant: .default, cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    if let vipProduct {
                        Divider()
                            .padding(.vertical, 4)

                        Button {
                            Task {
                                await subscriptionService.purchase(vipProduct)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(vipProduct.displayName)
                                            .font(.headline)
                                        Text("One-Time")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.yellow.opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Text(vipProduct.displayPrice + " — lifetime access")
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
                    }
                }
            }

            Button("Restore Purchases") {
                Task {
                    await subscriptionService.restorePurchases()
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: 420)
        .task {
            if subscriptionService.products.isEmpty {
                await subscriptionService.fetchProducts()
            }
        }
    }
}

#Preview {
    PremiumUpsellView(
        featureName: "Kanban View",
        featureDescription: "Visualize your tasks as drag-and-drop columns."
    )
    .environmentObject(SubscriptionService.shared)
}

import SwiftUI

struct PremiumFeatureModifier: ViewModifier {
    @EnvironmentObject private var subscriptionService: SubscriptionService

    let featureName: String
    let featureDescription: String
    let presentationStyle: PremiumPresentationStyle

    @State private var showUpsellSheet = false

    func body(content: Content) -> some View {
        switch presentationStyle {
        case .inline:
            Group {
                if subscriptionService.hasFullAccess {
                    content
                } else {
                    PremiumUpsellView(
                        featureName: featureName,
                        featureDescription: featureDescription
                    )
                }
            }
        case .sheet:
            content
                .onTapGesture {
                    if !subscriptionService.hasFullAccess {
                        showUpsellSheet = true
                    }
                }
                .sheet(isPresented: $showUpsellSheet) {
                    PremiumUpsellView(
                        featureName: featureName,
                        featureDescription: featureDescription
                    )
                }
        }
    }
}

enum PremiumPresentationStyle {
    case inline
    case sheet
}

extension View {
    func premiumGated(
        feature featureName: String,
        description featureDescription: String,
        style presentationStyle: PremiumPresentationStyle = .inline
    ) -> some View {
        modifier(
            PremiumFeatureModifier(
                featureName: featureName,
                featureDescription: featureDescription,
                presentationStyle: presentationStyle
            )
        )
    }
}

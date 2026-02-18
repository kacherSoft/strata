import SwiftUI
import SwiftData

extension View {
    func withAppEnvironment(container: ModelContainer) -> some View {
        self
            .modelContainer(container)
            .environmentObject(SubscriptionService.shared)
    }
}

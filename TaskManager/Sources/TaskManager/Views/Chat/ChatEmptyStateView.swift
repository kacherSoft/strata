import SwiftUI

/// Lightweight placeholder shown in the message area when a session has no messages yet.
struct ChatEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor.opacity(0.5))
            Text("What can I help you with?")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

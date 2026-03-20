import SwiftUI

/// Floating capsule button shown above input area during streaming to cancel generation.
struct StopGenerationButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Stop generating", systemImage: "stop.circle.fill")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

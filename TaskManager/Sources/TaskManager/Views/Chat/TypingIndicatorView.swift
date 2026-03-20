import SwiftUI

/// Animated three-dot typing indicator shown while waiting for first streaming token.
/// Matches assistant message layout (avatar + content area).
struct TypingIndicatorView: View {
    @State private var dotIndex = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar matching ChatMessageBubble assistant style
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())

            // Animated dots
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(dotIndex == index ? 1.2 : 0.8)
                        .opacity(dotIndex == index ? 1.0 : 0.35)
                        .animation(.easeInOut(duration: 0.3), value: dotIndex)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 40)
        .onReceive(timer) { _ in
            dotIndex = (dotIndex + 1) % 3
        }
    }
}

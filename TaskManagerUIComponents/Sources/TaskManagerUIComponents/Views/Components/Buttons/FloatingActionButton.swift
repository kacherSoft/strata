import SwiftUI

// MARK: - Floating Action Button (iOS 26 Camera Button Style)
public struct FloatingActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    public init(icon: String, title: String = "New Task", action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

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
            .liquidGlass(.fabButton)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

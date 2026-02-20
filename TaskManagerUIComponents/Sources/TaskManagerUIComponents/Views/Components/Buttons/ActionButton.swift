import SwiftUI

// MARK: - Action Button Component
public struct ActionButton: View {
    let icon: String
    var action: () -> Void

    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .liquidGlass(.circleButton)
        }
        .buttonStyle(.plain)
    }
}

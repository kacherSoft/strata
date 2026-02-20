import SwiftUI

// MARK: - Menu Button Component
public struct MenuButton<Content: View>: View {
    let icon: String
    let content: () -> Content

    public init(icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.content = content
    }

    public var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .liquidGlass(.circleButton)
        }
        .menuStyle(.borderlessButton)
    }
}

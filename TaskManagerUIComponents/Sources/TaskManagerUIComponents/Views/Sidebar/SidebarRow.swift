import SwiftUI

// MARK: - Sidebar Row Component
public struct SidebarRow: View {
    let item: SidebarItem

    public init(item: SidebarItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

            Text(item.title)
                .font(.system(size: 13))

            if item.count > 0 {
                Spacer()

                Text("\(item.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

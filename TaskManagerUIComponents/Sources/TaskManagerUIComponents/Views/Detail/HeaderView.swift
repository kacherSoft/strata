import SwiftUI

// MARK: - Header View with Search
public struct HeaderView: View {
    let title: String
    @Binding var searchText: String
    var onNewTask: () -> Void = {}

    public init(title: String, searchText: Binding<String>, onNewTask: @escaping () -> Void = {}) {
        self.title = title
        self._searchText = searchText
        self.onNewTask = onNewTask
    }

    public var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))

            // Search Bar
            SearchBar(text: $searchText)
                .frame(maxWidth: 280)

            Spacer()

            HStack(spacing: 8) {
                ActionButton(icon: "magnifyingglass") {}
                ActionButton(icon: "line.3.horizontal.decrease.circle") {}
                ActionButton(icon: "ellipsis.circle") {}
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 12)
        // .background(.regularMaterial)
    }
}

import SwiftUI

// MARK: - Sidebar View
public struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?

    public init(selectedItem: Binding<SidebarItem?>) {
        self._selectedItem = selectedItem
    }

    public var body: some View {
        List(selection: $selectedItem) {
            Section("My Work") {
                ForEach(SidebarItem.mainItems) { item in
                    SidebarRow(item: item)
                        .tag(item)
                }
            }

            Section("Lists") {
                ForEach(SidebarItem.listItems) { item in
                    SidebarRow(item: item)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Task Manager")
    }
}

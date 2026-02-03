import SwiftUI

// MARK: - Sidebar Item Model
public struct SidebarItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let icon: String
    public var count: Int

    public init(title: String, icon: String, count: Int = 0) {
        self.title = title
        self.icon = icon
        self.count = count
    }

    public nonisolated(unsafe) static let allTasks = SidebarItem(title: "All Tasks", icon: "tray.full")
    public nonisolated(unsafe) static let today = SidebarItem(title: "Today", icon: "sun.max.fill", count: 3)
    public nonisolated(unsafe) static let upcoming = SidebarItem(title: "Upcoming", icon: "calendar", count: 5)
    public nonisolated(unsafe) static let completed = SidebarItem(title: "Completed", icon: "checkmark.circle")

    public nonisolated(unsafe) static let mainItems = [allTasks, today, upcoming, completed]
    public nonisolated(unsafe) static let listItems = [
        SidebarItem(title: "Personal", icon: "person.fill"),
        SidebarItem(title: "Work", icon: "briefcase.fill"),
        SidebarItem(title: "Shopping", icon: "cart.fill")
    ]
}

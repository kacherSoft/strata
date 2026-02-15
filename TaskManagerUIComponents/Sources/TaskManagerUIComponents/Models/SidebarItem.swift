import SwiftUI

// MARK: - Calendar Filter Mode
public enum CalendarFilterMode: String, CaseIterable, Sendable {
    case all = "All"
    case deadline = "Deadline"
    case created = "Created"
}

// MARK: - Sidebar Item Model
public struct SidebarItem: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let icon: String
    public var count: Int
    public let isTag: Bool

    public init(title: String, icon: String, count: Int = 0, isTag: Bool = false) {
        self.title = title
        self.icon = icon
        self.count = count
        self.isTag = isTag
    }

    public static func tag(_ tagName: String) -> SidebarItem {
        SidebarItem(title: tagName, icon: "tag.fill", isTag: true)
    }

    public static let allTasks = SidebarItem(title: "All Tasks", icon: "tray.full")
    public static let today = SidebarItem(title: "Today", icon: "sun.max.fill")
    public static let upcoming = SidebarItem(title: "Upcoming", icon: "calendar")
    public static let inProgress = SidebarItem(title: "In Progress", icon: "play.circle")
    public static let completed = SidebarItem(title: "Completed", icon: "checkmark.circle")

    public static let mainItems = [allTasks, today, upcoming, inProgress, completed]
}

import Foundation

enum ViewMode: String, CaseIterable, Codable, Sendable {
    case list
    case kanban

    var displayName: String {
        switch self {
        case .list: return "List"
        case .kanban: return "Kanban"
        }
    }

    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .kanban: return "square.grid.3x3"
        }
    }
}

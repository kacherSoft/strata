import Foundation

public enum RecurrenceRule: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
    case weekdays

    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .weekdays: return "Weekdays"
        }
    }
}

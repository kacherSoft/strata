import Foundation

enum RecurrenceRule: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
    case weekdays

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .weekdays: return "Weekdays"
        }
    }

    var iconName: String {
        switch self {
        case .daily: return "sun.max"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .yearly: return "calendar.circle"
        case .weekdays: return "briefcase"
        }
    }

    func nextDate(from date: Date, interval: Int) -> Date {
        let calendar = Calendar.current
        let safeInterval = max(1, interval)

        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: safeInterval, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: safeInterval, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: safeInterval, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: safeInterval, to: date) ?? date
        case .weekdays:
            var next = date
            var weekdayCount = 0
            while weekdayCount < safeInterval {
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
                let weekday = calendar.component(.weekday, from: next)
                if weekday != 1 && weekday != 7 {
                    weekdayCount += 1
                }
            }
            return next
        }
    }
}

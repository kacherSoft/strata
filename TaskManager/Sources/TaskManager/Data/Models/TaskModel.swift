import SwiftData
import Foundation

@Model
final class TaskModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var dueDate: Date?
    var reminderDate: Date?
    var reminderDuration: Double = 1800
    var reminderFireDate: Date?  = nil
    var priority: TaskPriority
    var tags: [String]
    var statusRaw: String = TaskStatus.todo.rawValue
    var completedAt: Date?
    var isToday: Bool
    var hasReminder: Bool
    var photos: [String]
    var isRecurring: Bool = false
    var recurrenceRuleRaw: String?
    var recurrenceInterval: Int = 1
    var budget: Decimal?
    var client: String?
    var effort: Double?
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }
    
    var isCompleted: Bool { status == .completed }
    var isInProgress: Bool { status == .inProgress }

    var recurrenceRule: RecurrenceRule? {
        get { recurrenceRuleRaw.flatMap { RecurrenceRule(rawValue: $0) } }
        set { recurrenceRuleRaw = newValue?.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String = "",
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        reminderDuration: Double = 1800,
        priority: TaskPriority = .medium,
        tags: [String] = [],
        status: TaskStatus = .todo,
        isToday: Bool = false,
        hasReminder: Bool = false,
        photos: [String] = [],
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceInterval: Int = 1,
        budget: Decimal? = nil,
        client: String? = nil,
        effort: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.reminderDuration = reminderDuration
        self.reminderFireDate = nil
        self.priority = priority
        self.tags = tags
        self.statusRaw = status.rawValue
        self.isToday = isToday
        self.hasReminder = hasReminder
        self.photos = photos
        self.isRecurring = isRecurring
        self.recurrenceRuleRaw = recurrenceRule?.rawValue
        self.recurrenceInterval = max(1, recurrenceInterval)
        self.budget = budget
        self.client = client?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : client?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.effort = effort
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortOrder = 0
    }
    
    func setStatus(_ newStatus: TaskStatus) {
        status = newStatus
        if newStatus == .completed {
            completedAt = Date()
        } else {
            completedAt = nil
        }
        updatedAt = Date()
    }
    
    func cycleStatus() {
        switch status {
        case .todo:
            setStatus(.inProgress)
        case .inProgress:
            setStatus(.completed)
        case .completed:
            setStatus(.todo)
        }
    }
    
    func markComplete() {
        setStatus(.completed)
    }
    
    func markIncomplete() {
        setStatus(.todo)
    }
    
    func touch() {
        updatedAt = Date()
    }
}

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case todo
    case inProgress
    case completed
    
    var displayName: String {
        switch self {
        case .todo: return "Todo"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }
}

enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case none
    case low
    case medium
    case high
    case critical
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var sortValue: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .none: return 0
        }
    }
}

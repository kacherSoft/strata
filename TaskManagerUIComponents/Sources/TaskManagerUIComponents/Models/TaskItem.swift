import SwiftUI

// MARK: - Task Item Model
public struct TaskItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let notes: String
    public var status: Status
    public var isToday: Bool
    public let priority: Priority
    public let hasReminder: Bool
    public let reminderDuration: TimeInterval
    public let reminderFireDate: Date?
    public let dueDate: Date?
    public let tags: [String]
    public let photos: [URL]
    public let createdAt: Date?
    public let isRecurring: Bool
    public let recurrenceRule: RecurrenceRule?
    public let recurrenceInterval: Int
    public let customFieldEntries: [CustomFieldEntry]
    
    public enum Status: String, CaseIterable, Sendable {
        case todo = "Todo"
        case inProgress = "In Progress"
        case completed = "Completed"
    }

    public enum Priority: Sendable {
        case high, medium, low, none
    }
    
    public var isCompleted: Bool { status == .completed }
    public var isInProgress: Bool { status == .inProgress }

    public var isReminderActive: Bool {
        guard hasReminder, let fireDate = reminderFireDate else { return false }
        return fireDate > Date()
    }

    public var isReminderOverdue: Bool {
        guard hasReminder, let fireDate = reminderFireDate else { return false }
        return fireDate <= Date()
    }

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        status: Status = .todo,
        isToday: Bool,
        priority: Priority,
        hasReminder: Bool,
        reminderDuration: TimeInterval = 1800,
        reminderFireDate: Date? = nil,
        dueDate: Date?,
        tags: [String],
        photos: [URL] = [],
        createdAt: Date? = nil,
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceInterval: Int = 1,
        customFieldEntries: [CustomFieldEntry] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.isToday = isToday
        self.priority = priority
        self.hasReminder = hasReminder
        self.reminderDuration = reminderDuration
        self.reminderFireDate = reminderFireDate
        self.dueDate = dueDate
        self.tags = tags
        self.photos = photos
        self.createdAt = createdAt
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.recurrenceInterval = max(1, recurrenceInterval)
        self.customFieldEntries = customFieldEntries
    }
    
    // Legacy initializer for compatibility
    public init(
        id: UUID = UUID(),
        title: String,
        notes: String,
        isCompleted: Bool,
        isToday: Bool,
        priority: Priority,
        hasReminder: Bool,
        dueDate: Date?,
        tags: [String],
        photos: [URL] = [],
        createdAt: Date? = nil,
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        recurrenceInterval: Int = 1,
        customFieldEntries: [CustomFieldEntry] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = isCompleted ? .completed : .todo
        self.isToday = isToday
        self.priority = priority
        self.hasReminder = hasReminder
        self.reminderDuration = 1800
        self.reminderFireDate = nil
        self.dueDate = dueDate
        self.tags = tags
        self.photos = photos
        self.createdAt = createdAt
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.recurrenceInterval = max(1, recurrenceInterval)
        self.customFieldEntries = customFieldEntries
    }

    public static let sampleTasks = [
        TaskItem(
            title: "Design system components",
            notes: "Create reusable UI components with liquid glass effect",
            isCompleted: false,
            isToday: true,
            priority: .high,
            hasReminder: true,
            dueDate: Calendar.current.date(byAdding: .day, value: 0, to: Date()),
            tags: ["design", "ui"]
        ),
        TaskItem(
            title: "Review API documentation",
            notes: "Check latest endpoints and update integration",
            isCompleted: false,
            isToday: true,
            priority: .medium,
            hasReminder: false,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            tags: ["backend", "api"]
        ),
        TaskItem(
            title: "Setup dark mode support",
            notes: "Ensure all components work in both light and dark mode",
            isCompleted: false,
            isToday: true,
            priority: .high,
            hasReminder: true,
            dueDate: Date(),
            tags: ["ui", "accessibility"]
        ),
        TaskItem(
            title: "Write unit tests",
            notes: "Add test coverage for core components",
            isCompleted: false,
            isToday: false,
            priority: .low,
            hasReminder: false,
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            tags: ["testing"]
        ),
        TaskItem(
            title: "Update dependencies",
            notes: "Update all Swift packages to latest versions",
            isCompleted: true,
            isToday: false,
            priority: .none,
            hasReminder: false,
            dueDate: nil,
            tags: ["maintenance"]
        ),
        TaskItem(
            title: "Multi-line notes test",
            notes: "This task has multi-line notes to test expand/collapse.\n\nSecond paragraph with more details here.\n\nKey points:\n- First item to remember\n- Second item to track\n- Third item to complete",
            isCompleted: false,
            isToday: false,
            priority: .medium,
            hasReminder: false,
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()),
            tags: ["testing", "ui"]
        ),
        TaskItem(
            title: "Photo attachments test",
            notes: "Testing the photo thumbnail strip with two attached images.",
            isCompleted: false,
            isToday: true,
            priority: .high,
            hasReminder: true,
            dueDate: Date(),
            tags: ["testing", "photos"],
            photos: []
        )
    ]
}

// MARK: - Priority Color Helper
public func priorityColor(_ priority: TaskItem.Priority) -> Color {
    switch priority {
    case .high: return .red
    case .medium: return .orange
    case .low: return .blue
    case .none: return .secondary.opacity(0.5)
    }
}

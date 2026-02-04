import SwiftData
import Foundation

@Model
final class TaskModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var dueDate: Date?
    var reminderDate: Date?
    var priority: TaskPriority
    var tags: [String]
    var isCompleted: Bool
    var completedDate: Date?
    var isToday: Bool
    var hasReminder: Bool
    var photos: [String]
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    
    init(
        title: String,
        taskDescription: String = "",
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        priority: TaskPriority = .medium,
        tags: [String] = [],
        isToday: Bool = false,
        hasReminder: Bool = false,
        photos: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.priority = priority
        self.tags = tags
        self.isCompleted = false
        self.isToday = isToday
        self.hasReminder = hasReminder
        self.photos = photos
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sortOrder = 0
    }
    
    func markComplete() {
        isCompleted = true
        completedDate = Date()
        updatedAt = Date()
    }
    
    func markIncomplete() {
        isCompleted = false
        completedDate = nil
        updatedAt = Date()
    }
    
    func touch() {
        updatedAt = Date()
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

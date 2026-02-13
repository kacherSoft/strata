import Foundation
import TaskManagerUIComponents

extension TaskModel {
    func toTaskItem() -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            notes: taskDescription,
            status: status.toUIComponentStatus(),
            isToday: isToday,
            priority: priority.toUIComponentPriority(),
            hasReminder: hasReminder,
            reminderDuration: reminderDuration,
            reminderFireDate: reminderFireDate,
            dueDate: dueDate,
            tags: tags,
            photos: photos.map { URL(fileURLWithPath: $0) },
            createdAt: createdAt
        )
    }
}

extension TaskStatus {
    func toUIComponentStatus() -> TaskItem.Status {
        switch self {
        case .todo: return .todo
        case .inProgress: return .inProgress
        case .completed: return .completed
        }
    }
    
    static func from(_ status: TaskItem.Status) -> TaskStatus {
        switch status {
        case .todo: return .todo
        case .inProgress: return .inProgress
        case .completed: return .completed
        }
    }
}

extension TaskPriority {
    func toUIComponentPriority() -> TaskItem.Priority {
        switch self {
        case .critical, .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .none: return .none
        }
    }
    
    static func from(_ priority: TaskItem.Priority) -> TaskPriority {
        switch priority {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .none: return .none
        }
    }
}

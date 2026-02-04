import Foundation
import TaskManagerUIComponents

extension TaskModel {
    func toTaskItem() -> TaskItem {
        TaskItem(
            id: id,
            title: title,
            notes: taskDescription,
            isCompleted: isCompleted,
            isToday: isToday,
            priority: priority.toUIComponentPriority(),
            hasReminder: hasReminder,
            dueDate: dueDate,
            tags: tags,
            photos: photos.compactMap { URL(string: $0) }
        )
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

import SwiftUI

// MARK: - Task List View
public struct TaskListView: View {
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?
    
    let onToggleComplete: ((TaskItem) -> Void)?
    let onEdit: ((TaskItem, String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void)?
    let onDelete: ((TaskItem) -> Void)?
    let onPriorityChange: ((TaskItem, TaskItem.Priority) -> Void)?
    let onAddPhotos: ((TaskItem, [URL]) -> Void)?
    let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    let onDeletePhoto: ((URL) -> Void)?
    let onSetReminder: ((TaskItem) -> Void)?
    let calendarFilterDate: Date?
    let calendarFilterMode: CalendarFilterMode

    public init(
        tasks: [TaskItem],
        selectedTask: Binding<TaskItem?>,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all
    ) {
        self.tasks = tasks
        self._selectedTask = selectedTask
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self.onToggleComplete = nil
        self.onEdit = nil
        self.onDelete = nil
        self.onPriorityChange = nil
        self.onAddPhotos = nil
        self.onPickPhotos = nil
        self.onDeletePhoto = nil
        self.onSetReminder = nil
    }
    
    public init(
        tasks: [TaskItem],
        selectedTask: Binding<TaskItem?>,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        onToggleComplete: @escaping (TaskItem) -> Void,
        onEdit: @escaping (TaskItem, String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onPriorityChange: @escaping (TaskItem, TaskItem.Priority) -> Void,
        onAddPhotos: @escaping (TaskItem, [URL]) -> Void = { _, _ in },
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil,
        onSetReminder: ((TaskItem) -> Void)? = nil
    ) {
        self.tasks = tasks
        self._selectedTask = selectedTask
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self.onToggleComplete = onToggleComplete
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPriorityChange = onPriorityChange
        self.onAddPhotos = onAddPhotos
        self.onPickPhotos = onPickPhotos
        self.onDeletePhoto = onDeletePhoto
        self.onSetReminder = onSetReminder
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    if let onToggleComplete, let onEdit, let onDelete, let onPriorityChange, let onAddPhotos {
                        TaskRow(
                            task: task,
                            isSelected: selectedTask?.id == task.id,
                            calendarFilterDate: calendarFilterDate,
                            calendarFilterMode: calendarFilterMode,
                            onStatusChange: { _ in onToggleComplete(task) },
                            onEdit: { title, notes, dueDate, hasReminder, duration, priority, tags, photos in
                                onEdit(task, title, notes, dueDate, hasReminder, duration, priority, tags, photos)
                            },
                            onDelete: { onDelete(task) },
                            onPriorityChange: { priority in onPriorityChange(task, priority) },
                            onAddPhotos: { urls in onAddPhotos(task, urls) },
                            onPickPhotos: onPickPhotos,
                            onDeletePhoto: onDeletePhoto,
                            onSetReminder: { onSetReminder?(task) }
                        )
                        .onTapGesture { selectedTask = task }
                    } else {
                        TaskRow(task: task, isSelected: selectedTask?.id == task.id, calendarFilterDate: calendarFilterDate, calendarFilterMode: calendarFilterMode)
                            .onTapGesture { selectedTask = task }
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }
}

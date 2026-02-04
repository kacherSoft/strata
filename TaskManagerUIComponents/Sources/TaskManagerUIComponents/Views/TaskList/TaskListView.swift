import SwiftUI

// MARK: - Task List View
public struct TaskListView: View {
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?
    
    let onToggleComplete: ((TaskItem) -> Void)?
    let onEdit: ((TaskItem, String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void)?
    let onDelete: ((TaskItem) -> Void)?
    let onPriorityChange: ((TaskItem, TaskItem.Priority) -> Void)?

    public init(tasks: [TaskItem], selectedTask: Binding<TaskItem?>) {
        self.tasks = tasks
        self._selectedTask = selectedTask
        self.onToggleComplete = nil
        self.onEdit = nil
        self.onDelete = nil
        self.onPriorityChange = nil
    }
    
    public init(
        tasks: [TaskItem],
        selectedTask: Binding<TaskItem?>,
        onToggleComplete: @escaping (TaskItem) -> Void,
        onEdit: @escaping (TaskItem, String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onPriorityChange: @escaping (TaskItem, TaskItem.Priority) -> Void
    ) {
        self.tasks = tasks
        self._selectedTask = selectedTask
        self.onToggleComplete = onToggleComplete
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPriorityChange = onPriorityChange
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    if let onToggleComplete, let onEdit, let onDelete, let onPriorityChange {
                        TaskRow(
                            task: task,
                            isSelected: selectedTask?.id == task.id,
                            onToggleComplete: { onToggleComplete(task) },
                            onEdit: { title, notes, dueDate, hasReminder, priority, tags in
                                onEdit(task, title, notes, dueDate, hasReminder, priority, tags)
                            },
                            onDelete: { onDelete(task) },
                            onPriorityChange: { priority in onPriorityChange(task, priority) }
                        )
                        .onTapGesture { selectedTask = task }
                    } else {
                        TaskRow(task: task, isSelected: selectedTask?.id == task.id)
                            .onTapGesture { selectedTask = task }
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }
}

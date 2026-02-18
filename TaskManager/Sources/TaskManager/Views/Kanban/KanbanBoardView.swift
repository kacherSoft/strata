import SwiftUI
import TaskManagerUIComponents

struct KanbanBoardView: View {
    let tasks: [TaskItem]
    let onStatusChange: (UUID, TaskStatus) -> Void
    let onTaskSelect: (TaskItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KanbanColumnView(
                title: "To Do",
                status: .todo,
                tasks: tasks.filter { $0.status == .todo },
                onTaskDrop: onStatusChange,
                onTaskSelect: onTaskSelect
            )

            KanbanColumnView(
                title: "In Progress",
                status: .inProgress,
                tasks: tasks.filter { $0.status == .inProgress },
                onTaskDrop: onStatusChange,
                onTaskSelect: onTaskSelect
            )

            KanbanColumnView(
                title: "Done",
                status: .completed,
                tasks: tasks.filter { $0.status == .completed },
                onTaskDrop: onStatusChange,
                onTaskSelect: onTaskSelect
            )
        }
        .padding(12)
    }
}

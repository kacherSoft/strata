import SwiftUI

// MARK: - Task List View
public struct TaskListView: View {
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?

    public init(tasks: [TaskItem], selectedTask: Binding<TaskItem?>) {
        self.tasks = tasks
        self._selectedTask = selectedTask
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskRow(task: task, isSelected: selectedTask?.id == task.id)
                        .onTapGesture {
                            selectedTask = task
                        }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }
}

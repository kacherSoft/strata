import SwiftUI
import UniformTypeIdentifiers
import TaskManagerUIComponents

struct KanbanColumnView: View {
    let title: String
    let status: TaskStatus
    let tasks: [TaskItem]
    let onTaskDrop: (UUID, TaskStatus) -> Void
    let onTaskSelect: (TaskItem) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)

                Text("\(tasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .liquidGlass(.badge)

                Spacer()
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if tasks.isEmpty {
                        Text("No tasks")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(tasks) { task in
                            KanbanCardView(task: task) {
                                onTaskSelect(task)
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.9).combined(with: .opacity)
                            ))
                            .id("\(task.id.uuidString)-\(task.status.rawValue)")
                        }
                    }
                }
                .padding(.vertical, 4)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tasks.map(\.id))
            }
        }
        .padding(12)
        .liquidGlass(.kanbanColumn, isHighlighted: isTargeted)
        .contentShape(Rectangle())
        .onDrop(of: [.plainText], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
                return false
            }

            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let idValue = object as? String,
                      let taskID = UUID(uuidString: idValue) else {
                    return
                }

                DispatchQueue.main.async {
                    onTaskDrop(taskID, status)
                }
            }

            return true
        }
    }
}

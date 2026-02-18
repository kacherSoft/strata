import SwiftUI
import TaskManagerUIComponents

struct KanbanCardView: View {
    let task: TaskItem
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        cardContent
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture(perform: onSelect)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.16)) {
                    isHovered = hovering
                }
            }
            .scaleEffect(isHovered ? 1.01 : 1)
            .onDrag {
                NSItemProvider(object: task.id.uuidString as NSString)
            } preview: {
                cardContent
                    .frame(width: 220)
            }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 8) {
                Circle()
                    .fill(priorityColor(task.priority))
                    .frame(width: 8, height: 8)

                if let dueDate = task.dueDate {
                    Text(dueDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No due date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}

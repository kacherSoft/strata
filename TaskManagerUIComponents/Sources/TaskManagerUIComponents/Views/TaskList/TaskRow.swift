import SwiftUI

// MARK: - Task Row Component
public struct TaskRow: View {
    let task: TaskItem
    let isSelected: Bool
    @State private var isExpanded = false
    @State private var showEditSheet = false

    public init(task: TaskItem, isSelected: Bool) {
        self.task = task
        self.isSelected = isSelected
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Main Row Content
            HStack(spacing: 16) {
                // Checkbox
                Button(action: {}) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(task.isCompleted ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                // Task Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 13))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)

                    // Notes (expandable)
                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    // Tags
                    if !task.tags.isEmpty {
                        TagCloud(tags: task.tags)
                    }

                    HStack(spacing: 8) {
                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: task.isToday ? "calendar.badge.clock" : "calendar")
                                Text(dueDate, style: .date)
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(task.isToday ? .orange : .secondary)
                        }

                        if task.hasReminder {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Priority Indicator
                PriorityIndicator(priority: task.priority)
            }

            // Action Buttons (only when selected)
            if isSelected {
                HStack(spacing: 12) {
                    ActionButton(icon: "bubble.left.and.bubble.right") {}
                    ActionButton(icon: "paperclip") {}
                    Divider()
                        .frame(height: 20)
                    ActionButton(icon: "pencil") { showEditSheet = true }
                    ActionButton(icon: "flag") {}
                    ActionButton(icon: "trash") {}
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(isSelected ? .thinMaterial : .ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: isSelected ? 2 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .onChange(of: isSelected) { _, newValue in
            withAnimation(.spring(response: 0.3)) {
                isExpanded = newValue
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditTaskSheet(task: task, isPresented: $showEditSheet)
        }
    }
}

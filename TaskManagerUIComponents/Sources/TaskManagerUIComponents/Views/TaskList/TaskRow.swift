import SwiftUI

// MARK: - Task Row Component
public struct TaskRow: View {
    let task: TaskItem
    let isSelected: Bool
    let onToggleComplete: (() -> Void)?
    let onEdit: ((String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void)?
    let onDelete: (() -> Void)?
    let onPriorityChange: ((TaskItem.Priority) -> Void)?
    
    @State private var isExpanded = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var currentPriority: TaskItem.Priority

    public init(task: TaskItem, isSelected: Bool) {
        self.task = task
        self.isSelected = isSelected
        self._currentPriority = State(initialValue: task.priority)
        self.onToggleComplete = nil
        self.onEdit = nil
        self.onDelete = nil
        self.onPriorityChange = nil
    }
    
    public init(
        task: TaskItem,
        isSelected: Bool,
        onToggleComplete: @escaping () -> Void,
        onEdit: @escaping (String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void,
        onDelete: @escaping () -> Void,
        onPriorityChange: @escaping (TaskItem.Priority) -> Void
    ) {
        self.task = task
        self.isSelected = isSelected
        self._currentPriority = State(initialValue: task.priority)
        self.onToggleComplete = onToggleComplete
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPriorityChange = onPriorityChange
    }

    private func cyclePriority() {
        switch currentPriority {
        case .none: currentPriority = .low
        case .low: currentPriority = .medium
        case .medium: currentPriority = .high
        case .high: currentPriority = .none
        }
        onPriorityChange?(currentPriority)
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Main Row Content
            HStack(alignment: .top, spacing: 16) {
                // Checkbox
                Button(action: { onToggleComplete?() }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(task.isCompleted ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                // Task Info (title, notes, photos)
                VStack(alignment: .leading, spacing: 8) {
                    // Title
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

                    // Photos thumbnail strip
                    if !task.photos.isEmpty {
                        PhotoThumbnailStrip(photos: task.photos)
                    }
                }

                Spacer()

                // Priority flag (always visible, aligned to right edge)
                Button(action: cyclePriority) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(priorityColor(currentPriority))
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }

            // Bottom Row: Metadata (left) + Action Buttons (right, when selected)
            HStack(alignment: .center) {
                // Left side: Tags, Due Date, Reminder (always visible)
                HStack(spacing: 12) {
                    // Tags
                    if !task.tags.isEmpty {
                        TagCloud(tags: task.tags)
                    }

                    // Due date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: task.isToday ? "calendar.badge.clock" : "calendar")
                            Text(dueDate, style: .date)
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(task.isToday ? .orange : .secondary)
                    }

                    // Reminder
                    if task.hasReminder {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Right side: Action Buttons (only when selected)
                if isSelected {
                    HStack(spacing: 12) {
                        ActionButton(icon: "paperclip") {}
                        Divider()
                            .frame(height: 20)
                        ActionButton(icon: "pencil") { showEditSheet = true }
                        ActionButton(icon: "trash") { showDeleteConfirmation = true }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
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
        .onChange(of: task.priority) { _, newPriority in
            currentPriority = newPriority
        }
        .sheet(isPresented: $showEditSheet) {
            if let onEdit, let onDelete {
                EditTaskSheet(
                    task: task,
                    isPresented: $showEditSheet,
                    onSave: onEdit,
                    onDelete: onDelete
                )
            } else {
                EditTaskSheet(task: task, isPresented: $showEditSheet)
            }
        }
        .confirmationDialog(
            "Delete Task?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(task.title)\"? This action cannot be undone.")
        }
    }
}

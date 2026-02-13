import SwiftUI

// MARK: - Task Row Component
public struct TaskRow: View {
    let task: TaskItem
    let isSelected: Bool
    let onToggleComplete: (() -> Void)?
    let onStatusChange: ((TaskItem.Status) -> Void)?
    let onEdit: ((String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void)?
    let onDelete: (() -> Void)?
    let onPriorityChange: ((TaskItem.Priority) -> Void)?
    let onAddPhotos: (([URL]) -> Void)?
    let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    let onDeletePhoto: ((URL) -> Void)?
    let onSetReminder: (() -> Void)?
    let calendarFilterDate: Date?
    let calendarFilterMode: CalendarFilterMode
    
    @State private var isExpanded = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var currentPriority: TaskItem.Priority
    @State private var currentStatus: TaskItem.Status

    public init(
        task: TaskItem,
        isSelected: Bool,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all
    ) {
        self.task = task
        self.isSelected = isSelected
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self._currentPriority = State(initialValue: task.priority)
        self._currentStatus = State(initialValue: task.status)
        self.onToggleComplete = nil
        self.onStatusChange = nil
        self.onEdit = nil
        self.onDelete = nil
        self.onPriorityChange = nil
        self.onAddPhotos = nil
        self.onPickPhotos = nil
        self.onDeletePhoto = nil
        self.onSetReminder = nil
    }
    
    public init(
        task: TaskItem,
        isSelected: Bool,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        onToggleComplete: @escaping () -> Void,
        onEdit: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void,
        onDelete: @escaping () -> Void,
        onPriorityChange: @escaping (TaskItem.Priority) -> Void
    ) {
        self.task = task
        self.isSelected = isSelected
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self._currentPriority = State(initialValue: task.priority)
        self._currentStatus = State(initialValue: task.status)
        self.onToggleComplete = onToggleComplete
        self.onStatusChange = nil
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPriorityChange = onPriorityChange
        self.onAddPhotos = nil
        self.onPickPhotos = nil
        self.onDeletePhoto = nil
        self.onSetReminder = nil
    }
    
    public init(
        task: TaskItem,
        isSelected: Bool,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        onStatusChange: @escaping (TaskItem.Status) -> Void,
        onEdit: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void,
        onDelete: @escaping () -> Void,
        onPriorityChange: @escaping (TaskItem.Priority) -> Void,
        onAddPhotos: @escaping ([URL]) -> Void,
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil,
        onSetReminder: (() -> Void)? = nil
    ) {
        self.task = task
        self.isSelected = isSelected
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self._currentPriority = State(initialValue: task.priority)
        self._currentStatus = State(initialValue: task.status)
        self.onToggleComplete = nil
        self.onStatusChange = onStatusChange
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onPriorityChange = onPriorityChange
        self.onAddPhotos = onAddPhotos
        self.onPickPhotos = onPickPhotos
        self.onDeletePhoto = onDeletePhoto
        self.onSetReminder = onSetReminder
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
    
    private func cycleStatus() {
        switch currentStatus {
        case .todo: currentStatus = .inProgress
        case .inProgress: currentStatus = .completed
        case .completed: currentStatus = .todo
        }
        onStatusChange?(currentStatus)
        onToggleComplete?()
    }
    
    private var statusIcon: String {
        switch currentStatus {
        case .todo: return "circle"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch currentStatus {
        case .todo: return .secondary
        case .inProgress: return .orange
        case .completed: return .blue
        }
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Main Row Content
            HStack(alignment: .top, spacing: 16) {
                // Status Checkbox (cycles: todo -> inProgress -> completed -> todo)
                Button(action: cycleStatus) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(statusColor)
                }
                .buttonStyle(.plain)
                .help("Click to cycle status: Todo → In Progress → Completed")

                // Task Info (title, notes, photos)
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 13))
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)
                        
                        if let filterDate = calendarFilterDate {
                            let calendar = Calendar.current
                            let isCreated = task.createdAt.map { calendar.isDate($0, inSameDayAs: filterDate) } ?? false
                            let isDeadline = task.dueDate.map { calendar.isDate($0, inSameDayAs: filterDate) } ?? false
                            
                            if isDeadline && (calendarFilterMode == .all || calendarFilterMode == .deadline) {
                                Text("Deadline")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.red.opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
                            }
                            if isCreated && (calendarFilterMode == .all || calendarFilterMode == .created) {
                                Text("Created")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }

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
                        HStack(spacing: 3) {
                            Image(systemName: task.isReminderActive ? "bell.badge.fill" : "bell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(task.isReminderActive ? .orange : .secondary)
                            if task.isReminderActive, let fireDate = task.reminderFireDate {
                                Text(fireDate, style: .relative)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Spacer()

                // Right side: Action Buttons (only when selected)
                if isSelected {
                    HStack(spacing: 12) {
                        if task.hasReminder {
                            ActionButton(icon: task.isReminderActive ? "bell.slash" : "bell.badge") {
                                onSetReminder?()
                            }
                            .help(task.isReminderActive ? "Cancel reminder" : "Start reminder timer")
                        }
                        ActionButton(icon: "paperclip") { onAddPhotos?([]) }
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
        .onChange(of: task.status) { _, newStatus in
            currentStatus = newStatus
        }
        .sheet(isPresented: $showEditSheet) {
            if let onEdit, let onDelete {
                EditTaskSheet(
                    task: task,
                    isPresented: $showEditSheet,
                    onSave: onEdit,
                    onDelete: onDelete,
                    onPickPhotos: onPickPhotos,
                    onDeletePhoto: onDeletePhoto
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

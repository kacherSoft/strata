import SwiftUI

// MARK: - Task Row Component
public struct TaskRow: View {
    let task: TaskItem
    let isSelected: Bool
    let onToggleComplete: (() -> Void)?
    let onStatusChange: ((TaskItem.Status) -> Void)?
    let onEdit: ((String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, [UUID: CustomFieldEditValue]) -> Void)?
    let onDelete: (() -> Void)?
    let onPriorityChange: ((TaskItem.Priority) -> Void)?
    let onAddPhotos: (([URL]) -> Void)?
    let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    let onDeletePhoto: ((URL) -> Void)?
    let onCreateReminder: ((TimeInterval) -> Void)?
    let onEditReminder: ((TimeInterval) -> Void)?
    let onRemoveReminder: (() -> Void)?
    let onStopAlarm: (() -> Void)?
    let calendarFilterDate: Date?
    let calendarFilterMode: CalendarFilterMode
    let recurringFeatureEnabled: Bool
    let activeCustomFieldDefinitions: [CustomFieldDefinition]
    let availableTags: [String]
    
    @State private var isExpanded = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var currentPriority: TaskItem.Priority
    @State private var currentStatus: TaskItem.Status
    @State private var showReminderPopover = false
    @State private var now = Date()
    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(
        task: TaskItem,
        isSelected: Bool,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        recurringFeatureEnabled: Bool = false,
        activeCustomFieldDefinitions: [CustomFieldDefinition] = [],
        availableTags: [String] = []
    ) {
        self.task = task
        self.isSelected = isSelected
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.activeCustomFieldDefinitions = activeCustomFieldDefinitions
        self.availableTags = availableTags
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
        self.onCreateReminder = nil
        self.onEditReminder = nil
        self.onRemoveReminder = nil
        self.onStopAlarm = nil
    }
    
    public init(
        task: TaskItem,
        isSelected: Bool,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        recurringFeatureEnabled: Bool = false,
        activeCustomFieldDefinitions: [CustomFieldDefinition] = [],
        availableTags: [String] = [],
        onToggleComplete: @escaping () -> Void,
        onEdit: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, [UUID: CustomFieldEditValue]) -> Void,
        onDelete: @escaping () -> Void,
        onPriorityChange: @escaping (TaskItem.Priority) -> Void
    ) {
        self.task = task
        self.isSelected = isSelected
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.activeCustomFieldDefinitions = activeCustomFieldDefinitions
        self.availableTags = availableTags
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
        self.onCreateReminder = nil
        self.onEditReminder = nil
        self.onRemoveReminder = nil
        self.onStopAlarm = nil
    }
    
    public init(
        task: TaskItem,
        isSelected: Bool,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        recurringFeatureEnabled: Bool = false,
        activeCustomFieldDefinitions: [CustomFieldDefinition] = [],
        availableTags: [String] = [],
        onStatusChange: @escaping (TaskItem.Status) -> Void,
        onEdit: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, [UUID: CustomFieldEditValue]) -> Void,
        onDelete: @escaping () -> Void,
        onPriorityChange: @escaping (TaskItem.Priority) -> Void,
        onAddPhotos: @escaping ([URL]) -> Void,
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil,
        onCreateReminder: ((TimeInterval) -> Void)? = nil,
        onEditReminder: ((TimeInterval) -> Void)? = nil,
        onRemoveReminder: (() -> Void)? = nil,
        onStopAlarm: (() -> Void)? = nil
    ) {
        self.task = task
        self.isSelected = isSelected
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.activeCustomFieldDefinitions = activeCustomFieldDefinitions
        self.availableTags = availableTags
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
        self.onCreateReminder = onCreateReminder
        self.onEditReminder = onEditReminder
        self.onRemoveReminder = onRemoveReminder
        self.onStopAlarm = onStopAlarm
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
    
    private var isReminderActiveNow: Bool {
        guard task.hasReminder, let fireDate = task.reminderFireDate else { return false }
        return fireDate > now
    }

    private var isReminderOverdueNow: Bool {
        guard task.hasReminder, let fireDate = task.reminderFireDate else { return false }
        return fireDate <= now
    }

    private var reminderIcon: String {
        if isReminderOverdueNow {
            return "bell.and.waves.left.and.right.fill"
        } else if isReminderActiveNow {
            return "bell.badge.fill"
        } else {
            return "bell.fill"
        }
    }

    private var reminderColor: Color {
        if isReminderOverdueNow {
            return .red
        } else if isReminderActiveNow {
            return .orange
        } else {
            return .secondary
        }
    }

    private var reminderHelpText: String {
        if isReminderOverdueNow {
            return "Alarm ringing — click to stop"
        } else if isReminderActiveNow {
            return "Reminder active — click to edit or remove"
        } else {
            return "Set reminder"
        }
    }

    @ViewBuilder
    private var reminderPopoverContent: some View {
        if isReminderActiveNow {
            ReminderActionPopover(
                isPresented: $showReminderPopover,
                currentDuration: task.reminderDuration,
                mode: .edit,
                onSetDuration: { duration in
                    onEditReminder?(duration)
                },
                onRemoveReminder: {
                    onRemoveReminder?()
                }
            )
        } else {
            ReminderActionPopover(
                isPresented: $showReminderPopover,
                currentDuration: task.reminderDuration,
                mode: .create,
                onSetDuration: { duration in
                    onCreateReminder?(duration)
                }
            )
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
                        if task.isRecurring {
                            Image(systemName: "arrow.trianglehead.clockwise")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .help("Recurring task")
                        }

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
                        .liquidGlass(.circleButton)
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

                    ForEach(task.customFieldEntries) { entry in
                        let value = entry.displayValue
                        if !value.isEmpty {
                            Text(value)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Right side: Action Buttons
                HStack(spacing: 12) {
                    // Reminder bell — always visible for all tasks
                    Button {
                        if isReminderOverdueNow {
                            // Alarm ringing → stop it
                            onStopAlarm?()
                        } else if isReminderActiveNow {
                            // Active countdown → edit or remove
                            showReminderPopover = true
                        } else {
                            // No reminder → set one up
                            showReminderPopover = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: reminderIcon)
                                .font(.system(size: 13))
                            if isReminderActiveNow, let fireDate = task.reminderFireDate {
                                Text(fireDate, style: .relative)
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .foregroundStyle(reminderColor)
                        .padding(.horizontal, isReminderActiveNow || isReminderOverdueNow ? 8 : 0)
                        .padding(.vertical, isReminderActiveNow || isReminderOverdueNow ? 4 : 0)
                        .liquidGlass(.badge)
                        .background(
                            (isReminderActiveNow || isReminderOverdueNow)
                                ? reminderColor.opacity(0.15) : .clear
                        , in: Capsule())
                        .frame(minWidth: 28, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .help(reminderHelpText)
                    .popover(isPresented: $showReminderPopover) {
                        reminderPopoverContent
                    }

                    // Other action buttons only when selected
                    if isSelected {
                        ActionButton(icon: "paperclip") { onAddPhotos?([]) }
                        Divider()
                            .frame(height: 20)
                        ActionButton(icon: "pencil") { showEditSheet = true }
                        ActionButton(icon: "trash") { showDeleteConfirmation = true }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(16)
        .liquidGlass(isSelected ? .taskRowSelected : .taskRow)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 2)
            }
        }
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
        .onReceive(countdownTimer) { date in
            now = date
        }
        .onDisappear {
            countdownTimer.upstream.connect().cancel()
        }
        .sheet(isPresented: $showEditSheet) {
            if let onEdit, let onDelete {
                EditTaskSheet(
                    task: task,
                    isPresented: $showEditSheet,
                    recurringFeatureEnabled: recurringFeatureEnabled,
                    activeCustomFieldDefinitions: activeCustomFieldDefinitions,
                    initialCustomFieldValues: Dictionary(uniqueKeysWithValues: task.customFieldEntries.map { ($0.id, $0.toEditValue()) }),
                    availableTags: availableTags,
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

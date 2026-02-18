import SwiftUI

// MARK: - Task List View
public struct TaskListView: View {
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?
    
    let onToggleComplete: ((TaskItem) -> Void)?
    let onEdit: ((TaskItem, String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, Decimal?, String?, Double?) -> Void)?
    let onDelete: ((TaskItem) -> Void)?
    let onPriorityChange: ((TaskItem, TaskItem.Priority) -> Void)?
    let onAddPhotos: ((TaskItem, [URL]) -> Void)?
    let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    let onDeletePhoto: ((URL) -> Void)?
    let onCreateReminder: ((TaskItem, TimeInterval) -> Void)?
    let onEditReminder: ((TaskItem, TimeInterval) -> Void)?
    let onRemoveReminder: ((TaskItem) -> Void)?
    let onStopAlarm: ((TaskItem) -> Void)?
    let calendarFilterDate: Date?
    let calendarFilterMode: CalendarFilterMode
    let recurringFeatureEnabled: Bool
    let customFieldsFeatureEnabled: Bool

    public init(
        tasks: [TaskItem],
        selectedTask: Binding<TaskItem?>,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        recurringFeatureEnabled: Bool = false,
        customFieldsFeatureEnabled: Bool = false
    ) {
        self.tasks = tasks
        self._selectedTask = selectedTask
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.customFieldsFeatureEnabled = customFieldsFeatureEnabled
        self.onToggleComplete = nil
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
        tasks: [TaskItem],
        selectedTask: Binding<TaskItem?>,
        calendarFilterDate: Date? = nil,
        calendarFilterMode: CalendarFilterMode = .all,
        recurringFeatureEnabled: Bool = false,
        customFieldsFeatureEnabled: Bool = false,
        onToggleComplete: @escaping (TaskItem) -> Void,
        onEdit: @escaping (TaskItem, String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, Decimal?, String?, Double?) -> Void,
        onDelete: @escaping (TaskItem) -> Void,
        onPriorityChange: @escaping (TaskItem, TaskItem.Priority) -> Void,
        onAddPhotos: @escaping (TaskItem, [URL]) -> Void = { _, _ in },
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil,
        onCreateReminder: ((TaskItem, TimeInterval) -> Void)? = nil,
        onEditReminder: ((TaskItem, TimeInterval) -> Void)? = nil,
        onRemoveReminder: ((TaskItem) -> Void)? = nil,
        onStopAlarm: ((TaskItem) -> Void)? = nil
    ) {
        self.tasks = tasks
        self._selectedTask = selectedTask
        self.calendarFilterDate = calendarFilterDate
        self.calendarFilterMode = calendarFilterMode
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.customFieldsFeatureEnabled = customFieldsFeatureEnabled
        self.onToggleComplete = onToggleComplete
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
                            recurringFeatureEnabled: recurringFeatureEnabled,
                            customFieldsFeatureEnabled: customFieldsFeatureEnabled,
                            onStatusChange: { _ in onToggleComplete(task) },
                            onEdit: { title, notes, dueDate, hasReminder, duration, priority, tags, photos, isRecurring, recurrenceRule, recurrenceInterval, budget, client, effort in
                                onEdit(task, title, notes, dueDate, hasReminder, duration, priority, tags, photos, isRecurring, recurrenceRule, recurrenceInterval, budget, client, effort)
                            },
                            onDelete: { onDelete(task) },
                            onPriorityChange: { priority in onPriorityChange(task, priority) },
                            onAddPhotos: { urls in onAddPhotos(task, urls) },
                            onPickPhotos: onPickPhotos,
                            onDeletePhoto: onDeletePhoto,
                            onCreateReminder: { duration in onCreateReminder?(task, duration) },
                            onEditReminder: { duration in onEditReminder?(task, duration) },
                            onRemoveReminder: { onRemoveReminder?(task) },
                            onStopAlarm: { onStopAlarm?(task) }
                        )
                        .onTapGesture { selectedTask = task }
                    } else {
                        TaskRow(task: task, isSelected: selectedTask?.id == task.id, calendarFilterDate: calendarFilterDate, calendarFilterMode: calendarFilterMode, recurringFeatureEnabled: recurringFeatureEnabled, customFieldsFeatureEnabled: customFieldsFeatureEnabled)
                            .onTapGesture { selectedTask = task }
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }
}

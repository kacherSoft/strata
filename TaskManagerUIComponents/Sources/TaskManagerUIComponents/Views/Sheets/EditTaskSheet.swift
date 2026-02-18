import SwiftUI

// MARK: - Edit Task Sheet
public struct EditTaskSheet: View {
    let task: TaskItem
    @Binding var isPresented: Bool
    @State private var taskTitle: String
    @State private var taskNotes: String
    @State private var selectedDate: Date?
    @State private var hasDate: Bool
    @State private var hasReminder: Bool
    @State private var reminderDuration: TimeInterval
    @State private var selectedPriority: TaskItem.Priority
    @State private var tags: [String]
    @State private var showValidationError = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var photos: [URL]
    @State private var isRecurring: Bool
    @State private var recurrenceRule: RecurrenceRule
    @State private var recurrenceInterval: Int
    @State private var budget: Decimal?
    @State private var client: String
    @State private var effortHours: Double?
    
    private let onSave: ((String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, Decimal?, String?, Double?) -> Void)?
    private let onDelete: (() -> Void)?
    private let recurringFeatureEnabled: Bool
    private let customFieldsFeatureEnabled: Bool
    private let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    private let onDeletePhoto: ((URL) -> Void)?

    public init(task: TaskItem, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        _taskTitle = State(initialValue: task.title)
        _taskNotes = State(initialValue: task.notes)
        _selectedDate = State(initialValue: task.dueDate)
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasReminder = State(initialValue: task.hasReminder)
        _reminderDuration = State(initialValue: task.reminderDuration)
        _selectedPriority = State(initialValue: task.priority)
        _tags = State(initialValue: task.tags)
        _photos = State(initialValue: task.photos)
        _isRecurring = State(initialValue: task.isRecurring)
        _recurrenceRule = State(initialValue: task.recurrenceRule ?? .weekly)
        _recurrenceInterval = State(initialValue: max(1, task.recurrenceInterval))
        _budget = State(initialValue: task.budget)
        _client = State(initialValue: task.client ?? "")
        _effortHours = State(initialValue: task.effort)
        self.onSave = nil
        self.onDelete = nil
        self.recurringFeatureEnabled = false
        self.customFieldsFeatureEnabled = false
        self.onPickPhotos = nil
        self.onDeletePhoto = nil
    }
    
    public init(
        task: TaskItem,
        isPresented: Binding<Bool>,
        recurringFeatureEnabled: Bool = false,
        customFieldsFeatureEnabled: Bool = false,
        onSave: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, Decimal?, String?, Double?) -> Void,
        onDelete: @escaping () -> Void,
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil
    ) {
        self.task = task
        self._isPresented = isPresented
        _taskTitle = State(initialValue: task.title)
        _taskNotes = State(initialValue: task.notes)
        _selectedDate = State(initialValue: task.dueDate)
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasReminder = State(initialValue: task.hasReminder)
        _reminderDuration = State(initialValue: task.reminderDuration)
        _selectedPriority = State(initialValue: task.priority)
        _tags = State(initialValue: task.tags)
        _photos = State(initialValue: task.photos)
        _isRecurring = State(initialValue: task.isRecurring)
        _recurrenceRule = State(initialValue: task.recurrenceRule ?? .weekly)
        _recurrenceInterval = State(initialValue: max(1, task.recurrenceInterval))
        _budget = State(initialValue: task.budget)
        _client = State(initialValue: task.client ?? "")
        _effortHours = State(initialValue: task.effort)
        self.onSave = onSave
        self.onDelete = onDelete
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.customFieldsFeatureEnabled = customFieldsFeatureEnabled
        self.onPickPhotos = onPickPhotos
        self.onDeletePhoto = onDeletePhoto
    }
    
    private func validateAndSave() {
        if taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showValidationError = true
            return
        }
        showSaveConfirmation = true
    }
    
    private var normalizedClient: String? {
        let value = client.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func performSave() {
        let effectiveRecurring = recurringFeatureEnabled ? isRecurring : task.isRecurring
        let effectiveRule = recurringFeatureEnabled ? recurrenceRule : (task.recurrenceRule ?? .weekly)
        let effectiveInterval = recurringFeatureEnabled ? recurrenceInterval : max(1, task.recurrenceInterval)
        let effectiveBudget = customFieldsFeatureEnabled ? budget : task.budget
        let effectiveClient = customFieldsFeatureEnabled ? normalizedClient : task.client
        let effectiveEffort = customFieldsFeatureEnabled ? effortHours : task.effort

        onSave?(
            taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            taskNotes,
            hasDate ? selectedDate : nil,
            hasReminder,
            reminderDuration,
            selectedPriority,
            tags,
            photos,
            effectiveRecurring,
            effectiveRule,
            effectiveInterval,
            effectiveBudget,
            effectiveClient,
            effectiveEffort
        )
        isPresented = false
    }

    public var body: some View {
        NavigationStack {
            TaskFormContent(
                taskTitle: $taskTitle,
                taskNotes: $taskNotes,
                selectedDate: Binding(
                    get: { selectedDate ?? Date() },
                    set: { selectedDate = $0 }
                ),
                hasDate: $hasDate,
                hasReminder: $hasReminder,
                reminderDuration: $reminderDuration,
                selectedPriority: $selectedPriority,
                tags: $tags,
                showValidationError: $showValidationError,
                photos: $photos,
                isRecurring: $isRecurring,
                recurrenceRule: $recurrenceRule,
                recurrenceInterval: $recurrenceInterval,
                budget: $budget,
                client: $client,
                effortHours: $effortHours,
                recurringFeatureEnabled: recurringFeatureEnabled,
                customFieldsFeatureEnabled: customFieldsFeatureEnabled,
                onPickPhotos: onPickPhotos,
                onDeletePhoto: onDeletePhoto
            )
            .navigationTitle("Edit Task")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        validateAndSave()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        showDeleteConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .confirmationDialog(
                "Delete Task?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    isPresented = false
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete \"\(task.title)\"? This action cannot be undone.")
            }
            .confirmationDialog(
                "Save Changes?",
                isPresented: $showSaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Save Changes") {
                    performSave()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Save changes to \"\(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines))\"?")
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

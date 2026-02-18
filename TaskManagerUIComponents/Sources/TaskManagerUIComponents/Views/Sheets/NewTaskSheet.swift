import SwiftUI

// MARK: - New Task Sheet (for modal sheet presentation)
public struct NewTaskSheet: View {
    @Binding var isPresented: Bool
    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var selectedDate = Date()
    @State private var hasDate = false
    @State private var hasReminder = false
    @State private var reminderDuration: TimeInterval = 1800
    @State private var selectedPriority: TaskItem.Priority = .none
    @State private var tags: [String] = []
    @State private var photos: [URL] = []
    @State private var isRecurring = false
    @State private var recurrenceRule: RecurrenceRule = .weekly
    @State private var recurrenceInterval = 1
    @State private var budget: Decimal?
    @State private var client = ""
    @State private var effortHours: Double?
    @State private var showValidationError = false
    @State private var showCreateConfirmation = false
    
    private let onCreate: ((String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, Decimal?, String?, Double?) -> Void)?
    let recurringFeatureEnabled: Bool
    let customFieldsFeatureEnabled: Bool
    let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    let onDeletePhoto: ((URL) -> Void)?

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.onCreate = nil
        self.recurringFeatureEnabled = false
        self.customFieldsFeatureEnabled = false
        self.onPickPhotos = nil
        self.onDeletePhoto = nil
    }
    
    public init(
        isPresented: Binding<Bool>,
        recurringFeatureEnabled: Bool = false,
        customFieldsFeatureEnabled: Bool = false,
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil,
        onCreate: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, RecurrenceRule, Int, Decimal?, String?, Double?) -> Void
    ) {
        self._isPresented = isPresented
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.customFieldsFeatureEnabled = customFieldsFeatureEnabled
        self.onPickPhotos = onPickPhotos
        self.onDeletePhoto = onDeletePhoto
        self.onCreate = onCreate
    }
    
    private func validateAndCreate() {
        if taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showValidationError = true
            return
        }
        showCreateConfirmation = true
    }
    
    private var normalizedClient: String? {
        let value = client.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func performCreate() {
        let effectiveRecurring = recurringFeatureEnabled ? isRecurring : false

        onCreate?(
            taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            taskNotes,
            hasDate ? selectedDate : nil,
            hasReminder,
            reminderDuration,
            selectedPriority,
            tags,
            photos,
            effectiveRecurring,
            recurrenceRule,
            recurrenceInterval,
            customFieldsFeatureEnabled ? budget : nil,
            customFieldsFeatureEnabled ? normalizedClient : nil,
            customFieldsFeatureEnabled ? effortHours : nil
        )
        isPresented = false
    }

    public var body: some View {
        NavigationStack {
            TaskFormContent(
                taskTitle: $taskTitle,
                taskNotes: $taskNotes,
                selectedDate: $selectedDate,
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
            .navigationTitle("New Task")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        validateAndCreate()
                    }
                }
            }
            .confirmationDialog(
                "Create Task?",
                isPresented: $showCreateConfirmation,
                titleVisibility: Visibility.visible
            ) {
                Button("Create Task") {
                    performCreate()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Create task \"\(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines))\"?")
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

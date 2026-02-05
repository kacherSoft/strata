import SwiftUI

// MARK: - Quick Entry Content (for floating window presentation)
public struct QuickEntryContent: View {
    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var selectedDate = Date()
    @State private var hasDate = false
    @State private var hasReminder = false
    @State private var selectedPriority: TaskItem.Priority = .none
    @State private var tags: [String] = []
    @State private var showValidationError = false
    @State private var showCreateConfirmation = false
    
    public var onCancel: () -> Void
    public var onCreate: (String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void

    public init(
        onCancel: @escaping () -> Void,
        onCreate: @escaping (String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void
    ) {
        self.onCancel = onCancel
        self.onCreate = onCreate
    }
    
    private func validateAndCreate() {
        if taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showValidationError = true
            return
        }
        showCreateConfirmation = true
    }
    
    private func performCreate() {
        onCreate(
            taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            taskNotes,
            hasDate ? selectedDate : nil,
            hasReminder,
            selectedPriority,
            tags
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Content
            TaskFormContent(
                taskTitle: $taskTitle,
                taskNotes: $taskNotes,
                selectedDate: $selectedDate,
                hasDate: $hasDate,
                hasReminder: $hasReminder,
                selectedPriority: $selectedPriority,
                tags: $tags,
                showValidationError: $showValidationError
            )
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Create") {
                    validateAndCreate()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
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
        .frame(minWidth: 400, minHeight: 450)
    }
}

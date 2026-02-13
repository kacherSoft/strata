import SwiftUI

// MARK: - Quick Entry Content (for floating window presentation)
public struct QuickEntryContent: View {
    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var selectedDate = Date()
    @State private var hasDate = false
    @State private var hasReminder = false
    @State private var reminderDuration: TimeInterval = 1800
    @State private var selectedPriority: TaskItem.Priority = .none
    @State private var tags: [String] = []
    @State private var photos: [URL] = []
    @State private var showValidationError = false
    @State private var showCreateConfirmation = false
    
    public var onCancel: () -> Void
    public var onCreate: (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void
    public var onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    public var onDeletePhoto: ((URL) -> Void)?

    public init(
        onCancel: @escaping () -> Void,
        onCreate: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void,
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil
    ) {
        self.onCancel = onCancel
        self.onCreate = onCreate
        self.onPickPhotos = onPickPhotos
        self.onDeletePhoto = onDeletePhoto
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
            reminderDuration,
            selectedPriority,
            tags,
            photos
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
                reminderDuration: $reminderDuration,
                selectedPriority: $selectedPriority,
                tags: $tags,
                showValidationError: $showValidationError,
                photos: $photos,
                onPickPhotos: onPickPhotos,
                onDeletePhoto: onDeletePhoto
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
        .frame(minWidth: 480, minHeight: 600)
    }
}

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
    @State private var showValidationError = false
    @State private var showCreateConfirmation = false
    
    private let onCreate: ((String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void)?
    let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    let onDeletePhoto: ((URL) -> Void)?

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.onCreate = nil
        self.onPickPhotos = nil
        self.onDeletePhoto = nil
    }
    
    public init(
        isPresented: Binding<Bool>,
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil,
        onCreate: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void
    ) {
        self._isPresented = isPresented
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
    
    private func performCreate() {
        onCreate?(
            taskTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            taskNotes,
            hasDate ? selectedDate : nil,
            hasReminder,
            reminderDuration,
            selectedPriority,
            tags,
            photos
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

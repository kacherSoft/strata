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
    @State private var newTag: String = ""
    @State private var showValidationError = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var showTagConfirmation = false
    @State private var pendingTag = ""
    @State private var photos: [URL]
    
    private let onSave: ((String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void)?
    private let onDelete: (() -> Void)?
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
        self.onSave = nil
        self.onDelete = nil
        self.onPickPhotos = nil
        self.onDeletePhoto = nil
    }
    
    public init(
        task: TaskItem,
        isPresented: Binding<Bool>,
        onSave: @escaping (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void,
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
        self.onSave = onSave
        self.onDelete = onDelete
        self.onPickPhotos = onPickPhotos
        self.onDeletePhoto = onDeletePhoto
    }
    
    private func requestAddTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            newTag = ""
            return
        }
        pendingTag = trimmed
        showTagConfirmation = true
    }
    
    private func confirmAddTag() {
        tags.append(pendingTag)
        newTag = ""
        pendingTag = ""
    }
    
    private func validateAndSave() {
        if taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showValidationError = true
            return
        }
        showSaveConfirmation = true
    }
    
    private func performSave() {
        onSave?(
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
            Form {
                Section("Task Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Task title", text: $taskTitle)
                                .textFieldStyle(.plain)
                            Text("*")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .onChange(of: taskTitle) { _, _ in
                            showValidationError = false
                        }
                        
                        if showValidationError {
                            Label("Title is required", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    TextareaField(
                        text: $taskNotes,
                        placeholder: "Add notes...",
                        height: 100
                    )
                }

                Section("Dates & Reminders") {
                    Toggle("Set Due Date", isOn: $hasDate)

                    if hasDate {
                        DatePicker(
                            "Due Date",
                            selection: Binding(
                                get: { selectedDate ?? Date() },
                                set: { selectedDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }

                    Toggle("Set Reminder", isOn: $hasReminder)

                    if hasReminder {
                        ReminderDurationPicker(duration: $reminderDuration)
                    }
                }

                Section("Priority") {
                    PriorityPicker(selectedPriority: $selectedPriority)
                }
                
                Section("Tags") {
                    HStack {
                        TextField("Add tag (press Enter)", text: $newTag)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                requestAddTag()
                            }

                        Button("Add") {
                            requestAddTag()
                        }
                        .buttonStyle(.borderless)
                        .disabled(newTag.isEmpty)
                    }

                    if !tags.isEmpty {
                        TagCloud(tags: tags, onRemove: { tag in
                            tags.removeAll { $0 == tag }
                        })
                    }
                }
                
                Section("Attachments") {
                    HStack {
                        Button {
                            onPickPhotos? { urls in
                                photos.append(contentsOf: urls)
                            }
                        } label: {
                            Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        if !photos.isEmpty {
                            Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !photos.isEmpty {
                        PhotoThumbnailStrip(
                            photos: photos,
                            onRemove: { url in
                                photos.removeAll { $0 == url }
                                onDeletePhoto?(url)
                            }
                        )
                    }
                }
            }
            .formStyle(.grouped)
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
            .confirmationDialog(
                "Create Tag?",
                isPresented: $showTagConfirmation,
                titleVisibility: .visible
            ) {
                Button("Create \"\(pendingTag)\"") {
                    confirmAddTag()
                }
                Button("Cancel", role: .cancel) {
                    pendingTag = ""
                }
            } message: {
                Text("Create new tag \"\(pendingTag)\" and add it to this task?")
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

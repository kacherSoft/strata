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
    @State private var selectedPriority: TaskItem.Priority
    @State private var tags: [String]
    @State private var newTag: String = ""
    @State private var showValidationError = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var showTagConfirmation = false
    @State private var pendingTag = ""
    
    private let onSave: ((String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void)?
    private let onDelete: (() -> Void)?

    public init(task: TaskItem, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        _taskTitle = State(initialValue: task.title)
        _taskNotes = State(initialValue: task.notes)
        _selectedDate = State(initialValue: task.dueDate)
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasReminder = State(initialValue: task.hasReminder)
        _selectedPriority = State(initialValue: task.priority)
        _tags = State(initialValue: task.tags)
        self.onSave = nil
        self.onDelete = nil
    }
    
    public init(
        task: TaskItem,
        isPresented: Binding<Bool>,
        onSave: @escaping (String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.task = task
        self._isPresented = isPresented
        _taskTitle = State(initialValue: task.title)
        _taskNotes = State(initialValue: task.notes)
        _selectedDate = State(initialValue: task.dueDate)
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasReminder = State(initialValue: task.hasReminder)
        _selectedPriority = State(initialValue: task.priority)
        _tags = State(initialValue: task.tags)
        self.onSave = onSave
        self.onDelete = onDelete
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
            selectedPriority,
            tags
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
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Task")
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

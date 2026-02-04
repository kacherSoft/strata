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

    public var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task title", text: $taskTitle)
                        .textFieldStyle(.plain)

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
                        TextField("Add tag", text: $newTag)
                            .textFieldStyle(.plain)

                        Button("Add") {
                            if !newTag.isEmpty {
                                tags.append(newTag)
                                newTag = ""
                            }
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
                        onSave?(
                            taskTitle,
                            taskNotes,
                            hasDate ? selectedDate : nil,
                            hasReminder,
                            selectedPriority,
                            tags
                        )
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {
                        onDelete?()
                        isPresented = false
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

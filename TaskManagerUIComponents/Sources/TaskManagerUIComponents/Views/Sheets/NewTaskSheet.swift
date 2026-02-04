import SwiftUI

// MARK: - New Task Sheet
public struct NewTaskSheet: View {
    @Binding var isPresented: Bool
    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var selectedDate = Date()
    @State private var hasDate = false
    @State private var hasReminder = false
    @State private var selectedPriority: TaskItem.Priority = .none
    @State private var newTag = ""
    @State private var tags: [String] = []
    @State private var showValidationError = false
    @State private var showCreateConfirmation = false
    @State private var showTagConfirmation = false
    @State private var pendingTag = ""
    
    private let onCreate: ((String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void)?

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self.onCreate = nil
    }
    
    public init(
        isPresented: Binding<Bool>,
        onCreate: @escaping (String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void
    ) {
        self._isPresented = isPresented
        self.onCreate = onCreate
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
                        height: 80
                    )
                }

                Section("Dates & Reminders") {
                    Toggle("Set Due Date", isOn: $hasDate)

                    if hasDate {
                        DatePicker(
                            "Due Date",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }

                    Toggle("Set Reminder", isOn: $hasReminder)

                    if hasReminder && hasDate {
                        DatePicker(
                            "Reminder Time",
                            selection: $selectedDate,
                            displayedComponents: [.hourAndMinute]
                        )
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
            }
            .formStyle(.grouped)
            .navigationTitle("New Task")
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
                titleVisibility: .visible
            ) {
                Button("Create Task") {
                    performCreate()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Create task \"\(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines))\"?")
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

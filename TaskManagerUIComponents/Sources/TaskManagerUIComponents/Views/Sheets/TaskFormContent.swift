import SwiftUI

// MARK: - Task Form Content (Reusable)
public struct TaskFormContent: View {
    @Binding var taskTitle: String
    @Binding var taskNotes: String
    @Binding var selectedDate: Date
    @Binding var hasDate: Bool
    @Binding var hasReminder: Bool
    @Binding var selectedPriority: TaskItem.Priority
    @Binding var tags: [String]
    @Binding var showValidationError: Bool
    
    @State private var newTag = ""
    @State private var showTagConfirmation = false
    @State private var pendingTag = ""
    
    public init(
        taskTitle: Binding<String>,
        taskNotes: Binding<String>,
        selectedDate: Binding<Date>,
        hasDate: Binding<Bool>,
        hasReminder: Binding<Bool>,
        selectedPriority: Binding<TaskItem.Priority>,
        tags: Binding<[String]>,
        showValidationError: Binding<Bool>
    ) {
        self._taskTitle = taskTitle
        self._taskNotes = taskNotes
        self._selectedDate = selectedDate
        self._hasDate = hasDate
        self._hasReminder = hasReminder
        self._selectedPriority = selectedPriority
        self._tags = tags
        self._showValidationError = showValidationError
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
    
    public var body: some View {
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
}

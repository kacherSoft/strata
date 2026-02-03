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

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
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
                        TagCloud(tags: tags)
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
                    Button("Create") { isPresented = false }
                        .disabled(taskTitle.isEmpty)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

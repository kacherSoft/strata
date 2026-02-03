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

    public init(task: TaskItem, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        _taskTitle = State(initialValue: task.title)
        _taskNotes = State(initialValue: task.notes)
        _selectedDate = State(initialValue: task.dueDate)
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasReminder = State(initialValue: task.hasReminder)
        _selectedPriority = State(initialValue: task.priority)
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
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { isPresented = false }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete") {}
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

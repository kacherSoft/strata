import SwiftUI

// MARK: - Task Form Content (Reusable)
public struct TaskFormContent: View {
    @Binding var taskTitle: String
    @Binding var taskNotes: String
    @Binding var selectedDate: Date
    @Binding var hasDate: Bool
    @Binding var hasReminder: Bool
    @Binding var reminderDuration: TimeInterval
    @Binding var selectedPriority: TaskItem.Priority
    @Binding var tags: [String]
    @Binding var showValidationError: Bool
    @Binding var photos: [URL]
    @Binding var isRecurring: Bool
    @Binding var recurrenceRule: RecurrenceRule
    @Binding var recurrenceInterval: Int
    @Binding var budget: Decimal?
    @Binding var client: String
    @Binding var effortHours: Double?
    let recurringFeatureEnabled: Bool
    let customFieldsFeatureEnabled: Bool
    
    let onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    let onDeletePhoto: ((URL) -> Void)?
    
    @State private var newTag = ""
    @State private var showTagConfirmation = false
    @State private var pendingTag = ""
    
    public init(
        taskTitle: Binding<String>,
        taskNotes: Binding<String>,
        selectedDate: Binding<Date>,
        hasDate: Binding<Bool>,
        hasReminder: Binding<Bool>,
        reminderDuration: Binding<TimeInterval>,
        selectedPriority: Binding<TaskItem.Priority>,
        tags: Binding<[String]>,
        showValidationError: Binding<Bool>,
        photos: Binding<[URL]> = .constant([]),
        isRecurring: Binding<Bool> = .constant(false),
        recurrenceRule: Binding<RecurrenceRule> = .constant(.weekly),
        recurrenceInterval: Binding<Int> = .constant(1),
        budget: Binding<Decimal?> = .constant(nil),
        client: Binding<String> = .constant(""),
        effortHours: Binding<Double?> = .constant(nil),
        recurringFeatureEnabled: Bool = false,
        customFieldsFeatureEnabled: Bool = false,
        onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)? = nil,
        onDeletePhoto: ((URL) -> Void)? = nil
    ) {
        self._taskTitle = taskTitle
        self._taskNotes = taskNotes
        self._selectedDate = selectedDate
        self._hasDate = hasDate
        self._hasReminder = hasReminder
        self._reminderDuration = reminderDuration
        self._selectedPriority = selectedPriority
        self._tags = tags
        self._showValidationError = showValidationError
        self._photos = photos
        self._isRecurring = isRecurring
        self._recurrenceRule = recurrenceRule
        self._recurrenceInterval = recurrenceInterval
        self._budget = budget
        self._client = client
        self._effortHours = effortHours
        self.recurringFeatureEnabled = recurringFeatureEnabled
        self.customFieldsFeatureEnabled = customFieldsFeatureEnabled
        self.onPickPhotos = onPickPhotos
        self.onDeletePhoto = onDeletePhoto
    }
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
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

                if hasReminder {
                    ReminderDurationPicker(duration: $reminderDuration)
                }

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
            
            Section("Recurrence") {
                Toggle("Recurring Task", isOn: $isRecurring)
                    .disabled(!recurringFeatureEnabled)

                if !recurringFeatureEnabled {
                    Text("Premium feature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isRecurring {
                    if recurringFeatureEnabled {
                        Picker("Repeats", selection: $recurrenceRule) {
                            ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                                Text(rule.displayName).tag(rule)
                            }
                        }

                        let unit = recurrenceRule == .daily ? "day(s)" :
                            recurrenceRule == .weekly ? "week(s)" :
                            recurrenceRule == .monthly ? "month(s)" :
                            recurrenceRule == .yearly ? "year(s)" : "weekday(s)"

                        Stepper("Every \(recurrenceInterval) \(unit)", value: $recurrenceInterval, in: 1...52)
                    } else {
                        Text("Upgrade to edit recurrence settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Custom Fields") {
                if customFieldsFeatureEnabled {
                    HStack {
                        Text("Budget")
                        Spacer()
                        TextField("Amount", value: $budget, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }

                    HStack {
                        Text("Client")
                        Spacer()
                        TextField("Client name", text: $client)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 180)
                    }

                    HStack {
                        Text("Effort")
                        Spacer()
                        TextField("Hours", value: $effortHours, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("hours")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Premium feature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

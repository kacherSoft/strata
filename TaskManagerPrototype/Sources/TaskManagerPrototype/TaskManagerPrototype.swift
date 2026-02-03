import SwiftUI

// MARK: - Main App
@main
struct TaskManagerPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Text("")
                            .hidden()
                    }
                }
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.automatic)
        .defaultSize(width: 1000, height: 700)
    }
}

// MARK: - Main Content View with Sidebar Layout
struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem? = .allTasks
    @State private var selectedTask: TaskItem?
    @State private var tasks = TaskItem.sampleTasks
    @State private var showNewTaskSheet = false
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedSidebarItem)
                .frame(minWidth: 180, idealWidth: 220)
        } detail: {
            DetailPanelView(
                selectedSidebarItem: selectedSidebarItem,
                selectedTask: $selectedTask,
                tasks: tasks,
                searchText: $searchText,
                showNewTaskSheet: $showNewTaskSheet
            )
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(isPresented: $showNewTaskSheet)
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?

    var body: some View {
        List(selection: $selectedItem) {
            Section("My Work") {
                ForEach(SidebarItem.mainItems) { item in
                    SidebarRow(item: item)
                        .tag(item)
                }
            }

            Section("Lists") {
                ForEach(SidebarItem.listItems) { item in
                    SidebarRow(item: item)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Task Manager")
    }
}

// MARK: - Sidebar Row Component
struct SidebarRow: View {
    let item: SidebarItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundStyle(.secondary)
                .font(.system(size: 14))

            Text(item.title)
                .font(.system(size: 13))

            if item.count > 0 {
                Spacer()

                Text("\(item.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail Panel View
struct DetailPanelView: View {
    let selectedSidebarItem: SidebarItem?
    @Binding var selectedTask: TaskItem?
    let tasks: [TaskItem]
    @Binding var searchText: String
    @Binding var showNewTaskSheet: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header with Search
                HeaderView(
                    title: selectedSidebarItem?.title ?? "All Tasks",
                    searchText: $searchText,
                    onNewTask: { showNewTaskSheet = true }
                )

                // Task List
                TaskListView(
                    tasks: filteredTasks,
                    selectedTask: $selectedTask
                )

                // Detail View (when task selected)
                if let selectedTask = selectedTask {
                    TaskDetailView(task: selectedTask)
                }
            }
            .frame(minWidth: 600, minHeight: 400)
            .overlay {
                if filteredTasks.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No results found",
                        message: "Try a different search term"
                    )
                } else if filteredTasks.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No tasks yet",
                        message: "Create your first task to get started"
                    )
                }
            }

            // Floating Action Button
            FloatingActionButton(icon: "plus") {
                showNewTaskSheet = true
            }
            .padding(24)
        }
    }

    private var filteredTasks: [TaskItem] {
        var result = tasks

        // Filter by sidebar selection
        if let selectedItem = selectedSidebarItem {
            switch selectedItem {
            case .allTasks: break
            case .today: result = result.filter { $0.isToday }
            case .upcoming: result = result.filter { !$0.isToday }
            case .completed: result = result.filter { $0.isCompleted }
            default: break
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }
}

// MARK: - Header View with Search
struct HeaderView: View {
    let title: String
    @Binding var searchText: String
    var onNewTask: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))

            // Search Bar
            SearchBar(text: $searchText)
                .frame(maxWidth: 280)

            Spacer()

            HStack(spacing: 8) {
                // Filter Button
                MenuButton(icon: "line.3.horizontal.decrease.circle") {
                    Button("All Tasks") {}
                    Button("Today") {}
                    Button("Upcoming") {}
                    Divider()
                    Button("High Priority") {}
                    Button("Has Reminder") {}
                }

                // Sort Button
                MenuButton(icon: "arrow.up.arrow.down") {
                    Button("By Date") {}
                    Button("By Priority") {}
                    Button("By Title") {}
                    Divider()
                    Button("Newest First") {}
                    Button("Oldest First") {}
                }

                // More Options
                MenuButton(icon: "ellipsis.circle") {
                    Button("Mark All as Read") {}
                    Button("Archive Completed") {}
                    Divider()
                    Button("Settings...") {}
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 12)
        .background(.regularMaterial)
    }
}

// MARK: - Search Bar Component
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("Search tasks...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isFocused ? .blue.opacity(0.5) : .white.opacity(0.1), lineWidth: 1)
        }
        .onAppear { isFocused = false }
    }
}

// MARK: - Menu Button Component
struct MenuButton: View {
    let icon: String
    let content: () -> any View

    init(icon: String, @ViewBuilder content: @escaping () -> some View) {
        self.icon = icon
        self.content = content
    }

    var body: some View {
        Menu {
            AnyView(content())
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - Task List View
struct TaskListView: View {
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskRow(task: task, isSelected: selectedTask?.id == task.id)
                        .onTapGesture {
                            selectedTask = task
                        }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Task Row Component
struct TaskRow: View {
    let task: TaskItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Checkbox
            Button(action: {}) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isCompleted ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            // Task Info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Tags
                if !task.tags.isEmpty {
                    TagCloud(tags: task.tags)
                }

                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: task.isToday ? "calendar.badge.clock" : "calendar")
                            Text(dueDate, style: .date)
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(task.isToday ? .orange : .secondary)
                    }

                    if task.hasReminder {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    // Subtasks indicator
                    if task.subtaskCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                            Text("\(task.completedSubtasks)/\(task.subtaskCount)")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Priority Indicator
            if task.priority != .none {
                PriorityIndicator(priority: task.priority)
            }
        }
        .padding(16)
        .background(isSelected ? .thinMaterial : .ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: isSelected ? 2 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Tag Cloud Component
struct TagCloud: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(text: tag)
                }
            }
        }
    }
}

// MARK: - Tag Chip Component
struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Priority Indicator Component
struct PriorityIndicator: View {
    let priority: TaskItem.Priority

    var body: some View {
        Image(systemName: "flag.fill")
            .font(.system(size: 11))
            .foregroundStyle(priorityColor(priority))
    }

    private func priorityColor(_ priority: TaskItem.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .clear
        }
    }
}

// MARK: - Task Detail View
struct TaskDetailView: View {
    let task: TaskItem
    @State private var showEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))

                    Text(task.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if !task.tags.isEmpty {
                        TagCloud(tags: task.tags)
                    }

                    HStack(spacing: 16) {
                        if let dueDate = task.dueDate {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                Text("Due: \(dueDate, style: .date)")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }

                        if task.hasReminder {
                            HStack(spacing: 6) {
                                Image(systemName: "bell")
                                Text("Reminder set")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }

                        if task.subtaskCount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "checklist")
                                Text("\(task.completedSubtasks) of \(task.subtaskCount) completed")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    ActionButton(icon: "bubble.left.and.bubble.right", action: {})
                    ActionButton(icon: "paperclip", action: {})
                    Divider()
                        .frame(height: 20)
                    ActionButton(icon: "pencil", action: { showEditSheet = true })
                    ActionButton(icon: "flag", action: {})
                    ActionButton(icon: "trash", action: {})
                }
            }
            .padding(20)
            .background(.regularMaterial)
        }
        .transition(.move(edge: .bottom))
        .sheet(isPresented: $showEditSheet) {
            EditTaskSheet(task: task, isPresented: $showEditSheet)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - New Task Sheet
struct NewTaskSheet: View {
    @Binding var isPresented: Bool
    @State private var taskTitle = ""
    @State private var taskNotes = ""
    @State private var selectedDate = Date()
    @State private var hasDate = false
    @State private var hasReminder = false
    @State private var selectedPriority: TaskItem.Priority = .none
    @State private var newTag = ""
    @State private var tags: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    // Title Input
                    TextField("Task title", text: $taskTitle)
                        .textFieldStyle(.plain)

                    // Notes Text Area
                    TextareaField(
                        text: $taskNotes,
                        placeholder: "Add notes...",
                        height: 80
                    )
                }

                Section("Dates & Reminders") {
                    // Date Picker
                    Toggle("Set Due Date", isOn: $hasDate)

                    if hasDate {
                        DatePicker(
                            "Due Date",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }

                    // Reminder Toggle
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
                    // Tag Input
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

                    // Tags Display
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

// MARK: - Edit Task Sheet
struct EditTaskSheet: View {
    let task: TaskItem
    @Binding var isPresented: Bool
    @State private var taskTitle: String
    @State private var taskNotes: String
    @State private var selectedDate: Date?
    @State private var hasDate: Bool
    @State private var hasReminder: Bool
    @State private var selectedPriority: TaskItem.Priority

    init(task: TaskItem, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        _taskTitle = State(initialValue: task.title)
        _taskNotes = State(initialValue: task.notes)
        _selectedDate = State(initialValue: task.dueDate)
        _hasDate = State(initialValue: task.dueDate != nil)
        _hasReminder = State(initialValue: task.hasReminder)
        _selectedPriority = State(initialValue: task.priority)
    }

    var body: some View {
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

// MARK: - Textarea Field Component
struct TextareaField: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .background(.clear)
                .frame(height: height)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Priority Picker Component
struct PriorityPicker: View {
    @Binding var selectedPriority: TaskItem.Priority

    var body: some View {
        HStack(spacing: 12) {
            PriorityOption(
                label: "High",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                isSelected: selectedPriority == .high
            ) {
                selectedPriority = .high
            }

            PriorityOption(
                label: "Medium",
                icon: "minus.circle.fill",
                color: .orange,
                isSelected: selectedPriority == .medium
            ) {
                selectedPriority = .medium
            }

            PriorityOption(
                label: "Low",
                icon: "arrow.down.circle.fill",
                color: .blue,
                isSelected: selectedPriority == .low
            ) {
                selectedPriority = .low
            }

            PriorityOption(
                label: "None",
                icon: "circle",
                color: .secondary,
                isSelected: selectedPriority == .none
            ) {
                selectedPriority = .none
            }

            Spacer()
        }
    }
}

// MARK: - Priority Option Component
struct PriorityOption: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? color : .secondary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 56)
            .background {
                if isSelected {
                    color.opacity(0.15)
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary Button Component
struct PrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Action Button (iOS 26 Camera Button Style)
struct FloatingActionButton: View {
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("New Task")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Indicator Component
struct ProgressIndicator: View {
    let current: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Progress")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(current)/\(total)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.blue)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Models

struct SidebarItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    var count: Int = 0

    static let allTasks = SidebarItem(title: "All Tasks", icon: "tray.full")
    static let today = SidebarItem(title: "Today", icon: "sun.max.fill", count: 3)
    static let upcoming = SidebarItem(title: "Upcoming", icon: "calendar", count: 5)
    static let completed = SidebarItem(title: "Completed", icon: "checkmark.circle")

    static let mainItems = [allTasks, today, upcoming, completed]
    static let listItems = [
        SidebarItem(title: "Personal", icon: "person.fill"),
        SidebarItem(title: "Work", icon: "briefcase.fill"),
        SidebarItem(title: "Shopping", icon: "cart.fill")
    ]
}

struct TaskItem: Identifiable {
    let id = UUID()
    let title: String
    let notes: String
    var isCompleted: Bool
    var isToday: Bool
    let priority: Priority
    let hasReminder: Bool
    let dueDate: Date?
    let tags: [String]
    let subtaskCount: Int
    let completedSubtasks: Int

    enum Priority {
        case high, medium, low, none
    }

    static let sampleTasks = [
        TaskItem(
            title: "Design system components",
            notes: "Create reusable UI components with liquid glass effect",
            isCompleted: false,
            isToday: true,
            priority: .high,
            hasReminder: true,
            dueDate: Calendar.current.date(byAdding: .day, value: 0, to: Date()),
            tags: ["design", "ui"],
            subtaskCount: 3,
            completedSubtasks: 1
        ),
        TaskItem(
            title: "Review API documentation",
            notes: "Check latest endpoints and update integration",
            isCompleted: false,
            isToday: true,
            priority: .medium,
            hasReminder: false,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
            tags: ["backend", "api"],
            subtaskCount: 0,
            completedSubtasks: 0
        ),
        TaskItem(
            title: "Setup dark mode support",
            notes: "Ensure all components work in both light and dark mode",
            isCompleted: false,
            isToday: true,
            priority: .high,
            hasReminder: true,
            dueDate: Date(),
            tags: ["ui", "accessibility"],
            subtaskCount: 5,
            completedSubtasks: 2
        ),
        TaskItem(
            title: "Write unit tests",
            notes: "Add test coverage for core components",
            isCompleted: false,
            isToday: false,
            priority: .low,
            hasReminder: false,
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            tags: ["testing"],
            subtaskCount: 0,
            completedSubtasks: 0
        ),
        TaskItem(
            title: "Update dependencies",
            notes: "Update all Swift packages to latest versions",
            isCompleted: true,
            isToday: false,
            priority: .none,
            hasReminder: false,
            dueDate: nil,
            tags: ["maintenance"],
            subtaskCount: 0,
            completedSubtasks: 0
        )
    ]
}

// MARK: - Preview
#Preview("Main View") {
    ContentView()
        .frame(width: 1000, height: 700)
}

#Preview("New Task Sheet") {
    NewTaskSheet(isPresented: .constant(true))
        .frame(width: 600, height: 500)
}

#Preview("Components") {
    VStack(spacing: 20) {
        // Search Bar
        SearchBar(text: .constant(""))
            .frame(width: 300)

        // Tags
        TagCloud(tags: ["design", "ui", "urgent"])

        // Priority
        PriorityPicker(selectedPriority: .constant(.high))

        // Progress
        ProgressIndicator(current: 3, total: 5)

        // Primary Button
        PrimaryButton(title: "Create Task", icon: "plus") {}

        HStack(spacing: 12) {
            ActionButton(icon: "pencil", action: {})
            ActionButton(icon: "flag", action: {})
            ActionButton(icon: "trash", action: {})
        }
    }
    .padding()
    .frame(width: 500, height: 400)
    .background(.ultraThinMaterial)
}

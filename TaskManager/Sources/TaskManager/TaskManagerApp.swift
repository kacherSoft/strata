import SwiftUI
import SwiftData
import AppKit
import TaskManagerUIComponents
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    var modelContainer: ModelContainer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        clearStaleAttachmentFiles()

        // Apply saved settings on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.applySettingsOnLaunch()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Don't force window to front here - let WindowManager handle it
        // This prevents fighting with moveToActiveSpace behavior
    }
    
    @MainActor
    private func applySettingsOnLaunch() {
        guard let container = modelContainer else { return }
        let context = container.mainContext

        do {
            let descriptor = FetchDescriptor<SettingsModel>()
            if let settings = try context.fetch(descriptor).first {
                WindowManager.shared.setAlwaysOnTop(settings.alwaysOnTop)
            }
        } catch {
            return
        }
    }

    private func clearStaleAttachmentFiles() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EnhanceMeAttachments", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
    }
}

@main
struct TaskManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var subscriptionService = SubscriptionService.shared
    let container: ModelContainer?
    private let menuBarController = MenuBarController()

    init() {
        let resolvedContainer: ModelContainer?

        do {
            let configured = try ModelContainer.configured()
            try seedDefaultData(container: configured)
            resolvedContainer = configured
        } catch {
            do {
                let fallback = try ModelContainer.inMemoryFallback()
                try seedDefaultData(container: fallback)
                resolvedContainer = fallback
            } catch {
                resolvedContainer = nil
            }
        }

        container = resolvedContainer
        if let container {
            WindowManager.shared.configure(modelContainer: container)
            ShortcutManager.shared.configure(modelContainer: container)
            appDelegate.modelContainer = container
        }

    }

    var body: some Scene {
        WindowGroup("Task Manager", id: "main-window") {
            if let container {
                ContentView()
                    .withAppEnvironment(container: container)
            } else {
                Text("Unable to initialize local data store.")
                    .padding()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Query(sort: \TaskModel.createdAt, order: .reverse) private var taskModels: [TaskModel]
    @Query(sort: \CustomFieldDefinitionModel.sortOrder) private var customFieldDefinitions: [CustomFieldDefinitionModel]
    @Query private var customFieldValues: [CustomFieldValueModel]
    @Query private var settings: [SettingsModel]
    
    @State private var selectedSidebarItem: SidebarItem? = .allTasks
    @State private var selectedTask: TaskItem?
    @State private var showNewTaskSheet = false
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var selectedTag: String?
    @State private var selectedDate: Date?
    @State private var dateFilterMode: CalendarFilterMode = .all
    @State private var selectedPriority: TaskItem.Priority?
    @State private var viewMode: ViewMode = .list
    @State private var persistenceErrorMessage: String?
    private let reminderWatchTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentSettings: SettingsModel? { settings.first }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedItem: $selectedSidebarItem,
                tags: allTags,
                selectedTag: $selectedTag,
                selectedDate: $selectedDate,
                dateFilterMode: $dateFilterMode,
                selectedPriority: $selectedPriority,
                tasks: taskItems,
                isKanbanMode: Binding(
                    get: { viewMode == .kanban },
                    set: { viewMode = $0 ? .kanban : .list }
                ),
                showsKanbanPremiumBadge: !subscriptionService.canUse(.kanban)
            )
            .frame(minWidth: 220, idealWidth: 260)
            .onChange(of: selectedTag) { _, newValue in
                if newValue != nil {
                    selectedSidebarItem = nil
                    selectedDate = nil
                    selectedPriority = nil
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                dateFilterMode = .all
                if newValue != nil {
                    selectedSidebarItem = nil
                    selectedTag = nil
                    selectedPriority = nil
                }
            }
            .onChange(of: selectedSidebarItem) { _, newValue in
                if newValue != nil {
                    selectedTag = nil
                    selectedDate = nil
                    selectedPriority = nil
                }
            }
            .onChange(of: selectedPriority) { _, newValue in
                if newValue != nil {
                    selectedSidebarItem = nil
                    selectedTag = nil
                    selectedDate = nil
                }
            }
        } detail: {
            if viewMode == .list {
                DetailPanelView(
                    selectedSidebarItem: selectedSidebarItem,
                    selectedTask: $selectedTask,
                    tasks: taskItems,
                    searchText: $searchText,
                    showNewTaskSheet: $showNewTaskSheet,
                    selectedTag: selectedTag,
                    selectedDate: selectedDate,
                    dateFilterMode: dateFilterMode,
                    selectedPriority: selectedPriority,
                    recurringFeatureEnabled: subscriptionService.canUse(.recurringTasks),
                    activeCustomFieldDefinitions: activeCustomFieldDefinitions,
                    availableTags: allTags,
                    onToggleComplete: { taskItem in
                        toggleComplete(taskItem: taskItem)
                    },
                    onEdit: { taskItem, title, notes, dueDate, hasReminder, duration, priority, tags, photos, isRecurring, recurrenceRule, recurrenceInterval, customFieldValues in
                        updateTask(
                            taskItem: taskItem,
                            title: title,
                            notes: notes,
                            dueDate: dueDate,
                            hasReminder: hasReminder,
                            reminderDuration: duration,
                            priority: priority,
                            tags: tags,
                            photos: photos,
                            isRecurring: isRecurring,
                            recurrenceRule: recurrenceRule,
                            recurrenceInterval: recurrenceInterval,
                            customFieldValues: customFieldValues
                        )
                    },
                    onDelete: { taskItem in
                        deleteTask(taskItem: taskItem)
                    },
                    onPriorityChange: { taskItem, priority in
                        updatePriority(taskItem: taskItem, priority: priority)
                    },
                    onAddPhotos: { taskItem, urls in
                        addPhotos(taskItem: taskItem, urls: urls)
                    },
                    onPickPhotos: { completion in
                        PhotoStorageService.shared.pickPhotos(completion: completion)
                    },
                    onDeletePhoto: { url in
                        PhotoStorageService.shared.deletePhoto(at: url.path)
                    },
                    onCreateReminder: { taskItem, duration in
                        createReminder(taskItem: taskItem, duration: duration)
                    },
                    onEditReminder: { taskItem, duration in
                        editReminder(taskItem: taskItem, newDuration: duration)
                    },
                    onRemoveReminder: { taskItem in
                        removeReminder(taskItem: taskItem)
                    },
                    onStopAlarm: { taskItem in
                        stopAlarm(taskItem: taskItem)
                    }
                )
            } else {
                if subscriptionService.canUse(.kanban) {
                    KanbanBoardView(
                        tasks: filteredTaskItems,
                        onStatusChange: { taskID, newStatus in
                            updateStatus(taskID: taskID, newStatus: newStatus)
                        },
                        onTaskSelect: { task in
                            selectedTask = task
                        }
                    )
                } else {
                    PremiumUpsellView(
                        featureName: "Kanban View",
                        featureDescription: "Visualize your tasks in To Do, In Progress, and Done columns."
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(WindowActivator())
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(
                isPresented: $showNewTaskSheet,
                recurringFeatureEnabled: subscriptionService.canUse(.recurringTasks),
                activeCustomFieldDefinitions: activeCustomFieldDefinitions,
                availableTags: allTags,
                onPickPhotos: { completion in
                    PhotoStorageService.shared.pickPhotos(completion: completion)
                }
            ) { title, notes, dueDate, hasReminder, duration, priority, tags, photos, isRecurring, recurrenceRule, recurrenceInterval, customFieldValues in
                createTask(
                    title: title,
                    notes: notes,
                    dueDate: dueDate,
                    hasReminder: hasReminder,
                    reminderDuration: duration,
                    priority: priority,
                    tags: tags,
                    photos: photos,
                    isRecurring: isRecurring,
                    recurrenceRule: recurrenceRule,
                    recurrenceInterval: recurrenceInterval,
                    customFieldValues: customFieldValues
                )
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            WindowManager.shared.openWindowAction = openWindow
        }
        .onReceive(NotificationCenter.default.publisher(for: .showNewTaskSheet)) { _ in
            showNewTaskSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .reminderAlarmFired)) { notification in
            if let taskId = notification.userInfo?["taskId"] as? String {
                handleAlarmFired(taskId: taskId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskCompletedFromNotification)) { notification in
            if let taskId = notification.userInfo?["taskId"] as? String {
                handleTaskCompletedFromNotification(taskId: taskId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reminderDismissedFromNotification)) { notification in
            if let taskId = notification.userInfo?["taskId"] as? String {
                handleReminderDismissed(taskId: taskId)
            }
        }
        .onReceive(reminderWatchTimer) { _ in
            monitorReminderTimers()
        }
        .alert("Unable to Save Changes", isPresented: Binding(
            get: { persistenceErrorMessage != nil },
            set: { if !$0 { persistenceErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                persistenceErrorMessage = nil
            }
        } message: {
            Text(persistenceErrorMessage ?? "")
        }
    }
    
    private var activeCustomFieldDefinitions: [TaskManagerUIComponents.CustomFieldDefinition] {
        customFieldDefinitions
            .filter { $0.isActive }
            .map { $0.toDefinition() }
    }

    private var taskItems: [TaskItem] {
        let mapped = taskModels.map { task in
            let entries = customFieldValues
                .filter { $0.taskId == task.id }
                .compactMap { value -> TaskManagerUIComponents.CustomFieldEntry? in
                    guard let definition = customFieldDefinitions.first(where: { $0.id == value.definitionId }) else { return nil }
                    return value.toEntry(definition: definition)
                }
            return task.toTaskItem(customFieldEntries: entries)
        }
        let showCompleted = currentSettings?.showCompletedTasks ?? true
        return showCompleted ? mapped : mapped.filter { !$0.isCompleted }
    }
    
    private var allTags: [String] {
        Array(Set(taskModels.flatMap { $0.tags })).sorted()
    }

    private var filteredTaskItems: [TaskItem] {
        var result = taskItems

        if let priority = selectedPriority {
            result = result.filter { $0.priority == priority }
        } else if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        } else if let date = selectedDate {
            let calendar = Calendar.current
            switch dateFilterMode {
            case .all:
                result = result.filter {
                    let matchesDue = $0.dueDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                    let matchesCreated = $0.createdAt.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                    return matchesDue || matchesCreated
                }
            case .deadline:
                result = result.filter {
                    guard let dueDate = $0.dueDate else { return false }
                    return calendar.isDate(dueDate, inSameDayAs: date)
                }
            case .created:
                result = result.filter {
                    guard let createdAt = $0.createdAt else { return false }
                    return calendar.isDate(createdAt, inSameDayAs: date)
                }
            }
        } else if let selectedItem = selectedSidebarItem {
            switch selectedItem {
            case .allTasks: break
            case .today: result = result.filter { $0.isToday }
            case .upcoming: result = result.filter { !$0.isToday && !$0.isCompleted }
            case .inProgress: result = result.filter { $0.isInProgress }
            case .completed: result = result.filter { $0.isCompleted }
            default: break
            }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            persistenceErrorMessage = error.localizedDescription
        }
    }

    private func resolvedPriority(_ priority: TaskItem.Priority) -> TaskPriority {
        if priority == .none {
            return currentSettings?.defaultPriority ?? .medium
        }
        return TaskPriority.from(priority)
    }
    
    private func createTask(
        title: String,
        notes: String,
        dueDate: Date?,
        hasReminder: Bool,
        reminderDuration: TimeInterval = 1800,
        priority: TaskItem.Priority,
        tags: [String],
        photos: [URL] = [],
        isRecurring: Bool = false,
        recurrenceRule: TaskManagerUIComponents.RecurrenceRule = .weekly,
        recurrenceInterval: Int = 1,
        customFieldValues: [UUID: TaskManagerUIComponents.CustomFieldEditValue] = [:]
    ) {
        let storedPaths = photos.isEmpty ? [] : PhotoStorageService.shared.storePhotos(photos)
        let task = TaskModel(
            title: title,
            taskDescription: notes,
            dueDate: dueDate,
            reminderDuration: reminderDuration,
            priority: resolvedPriority(priority),
            tags: tags,
            hasReminder: hasReminder,
            photos: storedPaths,
            isRecurring: isRecurring,
            recurrenceRule: isRecurring ? RecurrenceRule(rawValue: recurrenceRule.rawValue) : nil,
            recurrenceInterval: recurrenceInterval
        )
        
        // Auto-start reminder timer when creating a task with a reminder
        if hasReminder {
            let soundId = currentSettings?.reminderSoundId ?? "default"
            task.reminderFireDate = Date().addingTimeInterval(reminderDuration)
            NotificationService.shared.scheduleTimerReminder(
                for: task.id,
                title: title,
                duration: reminderDuration,
                soundId: soundId
            )
        }
        
        modelContext.insert(task)
        saveCustomFieldValues(taskId: task.id, values: customFieldValues)
        saveContext()
    }

    private func saveCustomFieldValues(taskId: UUID, values: [UUID: TaskManagerUIComponents.CustomFieldEditValue]) {
        // Delete existing values for this task
        let existingValues = customFieldValues.filter { $0.taskId == taskId }
        for existing in existingValues {
            modelContext.delete(existing)
        }

        // Insert new values
        for (definitionId, editValue) in values {
            let model = CustomFieldValueModel(definitionId: definitionId, taskId: taskId)
            switch editValue {
            case .text(let text):
                model.stringValue = text.isEmpty ? nil : text
            case .number(let number):
                model.numberValue = number
            case .currency(let decimal):
                model.decimalValue = decimal
            case .date(let date):
                model.dateValue = date
            case .toggle(let bool):
                model.boolValue = bool
            }
            modelContext.insert(model)
        }
    }
    
    private func findTaskModel(for taskItem: TaskItem) -> TaskModel? {
        taskModels.first { $0.id == taskItem.id }
    }

    private func createRecurringNextTask(from task: TaskModel) {
        guard let rule = task.recurrenceRule else { return }

        let baseDate = task.dueDate ?? Date()
        let nextDueDate = rule.nextDate(from: baseDate, interval: max(1, task.recurrenceInterval))

        let nextTask = TaskModel(
            title: task.title,
            taskDescription: task.taskDescription,
            dueDate: nextDueDate,
            reminderDuration: task.reminderDuration,
            priority: task.priority,
            tags: task.tags,
            hasReminder: false,
            photos: task.photos,
            isRecurring: true,
            recurrenceRule: rule,
            recurrenceInterval: task.recurrenceInterval
        )

        modelContext.insert(nextTask)

        // Mark original task as no longer recurring to prevent duplicate spawns
        // if user moves it back and forth between columns
        task.isRecurring = false
    }
    
    private func toggleComplete(taskItem: TaskItem) {
        guard let task = findTaskModel(for: taskItem) else { return }

        let willComplete = task.status == .inProgress
        if willComplete, task.isRecurring {
            createRecurringNextTask(from: task)
        }

        task.cycleStatus()
        if task.isCompleted {
            cancelReminder(for: task)
        }
        saveContext()
    }

    private func updateStatus(taskID: UUID, newStatus: TaskStatus) {
        guard let task = taskModels.first(where: { $0.id == taskID }) else { return }

        if task.status != .completed,
           newStatus == .completed,
           task.isRecurring {
            createRecurringNextTask(from: task)
        }

        task.setStatus(newStatus)
        if newStatus == .completed {
            cancelReminder(for: task)
        }
        saveContext()
    }
    
    private func updateTask(
        taskItem: TaskItem,
        title: String,
        notes: String,
        dueDate: Date?,
        hasReminder: Bool,
        reminderDuration: TimeInterval = 1800,
        priority: TaskItem.Priority,
        tags: [String],
        photos: [URL] = [],
        isRecurring: Bool,
        recurrenceRule: TaskManagerUIComponents.RecurrenceRule,
        recurrenceInterval: Int,
        customFieldValues: [UUID: TaskManagerUIComponents.CustomFieldEditValue] = [:]
    ) {
        guard let task = findTaskModel(for: taskItem) else { return }
        task.title = title
        task.taskDescription = notes
        task.dueDate = dueDate
        task.hasReminder = hasReminder
        task.reminderDuration = reminderDuration
        task.priority = TaskPriority.from(priority)
        task.tags = tags
        task.photos = PhotoStorageService.shared.normalizeToStoredPaths(photos)
        task.isRecurring = isRecurring
        task.recurrenceRule = isRecurring ? RecurrenceRule(rawValue: recurrenceRule.rawValue) : nil
        task.recurrenceInterval = max(1, recurrenceInterval)
        
        // Auto-start/restart reminder when enabled or duration changed via edit
        if hasReminder {
            NotificationService.shared.cancelReminder(for: task.id)
            let soundId = currentSettings?.reminderSoundId ?? "default"
            task.reminderFireDate = Date().addingTimeInterval(reminderDuration)
            NotificationService.shared.scheduleTimerReminder(
                for: task.id,
                title: task.title,
                duration: reminderDuration,
                soundId: soundId
            )
        } else if !hasReminder {
            NotificationService.shared.cancelReminder(for: task.id)
            task.reminderFireDate = nil
        }
        
        task.touch()
        saveCustomFieldValues(taskId: task.id, values: customFieldValues)
        saveContext()
    }
    
    private func deleteTask(taskItem: TaskItem) {
        guard let task = findTaskModel(for: taskItem) else { return }
        NotificationService.shared.cancelReminder(for: task.id)
        modelContext.delete(task)
        saveContext()
        selectedTask = nil
    }
    
    private func updatePriority(taskItem: TaskItem, priority: TaskItem.Priority) {
        guard let task = findTaskModel(for: taskItem) else { return }
        task.priority = resolvedPriority(priority)
        task.touch()
        saveContext()
    }
    
    private func createReminder(taskItem: TaskItem, duration: TimeInterval) {
        guard let task = findTaskModel(for: taskItem) else { return }
        
        let soundId = currentSettings?.reminderSoundId ?? "default"
        task.hasReminder = true
        task.reminderDuration = duration
        task.reminderFireDate = Date().addingTimeInterval(duration)
        NotificationService.shared.scheduleTimerReminder(
            for: task.id,
            title: task.title,
            duration: duration,
            soundId: soundId
        )
        task.touch()
        saveContext()
    }
    
    private func editReminder(taskItem: TaskItem, newDuration: TimeInterval) {
        guard let task = findTaskModel(for: taskItem) else { return }
        
        // Cancel existing and restart with new duration
        NotificationService.shared.cancelReminder(for: task.id)
        let soundId = currentSettings?.reminderSoundId ?? "default"
        task.reminderDuration = newDuration
        task.reminderFireDate = Date().addingTimeInterval(newDuration)
        NotificationService.shared.scheduleTimerReminder(
            for: task.id,
            title: task.title,
            duration: newDuration,
            soundId: soundId
        )
        task.touch()
        saveContext()
    }
    
    private func removeReminder(taskItem: TaskItem) {
        guard let task = findTaskModel(for: taskItem) else { return }
        
        NotificationService.shared.cancelReminder(for: task.id)
        task.hasReminder = false
        task.reminderFireDate = nil
        task.touch()
        saveContext()
    }
    
    private func stopAlarm(taskItem: TaskItem) {
        guard let task = findTaskModel(for: taskItem) else { return }

        stopAlarm(for: task)
    }
    
    private func handleAlarmFired(taskId: String) {
        guard let uuid = UUID(uuidString: taskId),
              let task = taskModels.first(where: { $0.id == uuid }),
              !task.isCompleted else { return }
        let soundId = currentSettings?.reminderSoundId ?? "default"
        NotificationService.shared.startAlarm(for: uuid, soundId: soundId)
    }

    private func handleTaskCompletedFromNotification(taskId: String) {
        guard let uuid = UUID(uuidString: taskId),
              let task = taskModels.first(where: { $0.id == uuid }) else { return }

        if task.status != .completed, task.isRecurring {
            createRecurringNextTask(from: task)
        }

        task.setStatus(.completed)
        cancelReminder(for: task)
        saveContext()
    }

    private func handleReminderDismissed(taskId: String) {
        guard let uuid = UUID(uuidString: taskId),
              let task = taskModels.first(where: { $0.id == uuid }) else { return }
        cancelReminder(for: task)
        saveContext()
    }

    private func cancelReminder(for task: TaskModel) {
        NotificationService.shared.cancelReminder(for: task.id)
        task.hasReminder = false
        task.reminderFireDate = nil
        task.touch()
    }

    private func stopAlarm(for task: TaskModel) {
        NotificationService.shared.stopAlarm()
        cancelReminder(for: task)
        saveContext()
    }
    
    private func monitorReminderTimers() {
        let now = Date()

        if let alarmingTaskId = NotificationService.shared.alarmingTaskId {
            guard let alarmingTask = taskModels.first(where: { $0.id == alarmingTaskId }),
                  alarmingTask.hasReminder,
                  !alarmingTask.isCompleted,
                  let fireDate = alarmingTask.reminderFireDate,
                  fireDate <= now else {
                NotificationService.shared.stopAlarm()
                return
            }
            return
        }

        let overdueTasks = taskModels.filter {
            $0.hasReminder &&
            !$0.isCompleted &&
            ($0.reminderFireDate ?? .distantFuture) <= now
        }

        guard let overdueTask = overdueTasks.min(by: {
            ($0.reminderFireDate ?? .distantFuture) < ($1.reminderFireDate ?? .distantFuture)
        }) else {
            return
        }

        let soundId = currentSettings?.reminderSoundId ?? "default"
        NotificationService.shared.startAlarm(for: overdueTask.id, soundId: soundId)
    }
    
    private func addPhotos(taskItem: TaskItem, urls: [URL]) {
        guard let task = findTaskModel(for: taskItem) else { return }
        
        if urls.isEmpty {
            PhotoStorageService.shared.pickPhotos { pickedURLs in
                Task { @MainActor in
                    guard !pickedURLs.isEmpty else { return }
                    let storedPaths = PhotoStorageService.shared.storePhotos(pickedURLs)
                    task.photos.append(contentsOf: storedPaths)
                    task.touch()
                    self.saveContext()
                }
            }
        } else {
            let storedPaths = PhotoStorageService.shared.storePhotos(urls)
            task.photos.append(contentsOf: storedPaths)
            task.touch()
            saveContext()
        }
    }
}

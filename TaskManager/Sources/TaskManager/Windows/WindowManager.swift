import AppKit
import SwiftUI
import SwiftData
import TaskManagerUIComponents

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private var quickEntryPanel: QuickEntryPanel?
    private var settingsWindow: SettingsWindow?  // Legacy, kept for hideSettings
    private var enhanceMePanel: EnhanceMePanel?
    private var taskPanel: ChatPanel?  // Reuse ChatPanel (NSPanel subclass) for tasks
    private var modelContainer: ModelContainer?
    var openWindowAction: OpenWindowAction?
    
    private init() {}
    
    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - Close All Floating Windows
    
    private func closeAllFloatingWindows() {
        hideQuickEntry()
        hideSettings()
        hideEnhanceMe()
    }

    private func allTags(in context: ModelContext) -> [String] {
        do {
            let models = try context.fetch(FetchDescriptor<TaskModel>())
            return Array(Set(models.flatMap { $0.tags })).sorted()
        } catch {
            return []
        }
    }

    private func activeCustomFieldDefinitions(in context: ModelContext) -> [TaskManagerUIComponents.CustomFieldDefinition] {
        do {
            var descriptor = FetchDescriptor<CustomFieldDefinitionModel>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            descriptor.predicate = #Predicate { $0.isActive }
            let models = try context.fetch(descriptor)
            return models.map { $0.toDefinition() }
        } catch {
            return []
        }
    }
    
    /// Dismisses any visible floating window. Returns true if something was dismissed.
    func dismissVisibleFloatingWindow() -> Bool {
        if let panel = quickEntryPanel, panel.isVisible {
            hideQuickEntry()
            return true
        }
        if let window = settingsWindow, window.isVisible {
            hideSettings()
            return true
        }
        if let panel = enhanceMePanel, panel.isVisible {
            hideEnhanceMe()
            return true
        }
        if let panel = taskPanel, panel.isVisible {
            hideTasks()
            return true
        }
        return false
    }
    
    // MARK: - Quick Entry
    
    func showQuickEntry() {
        closeAllFloatingWindows()
        
        if quickEntryPanel == nil {
            quickEntryPanel = QuickEntryPanel()
        }
        
        guard let panel = quickEntryPanel, let container = modelContainer else { return }
        
        let view = QuickEntryWrapper(
            onDismiss: { [weak self] in self?.hideQuickEntry() },
            onCreate: { [weak self] title, notes, dueDate, hasReminder, duration, priority, tags, photos, isRecurring, recurrenceRule, recurrenceInterval, customFieldValues in
                self?.createTask(
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
                self?.hideQuickEntry()
            },
            activeCustomFieldDefinitions: self.activeCustomFieldDefinitions(in: container.mainContext),
            availableTags: self.allTags(in: container.mainContext),
            onPickPhotos: { completion in
                PhotoStorageService.shared.pickPhotos(completion: completion)
            }
        )
        .withAppEnvironment(container: container)
        
        panel.setContent(view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideQuickEntry() {
        quickEntryPanel?.orderOut(nil)
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
        guard let container = modelContainer else { return }
        let context = container.mainContext

        let defaultPriority: TaskPriority = {
            do {
                if let settings = try context.fetch(FetchDescriptor<SettingsModel>()).first {
                    return settings.defaultPriority
                }
            } catch {
                return .medium
            }
            return .medium
        }()

        let resolvedPriority: TaskPriority = priority == .none ? defaultPriority : TaskPriority.from(priority)
        let storedPaths = photos.isEmpty ? [] : PhotoStorageService.shared.storePhotos(photos)
        let task = TaskModel(
            title: title,
            taskDescription: notes,
            dueDate: dueDate,
            reminderDuration: reminderDuration,
            priority: resolvedPriority,
            tags: tags,
            hasReminder: hasReminder,
            photos: storedPaths,
            isRecurring: isRecurring,
            recurrenceRule: isRecurring ? RecurrenceRule(rawValue: recurrenceRule.rawValue) : nil,
            recurrenceInterval: recurrenceInterval
        )

        if hasReminder {
            let soundId: String = {
                do {
                    if let settings = try context.fetch(FetchDescriptor<SettingsModel>()).first {
                        return settings.reminderSoundId
                    }
                } catch {
                    return "default"
                }
                return "default"
            }()
            task.reminderFireDate = Date().addingTimeInterval(reminderDuration)
            NotificationService.shared.scheduleTimerReminder(
                for: task.id,
                title: title,
                duration: reminderDuration,
                soundId: soundId
            )
        }

        context.insert(task)

        // Save custom field values
        for (definitionId, editValue) in customFieldValues {
            let model = CustomFieldValueModel(definitionId: definitionId, taskId: task.id)
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
            context.insert(model)
        }

        do {
            try context.save()
        } catch {
            return
        }
    }
    
    // MARK: - Main Window

    private func isMainWindow(_ window: NSWindow) -> Bool {
        guard window.canBecomeKey, !(window is NSPanel) else { return false }
        return window.identifier?.rawValue == "main-window" || window.title == "Task Manager"
    }

    @discardableResult
    private func collapseDuplicateMainWindows() -> NSWindow? {
        let mainWindows = NSApp.windows.filter(isMainWindow)
        guard mainWindows.count > 1 else { return mainWindows.first }

        let primary =
            mainWindows.first(where: { $0.isKeyWindow }) ??
            mainWindows.first(where: { $0.isMainWindow }) ??
            mainWindows.first

        for window in mainWindows where window !== primary {
            window.close()
        }

        return primary
    }
    
    func focusMainWindowIfPresent() {
        guard let window = collapseDuplicateMainWindows() ?? getMainWindow() else { return }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showMainWindow() {
        if let window = collapseDuplicateMainWindows() ?? getMainWindow() {
            // Ensure the window moves to the current space/desktop
            window.collectionBehavior.insert(.moveToActiveSpace)
            // Order out and back to force space move
            if !window.isVisible || !window.isOnActiveSpace {
                window.orderOut(nil)
                window.makeKeyAndOrderFront(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            openWindowAction?(id: "main-window")
        }
    }
    
    func getMainWindow() -> NSWindow? {
        NSApp.windows.first(where: isMainWindow)
        ?? NSApp.windows.first(where: { $0.canBecomeKey && !($0 is NSPanel) && $0.isVisible })
    }
    
    // MARK: - Always on Top
    
    func setAlwaysOnTop(_ enabled: Bool) {
        guard let window = getMainWindow() else { return }
        window.level = enabled ? .floating : .normal
    }
    
    // MARK: - Settings
    
    func showSettings() {
        closeAllFloatingWindows()
        // Use SwiftUI Window scene via openWindowAction
        if let action = openWindowAction {
            action(id: "settings-window")
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideSettings() {
        // Find and close the settings window by title
        for window in NSApp.windows where window.title == "Settings" {
            window.orderOut(nil)
        }
    }
    
    // MARK: - Enhance Me
    
    func showEnhanceMe(withText text: String = "") {
        closeAllFloatingWindows()
        
        if enhanceMePanel == nil {
            enhanceMePanel = EnhanceMePanel()
        }
        
        guard let panel = enhanceMePanel, let container = modelContainer else { return }
        
        let view = EnhanceMeView(
            initialText: text,
            onDismiss: { [weak self] in self?.hideEnhanceMe() }
        )
        .withAppEnvironment(container: container)
        
        // Ensure the panel moves to the current space/desktop
        panel.collectionBehavior.insert(.moveToActiveSpace)
        
        panel.setContent(view)
        panel.center()
        
        // Order out and back to force space move if needed
        if !panel.isVisible || !panel.isOnActiveSpace {
            panel.orderOut(nil)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideEnhanceMe() {
        enhanceMePanel?.orderOut(nil)
    }

    // MARK: - Tasks (secondary panel, was main window before pivot)

    func showTasks() {
        guard let container = modelContainer else { return }

        if taskPanel == nil {
            let panel = ChatPanel()  // Reuse NSPanel subclass
            panel.title = "Strata Tasks"
            let view = ContentView()
                .withAppEnvironment(container: container)
            panel.collectionBehavior.insert(.moveToActiveSpace)
            panel.setContent(view)
            panel.center()
            taskPanel = panel
        }

        guard let panel = taskPanel else { return }
        if !panel.isVisible || !panel.isOnActiveSpace {
            panel.orderOut(nil)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideTasks() {
        taskPanel?.orderOut(nil)
    }
}

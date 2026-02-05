import AppKit
import SwiftUI
import SwiftData
import TaskManagerUIComponents

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private var quickEntryPanel: QuickEntryPanel?
    private var settingsWindow: SettingsWindow?
    private var modelContainer: ModelContainer?
    
    private init() {}
    
    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - Quick Entry
    
    func showQuickEntry() {
        if quickEntryPanel == nil {
            quickEntryPanel = QuickEntryPanel()
        }
        
        guard let panel = quickEntryPanel, let container = modelContainer else { return }
        
        let view = QuickEntryWrapper(
            onDismiss: { [weak self] in self?.hideQuickEntry() },
            onCreate: { [weak self] title, notes, dueDate, hasReminder, priority, tags in
                self?.createTask(title: title, notes: notes, dueDate: dueDate, hasReminder: hasReminder, priority: priority, tags: tags)
                self?.hideQuickEntry()
            }
        )
        .modelContainer(container)
        
        panel.setContent(view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideQuickEntry() {
        quickEntryPanel?.orderOut(nil)
    }
    
    private func createTask(title: String, notes: String, dueDate: Date?, hasReminder: Bool, priority: TaskItem.Priority, tags: [String]) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        
        let task = TaskModel(
            title: title,
            taskDescription: notes,
            dueDate: dueDate,
            priority: TaskPriority.from(priority),
            tags: tags,
            hasReminder: hasReminder
        )
        context.insert(task)
        try? context.save()
    }
    
    // MARK: - Main Window
    
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = getMainWindow() {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func getMainWindow() -> NSWindow? {
        NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" || $0.title == "Task Manager" })
        ?? NSApp.windows.first(where: { !($0 is NSPanel) && $0.isVisible })
    }
    
    // MARK: - Always on Top
    
    func setAlwaysOnTop(_ enabled: Bool) {
        guard let window = getMainWindow() else { return }
        window.level = enabled ? .floating : .normal
    }
    
    // MARK: - Settings
    
    func showSettings() {
        if settingsWindow == nil {
            guard let container = modelContainer else { return }
            settingsWindow = SettingsWindow(modelContainer: container)
        }
        
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideSettings() {
        settingsWindow?.orderOut(nil)
    }
    
    // MARK: - Enhance Me (Phase 3)
    
    func showEnhanceMe() {
        // Phase 3 implementation
        // For now, just show main window
        showMainWindow()
    }
}

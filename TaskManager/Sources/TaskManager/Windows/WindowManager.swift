import AppKit
import SwiftUI
import SwiftData
import TaskManagerUIComponents

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private var quickEntryPanel: QuickEntryPanel?
    private var settingsWindow: SettingsWindow?
    private var enhanceMePanel: EnhanceMePanel?
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
            onCreate: { [weak self] title, notes, dueDate, hasReminder, duration, priority, tags, photos in
                self?.createTask(title: title, notes: notes, dueDate: dueDate, hasReminder: hasReminder, reminderDuration: duration, priority: priority, tags: tags, photos: photos)
                self?.hideQuickEntry()
            },
            onPickPhotos: { completion in
                PhotoStorageService.shared.pickPhotos(completion: completion)
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
    
    private func createTask(title: String, notes: String, dueDate: Date?, hasReminder: Bool, reminderDuration: TimeInterval = 1800, priority: TaskItem.Priority, tags: [String], photos: [URL] = []) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        
        let storedPaths = photos.isEmpty ? [] : PhotoStorageService.shared.storePhotos(photos)
        let task = TaskModel(
            title: title,
            taskDescription: notes,
            dueDate: dueDate,
            reminderDuration: reminderDuration,
            priority: TaskPriority.from(priority),
            tags: tags,
            hasReminder: hasReminder,
            photos: storedPaths
        )
        context.insert(task)
        try? context.save()
    }
    
    // MARK: - Main Window
    
    func showMainWindow() {
        if let window = getMainWindow() {
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
        NSApp.windows.first(where: { ($0.identifier?.rawValue == "main-window" || $0.title == "Task Manager") && $0.canBecomeKey })
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
        .modelContainer(container)
        
        panel.setContent(view)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideEnhanceMe() {
        enhanceMePanel?.orderOut(nil)
    }
}

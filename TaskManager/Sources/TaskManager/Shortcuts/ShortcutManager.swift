import KeyboardShortcuts
import AppKit
import SwiftData

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    private var modelContainer: ModelContainer?
    private var localMonitor: Any?
    
    private init() {
        registerDefaultShortcuts()
        setupHandlers()
        setupLocalMonitor()
    }
    
    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - Global Shortcuts (system-wide)
    
    private func registerDefaultShortcuts() {
        // Global
        if KeyboardShortcuts.getShortcut(for: .quickEntry) == nil {
            KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        }
        if KeyboardShortcuts.getShortcut(for: .enhanceMe) == nil {
            KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        }
        if KeyboardShortcuts.getShortcut(for: .mainWindow) == nil {
            KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .mainWindow)
        }
        // Local (stored for customization)
        if KeyboardShortcuts.getShortcut(for: .settings) == nil {
            KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command]), for: .settings)
        }
        if KeyboardShortcuts.getShortcut(for: .newTask) == nil {
            KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command]), for: .newTask)
        }
    }
    
    private func setupHandlers() {
        KeyboardShortcuts.onKeyUp(for: .quickEntry) { [weak self] in
            self?.showQuickEntry()
        }
        
        KeyboardShortcuts.onKeyUp(for: .enhanceMe) { [weak self] in
            self?.showEnhanceMe()
        }
        
        KeyboardShortcuts.onKeyUp(for: .mainWindow) { [weak self] in
            self?.showMainWindow()
        }
    }
    
    // MARK: - Local Shortcuts (app-wide when focused)
    
    private func setupLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalShortcut(event)
        }
    }
    
    private func handleLocalShortcut(_ event: NSEvent) -> NSEvent? {
        if event.matchesShortcut(.settings) {
            showSettings()
            return nil
        }
        if event.matchesShortcut(.newTask) {
            showNewTaskSheet()
            return nil
        }
        if event.keyCode == 53 { // Escape key
            // First: dismiss any floating window (settings, quick entry, enhance me)
            if WindowManager.shared.dismissVisibleFloatingWindow() {
                return nil
            }
            // Second: if a sheet or modal is presented, let the system handle ESC
            if let keyWindow = NSApp.keyWindow {
                // Check if key window has attached sheets
                if !keyWindow.sheets.isEmpty {
                    return event
                }
                // Check if the key window IS a sheet (attached to another window)
                if keyWindow.sheetParent != nil {
                    return event
                }
                // Check if any visible window has sheets (covers edge cases)
                if NSApp.windows.contains(where: { $0.isVisible && !$0.sheets.isEmpty }) {
                    return event
                }
            }
            // Third: if a text field is being edited, let ESC cancel editing
            if let keyWindow = NSApp.keyWindow,
               let responder = keyWindow.firstResponder as? NSTextView,
               responder.isEditable {
                return event
            }
            // Last: close the main window
            closeMainWindow()
            return nil
        }
        return event
    }
    
    // MARK: - Actions
    
    func showQuickEntry() {
        WindowManager.shared.showQuickEntry()
    }
    
    func showMainWindow() {
        WindowManager.shared.showMainWindow()
    }
    
    func showEnhanceMe() {
        WindowManager.shared.showEnhanceMe()
    }
    
    func showSettings() {
        WindowManager.shared.showSettings()
    }
    
    func closeMainWindow() {
        if let window = WindowManager.shared.getMainWindow() {
            window.close()
        }
    }
    
    func showNewTaskSheet() {
        NotificationCenter.default.post(name: .showNewTaskSheet, object: nil)
    }
    
    func cycleAIMode() {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        AIService.shared.cycleMode(in: context)
    }
    
    static func resetAllToDefaults() {
        KeyboardShortcuts.reset(.quickEntry, .enhanceMe, .mainWindow, .settings, .newTask)
        KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .mainWindow)
        KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command]), for: .settings)
        KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command]), for: .newTask)
    }
}

extension Notification.Name {
    static let showNewTaskSheet = Notification.Name("showNewTaskSheet")
}

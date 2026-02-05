import AppKit
import SwiftUI
import SwiftData

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
        
        let view = QuickEntryView(
            onDismiss: { [weak self] in self?.hideQuickEntry() },
            onSave: { [weak self] in self?.hideQuickEntry() }
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
    
    // MARK: - Main Window
    
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main-window" || $0.title == "Task Manager" }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        }
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

import KeyboardShortcuts
import AppKit
import SwiftData

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    private var modelContainer: ModelContainer?
    
    private init() {
        registerDefaultShortcuts()
        setupHandlers()
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
        // Local (stored for customization, no global handler)
        if KeyboardShortcuts.getShortcut(for: .mainWindow) == nil {
            KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command]), for: .mainWindow)
        }
        if KeyboardShortcuts.getShortcut(for: .settings) == nil {
            KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command]), for: .settings)
        }

    }
    
    private func setupHandlers() {
        KeyboardShortcuts.onKeyUp(for: .quickEntry) { [weak self] in
            self?.showQuickEntry()
        }
        
        KeyboardShortcuts.onKeyUp(for: .enhanceMe) { [weak self] in
            self?.showEnhanceMe()
        }
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
    
    func cycleAIMode() {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        AIService.shared.cycleMode(in: context)
    }
    
    static func resetAllToDefaults() {
        KeyboardShortcuts.reset(.quickEntry, .enhanceMe, .mainWindow, .settings)
        KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command]), for: .mainWindow)
        KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command]), for: .settings)
    }
}

import KeyboardShortcuts
import AppKit

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    private init() {
        registerDefaultShortcuts()
        setupHandlers()
    }
    
    private func registerDefaultShortcuts() {
        if KeyboardShortcuts.getShortcut(for: .quickEntry) == nil {
            KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        }
        if KeyboardShortcuts.getShortcut(for: .mainWindow) == nil {
            KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .mainWindow)
        }
        if KeyboardShortcuts.getShortcut(for: .enhanceMe) == nil {
            KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        }
        if KeyboardShortcuts.getShortcut(for: .settings) == nil {
            KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command, .shift]), for: .settings)
        }
        if KeyboardShortcuts.getShortcut(for: .cycleAIMode) == nil {
            KeyboardShortcuts.setShortcut(.init(.m, modifiers: [.command, .shift]), for: .cycleAIMode)
        }
    }
    
    private func setupHandlers() {
        KeyboardShortcuts.onKeyUp(for: .quickEntry) { [weak self] in
            self?.showQuickEntry()
        }
        
        KeyboardShortcuts.onKeyUp(for: .mainWindow) { [weak self] in
            self?.showMainWindow()
        }
        
        KeyboardShortcuts.onKeyUp(for: .enhanceMe) { [weak self] in
            self?.showEnhanceMe()
        }
        
        KeyboardShortcuts.onKeyUp(for: .settings) { [weak self] in
            self?.showSettings()
        }
        
        KeyboardShortcuts.onKeyUp(for: .cycleAIMode) { [weak self] in
            self?.cycleAIMode()
        }
    }
    
    func showQuickEntry() {
        WindowManager.shared.showQuickEntry()
    }
    
    func showMainWindow() {
        WindowManager.shared.showMainWindow()
    }
    
    func showEnhanceMe() {
        // Phase 3 implementation
        WindowManager.shared.showEnhanceMe()
    }
    
    func showSettings() {
        WindowManager.shared.showSettings()
    }
    
    func cycleAIMode() {
        // Phase 3 implementation
    }
    
    static func resetAllToDefaults() {
        KeyboardShortcuts.reset(.quickEntry, .mainWindow, .enhanceMe, .settings, .cycleAIMode)
        KeyboardShortcuts.setShortcut(.init(.n, modifiers: [.command, .shift]), for: .quickEntry)
        KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .mainWindow)
        KeyboardShortcuts.setShortcut(.init(.e, modifiers: [.command, .shift]), for: .enhanceMe)
        KeyboardShortcuts.setShortcut(.init(.comma, modifiers: [.command, .shift]), for: .settings)
        KeyboardShortcuts.setShortcut(.init(.m, modifiers: [.command, .shift]), for: .cycleAIMode)
    }
}

import AppKit

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    
    override init() {
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            if let icon = NSImage(named: NSImage.Name("MenuBarIcon")) {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "TaskManager")
            }
            button.imagePosition = .imageOnly
            button.toolTip = "TaskManager"
        }
        
        let menu = NSMenu()
        
        let newTaskItem = NSMenuItem(title: "New Task", action: #selector(newTask), keyEquivalent: "")
        newTaskItem.target = self
        menu.addItem(newTaskItem)
        
        let showMainItem = NSMenuItem(title: "Show TaskFlow Pro", action: #selector(showMain), keyEquivalent: "")
        showMainItem.target = self
        menu.addItem(showMainItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let enhanceItem = NSMenuItem(title: "Enhance Me", action: #selector(enhanceMe), keyEquivalent: "")
        enhanceItem.target = self
        menu.addItem(enhanceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func newTask() {
        Task { @MainActor in
            ShortcutManager.shared.showQuickEntry()
        }
    }
    
    @objc private func showMain() {
        Task { @MainActor in
            ShortcutManager.shared.showMainWindow()
        }
    }
    
    @objc private func enhanceMe() {
        Task { @MainActor in
            ShortcutManager.shared.showEnhanceMe()
        }
    }
    
    @objc private func showSettings() {
        Task { @MainActor in
            ShortcutManager.shared.showSettings()
        }
    }
    
    @objc private func quit() {
        Task { @MainActor in
            NSApp.terminate(nil)
        }
    }
}

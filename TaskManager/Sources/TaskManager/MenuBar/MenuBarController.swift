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
                button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Strata")
            }
            button.imagePosition = .imageOnly
            button.toolTip = "Strata"
        }

        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show Strata", action: #selector(showMain), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

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

    @objc private func showMain() {
        Task { @MainActor in
            ShortcutManager.shared.showMainWindow()
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

import AppKit
import SwiftUI
import SwiftData

final class SettingsWindow: NSWindow {
    init(modelContainer: ModelContainer) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Settings"
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.center()
        
        let settingsView = SettingsView()
            .modelContainer(modelContainer)
        
        self.contentView = NSHostingView(rootView: settingsView)
    }
}

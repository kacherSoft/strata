import AppKit
import SwiftUI
import SwiftData

final class SettingsWindow: NSPanel {
    init(modelContainer: ModelContainer) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 480),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Settings"
        self.isFloatingPanel = true
        self.level = .floating
        self.hidesOnDeactivate = true
        self.center()
        
        let settingsView = SettingsView()
            .withAppEnvironment(container: modelContainer)
        
        self.contentView = NSHostingView(rootView: settingsView)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func resignKey() {
        super.resignKey()
        // Don't hide if a sheet is being presented
        if attachedSheet == nil {
            orderOut(nil)
        }
    }
}

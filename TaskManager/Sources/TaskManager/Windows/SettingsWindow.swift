import AppKit
import SwiftUI
import SwiftData

final class SettingsWindow: NSPanel {
    init(modelContainer: ModelContainer) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.title = "Settings"
        self.titlebarAppearsTransparent = true
        self.isFloatingPanel = true
        self.level = .floating
        self.hidesOnDeactivate = true
        self.isMovableByWindowBackground = true
        self.center()

        let settingsView = SettingsView()
            .withAppEnvironment(container: modelContainer)

        self.contentView = NSHostingView(rootView: settingsView)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        if attachedSheet == nil {
            orderOut(nil)
        }
    }
}

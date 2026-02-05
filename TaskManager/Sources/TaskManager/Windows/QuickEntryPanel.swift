import AppKit
import SwiftUI

final class QuickEntryPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        
        self.center()
    }
    
    func setContent<V: View>(_ view: V) {
        self.contentView = NSHostingView(rootView: view)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

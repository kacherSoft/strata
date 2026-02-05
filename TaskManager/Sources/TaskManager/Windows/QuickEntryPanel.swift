import AppKit
import SwiftUI

final class QuickEntryPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Quick Entry"
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        
        self.center()
    }
    
    func setContent<V: View>(_ view: V) {
        self.contentView = NSHostingView(rootView: view)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

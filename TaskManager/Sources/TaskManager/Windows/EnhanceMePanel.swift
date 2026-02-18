import AppKit
import SwiftUI

final class EnhanceMePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        title = "Enhance Me"
        isFloatingPanel = false
        level = .normal
        collectionBehavior = [.fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        
        minSize = NSSize(width: 500, height: 400)
        maxSize = NSSize(width: 1200, height: 800)
    }
    
    func setContent<V: View>(_ view: V) {
        contentView = NSHostingView(rootView: view)
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

import AppKit
import SwiftUI

final class ChatPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = ""
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = false
        level = .normal
        collectionBehavior = [.fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        minSize = NSSize(width: 700, height: 500)
        maxSize = NSSize(width: 1400, height: 900)
    }

    func setContent<V: View>(_ view: V) {
        contentView = NSHostingView(rootView: view)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

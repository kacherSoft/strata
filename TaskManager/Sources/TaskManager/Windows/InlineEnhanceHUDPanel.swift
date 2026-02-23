import AppKit
import SwiftUI

final class InlineEnhanceHUDPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false  // SwiftUI glow layers provide the visual shadow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = true
    }
    
    func setContent<V: View>(_ view: V) {
        // Add padding to allow glow halo to extend beyond the pill without clipping
        let paddedView = view.padding(30)
        let hostingView = NSHostingView(rootView: paddedView)
        let fittingSize = hostingView.fittingSize
        contentView = hostingView
        setContentSize(fittingSize)
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

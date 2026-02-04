import SwiftUI
import AppKit

struct WindowActivator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = ActivatorView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.level = .normal
            window.ignoresMouseEvents = false
            
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

private class ActivatorView: NSView {
    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

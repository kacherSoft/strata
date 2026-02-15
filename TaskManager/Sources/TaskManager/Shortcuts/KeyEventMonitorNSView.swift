import AppKit
import KeyboardShortcuts

@MainActor
class KeyEventMonitorNSView: NSView {
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeMonitor()
        } else if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyEvent(event)
            }
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil { removeMonitor() }
    }

    func handleKeyEvent(_ event: NSEvent) -> NSEvent? { event }

    private func removeMonitor() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

}

extension NSEvent {
    func matchesShortcut(_ name: KeyboardShortcuts.Name) -> Bool {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else { return false }
        let eventMods = modifierFlags.intersection(.deviceIndependentFlagsMask)
        return keyCode == shortcut.carbonKeyCode && eventMods == shortcut.modifiers
    }
}

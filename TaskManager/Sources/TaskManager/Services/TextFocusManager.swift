import AppKit

@MainActor
final class TextFocusManager: ObservableObject {
    static let shared = TextFocusManager()
    
    @Published var isEnhancing: Bool = false
    @Published var currentModeName: String = ""
    
    private var focusedElement: AXUIElement?
    private var focusedPID: pid_t = 0
    private var capturedText: String = ""
    private var hadSelection: Bool = false
    private var selectedRange: CFRange?
    
    // Track which PIDs we've already enabled manual accessibility for (Electron apps)
    private var manualAXEnabledPIDs = Set<pid_t>()
    
    private init() {}
    
    // MARK: - Capture Text
    
    func captureText() -> String? {
        guard AccessibilityManager.shared.isAccessibilityEnabled else { return nil }
        
        let systemWide = AXUIElementCreateSystemWide()
        
        // Get initial focused element + PID
        guard let (initialElement, pid) = getFocusedElement(systemWide) else { return nil }
        
        // Enable Electron accessibility if needed, then re-fetch
        ensureManualAccessibility(for: pid)
        
        // Re-fetch focused element (Electron rebuilds AX tree after flag is set)
        let element: AXUIElement
        if manualAXEnabledPIDs.contains(pid),
           let (refreshed, _) = getFocusedElement(systemWide) {
            element = refreshed
        } else {
            element = initialElement
        }
        
        // Walk up parent chain to find the best text-capable element
        let textElement = findTextElement(from: element)
        
        self.focusedElement = textElement
        self.focusedPID = pid
        
        // Try selected text first
        if let selectedText = getStringAttribute(textElement, kAXSelectedTextAttribute as String),
           !selectedText.isEmpty {
            self.capturedText = selectedText
            self.hadSelection = true
            
            var rangeValue: AnyObject?
            AXUIElementCopyAttributeValue(
                textElement,
                kAXSelectedTextRangeAttribute as CFString,
                &rangeValue
            )
            if let rangeRef = rangeValue {
                var range = CFRange()
                AXValueGetValue(rangeRef as! AXValue, .cfRange, &range)
                self.selectedRange = range
            }
            
            return selectedText
        }
        
        // Fall back to full value
        if let fullText = getStringAttribute(textElement, kAXValueAttribute as String),
           !fullText.isEmpty {
            self.capturedText = fullText
            self.hadSelection = false
            return fullText
        }
        
        // No text found
        self.focusedElement = nil
        self.focusedPID = 0
        return nil
    }
    
    // MARK: - Electron Accessibility
    
    private func ensureManualAccessibility(for pid: pid_t) {
        guard !manualAXEnabledPIDs.contains(pid) else { return }
        
        let appElement = AXUIElementCreateApplication(pid)
        let err = AXUIElementSetAttributeValue(
            appElement,
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )
        
        if err == .success {
            manualAXEnabledPIDs.insert(pid)
            // Brief pause for AX tree rebuild
            usleep(50_000)
        }
    }
    
    // MARK: - Focus Detection
    
    private func getFocusedElement(_ systemWide: AXUIElement) -> (AXUIElement, pid_t)? {
        var focusedValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard result == .success, let focused = focusedValue else { return nil }
        
        let element = focused as! AXUIElement
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return (element, pid)
    }
    
    // MARK: - Text Element Discovery
    
    private func findTextElement(from start: AXUIElement) -> AXUIElement {
        // Check if current element already has text attributes
        if hasTextCapability(start) { return start }
        
        // Walk up parent chain to find a text-capable element
        var current: AXUIElement = start
        for _ in 0..<8 {
            var parentValue: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentValue) == .success,
                  let parent = parentValue else { break }
            
            let parentElement = parent as! AXUIElement
            if hasTextCapability(parentElement) {
                return parentElement
            }
            current = parentElement
        }
        
        return start
    }
    
    private func hasTextCapability(_ element: AXUIElement) -> Bool {
        // Check role first — known text roles are a strong signal
        if let role = getStringAttribute(element, kAXRoleAttribute as String) {
            let textRoles: Set<String> = [
                kAXTextFieldRole, kAXTextAreaRole,
                "AXComboBox", "AXSearchField",
            ]
            if textRoles.contains(role) { return true }
        }
        
        // Check if element exposes text attributes (works for non-standard roles)
        var names: CFArray?
        guard AXUIElementCopyAttributeNames(element, &names) == .success,
              let attrNames = names as? [String] else { return false }
        
        let hasSelectedText = attrNames.contains(kAXSelectedTextAttribute as String)
        let hasValue = attrNames.contains(kAXValueAttribute as String)
        
        if hasSelectedText { return true }
        
        // Has value, but verify it's a String (not a slider/stepper number)
        if hasValue {
            var valueCheck: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueCheck)
            return valueCheck is String
        }
        
        return false
    }
    
    // MARK: - Replace Text
    
    func replaceText(_ newText: String) -> Bool {
        guard let element = focusedElement else { return false }
        
        // Validate focus hasn't changed (PID check)
        let systemWide = AXUIElementCreateSystemWide()
        var currentFocused: AnyObject?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &currentFocused)
        if let current = currentFocused {
            var currentPID: pid_t = 0
            AXUIElementGetPid(current as! AXUIElement, &currentPID)
            guard currentPID == focusedPID else { return false }
        }
        
        // Strategy 1: Try AXSelectedText (best for selection replacement)
        if hadSelection {
            var isSettable: DarwinBoolean = false
            AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSettable)
            if isSettable.boolValue {
                let result = AXUIElementSetAttributeValue(
                    element, kAXSelectedTextAttribute as CFString, newText as CFTypeRef
                )
                if result == .success { return true }
            }
        }
        
        // Strategy 2: Try AXValue (full field replacement)
        var isValueSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isValueSettable)
        if isValueSettable.boolValue {
            let axResult: AXError
            if hadSelection, let range = selectedRange {
                // Replace selection within full value
                var fullValue: AnyObject?
                AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &fullValue)
                if let fullText = fullValue as? String {
                    let nsString = fullText as NSString
                    let nsRange = NSRange(location: range.location, length: range.length)
                    let replaced = nsString.replacingCharacters(in: nsRange, with: newText)
                    axResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, replaced as CFTypeRef)
                } else {
                    axResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
                }
            } else {
                axResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
            }
            if axResult == .success { return true }
        }
        
        // Strategy 3: Clipboard paste fallback (Warp, Electron apps with read-only AX)
        return replaceViaClipboard(newText: newText)
    }
    
    private func replaceViaClipboard(newText: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        if !hadSelection {
            simulateKeyCombo(key: 0x00, flags: .maskCommand) // ⌘A
            usleep(50_000)
        }
        simulateKeyCombo(key: 0x09, flags: .maskCommand) // ⌘V
        
        // Restore clipboard after paste completes
        let prev = previousContents
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            if let prev {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
        }
        
        return true
    }
    
    // MARK: - Helpers
    
    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }
    
    private func simulateKeyCombo(key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
            keyDown.flags = flags
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
            keyUp.flags = flags
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Source Field Position
    
    func getSourceFieldRect() -> NSRect? {
        guard let element = focusedElement else { return nil }
        
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        
        guard let posRef = positionValue, let sizeRef = sizeValue else { return nil }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            return nil
        }
        
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let convertedRect = NSRect(
            x: position.x,
            y: screenHeight - position.y - size.height,
            width: size.width,
            height: size.height
        )
        
        let isOnScreen = NSScreen.screens.contains { $0.frame.intersects(convertedRect) }
        guard isOnScreen else { return nil }
        
        return convertedRect
    }
    
    // MARK: - Reset
    
    func reset() {
        focusedElement = nil
        focusedPID = 0
        capturedText = ""
        hadSelection = false
        selectedRange = nil
        isEnhancing = false
        currentModeName = ""
    }
}

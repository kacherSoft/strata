import AppKit

struct CapturedText {
    let content: String
    let sourceElement: AXUIElement
    let sourcePID: pid_t
    let hadSelection: Bool
    let selectedRange: CFRange?
    let captureMethod: CaptureMethod
    let appCategory: AppCategory
    let previousClipboard: String?
}

enum CaptureMethod: String {
    case directSelectedText
    case directValue
    case parentTraversal
    case childDescent
    case webRangeExtraction
    case clipboardFallback
}

@MainActor
final class TextCaptureEngine: ObservableObject {
    static let shared = TextCaptureEngine()
    
    @Published var lastCaptureMethod: CaptureMethod?
    @Published var lastAppCategory: AppCategory?
    
    var enableDebugLogging: Bool = false
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    func capture() -> CapturedText? {
        guard AccessibilityManager.shared.isAccessibilityEnabled else {
            log("Accessibility not enabled")
            return nil
        }
        
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused element and PID
        if let (initialElement, pid) = getFocusedElement(systemWide) {
            // Detect app category
            let appCategory = AppCategoryDetector.shared.detect(pid: pid)
            let isWebview = AppCategoryDetector.shared.detectWebview(in: initialElement)
            let effectiveCategory = isWebview ? .webview : appCategory

            log("App category: \(effectiveCategory.rawValue), PID: \(pid)")

            // Handle Electron specially
            if effectiveCategory == .electron {
                ElectronSpecialist.shared.ensureAccessibility(for: pid)

                // Refresh element after Electron accessibility setup
                if let (refreshed, _) = getFocusedElement(systemWide) {
                    return tryCaptureWith(element: refreshed, pid: pid, category: effectiveCategory)
                }
            }

            return tryCaptureWith(element: initialElement, pid: pid, category: effectiveCategory)
        }

        // Focused element can be missing in Electron/Web apps until manual AX is enabled.
        // Fallback: detect frontmost app, enable Electron AX if needed, then retry once.
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            log("No focused element found and no frontmost app")
            return nil
        }

        let pid = frontmost.processIdentifier
        let category = AppCategoryDetector.shared.detect(pid: pid)
        log("No focused element from system-wide AX. Frontmost app: \(frontmost.localizedName ?? "unknown") category=\(category.rawValue)")

        if category == .electron {
            ElectronSpecialist.shared.ensureAccessibility(for: pid)
            if let (refreshed, _) = getFocusedElement(systemWide) {
                let isWebview = AppCategoryDetector.shared.detectWebview(in: refreshed)
                return tryCaptureWith(element: refreshed, pid: pid, category: isWebview ? .webview : .electron)
            }
            log("No focused element found after Electron bootstrap")
            return nil
        }

        // Browser/Webview fallback: use frontmost app element directly.
        if category == .browser || category == .native {
            let appElement = AXUIElementCreateApplication(pid)
            var focusedValue: AnyObject?
            let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
            if focusedResult == .success, let focusedValue {
                let focused = unsafeDowncast(focusedValue, to: AXUIElement.self)
                let asWebview = AppCategoryDetector.shared.detectWebview(in: focused)
                let effective: AppCategory = asWebview ? .webview : category
                log("Recovered focused element from app root for \(category.rawValue)")
                return tryCaptureWith(element: focused, pid: pid, category: effective)
            }

            // Last chance for browser: ask for focused window then focused element.
            var windowValue: AnyObject?
            let windowResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
            if windowResult == .success, let windowValue {
                let windowElement = unsafeDowncast(windowValue, to: AXUIElement.self)
                var windowFocused: AnyObject?
                let wfResult = AXUIElementCopyAttributeValue(windowElement, kAXFocusedUIElementAttribute as CFString, &windowFocused)
                if wfResult == .success, let windowFocused {
                    let focused = unsafeDowncast(windowFocused, to: AXUIElement.self)
                    let asWebview = AppCategoryDetector.shared.detectWebview(in: focused)
                    let effective: AppCategory = asWebview ? .webview : category
                    log("Recovered focused element from focused window for \(category.rawValue)")
                    return tryCaptureWith(element: focused, pid: pid, category: effective)
                }
                log("Focused-window fallback failed: error=\(wfResult.rawValue)")
            } else {
                log("Focused-window lookup failed: error=\(windowResult.rawValue)")
            }
        }

        log("No focused element found")
        return nil
    }
    
    private func tryCaptureWith(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        if let role = getStringAttribute(element, kAXRoleAttribute as String) {
            log("Capture start: pid=\(pid) category=\(category.rawValue) focusedRole=\(role)")
        } else {
            log("Capture start: pid=\(pid) category=\(category.rawValue) focusedRole=<unknown>")
        }

        // Try layered capture
        if let captured = tryLayeredCapture(element: element, pid: pid, category: category) {
            lastCaptureMethod = captured.captureMethod
            lastAppCategory = category
            log("Capture success via \(captured.captureMethod.rawValue), len=\(captured.content.count), hadSelection=\(captured.hadSelection)")
            return captured
        }

        // Final fallback: clipboard
        if let captured = captureViaClipboard(element: element, pid: pid, category: category) {
            lastCaptureMethod = captured.captureMethod
            lastAppCategory = category
            log("Capture success via clipboard fallback, len=\(captured.content.count)")
            return captured
        }

        log("All capture methods failed")
        return nil
    }
    
    // MARK: - Layered Capture
    
    private func tryLayeredCapture(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        // Layer 1: Direct detection on focused element
        if let captured = tryDirectCapture(element: element, pid: pid, category: category) {
            return captured
        }
        
        // Layer 2: Parent traversal
        if let captured = tryParentTraversal(element: element, pid: pid, category: category) {
            return captured
        }
        
        // Layer 3: Child descent (for container elements)
        if let captured = tryChildDescent(element: element, pid: pid, category: category) {
            return captured
        }
        
        // Layer 4: Web content extraction (range-based)
        if category == .browser || category == .webview || category == .electron {
            if let captured = tryWebExtraction(element: element, pid: pid, category: category) {
                return captured
            }
        }
        
        return nil
    }
    
    // MARK: - Layer 1: Direct Capture
    
    private func tryDirectCapture(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        log("Layer 1: Trying direct capture")
        
        // Skip secure fields
        if isSecureField(element) {
            log("Skipping secure field")
            return nil
        }
        
        // Try selected text first
        if let selectedText = getStringAttribute(element, kAXSelectedTextAttribute as String),
           !selectedText.isEmpty {
            log("Layer 1: Found selected text directly")
            
            let range = getSelectedRange(from: element)
            return CapturedText(
                content: selectedText,
                sourceElement: element,
                sourcePID: pid,
                hadSelection: true,
                selectedRange: range,
                captureMethod: .directSelectedText,
                appCategory: category,
                previousClipboard: nil
            )
        }
        
        // Try full value
        if let fullText = getStringAttribute(element, kAXValueAttribute as String),
           !fullText.isEmpty {
            log("Layer 1: Found value directly")
            
            return CapturedText(
                content: fullText,
                sourceElement: element,
                sourcePID: pid,
                hadSelection: false,
                selectedRange: nil,
                captureMethod: .directValue,
                appCategory: category,
                previousClipboard: nil
            )
        }
        
        return nil
    }
    
    // MARK: - Layer 2: Parent Traversal
    
    private func tryParentTraversal(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        log("Layer 2: Trying parent traversal")
        
        var current = element
        for depth in 0..<8 {
            var parentValue: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentValue) == .success,
                  let parentValue else { break }
            
            let parentElement = unsafeDowncast(parentValue, to: AXUIElement.self)
            
            if let captured = tryDirectCapture(element: parentElement, pid: pid, category: category) {
                log("Layer 2: Found text at parent depth \(depth + 1)")
                return CapturedText(
                    content: captured.content,
                    sourceElement: parentElement,
                    sourcePID: pid,
                    hadSelection: captured.hadSelection,
                    selectedRange: captured.selectedRange,
                    captureMethod: .parentTraversal,
                    appCategory: category,
                    previousClipboard: nil
                )
            }
            
            current = parentElement
        }
        
        return nil
    }
    
    // MARK: - Layer 3: Child Descent
    
    private func tryChildDescent(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        log("Layer 3: Trying child descent")
        
        // Only search down from container roles
        guard let role = getStringAttribute(element, kAXRoleAttribute as String),
              isContainerRole(role) else {
            return nil
        }
        
        log("Layer 3: Element is container role: \(role)")
        
        if let found = findTextElementInChildren(element, depth: 0) {
            log("Layer 3: Found text element in children")
            if let captured = tryDirectCapture(element: found, pid: pid, category: category) {
                return CapturedText(
                    content: captured.content,
                    sourceElement: found,
                    sourcePID: pid,
                    hadSelection: captured.hadSelection,
                    selectedRange: captured.selectedRange,
                    captureMethod: .childDescent,
                    appCategory: category,
                    previousClipboard: nil
                )
            }
        }
        
        return nil
    }
    
    private func isContainerRole(_ role: String) -> Bool {
        let containerRoles: Set<String> = [
            "AXWebArea",
            "AXGroup",
            "AXScrollArea",
            "AXOutline",
            "AXTable",
            "AXRow",
            "AXColumn",
            "AXOutlineRow",
        ]
        return containerRoles.contains(role)
    }
    
    private func findTextElementInChildren(_ element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 12 else { return nil }  // Oracle: increased from 5 to 12 for complex DOM
        
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childArray = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childArray {
            // Check if this child has text capability
            if hasTextCapability(child) {
                return child
            }
            
            // Recurse
            if let found = findTextElementInChildren(child, depth: depth + 1) {
                return found
            }
        }
        
        return nil
    }
    
    private func hasTextCapability(_ element: AXUIElement) -> Bool {
        // Skip secure fields
        if isSecureField(element) { return false }
        
        // Check role
        if let role = getStringAttribute(element, kAXRoleAttribute as String) {
            let textRoles: Set<String> = [
                kAXTextFieldRole, kAXTextAreaRole,
                "AXComboBox", "AXSearchField",
                "AXWebArea"
            ]
            if textRoles.contains(role) { return true }
        }
        
        // Check attributes
        var names: CFArray?
        guard AXUIElementCopyAttributeNames(element, &names) == .success,
              let attrNames = names as? [String] else { return false }
        
        if attrNames.contains(kAXSelectedTextAttribute as String) { return true }
        if attrNames.contains(kAXSelectedTextRangeAttribute as String) { return true }
        if attrNames.contains("AXPlaceholderValue") { return true }
        
        // Check if value is string
        if attrNames.contains(kAXValueAttribute as String) {
            var valueCheck: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueCheck)
            return valueCheck is String
        }
        
        return false
    }
    
    private func isSecureField(_ element: AXUIElement) -> Bool {
        // Check role
        if let role = getStringAttribute(element, kAXRoleAttribute as String),
           role == "AXSecureTextField" {
            return true
        }
        
        // Check secure attribute
        var isSecure: AnyObject?
        if AXUIElementCopyAttributeValue(element, "AXIsSecure" as CFString, &isSecure) == .success,
           let secure = isSecure as? Bool {
            return secure
        }
        
        return false
    }
    
    // MARK: - Layer 4: Web Extraction
    
    private func tryWebExtraction(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        log("Layer 4: Trying web extraction (range-based)")
        
        // Skip secure fields
        if isSecureField(element) { return nil }
        
        // Get the text element (might need to descend)
        let textElement: AXUIElement
        if hasTextCapability(element) {
            textElement = element
        } else if let found = findTextElementInChildren(element, depth: 0) {
            textElement = found
        } else {
            return nil
        }
        
        // Get full value
        guard let fullText = getStringAttribute(textElement, kAXValueAttribute as String),
              !fullText.isEmpty else {
            return nil
        }
        
        // Try to get selection range
        if let range = getSelectedRange(from: textElement), range.length > 0 {
            let nsString = fullText as NSString
            let safeLocation = max(0, range.location)
            let safeLength = max(0, range.length)
            guard safeLocation <= nsString.length else { return nil }
            let clampedLength = min(safeLength, nsString.length - safeLocation)
            let nsRange = NSRange(location: safeLocation, length: clampedLength)
            let selectedText = nsString.substring(with: nsRange)
            
            log("Layer 4: Extracted selection via range")
            return CapturedText(
                content: selectedText,
                sourceElement: textElement,
                sourcePID: pid,
                hadSelection: true,
                selectedRange: range,
                captureMethod: .webRangeExtraction,
                appCategory: category,
                previousClipboard: nil
            )
        }
        
        // No selection, return full text
        log("Layer 4: Returning full value (no selection)")
        return CapturedText(
            content: fullText,
            sourceElement: textElement,
            sourcePID: pid,
            hadSelection: false,
            selectedRange: nil,
            captureMethod: .webRangeExtraction,
            appCategory: category,
            previousClipboard: nil
        )
    }
    
    // MARK: - Layer 5: Clipboard Fallback
    
    private func captureViaClipboard(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        log("Layer 5: Using clipboard fallback")
        
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        
        // Clear and copy
        pasteboard.clearContents()
        
        // Simulate ⌘C
        simulateKeyCombo(key: 0x08, flags: .maskCommand)
        usleep(100_000) // Wait for copy
        
        guard let copiedText = pasteboard.string(forType: .string),
              !copiedText.isEmpty else {
            // Restore clipboard synchronously
            if let prev = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
            return nil
        }

        // Restore user clipboard immediately to avoid data loss.
        if let prev = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(prev, forType: .string)
        }
        
        log("Layer 5: Captured \(copiedText.count) chars via clipboard")
        return CapturedText(
            content: copiedText,
            sourceElement: element,
            sourcePID: pid,
            hadSelection: true, // Clipboard captures selection
            selectedRange: nil,
            captureMethod: .clipboardFallback,
            appCategory: category,
            previousClipboard: previousContents
        )
    }
    
    // MARK: - Helpers
    
    private func getFocusedElement(_ systemWide: AXUIElement) -> (AXUIElement, pid_t)? {
        // Retry a few times because global shortcut timing can race with focus reporting
        for attempt in 1...3 {
            if let focused = getFocusedElementDirect(systemWide) {
                if attempt > 1 { log("Focused element found on retry #\(attempt)") }
                return focused
            }
            usleep(30_000)
        }

        // Fallback 1: focused application -> focused UI element
        var appValue: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &appValue)
        if appResult == .success, let appValue {
            let appElement = unsafeDowncast(appValue, to: AXUIElement.self)
            var focusedValue: AnyObject?
            let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
            if focusedResult == .success, let focusedValue {
                let element = unsafeDowncast(focusedValue, to: AXUIElement.self)
                var pid: pid_t = 0
                AXUIElementGetPid(element, &pid)
                log("Focused element resolved via focused application fallback")
                return (element, pid)
            }
            log("Focused app fallback failed: AXFocusedUIElement error=\(focusedResult.rawValue)")
        } else {
            log("Focused application lookup failed: error=\(appResult.rawValue)")
        }

        // Fallback 2: frontmost NSWorkspace app -> focused UI element
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
            var focusedValue: AnyObject?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
            if result == .success, let focusedValue {
                let element = unsafeDowncast(focusedValue, to: AXUIElement.self)
                var pid: pid_t = 0
                AXUIElementGetPid(element, &pid)
                log("Focused element resolved via NSWorkspace frontmost fallback (\(frontmost.localizedName ?? "unknown"))")
                return (element, pid)
            }
            log("Frontmost fallback failed for \(frontmost.localizedName ?? "unknown"): error=\(result.rawValue)")
        }

        return nil
    }

    private func getFocusedElementDirect(_ systemWide: AXUIElement) -> (AXUIElement, pid_t)? {
        var focusedValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard result == .success, let focusedValue else {
            log("Direct focused element lookup failed: error=\(result.rawValue)")
            return nil
        }

        let element = unsafeDowncast(focusedValue, to: AXUIElement.self)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return (element, pid)
    }
    
    private func getSelectedRange(from element: AXUIElement) -> CFRange? {
        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success,
        let rangeValue,
        CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }

        let axValue = unsafeDowncast(rangeValue, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }
    
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
    
    private func log(_ message: String) {
        if enableDebugLogging {
            print("[TextCaptureEngine] \(message)")
        }
    }
}

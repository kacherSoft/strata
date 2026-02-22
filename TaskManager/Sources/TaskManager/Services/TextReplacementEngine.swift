import AppKit

struct ReplacementResult {
    let success: Bool
    let strategy: ReplacementStrategy
    let error: String?
    let verified: Bool
}

enum ReplacementStrategy: String {
    case directValueSet
    case selectionReplace
    case rangeBasedUpdate
    case clipboardPaste
}

@MainActor
final class TextReplacementEngine: ObservableObject {
    static let shared = TextReplacementEngine()
    
    @Published var lastReplacementStrategy: ReplacementStrategy?
    
    var enableDebugLogging: Bool = false
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    func replace(captured: CapturedText, newText: String) -> ReplacementResult {
        log("Starting replacement: category=\(captured.appCategory.rawValue) captureMethod=\(captured.captureMethod.rawValue) hadSelection=\(captured.hadSelection) inputLen=\(captured.content.count) outputLen=\(newText.count)")
        
        // Validate focus hasn't changed
        guard validateFocus(captured) else {
            log("Focus validation failed - PID changed")
            return ReplacementResult(success: false, strategy: .directValueSet, error: "Focus changed", verified: false)
        }
        
        // Try strategies in order
        let strategies: [(ReplacementStrategy, (CapturedText, String) -> ReplacementResult)] = [
            (.directValueSet, tryDirectValueSet),
            (.selectionReplace, trySelectionReplace),
            (.rangeBasedUpdate, tryRangeBasedUpdate),
            (.clipboardPaste, tryClipboardPaste),
        ]
        
        for (strategy, handler) in strategies {
            log("Trying strategy: \(strategy.rawValue)")
            let result = handler(captured, newText)

            if result.success {
                // IMPORTANT: do not try another strategy after any successful write.
                // Retrying mutating strategies can duplicate text.
                let verified = verifyReplacement(captured: captured, expectedText: newText)
                lastReplacementStrategy = strategy
                if verified {
                    log("Strategy \(strategy.rawValue) succeeded and verified")
                } else {
                    log("Strategy \(strategy.rawValue) succeeded but could not be verified")
                }
                return ReplacementResult(success: true, strategy: strategy, error: nil, verified: verified)
            }

            log("Strategy \(strategy.rawValue) failed: \(result.error ?? "unknown")")
        }

        log("All replacement strategies failed")
        return ReplacementResult(success: false, strategy: .clipboardPaste, error: "All replacement strategies failed", verified: false)
    }
    
    // MARK: - Verification
    
    private func verifyReplacement(captured: CapturedText, expectedText: String) -> Bool {
        // Small delay to let the app update
        usleep(50_000)

        let element = captured.sourceElement

        // Selection replacement verification: compare selected text first
        if captured.hadSelection {
            var selectedObj: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedObj) == .success,
               let selected = selectedObj as? String {
                let match = selected == expectedText
                log("Verification(selected): \(match ? "PASSED" : "FAILED")")
                return match
            }

            // Fallback: range-based check in full value
            var valueObj: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
               let full = valueObj as? String,
               let range = captured.selectedRange {
                let ns = full as NSString
                let nsRange = NSRange(location: range.location, length: min(range.length, max(0, ns.length - range.location)))
                if nsRange.location >= 0, nsRange.location + nsRange.length <= ns.length {
                    let replacedSegment = ns.substring(with: nsRange)
                    let match = replacedSegment == expectedText
                    log("Verification(range): \(match ? "PASSED" : "FAILED")")
                    return match
                }
            }

            // If app does not expose verification attributes after edit, do not block success.
            log("Verification: selection attributes unavailable, assuming success")
            return true
        }

        // Full-field replacement verification
        var valueObj: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
              let currentValue = valueObj as? String else {
            log("Verification: value unavailable, assuming success")
            return true
        }

        let match = currentValue == expectedText
        log("Verification(value): \(match ? "PASSED" : "FAILED")")
        return match
    }
    
    // MARK: - Focus Validation
    
    private func validateFocus(_ captured: CapturedText) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var currentFocused: AnyObject?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &currentFocused)

        if let current = currentFocused {
            let currentElement = unsafeDowncast(current, to: AXUIElement.self)
            var currentPID: pid_t = 0
            AXUIElementGetPid(currentElement, &currentPID)

            // Strong check first: same focused element
            if CFEqual(currentElement, captured.sourceElement) {
                log("Focus validation: PASSED (same AX element)")
                return true
            }

            // Fallback check: same process
            let samePID = currentPID == captured.sourcePID
            log("Focus validation: \(samePID ? "PASSED" : "FAILED") (element changed, expected PID \(captured.sourcePID), got \(currentPID))")
            return samePID
        }

        return true // Can't verify, assume OK
    }
    
    // MARK: - Strategy 1: Direct Value Set
    
    private func tryDirectValueSet(_ captured: CapturedText, _ newText: String) -> ReplacementResult {
        let element = captured.sourceElement
        
        // Check if settable
        var isSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable)
        
        guard isSettable.boolValue else {
            log("kAXValueAttribute not settable")
            return ReplacementResult(success: false, strategy: .directValueSet, error: "Not settable", verified: false)
        }
        
        // Determine final text
        let finalText: String
        if captured.hadSelection, let range = captured.selectedRange {
            // Need to replace within full text
            var fullValue: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &fullValue)
            if let fullText = fullValue as? String {
                let nsString = fullText as NSString
                let safeLocation = max(0, range.location)
                let safeLength = max(0, range.length)
                guard safeLocation <= nsString.length else {
                    return ReplacementResult(success: false, strategy: .directValueSet, error: "Selection range out of bounds", verified: false)
                }
                let clampedLength = min(safeLength, nsString.length - safeLocation)
                let nsRange = NSRange(location: safeLocation, length: clampedLength)
                finalText = nsString.replacingCharacters(in: nsRange, with: newText)
            } else {
                finalText = newText
            }
        } else {
            finalText = newText
        }
        
        // Set value
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, finalText as CFTypeRef)
        
        if result == .success {
            return ReplacementResult(success: true, strategy: .directValueSet, error: nil, verified: false)
        } else {
            log("AXUIElementSetAttributeValue failed: \(result.rawValue)")
            return ReplacementResult(success: false, strategy: .directValueSet, error: "AXError: \(result.rawValue)", verified: false)
        }
    }
    
    // MARK: - Strategy 2: Selection Replacement
    
    private func trySelectionReplace(_ captured: CapturedText, _ newText: String) -> ReplacementResult {
        guard captured.hadSelection else {
            return ReplacementResult(success: false, strategy: .selectionReplace, error: "No selection", verified: false)
        }
        
        let element = captured.sourceElement
        
        // Check if settable
        var isSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &isSettable)
        
        guard isSettable.boolValue else {
            log("kAXSelectedTextAttribute not settable")
            return ReplacementResult(success: false, strategy: .selectionReplace, error: "Not settable", verified: false)
        }
        
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newText as CFTypeRef)
        
        if result == .success {
            return ReplacementResult(success: true, strategy: .selectionReplace, error: nil, verified: false)
        } else {
            return ReplacementResult(success: false, strategy: .selectionReplace, error: "AXError: \(result.rawValue)", verified: false)
        }
    }
    
    // MARK: - Strategy 3: Range-Based Update
    
    private func tryRangeBasedUpdate(_ captured: CapturedText, _ newText: String) -> ReplacementResult {
        let element = captured.sourceElement
        
        // Get current value
        var valueObj: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
              let currentText = valueObj as? String else {
            return ReplacementResult(success: false, strategy: .rangeBasedUpdate, error: "Cannot get value", verified: false)
        }
        
        // Check if value is settable
        var isSettable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable)
        
        guard isSettable.boolValue else {
            return ReplacementResult(success: false, strategy: .rangeBasedUpdate, error: "Value not settable", verified: false)
        }
        
        // Build replacement text
        let finalText: String
        if captured.hadSelection, let range = captured.selectedRange {
            let nsString = currentText as NSString
            let safeLocation = max(0, range.location)
            let safeLength = max(0, range.length)
            guard safeLocation <= nsString.length else {
                return ReplacementResult(success: false, strategy: .rangeBasedUpdate, error: "Selection range out of bounds", verified: false)
            }
            let clampedLength = min(safeLength, nsString.length - safeLocation)
            let nsRange = NSRange(location: safeLocation, length: clampedLength)
            finalText = nsString.replacingCharacters(in: nsRange, with: newText)
        } else {
            // Replace all
            finalText = newText
        }
        
        // Set new value
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, finalText as CFTypeRef)
        
        if result == .success {
            return ReplacementResult(success: true, strategy: .rangeBasedUpdate, error: nil, verified: false)
        } else {
            return ReplacementResult(success: false, strategy: .rangeBasedUpdate, error: "AXError: \(result.rawValue)", verified: false)
        }
    }
    
    // MARK: - Strategy 4: Clipboard Paste (with synchronous restore)
    
    private func tryClipboardPaste(_ captured: CapturedText, _ newText: String) -> ReplacementResult {
        log("Using clipboard paste strategy")
        
        let pasteboard = NSPasteboard.general
        let previousContents = captured.previousClipboard ?? pasteboard.string(forType: .string)
        
        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        // Ensure app is frontmost
        if let app = NSRunningApplication(processIdentifier: captured.sourcePID) {
            app.activate(options: [])
            usleep(30_000)
        }
        
        // Select all if no selection
        if !captured.hadSelection {
            simulateKeyCombo(key: 0x00, flags: .maskCommand) // ⌘A
            usleep(50_000)
        }
        
        // Paste
        simulateKeyCombo(key: 0x09, flags: .maskCommand) // ⌘V
        usleep(50_000)  // Wait for paste to complete
        
        // Oracle: Restore clipboard synchronously
        if let prev = previousContents {
            pasteboard.clearContents()
            pasteboard.setString(prev, forType: .string)
        }
        
        return ReplacementResult(success: true, strategy: .clipboardPaste, error: nil, verified: false)
    }
    
    // MARK: - Helpers
    
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
            print("[TextReplacementEngine] \(message)")
        }
    }
}

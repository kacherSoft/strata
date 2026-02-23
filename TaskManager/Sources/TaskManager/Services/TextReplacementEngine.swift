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
        let strategies: [(ReplacementStrategy, (CapturedText, String) -> ReplacementResult)]
        if isArcBrowser(pid: captured.sourcePID) {
            strategies = [
                (.clipboardPaste, tryClipboardPaste),
            ]
        } else {
            strategies = [
                (.directValueSet, tryDirectValueSet),
                (.selectionReplace, trySelectionReplace),
                (.clipboardPaste, tryClipboardPaste),
            ]
        }
        
        for (strategy, handler) in strategies {
            log("Trying strategy: \(strategy.rawValue)")
            let result = handler(captured, newText)

            if result.success {
                let verified = verifyReplacement(captured: captured, expectedText: newText)

                // Browser/WebView text fields can report successful AX writes while ignoring updates.
                // For browsers, only stop early on verified success or clipboard fallback.
                if !verified,
                   (captured.appCategory == .browser || captured.appCategory == .webview || captured.appCategory == .electron),
                   strategy != .clipboardPaste {
                    log("Strategy \(strategy.rawValue) reported success but verification failed in browser/webview/electron; trying next strategy")
                    continue
                }

                // IMPORTANT: do not try another strategy after a verified write.
                // Retrying mutating strategies can duplicate text.
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
        usleep(50_000)

        let element = captured.sourceElement

        if captured.hadSelection {
            var selectedObj: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedObj) == .success,
               let selected = selectedObj as? String,
               !selected.isEmpty {
                let match = selected == expectedText
                log("Verification(selected): \(match ? "PASSED" : "FAILED")")
                if match { return true }
            }

            if let range = captured.selectedRange {
                var valueObj: AnyObject?
                if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
                   let full = valueObj as? String {
                    let ns = full as NSString
                    let expectedLength = (expectedText as NSString).length
                    let safeLocation = max(0, range.location)
                    guard safeLocation <= ns.length else {
                        log("Verification(range): FAILED")
                        return false
                    }
                    let clampedLength = min(expectedLength, ns.length - safeLocation)
                    let nsRange = NSRange(location: safeLocation, length: clampedLength)
                    let replacedSegment = ns.substring(with: nsRange)
                    let match = replacedSegment == expectedText
                    log("Verification(range): \(match ? "PASSED" : "FAILED")")
                    return match
                }
            }

            log("Verification: selection attributes unavailable, assuming success")
            return true
        }

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
    
    // MARK: - Strategy 3: Clipboard Paste (with synchronous restore)
    
    private func tryClipboardPaste(_ captured: CapturedText, _ newText: String) -> ReplacementResult {
        log("Using clipboard paste strategy")
        
        let pasteboard = NSPasteboard.general
        let previousSnapshot = captured.previousClipboard ?? ClipboardSnapshot.capture(from: pasteboard)
        
        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        // Ensure app is frontmost
        if let app = NSRunningApplication(processIdentifier: captured.sourcePID) {
            app.activate(options: [])
            usleep(40_000)
        }

        // Re-focus original source element when possible (helps browser-based editors)
        var focusedResult = AXUIElementSetAttributeValue(
            captured.sourceElement,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        if focusedResult != .success {
            focusedResult = AXUIElementPerformAction(captured.sourceElement, kAXPressAction as CFString)
        }
        log("Focus restore result before paste: \(focusedResult.rawValue)")

        // Recreate selection only if focused element is still the captured element.
        if captured.hadSelection,
           let range = captured.selectedRange,
           isFocusedElementStillCaptured(captured) {
            var mutableRange = range
            if let rangeAX = AXValueCreate(.cfRange, &mutableRange) {
                let rangeResult = AXUIElementSetAttributeValue(
                    captured.sourceElement,
                    kAXSelectedTextRangeAttribute as CFString,
                    rangeAX
                )
                log("Selection restore result before paste: \(rangeResult.rawValue)")
            }
        } else if captured.hadSelection {
            log("Selection restore skipped: focused element changed")
        }
        usleep(40_000)
        
        let targetPID: pid_t? = isArcBrowser(pid: captured.sourcePID) ? captured.sourcePID : nil
        log("Clipboard key event target: \(targetPID.map(String.init) ?? "global")")

        // Select all if no selection
        if !captured.hadSelection {
            simulateKeyCombo(key: 0x00, flags: .maskCommand, toPID: targetPID) // ⌘A
            usleep(50_000)
        }
        
        // Paste
        simulateKeyCombo(key: 0x09, flags: .maskCommand, toPID: targetPID) // ⌘V
        usleep(80_000)  // Wait for paste to complete

        // Arc/Chromium can occasionally ignore first paste after focus restoration.
        // Retry only for full-field replacements; with selection replacements this can duplicate output.
        if !captured.hadSelection,
           !verifyClipboardPasteApplied(captured: captured, expectedText: newText) {
            log("Clipboard paste verification failed on first attempt (full-field mode); retrying once")
            simulateKeyCombo(key: 0x09, flags: .maskCommand, toPID: targetPID)
            usleep(80_000)
        }
        
        previousSnapshot.restore(to: pasteboard)
        
        return ReplacementResult(success: true, strategy: .clipboardPaste, error: nil, verified: false)
    }
    
    // MARK: - Helpers

    private func isArcBrowser(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return app.bundleIdentifier == "company.thebrowser.Browser"
    }

    private func isFocusedElementStillCaptured(_ captured: CapturedText) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else {
            return false
        }
        return CFEqual(unsafeDowncast(focused, to: AXUIElement.self), captured.sourceElement)
    }

    private func verifyClipboardPasteApplied(captured: CapturedText, expectedText: String) -> Bool {
        let element = captured.sourceElement

        if captured.hadSelection {
            var selectedObj: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedObj) == .success,
               let selected = selectedObj as? String {
                return selected == expectedText
            }

            var valueObj: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
               let full = valueObj as? String {
                return full.contains(expectedText)
            }

            return true
        }

        var valueObj: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
           let full = valueObj as? String {
            return full == expectedText
        }

        return true
    }
    
    private func simulateKeyCombo(key: CGKeyCode, flags: CGEventFlags, toPID pid: pid_t? = nil) {
        let source = CGEventSource(stateID: .hidSystemState)

        func post(_ event: CGEvent) {
            if let pid {
                event.postToPid(pid)
            } else {
                event.post(tap: .cghidEventTap)
            }
        }

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
            keyDown.flags = flags
            post(keyDown)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
            keyUp.flags = flags
            post(keyUp)
        }
    }
    
    private func log(_ message: String) {
        if enableDebugLogging {
            print("[TextReplacementEngine] \(message)")
        }
    }
}

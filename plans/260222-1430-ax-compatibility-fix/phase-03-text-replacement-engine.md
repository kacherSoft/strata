# Phase 3: Text Replacement Engine

**Goal**: Replace text in target field using multi-strategy approach with verification.

**Time**: ~4 hours

---

## Overview

Replace `TextFocusManager.replaceText()` with a robust multi-strategy replacement system that works when AX attributes are read-only or unavailable.

## Replacement Strategies

```
Strategy 1: Direct Value Set
    ↓ (fails)
Strategy 2: Selection Replacement
    ↓ (fails)
Strategy 3: Range-Based Update
    ↓ (fails)
Strategy 4: Clipboard Paste (with verification)
    ↓
VERIFICATION: Re-read value to confirm success
```

> **Note:** Typing simulation removed per Oracle review - unreliable for unicode/emoji

## Data Structures

```swift
struct ReplacementResult {
    let success: Bool
    let strategy: ReplacementStrategy
    let error: String?
    let verified: Bool  // Oracle: confirm value matches expected
}

enum ReplacementStrategy: String {
    case directValueSet      // AXUIElementSetAttributeValue(kAXValueAttribute)
    case selectionReplace    // AXUIElementSetAttributeValue(kAXSelectedTextAttribute)
    case rangeBasedUpdate    // Get value, modify range, set value
    case clipboardPaste      // Save clipboard → Set new → ⌘A + ⌘V → Verify → Restore
}
```

## Implementation

### File: `TextReplacementEngine.swift`

```swift
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
        log("Starting replacement for category: \(captured.appCategory.rawValue)")
        
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
                // Oracle: Verify the replacement actually happened
                let verified = verifyReplacement(element: captured.sourceElement, expectedText: newText)
                if verified {
                    lastReplacementStrategy = strategy
                    log("Strategy \(strategy.rawValue) succeeded and verified")
                    return ReplacementResult(success: true, strategy: strategy, error: nil, verified: true)
                } else {
                    log("Strategy \(strategy.rawValue) reported success but verification failed")
                    continue  // Try next strategy
                }
            }
        }
        
        log("All strategies failed")
        return ReplacementResult(success: false, strategy: .clipboardPaste, error: "All replacement strategies failed", verified: false)
    }
    
    // MARK: - Verification (Oracle recommendation)
    
    private func verifyReplacement(element: AXUIElement, expectedText: String) -> Bool {
        // Small delay to let the app update
        usleep(50_000)
        
        var valueObj: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueObj) == .success,
              let currentValue = valueObj as? String else {
            // Can't verify, assume success
            return true
        }
        
        return currentValue == expectedText
    }
    
    // MARK: - Focus Validation
    
    private func validateFocus(_ captured: CapturedText) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var currentFocused: AnyObject?
        AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &currentFocused)
        
        if let current = currentFocused {
            var currentPID: pid_t = 0
            AXUIElementGetPid(unsafeBitCast(current, to: AXUIElement.self), &currentPID)
            return currentPID == captured.sourcePID
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
            return ReplacementResult(success: false, strategy: .directValueSet, error: "Not settable")
        }
        
        // Determine final text
        let finalText: String
        if captured.hadSelection, let range = captured.selectedRange {
            // Need to replace within full text
            var fullValue: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &fullValue)
            if let fullText = fullValue as? String {
                let nsString = fullText as NSString
                let nsRange = NSRange(location: range.location, length: range.length)
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
            let nsRange = NSRange(location: range.location, length: range.length)
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
```

## Acceptance Criteria

- [ ] Strategy 1 works for native apps with settable values
- [ ] Strategy 2 works when selection replacement is available
- [ ] Strategy 3 works for browsers (range + value manipulation)
- [ ] Strategy 4 works as reliable fallback for Electron
- [ ] Clipboard is restored synchronously (no race conditions)
- [ ] Focus validation prevents writing to wrong app
- [ ] Verification confirms replacement success

## Dependencies

- [Phase 2: Text Capture Engine](phase-02-text-capture-engine.md)

## Next Phase

[Phase 4: Electron Support](phase-04-electron-support.md)

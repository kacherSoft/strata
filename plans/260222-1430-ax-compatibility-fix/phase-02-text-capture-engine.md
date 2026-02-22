# Phase 2: Text Capture Engine

**Goal**: Extract text from focused field using layered detection strategy.

**Time**: ~2 hours

---

## Overview

Replace `TextFocusManager.captureText()` with a robust multi-layer capture system that works across all app categories.

## Layered Capture Strategy

```
Layer 1: Direct Detection
    ↓ (fails)
Layer 2: Parent Traversal
    ↓ (fails)
Layer 3: Child Descent
    ↓ (fails)
Layer 4: Web Content Extraction
    ↓ (fails)
Layer 5: Clipboard Fallback
```

## Data Structures

```swift
struct CapturedText {
    let content: String
    let sourceElement: AXUIElement
    let sourcePID: pid_t
    let hadSelection: Bool
    let selectedRange: CFRange?
    let captureMethod: CaptureMethod
    let appCategory: AppCategory
    let previousClipboard: String?  // Oracle: store for synchronous restoration
}

enum CaptureMethod: String {
    case directSelectedText    // Layer 1: Direct kAXSelectedTextAttribute
    case directValue           // Layer 1: Direct kAXValueAttribute
    case parentTraversal       // Layer 2: Found in parent
    case childDescent          // Layer 3: Found in child
    case webRangeExtraction    // Layer 4: Range + Value extraction
    case clipboardFallback     // Layer 5: ⌘C fallback
}
```

## Implementation

### File: `TextCaptureEngine.swift`

```swift
import AppKit

struct CapturedText {
    let content: String
    let sourceElement: AXUIElement
    let sourcePID: pid_t
    let hadSelection: Bool
    let selectedRange: CFRange?
    let captureMethod: CaptureMethod
    let appCategory: AppCategory
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
    
    // Debug logging
    var enableDebugLogging: Bool = false
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    func capture() -> CapturedText? {
        guard AccessibilityManager.shared.isAccessibilityEnabled else { return nil }
        
        let systemWide = AXUIElementCreateSystemWide()
        
        // Get focused element and PID
        guard let (initialElement, pid) = getFocusedElement(systemWide) else {
            log("No focused element found")
            return nil
        }
        
        // Detect app category
        let appCategory = AppCategoryDetector.shared.detect(pid: pid)
        let isWebview = AppCategoryDetector.shared.detectWebview(in: initialElement)
        let effectiveCategory = isWebview ? .webview : appCategory
        
        log("App category: \(effectiveCategory.rawValue), PID: \(pid)")
        
        // Handle Electron specially
        if effectiveCategory == .electron {
            ElectronSpecialist.shared.ensureAccessibility(for: pid)
        }
        
        // Refresh element after Electron accessibility setup
        let element: AXUIElement
        if effectiveCategory == .electron,
           let (refreshed, _) = getFocusedElement(systemWide) {
            element = refreshed
        } else {
            element = initialElement
        }
        
        // Try layered capture
        if let captured = tryLayeredCapture(element: element, pid: pid, category: effectiveCategory) {
            lastCaptureMethod = captured.captureMethod
            lastAppCategory = effectiveCategory
            return captured
        }
        
        // Final fallback: clipboard
        if let captured = captureViaClipboard(element: element, pid: pid, category: effectiveCategory) {
            lastCaptureMethod = captured.captureMethod
            lastAppCategory = effectiveCategory
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
                appCategory: category
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
                appCategory: category
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
                  let parent = parentValue else { break }
            
            let parentElement = unsafeBitCast(parent, to: AXUIElement.self)
            
            if let captured = tryDirectCapture(element: parentElement, pid: pid, category: category) {
                log("Layer 2: Found text at parent depth \(depth + 1)")
                return CapturedText(
                    content: captured.content,
                    sourceElement: parentElement,
                    sourcePID: pid,
                    hadSelection: captured.hadSelection,
                    selectedRange: captured.selectedRange,
                    captureMethod: .parentTraversal,
                    appCategory: category
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
        
        if let found = findTextElementInChildren(element, depth: 0) {
            log("Layer 3: Found text element in children")
            return tryDirectCapture(element: found, pid: pid, category: category)
                .map { captured in
                    CapturedText(
                        content: captured.content,
                        sourceElement: found,
                        sourcePID: pid,
                        hadSelection: captured.hadSelection,
                        selectedRange: captured.selectedRange,
                        captureMethod: .childDescent,
                        appCategory: category
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
    
    // MARK: - Layer 4: Web Extraction
    
    private func tryWebExtraction(element: AXUIElement, pid: pid_t, category: AppCategory) -> CapturedText? {
        log("Layer 4: Trying web extraction (range-based)")
        
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
            let selectedText = nsString.substring(with: NSRange(location: range.location, length: range.length))
            
            log("Layer 4: Extracted selection via range")
            return CapturedText(
                content: selectedText,
                sourceElement: textElement,
                sourcePID: pid,
                hadSelection: true,
                selectedRange: range,
                captureMethod: .webRangeExtraction,
                appCategory: category
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
            appCategory: category
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
            // Restore clipboard synchronously (Oracle recommendation)
            if let prev = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
            return nil
        }
        
        // Keep previous contents for later restoration (stored in captured text)
        // Will be restored after replacement verification
        
        log("Layer 5: Captured \(copiedText.count) chars via clipboard")
        return CapturedText(
            content: copiedText,
            sourceElement: element,
            sourcePID: pid,
            hadSelection: true, // Clipboard captures selection
            selectedRange: nil,
            captureMethod: .clipboardFallback,
            appCategory: category,
            previousClipboard: previousContents  // Store for later restoration
        )
    }
    
    // MARK: - Helpers
    
    private func getFocusedElement(_ systemWide: AXUIElement) -> (AXUIElement, pid_t)? {
        var focusedValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard result == .success, let focused = focusedValue else { return nil }
        
        let element = unsafeBitCast(focused, to: AXUIElement.self)
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
        ) == .success else { return nil }
        
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return nil }
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
```

## Acceptance Criteria

- [ ] Layer 1 works for native apps (Notes, Telegram)
- [ ] Layer 2 works for wrapped controls
- [ ] Layer 3 works for browsers (finds text field inside AXWebArea)
- [ ] Layer 4 extracts selection from browsers using range + value
- [ ] Layer 5 captures via clipboard as last resort
- [ ] Debug logging shows which layer succeeded
- [ ] No regression in apps that already worked

## Dependencies

- [Phase 1: App Category Detector](phase-01-app-detection.md)

## Next Phase

[Phase 3: Text Replacement Engine](phase-03-text-replacement-engine.md)

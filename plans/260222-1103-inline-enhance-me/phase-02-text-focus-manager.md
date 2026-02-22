# Phase 2: TextFocusManager (System-Wide via AXUIElement)

## Context Links
- Parent: [plan.md](plan.md)
- Depends on: [phase-01-accessibility-manager.md](phase-01-accessibility-manager.md)

## Overview
| Property | Value |
|----------|-------|
| Priority | P1 |
| Status | Pending |
| Effort | 2-3h |

Create a singleton manager that uses the macOS Accessibility API (`AXUIElement`) to detect focused text fields in **any application**, capture text (selected or full), and replace text inline.

## Requirements

### Functional
- Detect the system-wide focused UI element via `AXUIElementCreateSystemWide()`
- Verify the focused element is a text field (`kAXTextFieldRole` or `kAXTextAreaRole`)
- Capture selected text if selection exists (`kAXSelectedTextAttribute`)
- Capture full field content if no selection (`kAXValueAttribute`)
- Replace text inline after enhancement
- Provide source field position for HUD placement
- Return `nil` gracefully when no text field is focused or no permission

### Non-Functional
- Thread-safe for MainActor
- Fast detection (<50ms including AX round-trip)
- No memory leaks (AXUIElement is a CF type)

## Architecture

```
AXUIElementCreateSystemWide()
    ↓
kAXFocusedUIElementAttribute → AXUIElement (focused element in any app)
    ↓
kAXRoleAttribute → "AXTextField" or "AXTextArea"?
    ↓ NO → return nil
    ↓ YES
kAXSelectedTextAttribute → selected text
    ↓ empty?
kAXValueAttribute → full field value
    ↓
Store element reference + captured text
    ↓ (after enhancement)
Set kAXSelectedTextAttribute or kAXValueAttribute → replace inline
```

## Related Code Files

### Reference Files
- `TaskManager/Sources/TaskManager/AI/Services/AIService.swift` — singleton pattern, `@MainActor`
- `TaskManager/Sources/TaskManager/AI/Models/AIEnhancementResult.swift` — result type (`.enhancedText`)

### New File
- `TaskManager/Sources/TaskManager/Services/TextFocusManager.swift`

## Implementation Steps

### 1. Create TextFocusManager.swift

```swift
import AppKit

@MainActor
final class TextFocusManager: ObservableObject {
    static let shared = TextFocusManager()
    
    // Public state
    @Published var isEnhancing: Bool = false
    @Published var currentModeName: String = ""
    
    // Private capture state
    private var focusedElement: AXUIElement?
    private var focusedPID: pid_t = 0
    private var capturedText: String = ""
    private var hadSelection: Bool = false
    private var selectedRange: CFRange?
    
    private init() {}
}
```

### 2. Implement captureText()

```swift
func captureText() -> String? {
    guard AccessibilityManager.shared.isAccessibilityEnabled else { return nil }
    
    // 1. Get the system-wide focused element
    let systemWide = AXUIElementCreateSystemWide()
    var focusedValue: AnyObject?
    let focusResult = AXUIElementCopyAttributeValue(
        systemWide,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    )
    guard focusResult == .success, let focused = focusedValue else { return nil }
    
    let element = focused as! AXUIElement
    
    // 2. Verify it's a text input element
    guard isTextInputElement(element) else { return nil }
    
    self.focusedElement = element
        AXUIElementGetPid(element, &self.focusedPID)
    
    // 3. Try selected text first
    var selectedTextValue: AnyObject?
    AXUIElementCopyAttributeValue(
        element,
        kAXSelectedTextAttribute as CFString,
        &selectedTextValue
    )
    if let selectedText = selectedTextValue as? String, !selectedText.isEmpty {
        self.capturedText = selectedText
        self.hadSelection = true
        
        // Capture selected range for reliable replacement
        var rangeValue: AnyObject?
        AXUIElementCopyAttributeValue(
            element,
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
    
    // 4. Fall back to full value
    var fullValue: AnyObject?
    AXUIElementCopyAttributeValue(
        element,
        kAXValueAttribute as CFString,
        &fullValue
    )
    if let fullText = fullValue as? String, !fullText.isEmpty {
        self.capturedText = fullText
        self.hadSelection = false
        return fullText
    }
    
    return nil
}
```

### 3. Implement isTextInputElement()

```swift
private func isTextInputElement(_ element: AXUIElement) -> Bool {
    var roleValue: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
    guard let role = roleValue as? String else { return false }
    
    let textRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole,
        "AXComboBox",       // Combo box text fields
        "AXSearchField",    // Search fields
    ]
    
    if textRoles.contains(role) { return true }
    
    // Fallback: check if element has a settable String AXValue attribute
    var isSettable: DarwinBoolean = false
    AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable)
    guard isSettable.boolValue else { return false }
    
    // Verify the value is actually a String (excludes sliders, steppers, etc.)
    var valueCheck: AnyObject?
    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueCheck)
    return valueCheck is String
}
```

### 4. Implement replaceText()

```swift
func replaceText(_ newText: String) -> Bool {
    guard let element = focusedElement else { return false }
    
    // Validate focus hasn't changed (stale element protection)
    let systemWide = AXUIElementCreateSystemWide()
    var currentFocused: AnyObject?
    AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &currentFocused)
    if let current = currentFocused {
        var currentPID: pid_t = 0
        AXUIElementGetPid(current as! AXUIElement, &currentPID)
        guard currentPID == focusedPID else { return false }
    }
    
    var result: AXError
    
    if hadSelection, let range = selectedRange {
        // Replace selection via full value (kAXSelectedTextAttribute is often read-only)
        var fullValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &fullValue)
        if let fullText = fullValue as? String {
            let nsString = fullText as NSString
            let nsRange = NSRange(location: range.location, length: range.length)
            let replaced = nsString.replacingCharacters(in: nsRange, with: newText)
            result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, replaced as CFTypeRef)
        } else {
            result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newText as CFTypeRef)
        }
    } else {
        // Replace entire field content
        result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
    }
    
    return result == .success
}
```

### 5. Implement getSourceFieldRect()

```swift
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
    
    // AX coords: origin at top-left of primary screen
    // NSRect coords: origin at bottom-left
    // Use primary screen (index 0) — AX coordinates are relative to it
    let screenHeight = NSScreen.screens.first?.frame.height ?? 0
    let convertedRect = NSRect(
        x: position.x,
        y: screenHeight - position.y - size.height,
        width: size.width,
        height: size.height
    )
    
    // Validate rect is on a visible screen; fallback to mouse location screen
    let isOnScreen = NSScreen.screens.contains { $0.frame.intersects(convertedRect) }
    guard isOnScreen else { return nil }
    
    return convertedRect
}
```

### 6. Implement reset()

```swift
func reset() {
    focusedElement = nil
    focusedPID = 0
    capturedText = ""
    hadSelection = false
    selectedRange = nil
    isEnhancing = false
    currentModeName = ""
}
```

## Todo List

- [ ] Create TextFocusManager.swift
- [ ] Implement captureText() with AXUIElement
- [ ] Implement isTextInputElement() role checking
- [ ] Implement replaceText() with selection-aware replacement
- [ ] Implement getSourceFieldRect() with coordinate conversion
- [ ] Implement reset()
- [ ] Test in TextEdit (native Cocoa app)
- [ ] Test in Safari (web form field)
- [ ] Test in Notes.app
- [ ] Implement PID validation in replaceText()
- [ ] Implement range-based selection replacement
- [ ] Add AX error return value checking

## Success Criteria

- [ ] Detects focused text field in other apps via AXUIElement
- [ ] Captures selected text when selection exists
- [ ] Captures full text when no selection
- [ ] Replaces text correctly in the source app
- [ ] Returns position rect for HUD placement
- [ ] Returns `nil` gracefully when no text field focused
- [ ] Returns `nil` gracefully when no Accessibility permission
- [ ] Works with native macOS apps (TextEdit, Notes, Safari)
- [ ] Validates focus PID before replacing text (stale element protection)
- [ ] Selection replacement works via range-based strategy

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Electron apps don't expose AX text attributes | Medium | Medium | Document as known limitation |
| `AXUIElementSetAttributeValue` fails silently | Medium | High | Check `isSettable` before writing; log failures |
| AX coordinate space differs on multi-monitor | Low | Medium | Use screen of focused element, not primary |
| Rich text lost on replacement | Medium | Low | Document plaintext-only enhancement |
| CF memory management issues | Low | Medium | AXUIElement is CF-bridged, ARC handles it |
| User switches focus during AI processing | Medium | High | PID validation before replaceText(); abort if focus changed |
| kAXSelectedTextAttribute is read-only in some apps | Medium | High | Use range-based replacement via kAXValueAttribute instead |

## Next Steps

After completion, proceed to [Phase 3: InlineEnhanceHUD](phase-03-inline-enhance-hud.md)

# Phase 4: Electron Support

**Goal**: Handle Electron apps specifically with proper AX tree initialization and timing.

**Time**: ~1 hour

---

## Overview

Electron apps have special accessibility requirements:
1. Need `AXManualAccessibility` flag set before AX tree is built
2. May need longer delays for tree rebuild
3. Some use Chromium's custom accessibility implementation

## Known Electron Apps

| App | Bundle ID | Notes |
|-----|-----------|-------|
| Slack | `com.tinyspeck.slackmacgap` | Most common, good AX support |
| VS Code | `com.microsoft.VSCode` | Custom editor, limited AX |
| Discord | `com.hnc.Discord` | Good AX after flag set |
| Spotify | `com.spotify.client` | Mixed AX support |
| Postman | `com.postmanlabs.mac` | Good AX support |
| Notion | `notion.id` | Webview-based, good AX |
| Figma | `com.figma.Desktop` | Canvas-based, limited AX |

## Implementation

### File: `ElectronSpecialist.swift`

```swift
import AppKit

@MainActor
final class ElectronSpecialist: ObservableObject {
    static let shared = ElectronSpecialist()
    
    // Apps known to need AXManualAccessibility
    private var enabledPIDs: Set<pid_t> = []
    
    // Apps that need extended timing
    private let slowApps: Set<String> = [
        "com.microsoft.VSCode",
        "com.figma.Desktop",
    ]
    
    var enableDebugLogging: Bool = false
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    func ensureAccessibility(for pid: pid_t) {
        guard !enabledPIDs.contains(pid) else {
            log("Already enabled for PID \(pid)")
            return
        }
        
        log("Setting up Electron accessibility for PID \(pid)")
        
        let appElement = AXUIElementCreateApplication(pid)
        
        // Strategy 1: Standard AXManualAccessibility flag
        let result1 = AXUIElementSetAttributeValue(
            appElement,
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )
        log("AXManualAccessibility result: \(result1.rawValue)")
        
        // Strategy 2: Enhanced UI flag (some Chromium versions)
        let result2 = AXUIElementSetAttributeValue(
            appElement,
            "AXEnhancedUserInterface" as CFString,
            kCFBooleanTrue
        )
        log("AXEnhancedUserInterface result: \(result2.rawValue)")
        
        // Strategy 3: Try accessibility enabled flag
        let result3 = AXUIElementSetAttributeValue(
            appElement,
            "AXAccessibilityEnabled" as CFString,
            kCFBooleanTrue
        )
        log("AXAccessibilityEnabled result: \(result3.rawValue)")
        
        // Mark as enabled
        enabledPIDs.insert(pid)
        
        // Wait for AX tree to rebuild
        let delay = getDelay(for: pid)
        log("Waiting \(delay)ms for AX tree rebuild")
        usleep(UInt32(delay * 1000))
    }
    
    // MARK: - Delay Calculation
    
    private func getDelay(for pid: pid_t) -> Int {
        guard let app = NSRunningApplication(processIdentifier: pid),
              let bundleID = app.bundleIdentifier else {
            return 100 // Default 100ms
        }
        
        // Known slow apps need more time
        if slowApps.contains(bundleID) {
            return 200
        }
        
        return 100
    }
    
    // MARK: - Validation
    
    func validateAccessibility(for pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        
        // Try to get the focused element
        var focused: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        
        if result == .success {
            log("Electron accessibility validated for PID \(pid)")
            return true
        }
        
        log("Electron accessibility validation failed: \(result.rawValue)")
        return false
    }
    
    // MARK: - Retry Logic
    
    func withRetry<T>(pid: pid_t, maxAttempts: Int = 3, operation: () -> T?) -> T? {
        for attempt in 1...maxAttempts {
            log("Attempt \(attempt)/\(maxAttempts)")
            
            ensureAccessibility(for: pid)
            
            if let result = operation() {
                return result
            }
            
            // Wait before retry
            if attempt < maxAttempts {
                usleep(100_000)
            }
        }
        
        return nil
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        enabledPIDs.removeAll()
    }
    
    func removeFromCache(pid: pid_t) {
        enabledPIDs.remove(pid)
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if enableDebugLogging {
            print("[ElectronSpecialist] \(message)")
        }
    }
}
```

## Integration Points

### In TextCaptureEngine

```swift
// In capture() method, after detecting app category:
if effectiveCategory == .electron {
    ElectronSpecialist.shared.ensureAccessibility(for: pid)
    
    // Refresh element after setup
    if let (refreshed, _) = getFocusedElement(systemWide) {
        element = refreshed
    }
}
```

### In TextReplacementEngine

```swift
// For Electron apps, prefer clipboard strategy
if captured.appCategory == .electron {
    // Skip direct strategies, go straight to clipboard
    return tryClipboardPaste(captured, newText)
}
```

## Acceptance Criteria

- [ ] Slack text capture and replacement works
- [ ] VS Code text capture works (replacement may be limited)
- [ ] Discord text capture and replacement works
- [ ] Proper timing delays based on app
- [ ] Retry logic handles intermittent failures
- [ ] Cache prevents repeated AX flag setting

## Dependencies

- [Phase 1: App Category Detector](phase-01-app-detection.md)

## Next Phase

[Phase 5: Integration](phase-05-integration.md)

# Phase 1: App Category Detector

**Goal**: Classify the target app to optimize capture/replace strategy selection.

**Time**: ~1 hour

---

## Overview

Different app categories require different accessibility approaches. This detector identifies the category so subsequent engines can use optimal strategies.

## Categories

```swift
enum AppCategory {
    case native       // Cocoa apps (Notes, Telegram, Finder)
    case browser      // Web browsers (Safari, Chrome, Firefox, Edge)
    case electron     // Electron apps (Slack, VS Code, Discord)
    case webview      // Embedded web content (Notion, Figma)
    case java         // Java/Swing apps (IntelliJ IDEA)
    case qt           // Qt-based apps (VLC, some Linux ports)
    case unknown      // Fallback for unrecognized apps
}
```

## Detection Heuristics

| Category | Detection Method |
|----------|-----------------|
| **Native** | Bundle contains AppKit, standard AX roles |
| **Browser** | Bundle ID matches known browser list, or contains WebKit/Chromium |
| **Electron** | Bundle contains Electron.framework, or "Electron" in info |
| **Webview** | Contains `AXWebArea` in focused element hierarchy |
| **Java** | Bundle contains Java runtime, or `java` in process args |
| **Qt** | Bundle contains Qt frameworks |

## Implementation

### File: `AppCategoryDetector.swift`

```swift
import AppKit

enum AppCategory: String, CaseIterable {
    case native
    case browser
    case electron
    case webview
    case java
    case qt
    case unknown
}

@MainActor
final class AppCategoryDetector {
    static let shared = AppCategoryDetector()
    
    private var cache: [pid_t: AppCategory] = [:]
    
    // Known browser bundle prefixes
    private let browserBundles: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
    ]
    
    // Known Electron apps
    private let electronBundles: Set<String> = [
        "com.tinyspeck.slackmacgap",
        "com.microsoft.VSCode",
        "com.hnc.Discord",
        "com.spotify.client",
        "com.postmanlabs.mac",
    ]
    
    private init() {}
    
    // MARK: - Main Detection
    
    func detect(pid: pid_t) -> AppCategory {
        // Check cache first
        if let cached = cache[pid] { return cached }
        
        let category = performDetection(pid: pid)
        cache[pid] = category
        return category
    }
    
    private func performDetection(pid: pid_t) -> AppCategory {
        guard let app = NSRunningApplication(processIdentifier: pid),
              let bundleURL = app.bundleURL else {
            return .unknown
        }
        
        let bundleID = app.bundleIdentifier ?? ""
        
        // 1. Check known browsers
        if browserBundles.contains(bundleID) || 
           browserBundles.contains(where: { bundleID.hasPrefix($0) }) {
            return .browser
        }
        
        // 2. Check known Electron apps
        if electronBundles.contains(bundleID) ||
           electronBundles.contains(where: { bundleID.hasPrefix($0) }) {
            return .electron
        }
        
        // 3. Check for Electron framework
        if hasElectronFramework(in: bundleURL) {
            return .electron
        }
        
        // 4. Check for Java
        if isJavaApp(app: app) {
            return .java
        }
        
        // 5. Check for Qt
        if hasQtFramework(in: bundleURL) {
            return .qt
        }
        
        // 6. Default to native for Cocoa apps
        if bundleURL.pathExtension == "app" {
            return .native
        }
        
        return .unknown
    }
    
    // MARK: - Webview Detection (requires AX element)
    
    func detectWebview(in element: AXUIElement) -> Bool {
        // Check if element or any parent is AXWebArea
        var current: AXUIElement = element
        for _ in 0..<10 {
            if let role = getStringAttribute(current, kAXRoleAttribute as String),
               role == "AXWebArea" {
                return true
            }
            
            var parent: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parentElement = parent else { break }
            current = unsafeBitCast(parentElement, to: AXUIElement.self)
        }
        return false
    }
    
    // MARK: - Helpers
    
    private func hasElectronFramework(in bundleURL: URL) -> Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Contents/Frameworks")
        guard let enumerator = FileManager.default.enumerator(at: frameworksURL, includingPropertiesForKeys: nil) else {
            return false
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent.contains("Electron") ||
               fileURL.lastPathComponent.contains("electron") {
                return true
            }
        }
        return false
    }
    
    private func hasQtFramework(in bundleURL: URL) -> Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Contents/Frameworks")
        guard let enumerator = FileManager.default.enumerator(at: frameworksURL, includingPropertiesForKeys: nil) else {
            return false
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent.contains("Qt") {
                return true
            }
        }
        return false
    }
    
    private func isJavaApp(app: NSRunningApplication) -> Bool {
        // Check process arguments for java
        let pid = app.processIdentifier
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS, pid]
        var argmax: Int = 0
        var size = MemoryLayout<Int>.stride
        
        sysctl(&mib, 3, &argmax, &size, nil, 0)
        
        // Simple check: look for java in executable path
        if let execURL = app.executableURL,
           execURL.path.contains("java") {
            return true
        }
        
        return false
    }
    
    private func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cache.removeAll()
    }
}
```

## Acceptance Criteria

- [ ] Correctly identifies Safari, Chrome, Firefox as `.browser`
- [ ] Correctly identifies Slack, VS Code as `.electron`
- [ ] Correctly identifies Notes, Telegram as `.native`
- [ ] Detects `AXWebArea` presence for webview detection
- [ ] Caches results to avoid repeated filesystem checks
- [ ] Falls back to `.unknown` gracefully

## Dependencies

None — this is the foundation phase.

## Next Phase

[Phase 2: Text Capture Engine](phase-02-text-capture-engine.md)

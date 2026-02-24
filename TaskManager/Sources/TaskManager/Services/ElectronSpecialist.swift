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
        log("Cache cleared")
    }
    
    func removeFromCache(pid: pid_t) {
        enabledPIDs.remove(pid)
        log("Removed PID \(pid) from cache")
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if enableDebugLogging {
            print("[ElectronSpecialist] \(message)")
        }
    }
}

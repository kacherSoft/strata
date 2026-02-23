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
    
    // Known browser bundle IDs
    private let browserBundles: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome.canary",
        "org.mozilla.firefoxdeveloperedition",
        "company.thebrowser.Browser",
    ]
    
    // Known Electron app bundle IDs
    private let electronBundles: Set<String> = [
        "com.tinyspeck.slackmacgap",
        "com.microsoft.VSCode",
        "com.hnc.Discord",
        "com.spotify.client",
        "com.postmanlabs.mac",
        "com notion",
        "com.figma.Desktop",
        "com.github Electron",
        "com whatsapp",
    ]
    
    var enableDebugLogging: Bool = false
    
    private init() {}
    
    // MARK: - Main Detection
    
    func detect(pid: pid_t) -> AppCategory {
        // Check cache first
        if let cached = cache[pid] {
            log("Cache hit for PID \(pid): \(cached.rawValue)")
            return cached
        }
        
        let category = performDetection(pid: pid)
        cache[pid] = category
        log("Detected PID \(pid) as \(category.rawValue)")
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
           electronBundles.contains(where: { bundleID.lowercased().contains($0.lowercased()) }) {
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
                log("Detected AXWebArea in hierarchy")
                return true
            }
            
            var parent: AnyObject?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parent else { break }
            current = unsafeDowncast(parent, to: AXUIElement.self)
        }
        return false
    }
    
    // MARK: - Helpers
    
    private func hasElectronFramework(in bundleURL: URL) -> Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Contents/Frameworks")
        guard let enumerator = FileManager.default.enumerator(
            at: frameworksURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent.lowercased()
            if name.contains("electron") || name.contains("chromium") {
                log("Found Electron framework: \(fileURL.lastPathComponent)")
                return true
            }
        }
        return false
    }
    
    private func hasQtFramework(in bundleURL: URL) -> Bool {
        let frameworksURL = bundleURL.appendingPathComponent("Contents/Frameworks")
        guard let enumerator = FileManager.default.enumerator(
            at: frameworksURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent.hasPrefix("Qt") {
                log("Found Qt framework: \(fileURL.lastPathComponent)")
                return true
            }
        }
        return false
    }
    
    private func isJavaApp(app: NSRunningApplication) -> Bool {
        // Check executable path for java
        if let execURL = app.executableURL,
           execURL.path.lowercased().contains("java") {
            return true
        }
        
        // Check bundle for Java indicators
        if let bundle = app.bundleIdentifier?.lowercased(),
           bundle.contains("java") || bundle.contains("jetbrains") {
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
        log("Cache cleared")
    }
    
    func removeFromCache(pid: pid_t) {
        cache.removeValue(forKey: pid)
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if enableDebugLogging {
            print("[AppCategoryDetector] \(message)")
        }
    }
}

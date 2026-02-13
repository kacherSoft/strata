import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Global shortcuts (work system-wide)
    static let quickEntry = Self("quickEntry")
    static let enhanceMe = Self("enhanceMe")
    
    // Local shortcuts (work only when app is focused, stored for customization)
    static let mainWindow = Self("mainWindow")
    static let settings = Self("settings")
}

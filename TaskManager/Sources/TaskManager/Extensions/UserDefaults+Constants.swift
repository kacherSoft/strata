import Foundation

extension UserDefaults {
    // MARK: - User Preference Keys
    
    /// Keys for storing user preferences and app state
    enum Keys {
        /// Whether user has completed the onboarding flow
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        
        /// Current appearance mode: "system", "light", or "dark"
        static let appearanceMode = "appearanceMode"
        
        #if DEBUG
        /// Debug-only: Grants VIP access without purchase (DO NOT ship to production)
        static let debugVIPGranted = "debug_vip_granted"
        #endif
    }
    
    // MARK: - Convenience Properties
    
    /// Whether user has completed the onboarding flow
    var hasCompletedOnboarding: Bool {
        get { bool(forKey: Keys.hasCompletedOnboarding) }
        set { set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    /// Current appearance mode
    var appearanceMode: String {
        get { string(forKey: Keys.appearanceMode) ?? "system" }
        set { set(newValue, forKey: Keys.appearanceMode) }
    }
    
    #if DEBUG
    /// Debug-only VIP grant toggle
    var debugVIPGranted: Bool {
        get { bool(forKey: Keys.debugVIPGranted) }
        set { set(newValue, forKey: Keys.debugVIPGranted) }
    }
    #endif
}

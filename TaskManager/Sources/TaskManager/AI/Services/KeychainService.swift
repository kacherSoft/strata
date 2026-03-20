import Foundation
import Security

final class KeychainService: Sendable {
    static let shared = KeychainService()
    private let service = "com.kachersoft.strata"
    
    enum Key: String, Sendable {
        case geminiAPIKey = "gemini-api-key"
        case zaiAPIKey = "zai-api-key"
        case openaiAPIKey = "openai-api-key"
        
        // DodoPayments entitlement keys
        case licenseKey = "strata.licenseKey"
        case licenseInstanceId = "strata.licenseInstanceId"
        case customerEmail = "strata.customerEmail"

        // Backend-signed token keys (Phase 1+)
        case entitlementToken = "strata.entitlementToken"
        case clockCheckpoint = "strata.clockCheckpoint"
        case installId = "strata.installId"
        case installRegistrationPubkeyHash = "strata.installRegistrationPubkeyHash"
        case entitlementLastValidatedAt = "strata.entitlementLastValidatedAt"
        case licenseOfflineGraceUntil = "strata.licenseOfflineGraceUntil"

        // Account auth/session keys (OTP flow)
        case accountSessionToken = "strata.accountSessionToken"
        case accountSessionExpiresAt = "strata.accountSessionExpiresAt"
        case accountUserId = "strata.accountUserId"
        case accountEmail = "strata.accountEmail"
        case accountSessionEnvironment = "strata.accountSessionEnvironment"
    }
    
    private init() {}
    
    func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    func hasKey(_ key: Key) -> Bool {
        get(key) != nil
    }

    // MARK: - Dynamic key support (for AIProviderModel.apiKeyRef)

    func saveValue(_ value: String, forRef ref: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func getValue(forRef ref: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteValue(forRef ref: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasValue(forRef ref: String) -> Bool {
        getValue(forRef: ref) != nil
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status): return "Failed to save to keychain (status: \(status))"
        case .encodingFailed: return "Failed to encode value"
        }
    }
}

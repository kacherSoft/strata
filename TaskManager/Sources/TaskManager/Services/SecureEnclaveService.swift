import Foundation
import Security
import CryptoKit

// ---------------------------------------------------------------------------
// SecureEnclaveService — install-bound keypair + nonce signing
// ---------------------------------------------------------------------------

final class SecureEnclaveService: Sendable {
    static let shared = SecureEnclaveService()

    private let keyTag = "com.kachersoft.strata.install-signing-key"

    private init() {}

    func publicKeyBase64() throws -> String {
        let key = try ensurePrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(key),
              let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw SecureEnclaveError.publicKeyExportFailed
        }
        return data.base64EncodedString()
    }

    func publicKeyHashBase64URL() throws -> String {
        let key = try ensurePrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(key),
              let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            throw SecureEnclaveError.publicKeyExportFailed
        }
        let digest = SHA256.hash(data: data)
        return Self.base64URLEncode(Data(digest))
    }

    func signNonce(_ nonce: String) throws -> String {
        let key = try ensurePrivateKey()
        let nonceData = Data(nonce.utf8)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .ecdsaSignatureMessageX962SHA256,
            nonceData as CFData,
            &error
        ) as Data? else {
            throw SecureEnclaveError.signingFailed(error?.takeRetainedValue())
        }
        return signature.base64EncodedString()
    }

    private func ensurePrivateKey() throws -> SecKey {
        if let existing = try loadPrivateKey() {
            return existing
        }
        return try createPrivateKey()
    }

    private func loadPrivateKey() throws -> SecKey? {
        let tagData = Data(keyTag.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let item else {
            throw SecureEnclaveError.keyLookupFailed(status)
        }
        return (item as! SecKey)
    }

    private func createPrivateKey() throws -> SecKey {
        let tagData = Data(keyTag.utf8)
        var error: Unmanaged<CFError>?

        // Prefer Secure Enclave-backed key when available.
        if let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            [.privateKeyUsage],
            nil
        ) {
            let secureEnclaveAttributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tagData,
                    kSecAttrAccessControl as String: access
                ]
            ]

            if let key = SecKeyCreateRandomKey(secureEnclaveAttributes as CFDictionary, &error) {
                return key
            }
        }

        // Fallback for environments where Secure Enclave is unavailable.
        error = nil
        let softwareKeyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tagData,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
        ]

        guard let key = SecKeyCreateRandomKey(softwareKeyAttributes as CFDictionary, &error) else {
            throw SecureEnclaveError.keyCreationFailed(error?.takeRetainedValue())
        }
        return key
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum SecureEnclaveError: LocalizedError {
    case keyLookupFailed(OSStatus)
    case keyCreationFailed(CFError?)
    case publicKeyExportFailed
    case signingFailed(CFError?)

    var errorDescription: String? {
        switch self {
        case .keyLookupFailed(let status):
            return "Failed to lookup install signing key (status: \(status))"
        case .keyCreationFailed(let error):
            return "Failed to create install signing key: \(error?.localizedDescription ?? "unknown error")"
        case .publicKeyExportFailed:
            return "Failed to export install public key"
        case .signingFailed(let error):
            return "Failed to sign challenge nonce: \(error?.localizedDescription ?? "unknown error")"
        }
    }
}

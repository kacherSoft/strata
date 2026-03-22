import Foundation
import Observation
import CryptoKit

enum PremiumFeature: String, CaseIterable {
    case kanban
    case recurringTasks
    case customFields
    case aiAttachments
    case inlineEnhance
}

@MainActor
@Observable
final class EntitlementService {
    private static let licenseOfflineGraceInterval: TimeInterval = 72 * 60 * 60

    // MARK: - Public State

    private(set) var isLicenseValid = false
    private(set) var isSubscriptionActive = false
    private(set) var subscriptionCustomerId: String?
    private(set) var subscriptionProductId: String?
    private(set) var subscriptionRenewalDateISO8601: String?
    private(set) var accountEmail: String?
    private(set) var accountUserId: String?
    private(set) var accountSessionExpiresAt: Date?

    var hasFullAccess: Bool {
        guard !isIntegrityCompromised else { return false }
        return isLicenseValid || isSubscriptionActive || isVIPAdminGranted
    }

    var isPremium: Bool { hasFullAccess }
    var isVIPPurchased: Bool { isLicenseValid }
    var isVIPActive: Bool {
        guard !isIntegrityCompromised else { return false }
        if isLicenseValid { return true }
        return isSubscriptionActive && resolvedTier == "vip"
    }
    var isProActive: Bool {
        guard !isIntegrityCompromised else { return false }
        return isSubscriptionActive && resolvedTier == "pro"
    }
    var isCheckoutActivationInProgress: Bool {
        validationState == .validating
    }
    /// Stored property so SwiftUI @Observable can track changes (computed keychain reads are not observable)
    private(set) var isAccountSignedIn = false

    /// Recalculate sign-in state from keychain + session expiry
    private func refreshSignedInState() {
        guard let token = keychain.get(.accountSessionToken)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            isAccountSignedIn = false
            return
        }
        if let expiry = accountSessionExpiresAt {
            isAccountSignedIn = Date() < expiry
        } else {
            isAccountSignedIn = true
        }
    }

    func canUse(_ feature: PremiumFeature) -> Bool { hasFullAccess }

    var accessLabel: String {
        if isIntegrityCompromised { return "Free" }
        if isLicenseValid { return "VIP (Lifetime)" }
        if isSubscriptionActive {
            if resolvedTier == "vip" { return "VIP (Lifetime)" }
            if subscriptionProductId == DodoPaymentsClient.proYearlyProductId { return "Pro Yearly" }
            if subscriptionProductId == DodoPaymentsClient.proMonthlyProductId { return "Pro Monthly" }
            return "Pro (Subscription)"
        }
        #if DEBUG
        if isVIPAdminGranted { return "VIP (Admin Grant)" }
        #endif
        return "Free"
    }

    // MARK: - Validation State

    enum ValidationState: Sendable {
        case idle, validating, valid, invalid, offline
    }

    enum RestoreOutcome: String, Sendable {
        case subscription
        case lifetime
        case none
    }

    struct EmailAuthChallenge: Sendable {
        let email: String
        let challengeId: String
        let expiresAt: Date
        let delivery: String
    }

    private(set) var validationState: ValidationState = .idle

    // MARK: - Singleton

    static let shared = EntitlementService()

    // MARK: - Dependencies

    private let client: DodoPaymentsClient
    private let backendClient: EntitlementBackendClient
    private let keychain: KeychainService
    private let secureEnclave: SecureEnclaveService

    // MARK: - Integrity (C4)

    private(set) var isIntegrityCompromised = false

    // MARK: - Install identity

    private(set) var installId: String = ""
    private var isInstallRegistered = false
    private var resolvedTier: String = "free"

    // MARK: - Init

    init(
        client: DodoPaymentsClient = .shared,
        backendClient: EntitlementBackendClient = .shared,
        keychain: KeychainService = .shared,
        secureEnclave: SecureEnclaveService = .shared
    ) {
        self.client = client
        self.backendClient = backendClient
        self.keychain = keychain
        self.secureEnclave = secureEnclave

        bootstrapInstallId()
        loadAccountSession()
        loadCachedEntitlement()

        Task {
            do {
                try await ensureInstallIdentityRegistered()
            } catch {
                print("[Entitlement] Install registration bootstrap failed: \(error.localizedDescription)")
            }
            await revalidate()
        }
    }

    // MARK: - Public API

    func loadAndValidate() async {
        loadCachedEntitlement()
        await revalidate()
    }

    func startEmailAuth(email: String) async throws -> EmailAuthChallenge {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            throw EntitlementError.accountEmailMissing
        }

        let response = try await backendClient.startEmailAuth(email: normalizedEmail)
        let expiresAt = Date(timeIntervalSince1970: TimeInterval(response.expires_at))
        return EmailAuthChallenge(
            email: normalizedEmail,
            challengeId: response.challenge_id,
            expiresAt: expiresAt,
            delivery: response.delivery
        )
    }

    func verifyEmailAuth(email: String, challengeId: String, code: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            throw EntitlementError.accountEmailMissing
        }

        let response = try await backendClient.verifyEmailAuth(
            email: normalizedEmail,
            challengeId: challengeId,
            code: code
        )
        saveAccountSession(
            token: response.session_token,
            userId: response.user_id,
            email: response.email,
            expiresAtUnix: response.session_expires_at
        )

        await revalidate()
    }

    func signOutAccount() async {
        try? await backendClient.revokeAccountSession()
        clearAccountSession()
        clearLinkedSubscriptionState(deleteEmail: true)
        await revalidate()
    }

    func listAccountDevices() async throws -> [DeviceInfo] {
        guard isAccountSignedIn else {
            throw EntitlementError.accountSignInRequired
        }
        let response = try await backendClient.listDevices()
        return response.devices
    }

    func revokeAccountDevice(installId: String) async throws {
        guard isAccountSignedIn else {
            throw EntitlementError.accountSignInRequired
        }
        try await backendClient.revokeDevice(installId: installId)
        if installId == self.installId {
            // Full entitlement clear — user drops to Free plan
            clearLinkedSubscriptionState(deleteEmail: false)
            isLicenseValid = false
            keychain.delete(.licenseKey)
            keychain.delete(.licenseInstanceId)
        }
        await revalidate()
    }

    func revalidate() async {
        loadAccountSession()
        validationState = .validating
        var usedOfflineCache = false

        // C4: Code-signature integrity check in release builds.
        let integrity = CodeIntegrityService.validateAtLaunch()
        switch integrity {
        case .invalid(let reason):
            isIntegrityCompromised = true
            isLicenseValid = false
            clearLinkedSubscriptionState(deleteEmail: false)
            validationState = .invalid
            print("[Entitlement] Code integrity check failed: \(reason)")
            return
        case .valid:
            isIntegrityCompromised = false
        case .skipped:
            isIntegrityCompromised = false
        }

        await revalidateLicensePath(&usedOfflineCache)
        await revalidateSubscriptionPath(&usedOfflineCache)

        if usedOfflineCache {
            validationState = .offline
            return
        }

        saveValidationTimestamp()
        validationState = hasFullAccess ? .valid : .invalid
    }

    func activateLicense(key: String) async throws {
        let deviceName = Host.current().localizedName ?? "Mac"
        let response = try await client.activateLicense(key: key, deviceName: deviceName)

        try keychain.save(key, for: .licenseKey)
        try keychain.save(response.license_key_instance_id, for: .licenseInstanceId)
        saveLicenseOfflineGraceWindow()
        saveClockCheckpoint()

        isLicenseValid = true
        saveValidationTimestamp()
        validationState = .valid
    }

    func deactivateLicense() async throws {
        guard let key = keychain.get(.licenseKey),
              let instanceId = keychain.get(.licenseInstanceId) else {
            return
        }

        var remoteError: Error?
        do {
            _ = try await client.deactivateLicense(key: key, instanceId: instanceId)
        } catch {
            remoteError = error
        }

        keychain.delete(.licenseKey)
        keychain.delete(.licenseInstanceId)
        keychain.delete(.licenseOfflineGraceUntil)

        isLicenseValid = false
        validationState = hasFullAccess ? .valid : .invalid

        if let remoteError {
            throw remoteError
        }
    }

    func beginCheckout(productId: String) async throws -> URL {
        guard isAccountSignedIn else {
            throw EntitlementError.accountSignInRequired
        }
        try await ensureInstallIdentityRegistered()

        let response = try await backendClient.createCheckoutSession(
            productId: productId,
            installId: installId,
            email: nil,
            returnURL: "strata://checkout-complete"
        )

        guard let url = URL(string: response.checkout_url),
              url.scheme?.lowercased() == "https" else {
            throw BackendError.invalidPortalURL
        }
        return url
    }

    func restorePurchases(licenseKey: String?) async throws -> RestoreOutcome {
        guard isAccountSignedIn else {
            throw EntitlementError.accountSignInRequired
        }

        return try await performRestorePurchases(
            email: accountEmail,
            licenseKey: licenseKey
        )
    }

    private func performRestorePurchases(
        email: String?,
        licenseKey: String?
    ) async throws -> RestoreOutcome {
        let proof = try await createInstallProof()
        let response = try await backendClient.restore(
            email: email,
            installId: installId,
            challengeId: proof.challengeId,
            nonceSignature: proof.signature,
            licenseKey: licenseKey
        )

        let claims = try verifyEntitlementToken(
            response.token,
            expectedInstallPubkeyHash: proof.installPubkeyHash
        )

        let resolvedEmail = response.resolved_email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let persistedEmail = resolvedEmail?.isEmpty == false ? resolvedEmail : email

        if claims.tier == "pro" || claims.tier == "vip" {
            guard let persistedEmail, !persistedEmail.isEmpty else {
                throw EntitlementError.subscriptionEmailMissing
            }
            try keychain.save(persistedEmail, for: .customerEmail)
            try keychain.save(response.token, for: .entitlementToken)
            isSubscriptionActive = true
            resolvedTier = claims.tier
            saveClockCheckpoint()
            saveValidationTimestamp()
            validationState = .valid
        } else {
            clearLinkedSubscriptionState(deleteEmail: false)
            validationState = hasFullAccess ? .valid : .invalid
        }

        switch response.restore_type?.lowercased() {
        case "subscription": return .subscription
        case "lifetime": return .lifetime
        default: return .none
        }
    }

    func subscriptionManagementURL() async throws -> URL {
        guard isAccountSignedIn else {
            throw EntitlementError.accountSignInRequired
        }

        let proof = try await createInstallProof()
        return try await backendClient.customerPortalURL(
            email: accountEmail,
            installId: installId,
            challengeId: proof.challengeId,
            nonceSignature: proof.signature
        )
    }

    func handleOpenURL(_ url: URL) async {
        guard url.scheme?.lowercased() == "strata" else { return }
        let matchesCheckoutComplete =
            url.host?.lowercased() == "checkout-complete" ||
            url.path.lowercased() == "/checkout-complete"
        guard matchesCheckoutComplete else { return }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            await revalidate()
            return
        }

        if let installIDParam = normalizedQueryValue(named: "install_id", in: components, lowercased: true),
           !installIDParam.isEmpty,
           installIDParam != installId {
            return
        }

        let status = normalizedQueryValue(named: "status", in: components, lowercased: true)
        let checkoutEmail =
            normalizedQueryValue(named: "customer_email", in: components, lowercased: true) ??
            normalizedQueryValue(named: "email", in: components, lowercased: true)
        let licenseKey = normalizedQueryValue(named: "license_key", in: components)
        let shouldAttemptImmediateRestore: Bool = {
            guard let status else { return true }
            return ["succeeded", "success", "completed", "paid", "active"].contains(status)
        }()

        if shouldAttemptImmediateRestore {
            validationState = .validating
            let didRestore = await attemptCheckoutRestore(
                emailHint: checkoutEmail,
                licenseKey: licenseKey
            )
            if didRestore {
                if let licenseKey, !licenseKey.isEmpty {
                    try? await activateLicense(key: licenseKey)
                }
                return
            }
        }

        await revalidate()
    }

    // MARK: - Debug

    #if DEBUG
    func toggleVIPAdminGrant() {
        UserDefaults.standard.debugVIPGranted.toggle()
    }

    var isVIPAdminGrantActive: Bool {
        UserDefaults.standard.debugVIPGranted
    }
    #endif

    // MARK: - Private

    private var isVIPAdminGranted: Bool {
        #if DEBUG
        UserDefaults.standard.debugVIPGranted
        #else
        false
        #endif
    }

    private struct InstallProof {
        let challengeId: String
        let signature: String
        let installPubkeyHash: String
    }

    private func loadAccountSession() {
        // Clear stale session if it was created against a different backend environment
        let currentEnv = backendClient.environment == .live ? "live" : "test"
        if let savedEnv = keychain.get(.accountSessionEnvironment), savedEnv != currentEnv {
            clearAccountSession()
            return
        }

        let email = keychain.get(.accountEmail)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        accountEmail = (email?.isEmpty == false) ? email : nil
        accountUserId = keychain.get(.accountUserId)

        if let encoded = keychain.get(.accountSessionExpiresAt),
           let unix = TimeInterval(encoded) {
            let expiry = Date(timeIntervalSince1970: unix)
            if Date() >= expiry {
                clearAccountSession()
                return
            }
            accountSessionExpiresAt = expiry
        } else {
            accountSessionExpiresAt = nil
        }
        refreshSignedInState()
    }

    private func saveAccountSession(
        token: String,
        userId: String,
        email: String,
        expiresAtUnix: Int
    ) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try? keychain.save(token, for: .accountSessionToken)
        try? keychain.save(userId, for: .accountUserId)
        try? keychain.save(normalizedEmail, for: .accountEmail)
        try? keychain.save(String(expiresAtUnix), for: .accountSessionExpiresAt)
        let envTag = backendClient.environment == .live ? "live" : "test"
        try? keychain.save(envTag, for: .accountSessionEnvironment)

        accountUserId = userId
        accountEmail = normalizedEmail
        accountSessionExpiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtUnix))
        refreshSignedInState()
    }

    private func clearAccountSession() {
        keychain.delete(.accountSessionToken)
        keychain.delete(.accountUserId)
        keychain.delete(.accountEmail)
        keychain.delete(.accountSessionExpiresAt)
        keychain.delete(.accountSessionEnvironment)

        accountUserId = nil
        accountEmail = nil
        accountSessionExpiresAt = nil
        refreshSignedInState()
    }

    private func normalizedQueryValue(
        named name: String,
        in components: URLComponents,
        lowercased: Bool = false
    ) -> String? {
        let value = components.queryItems?
            .first(where: { $0.name == name })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value, !value.isEmpty else { return nil }
        return lowercased ? value.lowercased() : value
    }

    private func attemptCheckoutRestore(emailHint: String?, licenseKey: String?) async -> Bool {
        // Webhook projection can arrive a few seconds after browser return.
        // Retry longer to auto-upgrade without requiring manual restore input.
        let attempts: [Duration] = [
            .zero,
            .seconds(2),
            .seconds(5),
            .seconds(10),
            .seconds(15),
            .seconds(20),
            .seconds(30),
        ]
        let normalizedEmailHint = emailHint?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let fallbackLinkedEmail = accountEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let candidateEmail = (normalizedEmailHint?.isEmpty == false)
            ? normalizedEmailHint
            : ((fallbackLinkedEmail?.isEmpty == false) ? fallbackLinkedEmail : nil)

        for delay in attempts {
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }

            do {
                let outcome = try await performRestorePurchases(
                    email: candidateEmail,
                    licenseKey: licenseKey
                )
                if outcome != .none {
                    return true
                }
            } catch {
                // Fall through and retry/revalidate.
            }
        }

        return false
    }

    // MARK: - Key Rotation Support

    /// Build a map of key ID → public key hex for multi-key verification.
    /// Supports rotation: current key (ENTITLEMENT_PUBLIC_KEY_HEX / key ID from ENTITLEMENT_KEY_ID)
    /// and optional previous key (ENTITLEMENT_PUBLIC_KEY_HEX_PREV / key ID from ENTITLEMENT_KEY_ID_PREV).
    private static var entitlementPublicKeyMap: [String: String] {
        var map: [String: String] = [:]

        // Current key
        if let hex = configuredEntitlementPublicKeyHex() {
            let kid = configuredStringFromEnvOrBundle("ENTITLEMENT_KEY_ID") ?? "default"
            map[kid] = hex
            // Also register under "default" for backward compat if no kid claim in old tokens
            if kid != "default" {
                map["default"] = hex
            }
        }

        // Previous key (only present during rotation window)
        if let prevHex = configuredEntitlementPrevPublicKeyHex() {
            let prevKid = configuredStringFromEnvOrBundle("ENTITLEMENT_KEY_ID_PREV") ?? "prev"
            map[prevKid] = prevHex
        }

        return map
    }

    private static func configuredEntitlementPublicKeyHex() -> String? {
        if let env = ProcessInfo.processInfo.environment["ENTITLEMENT_PUBLIC_KEY_HEX"] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidEntitlementPublicKeyHex(trimmed) { return trimmed }
        }

        if let info = Bundle.main.object(forInfoDictionaryKey: "ENTITLEMENT_PUBLIC_KEY_HEX") as? String {
            let trimmed = info.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidEntitlementPublicKeyHex(trimmed) { return trimmed }
        }

        return nil
    }

    private static func configuredEntitlementPrevPublicKeyHex() -> String? {
        if let env = ProcessInfo.processInfo.environment["ENTITLEMENT_PUBLIC_KEY_HEX_PREV"] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidEntitlementPublicKeyHex(trimmed) { return trimmed }
        }

        if let info = Bundle.main.object(forInfoDictionaryKey: "ENTITLEMENT_PUBLIC_KEY_HEX_PREV") as? String {
            let trimmed = info.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidEntitlementPublicKeyHex(trimmed) { return trimmed }
        }

        return nil
    }

    private static func configuredStringFromEnvOrBundle(_ key: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[key] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let info = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = info.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static func isValidEntitlementPublicKeyHex(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)
        }
    }

    private func bootstrapInstallId() {
        if let existing = keychain.get(.installId) {
            installId = existing
            return
        }
        let newId = UUID().uuidString.lowercased()
        try? keychain.save(newId, for: .installId)
        installId = newId
    }

    private func ensureInstallIdentityRegistered() async throws {
        if isInstallRegistered { return }

        let publicKeyHash = try secureEnclave.publicKeyHashBase64URL()
        if keychain.get(.installRegistrationPubkeyHash) == publicKeyHash {
            isInstallRegistered = true
            return
        }

        let publicKey = try secureEnclave.publicKeyBase64()
        try await backendClient.registerInstall(installId: installId, installPubkey: publicKey)
        try? keychain.save(publicKeyHash, for: .installRegistrationPubkeyHash)
        isInstallRegistered = true
    }

    private func createInstallProof() async throws -> InstallProof {
        try await ensureInstallIdentityRegistered()

        let challenge: InstallChallengeResponse
        do {
            challenge = try await backendClient.requestInstallChallenge(installId: installId)
        } catch {
            if isInstallNotRegisteredError(error) {
                isInstallRegistered = false
                keychain.delete(.installRegistrationPubkeyHash)
                try await ensureInstallIdentityRegistered()
                challenge = try await backendClient.requestInstallChallenge(installId: installId)
            } else {
                throw error
            }
        }

        let signature = try secureEnclave.signNonce(challenge.nonce)
        let installPubkeyHash = try secureEnclave.publicKeyHashBase64URL()

        return InstallProof(
            challengeId: challenge.challenge_id,
            signature: signature,
            installPubkeyHash: installPubkeyHash
        )
    }

    private func revalidateLicensePath(_ usedOfflineCache: inout Bool) async {
        guard let licenseKey = keychain.get(.licenseKey) else {
            isLicenseValid = false
            keychain.delete(.licenseOfflineGraceUntil)
            return
        }

        let instanceId = keychain.get(.licenseInstanceId)
        do {
            let response = try await client.validateLicense(key: licenseKey, instanceId: instanceId)
            isLicenseValid = response.valid
            if response.valid {
                saveLicenseOfflineGraceWindow()
                saveClockCheckpoint()
            } else {
                keychain.delete(.licenseOfflineGraceUntil)
            }
        } catch {
            let clockRollbackDetected = detectClockRollback()
            if !clockRollbackDetected && canUseOfflineLicenseGrace() {
                isLicenseValid = true
                usedOfflineCache = true
                return
            }

            if clockRollbackDetected {
                keychain.delete(.licenseOfflineGraceUntil)
            }
            isLicenseValid = false
        }
    }

    private func revalidateSubscriptionPath(_ usedOfflineCache: inout Bool) async {
        guard isAccountSignedIn, let email = accountEmail, !email.isEmpty else {
            clearLinkedSubscriptionState(deleteEmail: false)
            return
        }

        do {
            let proof = try await createInstallProof()
            let response = try await backendClient.resolve(
                email: email,
                installId: installId,
                challengeId: proof.challengeId,
                nonceSignature: proof.signature
            )

            let claims = try verifyEntitlementToken(
                response.token,
                expectedInstallPubkeyHash: proof.installPubkeyHash
            )

            try? keychain.save(response.token, for: .entitlementToken)

            if claims.tier == "pro" || claims.tier == "vip" {
                isSubscriptionActive = true
                resolvedTier = claims.tier
            } else {
                clearLinkedSubscriptionState(deleteEmail: false)
            }

            saveClockCheckpoint()
        } catch {
            print("[Entitlement] revalidate failed: \(error)")
            if let backendError = error as? BackendError, case .authRequired = backendError {
                clearAccountSession()
                clearLinkedSubscriptionState(deleteEmail: false)
                return
            }

            if let backendError = error as? BackendError, backendError.isTransient,
               let cachedToken = keychain.get(.entitlementToken) {
                do {
                    let expectedHash = try secureEnclave.publicKeyHashBase64URL()
                    let claims = try verifyEntitlementToken(
                        cachedToken,
                        expectedInstallPubkeyHash: expectedHash
                    )

                    if detectClockRollback() {
                        clearLinkedSubscriptionState(deleteEmail: false)
                        return
                    }

                    if claims.tier == "pro" || claims.tier == "vip" {
                        isSubscriptionActive = true
                        resolvedTier = claims.tier
                        usedOfflineCache = true
                        return
                    }
                } catch {
                    keychain.delete(.entitlementToken)
                }
            }

            clearLinkedSubscriptionState(deleteEmail: false)
        }
    }

    private func verifyEntitlementToken(
        _ token: String,
        expectedInstallPubkeyHash: String
    ) throws -> EntitlementTokenClaims {
        let parts = token.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else {
            throw BackendError.invalidToken("Invalid token format")
        }

        let payloadB64 = String(parts[0])
        let signatureB64 = String(parts[1])

        guard let payloadData = Self.base64urlDecode(payloadB64) else {
            throw BackendError.invalidToken("Failed to decode token payload")
        }

        guard let signatureData = Self.base64urlDecode(signatureB64) else {
            throw BackendError.invalidToken("Failed to decode token signature")
        }

        // Decode claims first to read kid before signature verification
        let claims = try JSONDecoder().decode(EntitlementTokenClaims.self, from: payloadData)

        // Select key by kid claim; fall back to "default" for tokens without kid
        let kid = claims.kid ?? "default"
        let keyMap = Self.entitlementPublicKeyMap
        guard let publicKeyHex = keyMap[kid], !publicKeyHex.isEmpty,
              let publicKeyData = Self.hexToData(publicKeyHex),
              publicKeyData.count == 32 else {
            #if DEBUG
            if keyMap.isEmpty {
                print("[Entitlement] Missing ENTITLEMENT_PUBLIC_KEY_HEX configuration; token verification will fail.")
                throw BackendError.invalidToken("Missing or invalid ENTITLEMENT_PUBLIC_KEY_HEX configuration")
            }
            #endif
            throw BackendError.invalidToken("Unknown key ID '\(kid)' — key rotation may be incomplete")
        }

        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        guard publicKey.isValidSignature(signatureData, for: payloadData) else {
            throw BackendError.invalidToken("Signature verification failed")
        }

        let now = Int(Date().timeIntervalSince1970)
        guard now < claims.exp else {
            throw BackendError.invalidToken("Token expired")
        }

        guard claims.install_id == installId else {
            throw BackendError.invalidToken("install_id mismatch")
        }

        guard let claimHash = claims.install_pubkey_hash,
              !claimHash.isEmpty,
              claimHash == expectedInstallPubkeyHash else {
            throw BackendError.invalidToken("install_pubkey_hash mismatch")
        }

        return claims
    }

    private func saveLicenseOfflineGraceWindow() {
        let graceUntil = Date().addingTimeInterval(Self.licenseOfflineGraceInterval)
        let encoded = ISO8601DateFormatter().string(from: graceUntil)
        try? keychain.save(encoded, for: .licenseOfflineGraceUntil)
    }

    private func canUseOfflineLicenseGrace() -> Bool {
        guard let encoded = keychain.get(.licenseOfflineGraceUntil),
              let graceUntil = ISO8601DateFormatter().date(from: encoded) else {
            return false
        }

        return Date() < graceUntil
    }

    private func isInstallNotRegisteredError(_ error: Error) -> Bool {
        guard case let BackendError.httpError(statusCode, body) = error else {
            return false
        }
        guard statusCode == 404 || statusCode == 400 else {
            return false
        }
        return body.contains("INSTALL_NOT_REGISTERED")
    }

    private func saveClockCheckpoint() {
        let checkpoint = ClockCheckpoint(
            wallClock: Date().timeIntervalSince1970,
            systemUptime: ProcessInfo.processInfo.systemUptime
        )
        if let data = try? JSONEncoder().encode(checkpoint),
           let json = String(data: data, encoding: .utf8) {
            try? keychain.save(json, for: .clockCheckpoint)
        }
    }

    private func detectClockRollback() -> Bool {
        guard let checkpointJSON = keychain.get(.clockCheckpoint),
              let data = checkpointJSON.data(using: .utf8),
              let checkpoint = try? JSONDecoder().decode(ClockCheckpoint.self, from: data) else {
            return false
        }

        let currentWall = Date().timeIntervalSince1970
        let currentUptime = ProcessInfo.processInfo.systemUptime

        let wallDelta = currentWall - checkpoint.wallClock
        let uptimeDelta = currentUptime - checkpoint.systemUptime

        if wallDelta < -300 {
            return true
        }

        if uptimeDelta > 0 && wallDelta < uptimeDelta - 600 {
            return true
        }

        return false
    }

    private func loadCachedEntitlement() {
        isSubscriptionActive = false
        subscriptionCustomerId = nil
        subscriptionProductId = nil
        subscriptionRenewalDateISO8601 = nil
        resolvedTier = "free"

        guard isAccountSignedIn else {
            keychain.delete(.entitlementToken)
            return
        }

        guard let cachedToken = keychain.get(.entitlementToken) else {
            return
        }

        do {
            let expectedHash = try secureEnclave.publicKeyHashBase64URL()
            let claims = try verifyEntitlementToken(
                cachedToken,
                expectedInstallPubkeyHash: expectedHash
            )

            if claims.tier == "pro" || claims.tier == "vip" {
                isSubscriptionActive = true
                resolvedTier = claims.tier
            }
        } catch {
            keychain.delete(.entitlementToken)
            clearLinkedSubscriptionState(deleteEmail: false)
        }
    }

    private func clearLinkedSubscriptionState(deleteEmail: Bool) {
        isSubscriptionActive = false
        subscriptionCustomerId = nil
        subscriptionProductId = nil
        subscriptionRenewalDateISO8601 = nil
        resolvedTier = "free"
        keychain.delete(.entitlementToken)
        if deleteEmail {
            keychain.delete(.customerEmail)
        }
    }

    private func saveValidationTimestamp() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        try? keychain.save(timestamp, for: .entitlementLastValidatedAt)
    }

    // MARK: - Base64url Helpers

    private static func base64urlDecode(_ str: String) -> Data? {
        var base64 = str
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }

    private static func hexToData(_ hex: String) -> Data? {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count % 2 == 0 else { return nil }
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let nextIndex = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}

// MARK: - Token Claims

struct EntitlementTokenClaims: Codable {
    let tier: String
    let sub: String
    let install_id: String
    let iat: Int
    let exp: Int
    let jti: String
    /// Key ID for rotation support — identifies which public key was used to sign this token
    let kid: String?
    let install_pubkey_hash: String?
}

// MARK: - Clock Checkpoint

private struct ClockCheckpoint: Codable {
    let wallClock: TimeInterval
    let systemUptime: TimeInterval
}

enum EntitlementError: LocalizedError {
    case subscriptionNotActive
    case subscriptionEmailMissing
    case accountSignInRequired
    case accountEmailMissing

    var errorDescription: String? {
        switch self {
        case .subscriptionNotActive:
            return "No active subscription found for this email"
        case .subscriptionEmailMissing:
            return "No linked subscription email found"
        case .accountSignInRequired:
            return "Sign in is required before restoring or purchasing"
        case .accountEmailMissing:
            return "Email is required"
        }
    }
}

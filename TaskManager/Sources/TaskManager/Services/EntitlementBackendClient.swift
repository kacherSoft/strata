import Foundation

// ---------------------------------------------------------------------------
// EntitlementBackendClient — HTTP client for the Strata backend
// ---------------------------------------------------------------------------

/// Client for the Strata entitlement backend (Cloudflare Worker).
/// Handles install registration/challenge, checkout, resolve, restore, and portal endpoints.
struct EntitlementBackendClient: Sendable {

    // MARK: - Environment

    enum Environment: Sendable {
        case test
        case live

        fileprivate var infoPlistKey: String {
            switch self {
            case .test: return "STRATA_BACKEND_TEST_BASE_URL"
            case .live: return "STRATA_BACKEND_LIVE_BASE_URL"
            }
        }

        fileprivate var processEnvKey: String {
            switch self {
            case .test: return "STRATA_BACKEND_TEST_BASE_URL"
            case .live: return "STRATA_BACKEND_LIVE_BASE_URL"
            }
        }

        fileprivate var fallbackBaseURL: String {
            switch self {
            case .test: return "https://strata-backend-test.kacher.workers.dev"
            case .live: return "https://strata-backend.kacher.workers.dev"
            }
        }
    }

    static let shared = EntitlementBackendClient()

    let environment: Environment
    private let baseURL: URL

    init(environment: Environment? = nil, baseURL: URL? = nil) {
        #if DEBUG
        self.environment = environment ?? .test
        #else
        self.environment = environment ?? .live
        #endif
        self.baseURL = baseURL ?? Self.resolveBaseURL(for: self.environment)
    }

    // MARK: - Install Identity

    func registerInstall(installId: String, installPubkey: String) async throws {
        let body = InstallRegisterRequest(install_id: installId, install_pubkey: installPubkey)
        _ = try await post("/v1/installs/register", body: body) as InstallRegisterResponse
    }

    func requestInstallChallenge(installId: String) async throws -> InstallChallengeResponse {
        let body = InstallChallengeRequest(install_id: installId)
        return try await post("/v1/installs/challenge", body: body)
    }

    // MARK: - Resolve

    func resolve(
        email: String?,
        installId: String,
        challengeId: String,
        nonceSignature: String
    ) async throws -> ResolveResponse {
        let body = ResolveRequest(
            email: email?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
            install_id: installId,
            challenge_id: challengeId,
            nonce_signature: nonceSignature
        )
        return try await post("/v1/entitlements/resolve", body: body, requiresAuth: true, retryable: false)
    }

    // MARK: - Restore

    func restore(
        email: String?,
        installId: String,
        challengeId: String,
        nonceSignature: String,
        licenseKey: String?
    ) async throws -> RestoreResponse {
        let body = RestoreRequest(
            email: email?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
            install_id: installId,
            challenge_id: challengeId,
            nonce_signature: nonceSignature,
            license_key: licenseKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return try await post("/v1/purchases/restore", body: body, requiresAuth: true, retryable: false)
    }

    // MARK: - Checkout

    func createCheckoutSession(
        productId: String,
        installId: String,
        email: String?,
        returnURL: String
    ) async throws -> CheckoutSessionResponse {
        let body = CheckoutSessionRequest(
            product_id: productId,
            install_id: installId,
            email: email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            return_url: returnURL
        )
        return try await post("/v1/checkout-sessions", body: body, requiresAuth: true)
    }

    // MARK: - Customer Portal

    func customerPortalURL(
        email: String?,
        installId: String,
        challengeId: String,
        nonceSignature: String
    ) async throws -> URL {
        let body = PortalSessionRequest(
            email: email?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
            install_id: installId,
            challenge_id: challengeId,
            nonce_signature: nonceSignature
        )
        let response: PortalSessionResponse = try await post(
            "/v1/customer-portal/session",
            body: body,
            requiresAuth: true,
            retryable: false
        )
        guard let url = URL(string: response.portal_url),
              url.scheme?.lowercased() == "https" else {
            throw BackendError.invalidPortalURL
        }
        return url
    }

    // MARK: - Account Auth (OTP)

    func startEmailAuth(email: String) async throws -> AuthStartResponse {
        let body = AuthStartRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
        return try await post("/v1/auth/email/start", body: body)
    }

    func verifyEmailAuth(
        email: String,
        challengeId: String,
        code: String
    ) async throws -> AuthVerifyResponse {
        let body = AuthVerifyRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            challenge_id: challengeId.trimmingCharacters(in: .whitespacesAndNewlines),
            code: code.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return try await post("/v1/auth/email/verify", body: body)
    }

    func revokeAccountSession() async throws {
        let _: SessionRevokeResponse = try await post(
            "/v1/auth/session/revoke",
            body: EmptyRequest(),
            requiresAuth: true
        )
    }

    // MARK: - Devices

    func listDevices() async throws -> DevicesListResponse {
        return try await get("/v1/devices", requiresAuth: true)
    }

    func revokeDevice(installId: String) async throws {
        let _: DeviceRevokeResponse = try await post(
            "/v1/devices/revoke",
            body: RevokeDeviceRequest(install_id: installId),
            requiresAuth: true
        )
    }

    // MARK: - Private

    private let timeout: TimeInterval = 15
    private let maxRetries = 2
    private let retryDelay: TimeInterval = 1.0
    private let keychain = KeychainService.shared

    private static func resolveBaseURL(for environment: Environment) -> URL {
        let processEnv = ProcessInfo.processInfo.environment

        if let configured = processEnv[environment.processEnvKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: configured), !configured.isEmpty {
            return url
        }

        if let infoValue = Bundle.main.object(forInfoDictionaryKey: environment.infoPlistKey) as? String {
            let configured = infoValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: configured), !configured.isEmpty {
                return url
            }
        }

        guard let fallback = URL(string: environment.fallbackBaseURL) else {
            fatalError("Invalid fallback backend URL")
        }
        return fallback
    }

    private func authorizationHeaderValue() -> String? {
        guard let token = keychain.get(.accountSessionToken)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }
        return "Bearer \(token)"
    }

    private func decodeErrorCode(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["error_code"] as? String else {
            return nil
        }
        return code
    }

    private func post<T: Encodable, R: Decodable>(
        _ path: String,
        body: T,
        requiresAuth: Bool = false,
        retryable: Bool = true
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth {
            guard let authValue = authorizationHeaderValue() else {
                throw BackendError.authRequired
            }
            request.setValue(authValue, forHTTPHeaderField: "Authorization")
        } else if let authValue = authorizationHeaderValue() {
            request.setValue(authValue, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let effectiveMaxRetries = retryable ? maxRetries : 0
        var lastError: Error?

        for attempt in 0...effectiveMaxRetries {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw BackendError.networkError(URLError(.badServerResponse))
                }

                if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
                    lastError = BackendError.httpError(
                        statusCode: httpResponse.statusCode,
                        body: String(data: data, encoding: .utf8) ?? ""
                    )
                    if attempt < effectiveMaxRetries { continue }
                    throw lastError!
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorBody = String(data: data, encoding: .utf8) ?? ""
                    if httpResponse.statusCode == 401 {
                        let errorCode = decodeErrorCode(from: errorBody)
                        if errorCode == "AUTH_REQUIRED" || errorCode == "INVALID_SESSION" {
                            throw BackendError.authRequired
                        }
                    }
                    throw BackendError.httpError(
                        statusCode: httpResponse.statusCode,
                        body: errorBody
                    )
                }

                // Server processed the request — never retry after 2xx.
                do {
                    return try JSONDecoder().decode(R.self, from: data)
                } catch {
                    let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                    NSLog("[BackendClient] POST %@ decode failed status=%d body=%@: %@",
                          path, httpResponse.statusCode, preview, "\(error)")
                    throw BackendError.networkError(error)
                }
            } catch let error as BackendError {
                lastError = error
                switch error {
                case .networkError:
                    if attempt < effectiveMaxRetries { continue }
                case .httpError(let code, _) where code >= 500 || code == 429:
                    if attempt < effectiveMaxRetries { continue }
                default:
                    throw error
                }
            } catch {
                lastError = BackendError.networkError(error)
                if attempt < effectiveMaxRetries { continue }
            }
        }

        throw lastError ?? BackendError.networkError(URLError(.unknown))
    }

    private func get<R: Decodable>(
        _ path: String,
        requiresAuth: Bool = false
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        if requiresAuth {
            guard let authValue = authorizationHeaderValue() else {
                throw BackendError.authRequired
            }
            request.setValue(authValue, forHTTPHeaderField: "Authorization")
        } else if let authValue = authorizationHeaderValue() {
            request.setValue(authValue, forHTTPHeaderField: "Authorization")
        }

        var lastError: Error?

        for attempt in 0...maxRetries {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw BackendError.networkError(URLError(.badServerResponse))
                }

                if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 {
                    lastError = BackendError.httpError(
                        statusCode: httpResponse.statusCode,
                        body: String(data: data, encoding: .utf8) ?? ""
                    )
                    if attempt < maxRetries { continue }
                    throw lastError!
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorBody = String(data: data, encoding: .utf8) ?? ""
                    if httpResponse.statusCode == 401 {
                        let errorCode = decodeErrorCode(from: errorBody)
                        if errorCode == "AUTH_REQUIRED" || errorCode == "INVALID_SESSION" {
                            throw BackendError.authRequired
                        }
                    }
                    throw BackendError.httpError(
                        statusCode: httpResponse.statusCode,
                        body: errorBody
                    )
                }

                do {
                    return try JSONDecoder().decode(R.self, from: data)
                } catch {
                    let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                    NSLog("[BackendClient] GET %@ decode failed status=%d body=%@: %@",
                          path, httpResponse.statusCode, preview, "\(error)")
                    throw BackendError.networkError(error)
                }
            } catch let error as BackendError {
                lastError = error
                switch error {
                case .networkError:
                    if attempt < maxRetries { continue }
                case .httpError(let code, _) where code >= 500 || code == 429:
                    if attempt < maxRetries { continue }
                default:
                    throw error
                }
            } catch {
                lastError = BackendError.networkError(error)
                if attempt < maxRetries { continue }
            }
        }

        throw lastError ?? BackendError.networkError(URLError(.unknown))
    }
}

// MARK: - Request / Response Types

struct ResolveRequest: Encodable {
    let email: String?
    let install_id: String
    let challenge_id: String
    let nonce_signature: String
}

struct ResolveResponse: Decodable {
    let token: String
}

struct PortalSessionRequest: Encodable {
    let email: String?
    let install_id: String
    let challenge_id: String
    let nonce_signature: String
}

struct PortalSessionResponse: Decodable {
    let portal_url: String
}

struct InstallRegisterRequest: Encodable {
    let install_id: String
    let install_pubkey: String
}

struct InstallRegisterResponse: Decodable {
    let registered: Bool
}

struct InstallChallengeRequest: Encodable {
    let install_id: String
}

struct InstallChallengeResponse: Decodable {
    let challenge_id: String
    let nonce: String
    let expires_at: Int
}

struct CheckoutSessionRequest: Encodable {
    let product_id: String
    let install_id: String
    let email: String?
    let return_url: String
}

struct CheckoutSessionResponse: Decodable {
    let checkout_url: String
    let session_id: String
}

struct RestoreRequest: Encodable {
    let email: String?
    let install_id: String
    let challenge_id: String
    let nonce_signature: String
    let license_key: String?
}

struct RestoreResponse: Decodable {
    let token: String
    let restore_type: String?
    let resolved_email: String?
}

struct AuthStartRequest: Encodable {
    let email: String
}

struct AuthStartResponse: Decodable {
    let challenge_id: String
    let expires_at: Int
    let delivery: String
}

struct AuthVerifyRequest: Encodable {
    let email: String
    let challenge_id: String
    let code: String
}

struct AuthVerifyResponse: Decodable {
    let session_token: String
    let session_expires_at: Int
    let user_id: String
    let email: String
}

struct EmptyRequest: Encodable {}

struct SessionRevokeResponse: Decodable {
    let revoked: Bool
}

struct DeviceInfo: Decodable {
    let install_id: String
    let nickname: String?
    let first_seen_at: Int
    let last_seen_at: Int
    let revoked_at: Int?
    let active: Bool
}

struct DevicesListResponse: Decodable {
    let devices: [DeviceInfo]
}

struct RevokeDeviceRequest: Encodable {
    let install_id: String
}

struct DeviceRevokeResponse: Decodable {
    let revoked: Bool
}

// MARK: - Errors

enum BackendError: LocalizedError {
    case httpError(statusCode: Int, body: String)
    case networkError(Error)
    case invalidPortalURL
    case invalidToken(String)
    case authRequired

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return Self.friendlyMessage(statusCode: code, body: body)
        case .networkError:
            return "Unable to connect to the server. Please check your internet connection and try again."
        case .invalidPortalURL:
            return "Unable to open the subscription management page. Please try again."
        case .invalidToken:
            return "Your entitlement could not be verified. Please try restoring your purchase."
        case .authRequired:
            return "Please sign in to continue."
        }
    }

    private static let errorCodeMessages: [String: String] = [
        "CHALLENGE_ALREADY_USED": "Verification failed. Please try again.",
        "CHALLENGE_EXPIRED": "Verification expired. Please try again.",
        "INVALID_CHALLENGE": "Verification failed. Please try again.",
        "INVALID_INSTALL_PROOF": "Device verification failed. Please try again.",
        "RATE_LIMITED": "Too many requests. Please wait a moment and try again.",
        "PROVIDER_ERROR": "Payment service is temporarily unavailable. Please try again later.",
        "CUSTOMER_NOT_FOUND": "No account found for this email address.",
        "DEVICE_LIMIT_REACHED": "You've reached the maximum number of devices for your plan.",
        "DEVICE_NOT_FOUND": "Device not found. It may have already been removed.",
        "ACCOUNT_MISMATCH": "The email doesn't match your signed-in account.",
        "OTP_EXPIRED": "Verification code has expired. Please request a new one.",
        "OTP_ATTEMPTS_EXCEEDED": "Too many failed attempts. Please request a new code.",
        "INVALID_OTP": "Invalid verification code. Please check and try again.",
        "INVALID_SESSION": "Your session has expired. Please sign in again.",
        "ALREADY_REGISTERED": "This device is already registered.",
    ]

    private static func friendlyMessage(statusCode: Int, body: String) -> String {
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorCode = json["error_code"] as? String {
            if let friendly = errorCodeMessages[errorCode] {
                return friendly
            }
            if let message = json["message"] as? String {
                return message
            }
        }
        switch statusCode {
        case 401: return "Authentication required. Please sign in and try again."
        case 429: return "Too many requests. Please wait a moment and try again."
        case 502, 503: return "Service temporarily unavailable. Please try again later."
        default: return "Something went wrong (error \(statusCode)). Please try again."
        }
    }

    /// Whether this error should trigger offline fallback.
    var isTransient: Bool {
        switch self {
        case .networkError:
            return true
        case .httpError(let code, _):
            return code == 429 || code >= 500
        case .authRequired:
            return false
        default:
            return false
        }
    }
}

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
        email: String,
        installId: String,
        challengeId: String,
        nonceSignature: String
    ) async throws -> ResolveResponse {
        let body = ResolveRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            install_id: installId,
            challenge_id: challengeId,
            nonce_signature: nonceSignature
        )
        return try await post("/v1/entitlements/resolve", body: body)
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
        return try await post("/v1/purchases/restore", body: body)
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
        return try await post("/v1/checkout-sessions", body: body)
    }

    // MARK: - Customer Portal

    func customerPortalURL(
        email: String,
        installId: String,
        challengeId: String,
        nonceSignature: String
    ) async throws -> URL {
        let body = PortalSessionRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            install_id: installId,
            challenge_id: challengeId,
            nonce_signature: nonceSignature
        )
        let response: PortalSessionResponse = try await post(
            "/v1/customer-portal/session",
            body: body
        )
        guard let url = URL(string: response.portal_url),
              url.scheme?.lowercased() == "https" else {
            throw BackendError.invalidPortalURL
        }
        return url
    }

    // MARK: - Private

    private let timeout: TimeInterval = 15
    private let maxRetries = 2
    private let retryDelay: TimeInterval = 1.0

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

    private func post<T: Encodable, R: Decodable>(
        _ path: String,
        body: T
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

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
                    throw BackendError.httpError(
                        statusCode: httpResponse.statusCode,
                        body: errorBody
                    )
                }

                return try JSONDecoder().decode(R.self, from: data)
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
    let email: String
    let install_id: String
    let challenge_id: String
    let nonce_signature: String
}

struct ResolveResponse: Decodable {
    let token: String
}

struct PortalSessionRequest: Encodable {
    let email: String
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

// MARK: - Errors

enum BackendError: LocalizedError {
    case httpError(statusCode: Int, body: String)
    case networkError(Error)
    case invalidPortalURL
    case invalidToken(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "Backend HTTP \(code): \(body)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidPortalURL:
            return "Invalid portal URL received from backend"
        case .invalidToken(let reason):
            return "Invalid entitlement token: \(reason)"
        }
    }

    /// Whether this error should trigger offline fallback.
    var isTransient: Bool {
        switch self {
        case .networkError:
            return true
        case .httpError(let code, _):
            return code == 429 || code >= 500
        default:
            return false
        }
    }
}

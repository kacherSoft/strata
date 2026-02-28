import Foundation

struct DodoPaymentsClient: Sendable {

    enum Environment: Sendable {
        case test
        case live

        var baseURL: URL {
            switch self {
            case .test: URL(string: "https://test.dodopayments.com")!
            case .live: URL(string: "https://live.dodopayments.com")!
            }
        }
    }

    static let shared = DodoPaymentsClient()

    let environment: Environment

    init(environment: Environment? = nil) {
        #if DEBUG
        self.environment = environment ?? .test
        #else
        self.environment = environment ?? .live
        #endif
    }

    static let proMonthlyProductId = "pdt_0NZEvu9tI0aecVEYkmxOH"
    static let proYearlyProductId = "pdt_0NZEzxFzK5RRekOJXQHpZ"
    static let vipLifetimeProductId = "pdt_0NZEzLgAEu8PcrUBqi8mt"

    // MARK: - License Activation

    func activateLicense(key: String, deviceName: String) async throws -> ActivateResponse {
        let body = ActivateRequest(license_key: key, name: deviceName)
        return try await post("/licenses/activate", body: body)
    }

    // MARK: - License Validation

    func validateLicense(key: String, instanceId: String? = nil) async throws -> ValidateResponse {
        let body = ValidateRequest(license_key: key, license_key_instance_id: instanceId)
        return try await post("/licenses/validate", body: body)
    }

    // MARK: - License Deactivation

    func deactivateLicense(key: String, instanceId: String) async throws -> DeactivateResponse {
        let body = DeactivateRequest(license_key: key, license_key_instance_id: instanceId)
        return try await post("/licenses/deactivate", body: body)
    }

    // MARK: - Private

    private func post<T: Encodable, R: Decodable>(_ path: String, body: T) async throws -> R {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = environment.baseURL.appendingPathComponent(trimmedPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        let data = try await getResponseData(for: request)

        if data.isEmpty || (data.count == 1 && data[0] == 0x0A) {
            if let empty = DeactivateResponse() as? R { return empty }
        }

        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw DodoPaymentsError.decodingError(error)
        }
    }

    private func getResponseData(for request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw DodoPaymentsError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DodoPaymentsError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DodoPaymentsError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        return data
    }
}

// MARK: - Request / Response Types

struct ActivateRequest: Encodable {
    let license_key: String
    let name: String
}

struct ActivateResponse: Decodable {
    let license_key_instance_id: String

    enum CodingKeys: String, CodingKey {
        case license_key_instance_id
        case id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let instanceID = try container.decodeIfPresent(String.self, forKey: .license_key_instance_id),
           !instanceID.isEmpty {
            license_key_instance_id = instanceID
            return
        }
        license_key_instance_id = try container.decode(String.self, forKey: .id)
    }
}

struct ValidateRequest: Encodable {
    let license_key: String
    let license_key_instance_id: String?
}

struct ValidateResponse: Decodable {
    let valid: Bool
}

struct DeactivateRequest: Encodable {
    let license_key: String
    let license_key_instance_id: String
}

struct DeactivateResponse: Decodable {
    // DodoPayments returns 200 on success; body may vary
}

// MARK: - Errors

enum DodoPaymentsError: LocalizedError {
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case networkError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let body):
            if statusCode == 404 {
                return "License key or instance not found"
            }
            if statusCode == 400 {
                return "Invalid request to DodoPayments: \(body)"
            }
            return "DodoPayments error (\(statusCode)): \(body)"
        case .decodingError(let error):
            return "Failed to decode DodoPayments response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid URL configuration"
        }
    }
}

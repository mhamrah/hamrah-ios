import Foundation

class SecureAPIService: ObservableObject {
    static let shared = SecureAPIService()

    private let attestationManager = AppAttestationManager.shared
    private var baseURL: String {
        APIConfiguration.shared.baseURL
    }

    private init() {}

    // MARK: - Secure API Request Methods

    /// Makes a secure API request with App Attestation
    func makeSecureRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        accessToken: String?,
        responseType: T.Type,
        customBaseURL: String? = nil
    ) async throws -> T {
        let targetBaseURL = customBaseURL ?? baseURL
        let url = URL(string: "\(targetBaseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add authorization if provided
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body if provided
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        // Generate challenge for attestation
        let challenge = generateRequestChallenge(url: url, method: method, body: body)

        // Add App Attestation headers (required)
        let attestationHeaders = try await attestationManager.generateAttestationHeaders(
            for: challenge)
        for (key, value) in attestationHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add challenge for server verification
        request.setValue(challenge.base64EncodedString(), forHTTPHeaderField: "X-Request-Challenge")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle authentication errors
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            // Try to decode error message
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let errorMessage = errorData["error"] as? String
            {
                throw APIError.serverError(httpResponse.statusCode, errorMessage)
            }
            throw APIError.serverError(httpResponse.statusCode, "Request failed")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Initialize attestation (should be called after login)
    func initializeAttestation(accessToken: String) async {
        do {
            try await attestationManager.initializeAttestation(accessToken: accessToken)
            print("✅ App Attestation initialized successfully")
        } catch {
            print("⚠️ Failed to initialize App Attestation: \(error)")
            // Continue without attestation - app should still work with fallback headers
        }
    }

    // MARK: - Convenience Methods

    func get<T: Codable>(
        endpoint: String,
        accessToken: String?,
        responseType: T.Type,
        customBaseURL: String? = nil
    ) async throws -> T {
        return try await makeSecureRequest(
            endpoint: endpoint,
            method: .GET,
            body: nil,
            accessToken: accessToken,
            responseType: responseType,
            customBaseURL: customBaseURL
        )
    }

    func post<T: Codable>(
        endpoint: String,
        body: [String: Any],
        accessToken: String?,
        responseType: T.Type,
        customBaseURL: String? = nil
    ) async throws -> T {
        return try await makeSecureRequest(
            endpoint: endpoint,
            method: .POST,
            body: body,
            accessToken: accessToken,
            responseType: responseType,
            customBaseURL: customBaseURL
        )
    }

    func delete<T: Codable>(
        endpoint: String,
        body: [String: Any]? = nil,
        accessToken: String?,
        responseType: T.Type
    ) async throws -> T {
        return try await makeSecureRequest(
            endpoint: endpoint,
            method: .DELETE,
            body: body,
            accessToken: accessToken,
            responseType: responseType
        )
    }

    // MARK: - Raw HEAD/Download (binary/HTML)

    /// Issues a raw HEAD request with App Attestation.
    /// Returns the HTTPURLResponse so callers can inspect headers like ETag/Content-Length.
    /// Accepts 200 OK and 304 Not Modified statuses.
    func headRaw(
        endpoint: String,
        ifNoneMatchETag: String? = nil,
        accessToken: String?,
        customBaseURL: String? = nil
    ) async throws -> HTTPURLResponse {
        let targetBaseURL = customBaseURL ?? baseURL
        let url = URL(string: "\(targetBaseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.HEAD.rawValue

        // Authorization (optional)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Conditional request (optional)
        if let etag = ifNoneMatchETag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        // App Attestation
        let challenge = generateRequestChallenge(url: url, method: .HEAD, body: nil)
        let attestationHeaders = try await attestationManager.generateAttestationHeaders(
            for: challenge)
        for (key, value) in attestationHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(challenge.base64EncodedString(), forHTTPHeaderField: "X-Request-Challenge")

        // Execute
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 304 else {
            throw APIError.serverError(httpResponse.statusCode, "HEAD request failed")
        }
        return httpResponse
    }

    /// Downloads raw content (binary/HTML) with App Attestation.
    /// Returns the temporary file URL and HTTPURLResponse for caller-managed caching.
    func downloadRaw(
        endpoint: String,
        accessToken: String?,
        customBaseURL: String? = nil
    ) async throws -> (URL, HTTPURLResponse) {
        let targetBaseURL = customBaseURL ?? baseURL
        let url = URL(string: "\(targetBaseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.GET.rawValue

        // Authorization (optional)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // App Attestation
        let challenge = generateRequestChallenge(url: url, method: .GET, body: nil)
        let attestationHeaders = try await attestationManager.generateAttestationHeaders(
            for: challenge)
        for (key, value) in attestationHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(challenge.base64EncodedString(), forHTTPHeaderField: "X-Request-Challenge")

        // Execute download
        let (tempURL, response) = try await URLSession.shared.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode, "Download request failed")
        }

        return (tempURL, httpResponse)
    }

    // MARK: - Private Methods

    private func generateRequestChallenge(url: URL, method: HTTPMethod, body: [String: Any]?)
        -> Data
    {
        // Create a deterministic challenge based on request details
        var challengeString = "\(method.rawValue):\(url.absoluteString)"

        if let body = body {
            // Sort keys for deterministic serialization
            let sortedKeys = body.keys.sorted()
            let bodyString = sortedKeys.map { key in
                "\(key):\(body[key] ?? "")"
            }.joined(separator: ",")
            challengeString += ":\(bodyString)"
        }

        challengeString += ":\(Date().timeIntervalSince1970)"

        return challengeString.data(using: .utf8) ?? Data()
    }
}

// MARK: - HTTP Method Enum

enum HTTPMethod: String {
    case GET = "GET"
    case HEAD = "HEAD"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Error Types

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    case attestationFailed(String)
    case simulatorNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .attestationFailed(let details):
            #if targetEnvironment(simulator)
                return
                    "App verification not supported on simulator. Please test on a physical device."
            #else
                return "App verification failed: \(details)"
            #endif
        case .simulatorNotSupported:
            return
                "This feature requires a physical iOS device and is not supported on the simulator."
        }
    }
}

// MARK: - Note:
// APIResponse model now lives in Models/APIResponse.swift (previously referenced from MyAccountView.swift)

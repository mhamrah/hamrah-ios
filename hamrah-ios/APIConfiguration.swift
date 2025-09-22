import Foundation

@Observable
class APIConfiguration {
    enum Environment: String, CaseIterable {
        case production = "Production"
        case development = "Development"
        case custom = "Custom"

        var baseURL: String {
            switch self {
            case .production:
                return "https://api.hamrah.app"
            case .development:
                return "http://127.0.0.1:8787"
            case .custom:
                return ""  // Will be set by user
            }
        }

        var webAppBaseURL: String {
            switch self {
            case .production:
                return "https://hamrah.app"  // WebAuthn operations go to web app
            case .development:
                return "https://localhost:5173"  // Same for development
            case .custom:
                return ""  // Will be set by user
            }
        }
    }

    static let shared = APIConfiguration()

    private let environmentKey = "APIEnvironment"
    private let customApiBaseURLKey = "CustomAPIBaseURL"
    private let customWebAppBaseURLKey = "CustomWebAppBaseURL"
    private let legacyCustomBaseURLKey = "CustomBaseURL"

    var currentEnvironment: Environment {
        didSet {
            UserDefaults.standard.set(currentEnvironment.rawValue, forKey: environmentKey)
        }
    }

    var customApiBaseURL: String {
        didSet {
            UserDefaults.standard.set(customApiBaseURL, forKey: customApiBaseURLKey)
        }
    }

    var customWebAppBaseURL: String {
        didSet {
            UserDefaults.standard.set(customWebAppBaseURL, forKey: customWebAppBaseURLKey)
        }
    }

    // Backward-compat: single custom URL maps to API (and seeds Web if unset)
    var customBaseURL: String {
        get { customApiBaseURL }
        set {
            customApiBaseURL = newValue
            if customWebAppBaseURL.isEmpty {
                customWebAppBaseURL = newValue
            }
            UserDefaults.standard.set(newValue, forKey: legacyCustomBaseURLKey)
        }
    }

    init() {
        // Load saved environment or default to production
        if let savedEnvironment = UserDefaults.standard.string(forKey: environmentKey),
            let environment = Environment(rawValue: savedEnvironment)
        {
            self.currentEnvironment = environment
        } else {
            self.currentEnvironment = .production
        }

        // Load saved custom base URLs (with legacy migration)
        let defaults = UserDefaults.standard
        let legacy = defaults.string(forKey: legacyCustomBaseURLKey) ?? ""
        self.customApiBaseURL = defaults.string(forKey: customApiBaseURLKey) ?? legacy
        self.customWebAppBaseURL = defaults.string(forKey: customWebAppBaseURLKey) ?? legacy
    }

    // Test-specific initializer that always uses production
    static func testInstance() -> APIConfiguration {
        let config = APIConfiguration()
        config.currentEnvironment = .production
        return config
    }

    var baseURL: String {
        switch currentEnvironment {
        case .production, .development:
            return currentEnvironment.baseURL
        case .custom:
            let url = customApiBaseURL
            if url.isEmpty {
                return Environment.production.baseURL  // Fallback to production
            }
            // Allow http/https; if no scheme, default to https
            if url.hasPrefix("http://") || url.hasPrefix("https://") {
                return url
            } else {
                return "https://\(url)"
            }
        }
    }

    var webAppBaseURL: String {
        switch currentEnvironment {
        case .production, .development:
            return currentEnvironment.webAppBaseURL
        case .custom:
            let url = customWebAppBaseURL
            if url.isEmpty {
                return Environment.production.webAppBaseURL  // Fallback to production web app
            }
            // Ensure HTTPS is used for web app
            if url.hasPrefix("http://") {
                return url.replacingOccurrences(of: "http://", with: "https://")
            } else if !url.hasPrefix("https://") {
                return "https://\(url)"
            }
            return url
        }
    }

    func setCustomURL(_ url: String) {
        customApiBaseURL = url
        customWebAppBaseURL = url
        currentEnvironment = .custom
    }

    func setCustomApiURL(_ url: String) {
        customApiBaseURL = url
        currentEnvironment = .custom
    }

    func setCustomWebURL(_ url: String) {
        customWebAppBaseURL = url
        currentEnvironment = .custom
    }

    func reset() {
        currentEnvironment = .production
        customApiBaseURL = ""
        customWebAppBaseURL = ""
    }
}

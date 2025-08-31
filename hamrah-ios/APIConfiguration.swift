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
                return "https://localhost:5173"
            case .custom:
                return "" // Will be set by user
            }
        }
    }
    
    static let shared = APIConfiguration()
    
    private let environmentKey = "APIEnvironment"
    private let customBaseURLKey = "CustomBaseURL"
    
    var currentEnvironment: Environment {
        didSet {
            UserDefaults.standard.set(currentEnvironment.rawValue, forKey: environmentKey)
        }
    }
    
    var customBaseURL: String {
        didSet {
            UserDefaults.standard.set(customBaseURL, forKey: customBaseURLKey)
        }
    }
    
    init() {
        // Load saved environment or default to production
        if let savedEnvironment = UserDefaults.standard.string(forKey: environmentKey),
           let environment = Environment(rawValue: savedEnvironment) {
            self.currentEnvironment = environment
        } else {
            self.currentEnvironment = .production
        }
        
        // Load saved custom base URL
        self.customBaseURL = UserDefaults.standard.string(forKey: customBaseURLKey) ?? ""
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
            if customBaseURL.isEmpty {
                return Environment.production.baseURL // Fallback to production
            }
            // Ensure HTTPS is used
            if customBaseURL.hasPrefix("http://") {
                return customBaseURL.replacingOccurrences(of: "http://", with: "https://")
            } else if !customBaseURL.hasPrefix("https://") {
                return "https://\(customBaseURL)"
            }
            return customBaseURL
        }
    }
    
    func setCustomURL(_ url: String) {
        customBaseURL = url
        currentEnvironment = .custom
    }
    
    func reset() {
        currentEnvironment = .production
        customBaseURL = ""
    }
}
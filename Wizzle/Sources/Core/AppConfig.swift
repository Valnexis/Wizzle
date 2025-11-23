import Foundation

// MARK: - App Environment

/// Represents which backend environment the app in currently targeting
enum AppEnvironment: String, Codable, CaseIterable {
    case dev
    case staging
    case prod
    
    /// Short emoji label for logs / UI
    var symbol: String {
        switch self {
        case .dev: return "🧪"
        case .staging: return "🚧"
        case .prod: return "🚀"
        }
    }
}
// MARK: - App Configuration

/// Global configuration describing API base URLs, version info, and environment.
struct AppConfig {
    
    // MARKL - Properties
    let env: AppEnvironment
    let apiBaseURL: URL
    let buildNumber: String
    let version: String
    
    // A quick health-check endpoint)
    var healthCheckURL: URL {
        apiBaseURL.appendingPathComponent("status")
    }

    // MARK: - Current Configuration
    static let current: AppConfig = {
        // Automatically select environment based on build flags
        let env: AppEnvironment = {
            #if DEBUG
            return .dev
            #elseif STAGING
            return .staging
            #else
            return .prod
            #endif
        }()
        
        // Base API URL per environment
        let base: URL = {
            switch env {
            case .dev:
                return URL(string: "http://192.148.1.45:3001")!
            case .staging:
                return URL(string: "https://staging.api.wizzle.example")!
            case .prod:
                return URL(string: "https://api.wizzle.example")!
            }
        }()
        
        // Pull versioning from Info.plist
        let info = Bundle.main.infoDictionary ?? [:]
        let build = info["CFBundleVersion"] as? String ?? "0"
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0"
        return AppConfig(
            env: env,
            apiBaseURL: base,
            buildNumber: build,
            version: version
        )
    }()
}

// MARK: - Debug / Print Helpers

extension AppConfig: CustomStringConvertible {
    var description: String {
        "\(env.symbol) [\(env.rawValue.uppercased())] \(apiBaseURL.absoluteString) • v\(version) (\(buildNumber))"
    }
}

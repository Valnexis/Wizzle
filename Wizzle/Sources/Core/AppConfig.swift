import Foundation

enum AppEnvironment: String {
    case dev, staging, prod
}

struct AppConfig {
    let env: AppEnvironment
    let apiBaseURL: URL
    let buildNumber: String
    let version: String

    // ✅ This property is plain static — not @MainActor
    static let current: AppConfig = {
        let env: AppEnvironment = .dev
        let base: URL = {
            switch env {
            case .dev: return URL(string: "http://192.168.1.45:3001")!
            case .staging: return URL(string: "https://staging.api.wizzle.example")!
            case .prod: return URL(string: "https://api.wizzle.example")!
            }
        }()

        let info = Bundle.main.infoDictionary ?? [:]
        return AppConfig(
            env: env,
            apiBaseURL: base,
            buildNumber: info["CFBundleVersion"] as? String ?? "0",
            version: info["CFBundleShortVersionString"] as? String ?? "0.0"
        )
    }()
}

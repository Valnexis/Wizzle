import Foundation

// MARK: - Global configuration & DI container

/// A lightweight, actor-isolated dependency container.
/// Initializes shared app-wide services (API, Keychain, Session).
actor Container {
    static let shared = Container()

    var api: APIClient!
    var keychain: KeychainStore!
    var session: SessionStore!

    init() {}

    /// Call once at app launch.
    func setup() {
        // 🧱 Initialize base dependencies (Foundation only)
        let config = AppConfig.current
        self.api = URLSessionAPI(baseURL: config.apiBaseURL)

        // ✅ Use our custom SessionStore
        self.session = SessionStore.shared

        // ✅ Initialize your keychain wrapper (optional, can reuse SessionStore for secure items)
        self.keychain = SystemKeychainStore()

        print("✅ Container setup complete")
    }
}

import Foundation

// MARK: - Global configuration & DI container

/// A lightweight, actor-isolated dependency container.
/// Initializes shared app-wide services (API, Keychain, Session).
actor Container {
    // MARK: Shared Instance
    static let shared = Container()
    
    // MARK: Dependencies
    var api: APIClient!
    var keychain: KeychainStore!
    var session: SessionStore!

    // MARK: Init
    init() {}

    /// Call once at app launch to initialize all dependencies
    func setup() {
        // Initialize core services (Foundation only, no MainActor)
        let config = AppConfig.current
        self.api = URLSessionAPI(baseURL: config.apiBaseURL)

        // Unified secure session (Keychain + token persistence)
        self.session = SessionStore.shared

        // Optional Keychain wrapper (only if we have SystemKeychainStore.swift)
        // If that file is removed, just delete this line
        if let systemStore = try? SystemKeychainStore() {
            self.keychain = systemStore
        }

        print("✅ Container setup complete for", config.apiBaseURL.absoluteString)
    }
}

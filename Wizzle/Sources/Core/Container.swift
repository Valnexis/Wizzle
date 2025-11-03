import Foundation

// MARK: - Global configuration & DI container

/// A lightweight, actor-isolated dependency container.
/// Nothing here should depend on MainActor or SwiftUI.
actor Container {
    static let shared = Container()

    var api: APIClient!
    var keychain: KeychainStore!
    var session: SessionStore!

    init() { }

    /// Call once at app launch.
    func setup() {
        // All of these types are pure data / Foundation only,
        // so they're safe to initialize inside our own actor.
        self.keychain = SystemKeychainStore()
        self.session = SecureSessionStore()

        // Access AppConfig.current in a non-isolated way
        let config = AppConfig.current
        self.api = URLSessionAPI(baseURL: config.apiBaseURL)
    }
}

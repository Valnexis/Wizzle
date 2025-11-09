import Foundation
import Security

// MARK: - SessionStore
/// Secure storage for access/refresh tokens and the authenticated user.
final class SessionStore {
    static let shared = SessionStore()
    private init() {}

    // MARK: - Keychain identifiers
    private let accountKey = "wizzle.session"
    private let service = "com.wizzle.app"

    // MARK: - Session Persistence

    /// Saves the current authenticated session securely in the Keychain.
    func saveSession(user: User, accessToken: String, refreshToken: String) {
        let session = SavedSession(user: user, accessToken: accessToken, refreshToken: refreshToken)

        guard let data = try? JSONEncoder().encode(session) else {
            print("❌ Failed to encode session")
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Remove old item before writing
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("✅ Session saved securely")
        } else {
            print("❌ Keychain save failed:", status)
        }
    }

    /// Attempts to load an existing session from the Keychain.
    func loadSession() -> SavedSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        } else if status != errSecSuccess {
            print("❌ Keychain load failed:", status)
            return nil
        }

        guard let data = item as? Data,
              let session = try? JSONDecoder().decode(SavedSession.self, from: data) else {
            print("❌ Failed to decode saved session data")
            return nil
        }

        return session
    }

    /// Clears session info completely.
    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
        print("🧹 Session cleared")
    }

    // MARK: - Token Accessors

    var accessToken: String? {
        get { loadSession()?.accessToken }
        set { updateTokenField(\.accessToken, to: newValue) }
    }

    var refreshToken: String? {
        get { loadSession()?.refreshToken }
        set { updateTokenField(\.refreshToken, to: newValue) }
    }

    // MARK: - Private Helpers

    private func updateTokenField(_ keyPath: WritableKeyPath<SavedSession, String>, to newValue: String?) {
        guard let newValue else { return }
        guard var session = loadSession() else { return }

        session[keyPath: keyPath] = newValue
        guard let data = try? JSONEncoder().encode(session) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}

// MARK: - Codable Struct
struct SavedSession: Codable {
    let user: User
    var accessToken: String
    var refreshToken: String
}

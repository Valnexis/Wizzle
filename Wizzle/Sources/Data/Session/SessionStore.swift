import Foundation
import Security

final class SessionStore {
    static let shared = SessionStore()
    private init() {}

    private let accountKey = "wizzle.session"
    private let service = "com.wizzle.app"

    // MARK: - Save session
    func saveSession(user: User, accessToken: String, refreshToken: String) {
        let session = SavedSession(user: user,
                                   accessToken: accessToken,
                                   refreshToken: refreshToken)
        if let data = try? JSONEncoder().encode(session) {
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

    // MARK: - Load session
    func loadSession() -> SavedSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let session = try? JSONDecoder().decode(SavedSession.self, from: data)
        else { return nil }
        return session
    }

    // MARK: - Clear session
    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
    }
    // MARK: - Token access helpers
    var accessToken: String? {
        get { loadSession()?.accessToken }
        set {
            guard let newToken = newValue else { return }
            if var session = loadSession() {
                session = SavedSession(
                    user: session.user,
                    accessToken: newToken,
                    refreshToken: session.refreshToken
                )
                if let data = try? JSONEncoder().encode(session) {
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
        }
    }

    var refreshToken: String? {
        get { loadSession()?.refreshToken }
        set {
            guard let newToken = newValue else { return }
            if var session = loadSession() {
                session = SavedSession(
                    user: session.user,
                    accessToken: session.accessToken,
                    refreshToken: newToken
                )
                if let data = try? JSONEncoder().encode(session) {
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
        }
    }
}

struct SavedSession: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
}

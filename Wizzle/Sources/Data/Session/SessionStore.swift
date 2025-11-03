import Foundation

// MARK: - SessionStore Protocol

protocol SessionStore: AnyObject { // 👈 make it class-bound
    var accessToken: String? { get set }
    var refreshToken: String? { get set }
    func clear()
}

// MARK: - Secure Implementation (with Keychain)

final class SecureSessionStore: SessionStore {
    private let keychain = SystemKeychainStore()
    private enum Keys {
        static let access = "access_token"
        static let refresh = "refresh_token"
    }

    var accessToken: String? {
        get { try? keychain.get(Keys.access).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let v = newValue {
                try? keychain.set(Data(v.utf8), for: Keys.access)
            } else {
                try? keychain.remove(Keys.access)
            }
        }
    }

    var refreshToken: String? {
        get { try? keychain.get(Keys.refresh).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let v = newValue {
                try? keychain.set(Data(v.utf8), for: Keys.refresh)
            } else {
                try? keychain.remove(Keys.refresh)
            }
        }
    }

    func clear() {
        try? keychain.remove(Keys.access)
        try? keychain.remove(Keys.refresh)
    }
}

// MARK: - In-memory variant (optional, for testing)

final class InMemorySessionStore: SessionStore {
    var accessToken: String?
    var refreshToken: String?
    func clear() { accessToken = nil; refreshToken = nil }
}

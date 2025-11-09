import Foundation
import Security

// MARK: - Protocol

///Simple protocol abstraction for secure Keychain storage.
protocol KeychainStore {
    func set(_ data: Data, for key: String) throws
    func get(_ key: String) throws -> Data?
    func remove(_ key: String) throws
}

// MARK: - Error

enum KeychainError: Error {
    case status(OSStatus)
}

// Human-readable Keychain error messages
extension KeychainError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .status(let code):
            return SecCopyErrorMessageString(code, nil) as String?
                ?? "Unknown Keychain error (\(code))"
        }
    }
}
// MARK: - Implementation

/// System Keychain wrapper that securely stores small items (tokens, credentials, identifiers) under the app's bundle ID.
final class SystemKeychainStore: KeychainStore {
    private let service = Bundle.main.bundleIdentifier ?? "wizzle.app"

    // MARK: Write
    func set(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Delete any existing entry first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        
        #if DEBUG
        print("🔐 Keychain[\(key)] \(data.count) bytes saved")
        #endif
    }
    
    // MARK: Read
    func get(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.status(status)
        }
        return data
    }

    // MARK: Remove
    func remove(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        #if DEBUG
        print("🗑️ Keychain[\(key)] removed")
        #endif
    }
}

// MARK: - String Convenience Helpers

extension KeychainStore {
    // Save a plain string value.
    func set(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else { return }
        try set(data, for: key)
    }
    
    // Retrieve a plain string value.
    func getString(_ key: String) throws -> String? {
        guard let data = try get(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

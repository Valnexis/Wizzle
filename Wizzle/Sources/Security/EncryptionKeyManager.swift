import Foundation
import CryptoKit
import Security

final class EncryptionKeyManager {
    static let shared = EncryptionKeyManager()
    private let keyTag = "com.wizzle.encryptionKey"
    
    private init() {}
    
    // MARK: - Public API
    
    func fetchOrCreateKey() throws -> SymmetricKey {
        if let existing = loadKey() { return existing }
        
        let newKey = SymmetricKey(size: .bits256)
        try saveKey(newKey)
#if DEBUG
        print("🔑 New encryption key generated and stored securely.")
#endif
        return newKey
    }
    
    func resetKey() throws {
        // Call this on full logout / app reset
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
#if DEBUG
        print("🧹 Encryption key deleted from keychain.")
#endif
    }
    
    // MARK: - Private helpers
    
    private func loadKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return SymmetricKey(data: data)
    }
    
    private func saveKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            // ❌ kSecAttrKeyTypeAES removed (not available on iOS)
        ]
        
        // Remove any existing key first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
    }
}

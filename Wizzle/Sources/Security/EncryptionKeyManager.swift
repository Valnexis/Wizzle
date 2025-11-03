import Foundation
import CryptoKit
import Security

final class EncryptionKeyManager {
    static let shared = EncryptionKeyManager()
    private let keyTag = "com.wizzle.encryptionKey"
    
    private init() {}
    
    func fetchOrCreateKey() throws -> SymmetricKey {
        if let existing = loadKey() { return existing }
        
        let newKey = SymmetricKey(size: .bits256)
        try saveKey(newKey)
        return newKey
    }
    
    private func loadKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }
    
    private func saveKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "KeySaveError", code: Int(status))}
    }
}

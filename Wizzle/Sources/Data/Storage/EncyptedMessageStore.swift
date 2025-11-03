import Foundation
import CryptoKit
import SQLite3

final class EncryptedMessageStore {
    static let shared = EncryptedMessageStore()
    private var db: OpaquePointer?
    
    private init() {
        open()
        createTable()
    }
    
    private func open() {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("messages.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Unable to open database at \(fileURL.path)")
        } else {
            print("Database opened at \(fileURL.path)")
        }
    }
    
    private func createTable() {
        let query = """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                conversationId TEXT,
                ciphertext BLOB
            );
            """
        sqlite3_exec(db, query, nil, nil, nil)
    }
    
    func save(_ message: Message) {
        do {
            let key = try EncryptionKeyManager.shared.fetchOrCreateKey()
            let plain = try JSONEncoder().encode(message)
            let sealed = try AES.GCM.seal(plain, using: key)
            let cipherData = sealed.combined!
            
            var stmt: OpaquePointer?
            let query = "INSERT OR REPLACE INTO messages (id, conversationId, ciphertext) VALUES (?,?,?);"
            sqlite3_prepare_v2(db, query, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, (message.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (message.conversationId as NSString).utf8String, -1, nil)
            cipherData.withUnsafeBytes {
                sqlite3_bind_blob(stmt, 3, $0.baseAddress, Int32($0.count), nil)
            }
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        } catch {
            print("Encryption save error:", error)
        }
    }
    
    func load(for conversationId: String) -> [Message] {
        var stmt: OpaquePointer?
        let query = "SELECT ciphertext FROM messages WHERE conversationId = ?;"
        sqlite3_prepare_v2(db, query, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, (conversationId as NSString).utf8String, -1, nil)
        
        var results: [Message] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let bytes = sqlite3_column_blob(stmt, 0)
            let size = sqlite3_column_bytes(stmt, 0)
            let data = Data(bytes: bytes!, count: Int(size))
            do {
                let key = try EncryptionKeyManager.shared.fetchOrCreateKey()
                let box = try AES.GCM.SealedBox(combined: data)
                let plain = try AES.GCM.open(box, using: key)
                let msg = try JSONDecoder().decode(Message.self, from: plain)
                results.append(msg)
            } catch {
                print("Decrypt error:", error)
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
}

import Foundation
import CryptoKit
import SQLite3

// MARK: - Secure local encrypted message storage
final class EncryptedMessageStore {
    static let shared = EncryptedMessageStore()
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.wizzle.messageStore")

    private init() {
        queue.sync {
            open()
            createTable()
        }
    }

    // MARK: - Open database
    private func open() {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("messages.sqlite")

        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ Unable to open database at \(fileURL.path)")
        } else {
            print("📁 Database opened at \(fileURL.path)")
        }
    }

    // MARK: - Table schema
    private func createTable() {
        let query = """
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            conversationId TEXT,
            ciphertext BLOB,
            createdAt TEXT DEFAULT CURRENT_TIMESTAMP
        );
        """
        if sqlite3_exec(db, query, nil, nil, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(db))
            print("❌ SQLite table creation failed:", err)
        }
    }

    // MARK: - Save encrypted message
    func save(_ message: Message) {
        queue.async {
            do {
                let key = try EncryptionKeyManager.shared.fetchOrCreateKey()
                let plain = try JSONEncoder().encode(message)
                let sealed = try AES.GCM.seal(plain, using: key)
                guard let cipherData = sealed.combined else {
                    print("❌ Missing AES.GCM combined data")
                    return
                }

                var stmt: OpaquePointer?
                let query = "INSERT OR REPLACE INTO messages (id, conversationId, ciphertext) VALUES (?,?,?);"
                if sqlite3_prepare_v2(self.db, query, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (message.id as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (message.conversationId as NSString).utf8String, -1, nil)
                    cipherData.withUnsafeBytes {
                        sqlite3_bind_blob(stmt, 3, $0.baseAddress, Int32($0.count), nil)
                    }
                    if sqlite3_step(stmt) != SQLITE_DONE {
                        let err = String(cString: sqlite3_errmsg(self.db))
                        print("❌ Insert failed:", err)
                    }
                }
                sqlite3_finalize(stmt)
            } catch {
                print("🔐 Encryption save error:", error)
            }
        }
    }

    // MARK: - Load and decrypt messages for a chat
    func load(for conversationId: String) -> [Message] {
        var results: [Message] = []

        queue.sync {
            var stmt: OpaquePointer?
            let query = "SELECT ciphertext FROM messages WHERE conversationId = ? ORDER BY createdAt ASC;"
            sqlite3_prepare_v2(db, query, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, (conversationId as NSString).utf8String, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let bytes = sqlite3_column_blob(stmt, 0) else { continue }
                let size = sqlite3_column_bytes(stmt, 0)
                let data = Data(bytes: bytes, count: Int(size))
                do {
                    let key = try EncryptionKeyManager.shared.fetchOrCreateKey()
                    let box = try AES.GCM.SealedBox(combined: data)
                    let plain = try AES.GCM.open(box, using: key)
                    let msg = try JSONDecoder().decode(Message.self, from: plain)
                    results.append(msg)
                } catch {
                    print("🔓 Decrypt error:", error)
                }
            }

            sqlite3_finalize(stmt)
        }

        return results
    }

    // MARK: - Maintenance
    func deleteAll() {
        queue.async {
            let query = "DELETE FROM messages;"
            if sqlite3_exec(self.db, query, nil, nil, nil) == SQLITE_OK {
                print("🧹 All messages wiped")
            }
        }
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    func delete(id: String) {
        let query = "DELETE FROM messages WHERE id = ?;"
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, query, -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }
}

import Foundation

// MARK: - Unread Message Count Cache
/// Stores and retrieves unread message counts per conversation.
/// Backed by `UserDefaults` for simplicity.
final class UnreadStore {
    static let shared = UnreadStore()
    private init() {}

    private let key = "wizzle.unreadCounts"
    private let queue = DispatchQueue(label: "com.wizzle.unreadStore", qos: .utility)

    // MARK: - Read
    func load() -> [String: Int] {
        queue.sync {
            (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
        }
    }

    // MARK: - Write
    private func save(_ data: [String: Int]) {
        queue.async {
            UserDefaults.standard.set(data, forKey: self.key)
            UserDefaults.standard.synchronize() // ensures write is flushed promptly
        }
    }

    // MARK: - Update single conversation
    func setUnreadCount(for conversationId: String, count: Int) {
        queue.async {
            var current = (UserDefaults.standard.dictionary(forKey: self.key) as? [String: Int]) ?? [:]
            current[conversationId] = count
            UserDefaults.standard.set(current, forKey: self.key)
        }
    }

    func incrementUnread(for conversationId: String) {
        queue.async {
            var current = (UserDefaults.standard.dictionary(forKey: self.key) as? [String: Int]) ?? [:]
            current[conversationId, default: 0] += 1
            UserDefaults.standard.set(current, forKey: self.key)
        }
    }

    func clearUnread(for conversationId: String) {
        queue.async {
            var current = (UserDefaults.standard.dictionary(forKey: self.key) as? [String: Int]) ?? [:]
            current[conversationId] = 0
            UserDefaults.standard.set(current, forKey: self.key)
        }
    }

    // MARK: - Utilities
    func clearAll() {
        queue.async {
            UserDefaults.standard.removeObject(forKey: self.key)
            print("🧹 Cleared all unread counts")
        }
    }
}

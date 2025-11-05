import Foundation

final class UnreadStore {
    static let shared = UnreadStore()
    private let key = "wizzle.unreadCounts"

    private init() {}

    // MARK: - Read
    func load() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    // MARK: - Write
    func save(_ data: [String: Int]) {
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Update single conversation
    func setUnreadCount(for conversationId: String, count: Int) {
        var current = load()
        current[conversationId] = count
        save(current)
    }

    func incrementUnread(for conversationId: String) {
        var current = load()
        current[conversationId, default: 0] += 1
        save(current)
    }

    func clearUnread(for conversationId: String) {
        var current = load()
        current[conversationId] = 0
        save(current)
    }
}

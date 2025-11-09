import Foundation

// MARK: - User
struct User: Codable, Identifiable, Hashable {
    let id: String
    let email: String
    let displayName: String
}

// MARK: - Conversation
struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let isGroup: Bool
    let title: String?
    let members: [String]
    let lastMessage: Message?
    let updatedAt: Date

    // Local only — not persisted to backend
    var unreadCount: Int? = 0

    // MARK: - Helpers
    var displayTitle: String {
        title ?? (isGroup ? "Group Chat" : "Direct Chat")
    }

    var lastMessagePreview: String {
        guard let message = lastMessage else { return "No messages yet" }
        switch message.kind {
        case .text(let text): return text
        case .file(let name, _, _, _): return "📎 \(name)"
        }
    }
}

// MARK: - MessageKind
enum MessageKind: Codable, Hashable {
    case text(String)
    case file(name: String, size: Int64, mime: String, url: URL?)

    private enum CodingKeys: String, CodingKey {
        case type, value, name, size, mime, url
    }

    // Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case "file":
            let name = try container.decode(String.self, forKey: .name)
            let size = try container.decode(Int64.self, forKey: .size)
            let mime = try container.decode(String.self, forKey: .mime)
            let url = try? container.decode(URL.self, forKey: .url)
            self = .file(name: name, size: size, mime: mime, url: url)
        default:
            self = .text("⚠️ Unknown message type")
        }
    }

    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let name, let size, let mime, let url):
            try container.encode("file", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(size, forKey: .size)
            try container.encode(mime, forKey: .mime)
            try container.encodeIfPresent(url, forKey: .url)
        }
    }
}

// MARK: - DeliveryStatus
enum DeliveryStatus: String, Codable, Hashable, CaseIterable {
    case pending, sent, delivered, read

    var icon: String {
        switch self {
        case .pending: return "⏳"
        case .sent: return "✓"
        case .delivered: return "✓✓"
        case .read: return "✓✓✓"
        }
    }
}

// MARK: - Message
struct Message: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let sentAt: Date
    let kind: MessageKind
    let status: DeliveryStatus

    // MARK: - Helpers
    func isOutgoing(for currentUserId: String) -> Bool {
        senderId == currentUserId
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: sentAt)
    }
}

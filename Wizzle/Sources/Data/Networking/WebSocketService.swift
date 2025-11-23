import Foundation
import Combine

// MARK: - Outgoing Message Wrapper
private struct OutgoingMessage: Codable {
    let type: String
    let message: Message
}

// MARK: - WebSocket Service
@MainActor
final class WebSocketService: ObservableObject {
    // MARK: - Published Properties
    @Published var incomingMessage: Message?
    @Published var deliveryUpdate: (String, DeliveryStatus)?
    @Published var chatUpdate: Conversation?
    @Published var deletedMessageId: String?

    // MARK: - Private Properties
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var currentUserId: String?

    // MARK: - Lifecycle
    func connect(currentUserId: String) {
        guard !isConnected else { return } // prevent multiple connections
        guard let url = URL(string: "ws://192.168.1.45:3001") else {
            print("❌ Invalid WebSocket URL")
            return
        }

        self.currentUserId = currentUserId
        self.session = URLSession(configuration: .default)
        self.task = session?.webSocketTask(with: url)
        task?.resume()

        // Identify user immediately
        let identify = ["type": "identify", "userId": currentUserId]
        if let data = try? JSONSerialization.data(withJSONObject: identify),
           let text = String(data: data, encoding: .utf8) {
            sendRaw(text)
        }

        isConnected = true
        print("✅ WebSocket connected for user:", currentUserId)
        listen()
    }

    func disconnect() {
        guard isConnected else { return }
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session = nil
        isConnected = false
        print("🧹 WebSocket disconnected")
    }

    // MARK: - Senders

    func sendMessage(_ message: Message) {
        let outgoing = OutgoingMessage(type: "message", message: message)
        guard let data = try? JSONEncoder().encode(outgoing),
              let text = String(data: data, encoding: .utf8) else {
            print("❌ Failed to encode outgoing message")
            return
        }
        sendRaw(text)
    }

    func sendDeliveryStatus(_ messageId: String, to receiver: String, status: DeliveryStatus) {
        let payload: [String: Any] = [
            "type": status.rawValue,
            "messageId": messageId,
            "to": receiver
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let text = String(data: data, encoding: .utf8) {
            sendRaw(text)
        }
    }

    // MARK: - Private Helpers

    private func sendRaw(_ text: String) {
        task?.send(.string(text)) { error in
            if let error = error {
                print("❌ WebSocket send error:", error.localizedDescription)
            }
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let err):
                print("❌ WebSocket receive error:", err)
                self.reconnectIfNeeded()

            case .success(let msg):
                if case let .string(text) = msg {
                    self.handleIncoming(text)
                }
                // Keep listening continuously
                self.listen()
            }
        }
    }
    

    private func handleIncoming(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "message":
            if let msgData = try? JSONSerialization.data(withJSONObject: json["message"] ?? [:]),
               let decoded = try? JSONDecoder().decode(Message.self, from: msgData) {
                incomingMessage = decoded
                print("💬 Received message:", decoded.id)
            }

        case "delivered":
            if let id = json["messageId"] as? String {
                deliveryUpdate = (id, .delivered)
                print("📬 Message \(id) delivered")
            }

        case "read":
            if let id = json["messageId"] as? String {
                deliveryUpdate = (id, .read)
                print("👁 Message \(id) read")
            }

        case "chat_update":
            if let convData = try? JSONSerialization.data(withJSONObject: json["conversation"] ?? [:]),
               let conv = try? JSONDecoder().decode(Conversation.self, from: convData) {
                chatUpdate = conv
                print("🔄 Chat updated:", conv.id)
            }
            
        case "delete_message":
            if let id = json["messageId"] as? String {
                deletedMessageId = id
                print("🗑 Deleted message arrived:", id)
            }

        default:
            print("⚠️ Unknown WS type:", type)
        }
    }

    private func reconnectIfNeeded() {
        guard let userId = currentUserId else { return }
        print("♻️ Attempting to reconnect WebSocket...")
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            connect(currentUserId: userId)
        }
    }
    
    func sendDeleteMessage(id: String) {
        let payload: [String: Any] = ["type": "delete_message", "messageId": id]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let text = String(data: data, encoding: .utf8) {
            task?.send(.string(text)) { _ in }
        }
    }
}

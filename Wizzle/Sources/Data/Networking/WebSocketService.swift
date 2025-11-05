import Foundation
import Combine

private struct OutgoingMessage: Codable {
    let type: String
    let message: Message
}

final class WebSocketService: ObservableObject {
    private var task: URLSessionWebSocketTask?
    @Published var incomingMessage: Message?
    @Published var deliveryUpdate: (String, DeliveryStatus)?
    @Published var chatUpdate: Conversation?

    func connect(currentUserId: String) {
        guard let url = URL(string: "ws://127.0.0.1:3001") else { return }
        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        task?.resume()
        
        let identify = ["type": "identify", "userId": currentUserId]
        if let data = try? JSONSerialization.data(withJSONObject: identify),
           let text = String(data: data, encoding: .utf8) {
            task?.send(.string(text)) { _ in }
        }
        
        listen()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
    }

    func sendMessage(_ message: Message) {
        let outgoing = OutgoingMessage(type: "message", message: message)
        guard let data = try? JSONEncoder().encode(outgoing),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { error in
            if let error = error {
                print("❌ WebSocket send error:", error)
            }
        }
    }
    
    func sendDeliveryStatus(_ messageId: String, to receiver: String, status: DeliveryStatus) {
        let payload: [String: Any] = ["type": status.rawValue, "messageId": messageId, "to": receiver]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let text = String(data: data, encoding: .utf8) {
            task?.send(.string(text)) { if let e = $0 { print("❌ send:", e) } }
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            switch result {
            case .failure(let err):
                print("❌ WS receive:", err)
            case .success(let msg):
                if case let .string(text) = msg,
                   let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json ["type"] as? String {
                    DispatchQueue.main.async{
                        switch type {
                        case "message":
                            if let msgData = try? JSONSerialization.data(withJSONObject: json["message"] ?? [:]),
                               let decoded = try? JSONDecoder().decode(Message.self, from: msgData) {
                                self?.incomingMessage = decoded
                            }
                        case "delivered":
                            if let id = json["messageId"] as? String {
                                self?.deliveryUpdate = (id, .delivered)
                            }
                        case "read":
                            if let id = json["messageId"] as? String {
                                self?.deliveryUpdate = (id, .read)
                            }
                        case "chat_update":
                            if let convData = try? JSONSerialization.data(withJSONObject: json["conversation"] ?? [:]),
                               let conv = try? JSONDecoder().decode(Conversation.self, from: data) {
                                self?.chatUpdate = conv
                            }
                        default: break
                        }
                    }
                }
                self?.listen()
            }
        }
    }
}

import Foundation
import Combine   // ✅ required for ObservableObject and @Published
import SwiftUI   // optional if you’re using it elsewhere

final class WebSocketService: ObservableObject {
    private var task: URLSessionWebSocketTask?
    @Published var incomingMessage: Message?

    func connect(currentUserId: String) {
        guard let url = URL(string: "ws://127.0.0.1:3001") else { return }
        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        task?.resume()
        listen()
        print("🔌 WebSocket connected for \(currentUserId)")
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        print("🔌 WebSocket disconnected")
    }

    func send(_ message: Message) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { error in
            if let error = error {
                print("❌ WebSocket send error:", error)
            }
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
                   let decoded = try? JSONDecoder().decode(Message.self, from: data) {
                    DispatchQueue.main.async {
                        self?.incomingMessage = decoded
                    }
                }
                self?.listen() // keep listening for next messages
            }
        }
    }
}

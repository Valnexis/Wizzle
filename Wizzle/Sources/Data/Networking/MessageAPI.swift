import Foundation

struct SendMessageRequest: Codable {
    let senderId: String
    let content: String
}

protocol MessageRepository {
    func fetchMessages(for conversationId: String) async throws -> [Message]
    func sendMessage(to conversationId: String, body: SendMessageRequest) async throws -> Message
}

final class RemoteMessageRepository: MessageRepository {
    private let api: APIClient
    init(api: APIClient = URLSessionAPI(baseURL: AppConfig.current.apiBaseURL)) {
        self.api = api
    }
    
    func fetchMessages(for conversationId: String) async throws -> [Message] {
        let req = APIRequest(path: "messages/\(conversationId)", method: .GET)
        return try await api.send(req)
    }
    
    func sendMessage(to conversationId: String, body: SendMessageRequest) async throws -> Message {
        let encoded = try JSONEncoder().encode(body)
        let req = APIRequest(path: "messages/\(conversationId)", method: .POST, body: encoded)
        return try await api.send(req)
    }
}

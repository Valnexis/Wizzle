import Foundation

// MARK: DTOs

/// Request body for sending a message to a conversation
struct SendMessageRequest: Codable {
    let senderId: String
    let content: String
}

// MARK: - Repository Protocol

protocol MessageRepository {
    func fetchMessages(for conversationId: String) async throws -> [Message]
    func sendMessage(to conversationId: String, body: SendMessageRequest) async throws -> Message
}

// MARK: - Remote Implementation

final class RemoteMessageRepository: MessageRepository {
    private let api: APIClient
    
    // MARK: Init
    init(api: APIClient = URLSessionAPI(baseURL: AppConfig.current.apiBaseURL)) {
        self.api = api
    }
    
    // MARK: - Methods
    
    func fetchMessages(for conversationId: String) async throws -> [Message] {
        let request = APIRequest(
            path: "messages/\(conversationId)",
            method: .GET,
            requiresAuth: true
        )
        return try await api.send(request)
    }
    
    func sendMessage(to conversationId: String, body: SendMessageRequest) async throws -> Message {
        // Uses `APIRequest(json:)` helper for consistency and safety
        let request = try APIRequest(
            path: "messages/\(conversationId)",
            method: .POST,
            json: body,
            requiresAuth: true
        )
        return try await api.send(request)
    }
}

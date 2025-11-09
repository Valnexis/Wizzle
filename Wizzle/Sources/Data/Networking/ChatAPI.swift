import Foundation

// MARK: - DTOs

/// Request body for creating a new chat or group conversation.
struct CreateChatRequest: Codable {
    let memberIds: [String]
    let title: String?
}

// MARK: - Repository Protocol

protocol ChatRepository {
    func listChats() async throws -> [Conversation]
    func createChat(_ req: CreateChatRequest) async throws -> Conversation
}

// MARK: - Remote Implementation

final class RemoteChatRepository: ChatRepository {
    static let shared = RemoteChatRepository()
    
    private let api: APIClient
    
    // MARK: Init
    init(api: APIClient = URLSessionAPI(baseURL: AppConfig.current.apiBaseURL)) {
        self.api = api
    }
    
    // MARK: - Methods
    
    func listChats() async throws -> [Conversation] {
        let request = APIRequest(path: "chats", method: .GET, requiresAuth: true)
        return try await api.send(request)
    }
    
    func createChat(_ req: CreateChatRequest) async throws -> Conversation {
        // Using new `APIRequest(json:)` helper for cleaner body creation
        let request = try APIRequest(path: "chats", method: .POST, json: req, requiresAuth: true)
        return try await api.send(request)
    }
}

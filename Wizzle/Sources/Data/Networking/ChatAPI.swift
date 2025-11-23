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
    func deleteChat(id: String) async throws
}

// MARK: - Remote Implementation

final class RemoteChatRepository: ChatRepository {
    static let shared = RemoteChatRepository()
    private let api: APIClient

    // MARK: - Init
    init(api: APIClient = URLSessionAPI(baseURL: AppConfig.current.apiBaseURL)) {
        self.api = api
    }

    // MARK: - Methods

    func listChats() async throws -> [Conversation] {
        let request = APIRequest(path: "chats", method: .GET, requiresAuth: true)
        return try await api.send(request)
    }

    func createChat(_ req: CreateChatRequest) async throws -> Conversation {
        let body = try JSONEncoder().encode(req)
        let request = APIRequest(path: "chats", method: .POST, body: body, requiresAuth: true)
        return try await api.send(request)
    }

    func deleteChat(id: String) async throws {
        let request = APIRequest(path: "chats/\(id)", method: .DELETE, requiresAuth: true)
        try await api.send(request)
    }
}

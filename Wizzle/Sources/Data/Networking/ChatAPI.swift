import Foundation

struct CreateChatRequest: Codable {
    let memberIds: [String]
    let title: String?
}

protocol ChatRepository {
    func listChats() async throws -> [Conversation]
    func createChat(_ req: CreateChatRequest) async throws -> Conversation
}

final class RemoteChatRepository: ChatRepository {
    static let shared = RemoteChatRepository()
    
    private let api: APIClient
    
    init(api: APIClient = URLSessionAPI(baseURL: AppConfig.current.apiBaseURL)) {
        self.api = api
    }
    func listChats() async throws -> [Conversation] {
        let req = APIRequest(path: "chats", method: .GET)
        return try await api.send(req)
    }
    func createChat(_ req: CreateChatRequest) async throws -> Conversation {
        let body = try JSONEncoder().encode(req)
        let r = APIRequest(path: "chats", method: .POST, body: body)
        return try await api.send(r)
    }
}

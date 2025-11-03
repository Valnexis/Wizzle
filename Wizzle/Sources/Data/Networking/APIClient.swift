import Foundation

// MARK: - Request & Response primitives

public struct APIRequest {
    public enum Method: String { case GET, POST, PUT, PATCH, DELETE }

    public var path: String
    public var method: Method
    public var headers: [String:String]
    public var body: Data?
    public var requiresAuth: Bool

    public init(
        path: String,
        method: Method = .GET,
        headers: [String:String] = [:],
        body: Data? = nil,
        requiresAuth: Bool = false
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

public struct EmptyResponse: Decodable {}

// MARK: - APIClient protocol

public protocol APIClient {
    var baseURL: URL { get }
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
    func send(_ request: APIRequest) async throws
}

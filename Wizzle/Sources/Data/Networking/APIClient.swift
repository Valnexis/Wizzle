import Foundation

// MARK: - Request & Response Primitives

public struct APIRequest: Sendable {
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

// MARK: - JSON Body Convenience

public extension APIRequest {
    /// Convenience initializer for Encodable bodies
    init<T>(
        path: String,
        method: Method,
        json body: T,
        headers: [String: String] = [:],
        requiresAuth: Bool = false
    ) throws where T: Encodable {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = try JSONEncoder().encode(body)
        self.requiresAuth = requiresAuth
    }
}

public struct EmptyResponse: Decodable, Sendable {}

// MARK: - APIClient Protocol

public protocol APIClient: Sendable {
    var baseURL: URL { get }
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
    func send(_ request: APIRequest) async throws
}

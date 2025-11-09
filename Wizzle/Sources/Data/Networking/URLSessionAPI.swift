import Foundation

// MARK: - Concrete Implementation of APIClient Using URLSession

final class URLSessionAPI: APIClient {
    // MARK: - Properties
    let baseURL: URL
    private let session: URLSession
    private var tokenProvider: () -> String? = { Container.shared.session.accessToken }

    // MARK: - JSON Encoder / Decoder
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            if let date = formatter.date(from: dateStr) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(dateStr)"
            )
        }
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    
    // MARK: - Init
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Public

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let (data, _) = try await data(for: request)
        do {
            return try URLSessionAPI.decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            if let json = String(data: data, encoding: .utf8) {
                print("❌ Decoding failed for \(T.self):\n\(json)")
            }
            #endif
            throw AppError.decoding
        }
    }

    func send(_ request: APIRequest) async throws {
        _ = try await data(for: request)
    }

    // MARK: - Core request performer
    private func data(for request: APIRequest) async throws -> (Data, URLResponse) {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(request.path))
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        // Default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Custom headers from request
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Auth header
        if request.requiresAuth, let token = tokenProvider() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        #if DEBUG
        debugPrint("➡️ \(request.method.rawValue) \(urlRequest.url?.absoluteString ?? "")")
        if let body = request.body, let json = String(data: body, encoding: .utf8) {
            debugPrint("📤 Body:", json)
        }
        #endif

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.unknown
        }
        
        #if DEBUG
        debugPrint("⬅️ HTTP \(http.statusCode) for \(request.path)")
        if let json = String(data: data, encoding: .utf8) {
            debugPrint("📥 Response:", json)
        }
        #endif

        switch http.statusCode {
        case 200..<300:
            return (data, response)
        case 401:
            throw AppError.unauthorized
        case 404:
            throw AppError.notFound
        default:
            throw AppError.network("HTTP \(http.statusCode)")
        }
    }
}

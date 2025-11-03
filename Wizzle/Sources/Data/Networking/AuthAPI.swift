import Foundation

// MARK: - DTOs

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let givenName: String
    let familyName: String
}

struct SignInRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
}

// MARK: - Repository Protocol

protocol AuthRepository {
    func signUp(_ req: SignUpRequest) async throws -> User
    func signIn(_ req: SignInRequest) async throws -> User
    func signOut() async
}

// MARK: - Implementation

final class RemoteAuthRepository: AuthRepository {
    private let api: APIClient
    private let session: SessionStore

    // ✅ Now async init to safely touch the Container actor
    init() async {
        // Hop into Container actor context
        self.api = await Container.shared.api
        self.session = await Container.shared.session
    }

    // MARK: - Methods

    func signUp(_ req: SignUpRequest) async throws -> User {
        let body = try JSONEncoder().encode(req)
        let request = APIRequest(
            path: "auth/signup",
            method: .POST,
            body: body
        )

        let response: AuthResponse = try await api.send(request)
        session.accessToken = response.accessToken
        session.refreshToken = response.refreshToken
        return response.user
    }

    func signIn(_ req: SignInRequest) async throws -> User {
        let body = try JSONEncoder().encode(req)
        let request = APIRequest(
            path: "auth/signin",
            method: .POST,
            body: body
        )

        let response: AuthResponse = try await api.send(request)
        session.accessToken = response.accessToken
        session.refreshToken = response.refreshToken
        return response.user
    }

    func signOut() async {
        session.clear()
    }
}

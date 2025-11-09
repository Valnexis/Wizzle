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

// MARK: - Remote Implementation

final class RemoteAuthRepository: AuthRepository {
    private let api: APIClient
    private let session: SessionStore

    // MARK: Init
    init() async {
        // Ensure container setup completed before use
        self.api = await Container.shared.api
        self.session = await Container.shared.session
    }

    // MARK: - Methods

    func signUp(_ req: SignUpRequest) async throws -> User {
        // Cleaner, uses new `APIRequest` JSON convenience
        let request = try APIRequest(path: "auth/signup", method: .POST, json: req)
        let response: AuthResponse = try await api.send(request)
        
        #if DEBUG
        print("📡 Auth request:", request.path)
        print("📥 Response:", response.user.displayName)
        #endif

        // Save tokens securely
        session.accessToken = response.accessToken
        session.refreshToken = response.refreshToken
        return response.user
    }

    func signIn(_ req: SignInRequest) async throws -> User {
        let request = try APIRequest(path: "auth/signin", method: .POST, json: req)
        let response: AuthResponse = try await api.send(request)
        
        #if DEBUG
        print("📡 Auth request:", request.path)
        print("📥 Response:", response.user.displayName)
        #endif
        
        session.accessToken = response.accessToken
        session.refreshToken = response.refreshToken
        return response.user
    }

    func signOut() async {
        session.clear()
    }
}

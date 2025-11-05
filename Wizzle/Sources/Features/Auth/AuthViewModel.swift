import Foundation
import Combine
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published state
    @Published var email = ""
    @Published var password = ""
    @Published var givenName = ""
    @Published var familyName = ""
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentUser: User?

    // MARK: - Dependencies
    private var repo: AuthRepository?

    // MARK: - Init
    init() {
        Task { [weak self] in
            self?.repo = await RemoteAuthRepository()
        }

        // ✅ Try to restore saved session on launch
        if let saved = SessionStore.shared.loadSession() {
            print("✅ Restored session for \(saved.user.displayName)")
            currentUser = saved.user
        }
    }

    // MARK: - Actions
    func signUp() async {
        guard let repo = repo else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await repo.signUp(
                .init(
                    email: email,
                    password: password,
                    givenName: givenName,
                    familyName: familyName
                )
            )
            if let u = currentUser {
                // ✅ Save session to Keychain
                SessionStore.shared.saveSession(
                    user: u,
                    accessToken: "access-\(u.id)",
                    refreshToken: "refresh-\(u.id)"
                )
                NotificationCenter.default.post(name: .didAuthUser, object: u)
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign up failed."
        }
    }

    func signIn() async {
        guard let repo = repo else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await repo.signIn(
                .init(email: email, password: password)
            )
            if let u = currentUser {
                // ✅ Save session to Keychain
                SessionStore.shared.saveSession(
                    user: u,
                    accessToken: "access-\(u.id)",
                    refreshToken: "refresh-\(u.id)"
                )
                NotificationCenter.default.post(name: .didAuthUser, object: u)
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign in failed."
        }
    }

    // MARK: - Logout
    func logout() {
        SessionStore.shared.clear()
        currentUser = nil
        print("🚪 Logged out and cleared session")
    }
}

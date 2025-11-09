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
            guard let self else { return }
            self.repo = await RemoteAuthRepository()
        }

        // ✅ Attempt to restore previously saved session
        if let saved = SessionStore.shared.loadSession() {
            print("✅ Restored session for \(saved.user.displayName)")
            currentUser = saved.user
        }
    }

    // MARK: - Sign Up
    func signUp() async {
        guard !email.isEmpty, !password.isEmpty, !givenName.isEmpty, !familyName.isEmpty else {
            error = "Please fill out all fields."
            return
        }
        guard let repo = repo else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let user = try await repo.signUp(
                .init(email: email, password: password, givenName: givenName, familyName: familyName)
            )
            currentUser = user
            persistSession(for: user)
            NotificationCenter.default.post(name: .didAuthUser, object: user)
        } catch {
            handleAuthError(error, context: "Sign up failed")
        }
    }

    // MARK: - Sign In
    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please enter your email and password."
            return
        }
        guard let repo = repo else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let user = try await repo.signIn(.init(email: email, password: password))
            currentUser = user
            persistSession(for: user)
            NotificationCenter.default.post(name: .didAuthUser, object: user)
        } catch {
            handleAuthError(error, context: "Sign in failed")
        }
    }

    // MARK: - Logout
    func logout() {
        SessionStore.shared.clear()
        currentUser = nil
        print("🚪 Logged out and cleared session")
    }

    // MARK: - Private Helpers

    private func persistSession(for user: User) {
        SessionStore.shared.saveSession(
            user: user,
            accessToken: "access-\(user.id)",
            refreshToken: "refresh-\(user.id)"
        )
    }

    private func handleAuthError(_ error: Error, context: String) {
        if let appError = error as? AppError {
            self.error = appError.errorDescription ?? context
        } else if let localized = error as? LocalizedError {
            self.error = localized.errorDescription ?? context
        } else {
            self.error = context
        }
        print("❌ \(context):", error.localizedDescription)
    }
}

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
        // Launch async setup so the view can appear instantly
        Task { [weak self] in
            self?.repo = await RemoteAuthRepository()
        }
    }

    // MARK: - Actions
    func signUp() async {
        guard let repo = repo else { return }   // ✅ ensure repo exists
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
                NotificationCenter.default.post(name: .didAuthUser, object: u)
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign up failed."
        }
    }

    func signIn() async {
        guard let repo = repo else { return }   // ✅ ensure repo exists
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await repo.signIn(
                .init(email: email, password: password)
            )
            if let u = currentUser {
                NotificationCenter.default.post(name: .didAuthUser, object: u)
            }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "Sign in failed."
        }
    }
}

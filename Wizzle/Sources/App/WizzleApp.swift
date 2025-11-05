import SwiftUI

@main
struct WizzleApp: App {
    init() {
        Task {
            await Container.shared.setup()
        }
    }
    @StateObject private var auth = AuthViewModel()
    @State private var isAuthenticated = false
    @State private var user: User?

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated, let user = user {
                    MainTabView(
                        currentUser: user,
                        onLogout: {
                            SessionStore.shared.clear()
                            self.user = nil
                            self.isAuthenticated = false
                        }
                    )
                } else {
                    AuthView()
                        .onReceive(NotificationCenter.default.publisher(for: .didAuthUser)) { note in
                            if let u = note.object as? User {
                                user = u
                                isAuthenticated = true
                            }
                        }
                        .task {
                            if let saved = SessionStore.shared.loadSession() {
                                user = saved.user
                                isAuthenticated = true
                                print("✅ Restored session for \(saved.user.displayName)")
                            }
                        }
                }
            }
        }
    }
}

extension Notification.Name {
    static let didAuthUser = Notification.Name("didAuthUser")
}

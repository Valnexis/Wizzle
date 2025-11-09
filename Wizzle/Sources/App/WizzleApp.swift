import SwiftUI

// MARK: - Entry Point
@main
struct WizzleApp: App {
    
    // MARK: - State
    @StateObject private var auth = AuthViewModel()
    @State private var isAuthenticated = false
    @State private var user: User?

    // MARK: - Init
    init() {
        // Initialize global dependecies once at launch
        Task {
            await Container.shared.setup()
            
            // MARK: - Server Health Check

            let url = AppConfig.current.healthCheckURL
            URLSession.shared.dataTask(with: url) { data, _, _ in
                print("Server status:", String(data: data ?? Data(), encoding: .utf8) ?? "nil")
            }.resume()
        }
    }
    
    // MARK: - Scene
    var body: some Scene {
        WindowGroup {
            Group {
                // When authenticated -> Show main app
                if isAuthenticated, let user = user {
                    MainTabView(
                        currentUser: user,
                        onLogout: {
                            // Clear session & return to login
                            SessionStore.shared.clear()
                            self.user = nil
                            self.isAuthenticated = false
                            print("Logged out")
                        }
                    )
                }
                
                // When not authenticated -> Show AuthView
                else {
                    AuthView()
                        // Listen for sign-in/up events
                        .onReceive(NotificationCenter.default.publisher(for: .didAuthUser)) { note in
                            if let u = note.object as? User {
                                user = u
                                isAuthenticated = true
                                print("✅ Authenticated as \(u.displayName)")
                            }
                        }
                        // Restore saved session on app launch
                        .task {
                            if let saved = SessionStore.shared.loadSession() {
                                user = saved.user
                                isAuthenticated = true
                                print("✅ Restored session for \(saved.user.displayName)")
                            } else {
                                print("⚠️ No saved session found")
                            }
                        }
                }
            }
            // MARK: Global Environment
            .environmentObject(auth)
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let didAuthUser = Notification.Name("didAuthUser")
}

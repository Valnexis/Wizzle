import SwiftUI

@main
struct WizzleApp: App {
    @State private var isAuthenticated = false
    @State private var user: User?

    init() {
        // Initialize the dependency container
        Task {
            await Container.shared.setup()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated, let user = user {
                    ChatsListView(currentUser: user)
                } else {
                    AuthView()
                        .onReceive(NotificationCenter.default.publisher(for: .didAuthUser)) { note in
                            if let u = note.object as? User {
                                user = u
                                isAuthenticated = true
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

import SwiftUI

struct MainTabView: View {
    let currentUser: User
    var onLogout: () -> Void

    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            // MARK: - Chats
            NavigationStack {
                ChatsListView(currentUser: currentUser)
                    .navigationTitle("Chats")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Chats", systemImage: selection == 0 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
            }
            .tag(0)

            // MARK: - Profile
            NavigationStack {
                ProfileView(currentUser: currentUser, onLogout: onLogout)
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Profile", systemImage: selection == 1 ? "person.crop.circle.fill" : "person.crop.circle")
            }
            .tag(1)
        }
        .tint(.blue)
        .onAppear {
            // Restore last used tab (optional)
            if let last = UserDefaults.standard.value(forKey: "lastTabSelection") as? Int {
                selection = last
            }
        }
        .onChange(of: selection) { newValue in
            UserDefaults.standard.set(newValue, forKey: "lastTabSelection")
        }
    }
}

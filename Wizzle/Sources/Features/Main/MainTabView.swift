import SwiftUI

struct MainTabView: View {
    let currentUser: User
    var onLogout: () -> Void

    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ChatsListView(currentUser: currentUser)
                    .navigationTitle("Chats")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Chats", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(0)

            NavigationStack {
                ProfileView(currentUser: currentUser, onLogout: onLogout)
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(1)
        }
    }
}

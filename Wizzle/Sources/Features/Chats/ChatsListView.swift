import SwiftUI
import Combine

struct ChatsListView: View {
    let currentUser: User
    @State private var conversations: [Conversation] = []
    @State private var showWelcome = false
    @State private var isRefreshing = false
    @StateObject private var socket = WebSocketService()

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack {
                // ✅ Welcome banner — shown only once
                if showWelcome {
                    WelcomeBanner {
                        withAnimation {
                            showWelcome = false
                            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                chatList
            }
            .navigationTitle("Chats")
            .onAppear {
                socket.connect(currentUserId: currentUser.id)

                // ✅ Show welcome only if not seen before
                if !UserDefaults.standard.bool(forKey: "hasSeenWelcome") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showWelcome = true
                    }
                }
            }
            .onDisappear {
                socket.disconnect()
            }
            .onReceive(socket.$chatUpdate.compactMap { $0 }) { updated in
                if let index = conversations.firstIndex(where: { $0.id == updated.id }) {
                    conversations[index] = updated
                } else {
                    conversations.append(updated)
                }

                // Update unread count
                if let index = conversations.firstIndex(where: { $0.id == updated.id }) {
                    var convo = conversations[index]
                    convo.unreadCount = (convo.unreadCount ?? 0) + 1
                    conversations[index] = convo
                    UnreadStore.shared.setUnreadCount(for: convo.id, count: convo.unreadCount ?? 0)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshChats() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    NavigationLink(destination: NewChatView(currentUser: currentUser)) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .task {
            await refreshChats()
            restoreUnreadCounts()
        }
    }

    // MARK: - Chat List
    @ViewBuilder
    private var chatList: some View {
        if conversations.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No conversations yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Start a new chat using the pencil icon above.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
        } else {
            List {
                ForEach(conversations) { c in
                    NavigationLink(destination: ChatView(conversation: c, currentUser: currentUser)) {
                        ChatRow(conversation: c)
                    }
                }
                .onDelete(perform: deleteChats) // Swipe-to-delete
            }
            .refreshable { await refreshChats() }
        }
    }
    
    // MARK: - Delete Chats
    private func deleteChats(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let conv = conversations[index]
                do {
                    try await RemoteChatRepository.shared.deleteChat(id: conv.id)
                    await MainActor.run {
                        conversations.remove(atOffsets: offsets)
                    }
                    print("🗑️ Deleted chat \(conv.id)")
                } catch {
                    print("❌ Delete chat failed:", error)
                }
            }
        }
    }

    // MARK: - Helpers
    private func refreshChats() async {
        do {
            let fetched = try await RemoteChatRepository.shared.listChats()
            await MainActor.run {
                self.conversations = fetched
            }
        } catch {
            print("❌ Failed to fetch chats:", error)
        }
    }

    private func restoreUnreadCounts() {
        let savedCounts = UnreadStore.shared.load()
        for (id, count) in savedCounts {
            if let index = conversations.firstIndex(where: { $0.id == id }) {
                conversations[index].unreadCount = count
            }
        }
    }
}

// MARK: - Row
private struct ChatRow: View {
    let conversation: Conversation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title ?? "Direct chat")
                    .font(.headline)
                if let m = conversation.lastMessage {
                    Text(preview(for: m))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let count = conversation.unreadCount, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .padding(6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }

    private func preview(for m: Message) -> String {
        switch m.kind {
        case .text(let s): return s
        case .file(let name, _, _, _): return "📎 \(name)"
        }
    }
}

// MARK: - Welcome Banner
private struct WelcomeBanner: View {
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Wizzle 👋")
                    .font(.headline)
                Text("Start chatting securely with your friends!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(radius: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

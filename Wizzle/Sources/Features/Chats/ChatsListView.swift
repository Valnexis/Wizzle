import SwiftUI
import Combine

struct ChatsListView: View {
    let currentUser: User
    @State private var conversations: [Conversation] = []
    @State private var isRefreshing = false
    @StateObject private var socket = WebSocketService()

    init(currentUser: User) {
        self.currentUser = currentUser
        _conversations = State(initialValue: [
            Conversation(
                id: "c1",
                isGroup: false,
                title: "Direct Chat",
                members: [currentUser.id, "user_b"],
                lastMessage: Message(
                    id: "m1",
                    conversationId: "c1",
                    senderId: "user_b",
                    sentAt: Date(),
                    kind: .text("Welcome to Wizzle 👋"),
                    status: .delivered
                ),
                updatedAt: Date()
            )
        ])
    }

    var body: some View {
        NavigationStack {
            chatList
                .navigationTitle("Chats")
                .onAppear {
                    socket.connect(currentUserId: currentUser.id)
                    
                }
                .onDisappear {
                    socket.disconnect()
                }
                .onReceive(socket.$chatUpdate.compactMap { $0 }) { updated in
                    if let index = conversations.firstIndex(where: { $0.id == updated.id}) {
                        conversations[index] = updated
                    } else {
                        conversations.append(updated)
                    }
                    if let index = conversations.firstIndex(where: { $0.id == updated.id }) {
                        var convo = conversations[index]
                        convo.unreadCount = (convo.unreadCount ?? 0) + 1
                        conversations[index] = convo
                        UnreadStore.shared.setUnreadCount(for: convo.id, count: convo.unreadCount ?? 0)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button{
                            Task { await refreshChats()}
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
            let savedCounts = UnreadStore.shared.load()
            for (id, count) in savedCounts {
                if let index = conversations.firstIndex(where: { $0.id == id }) {
                    conversations[index].unreadCount = count
                }
            }
        }
    }

    @ViewBuilder
    private var chatList: some View {
        List(conversations) { c in
            NavigationLink(destination: ChatView(conversation: c, currentUser: currentUser)) {
                ChatRow(conversation: c)
            }
        }
        .refreshable {
            await refreshChats()
        }
    }
    
    private func refreshChats() async {
        do {
            let fetched = try await RemoteChatRepository.shared.listChats()
            await MainActor.run {
                self.conversations = fetched
            }
        } catch {
            print("Failed to fetch chats:", error)
        }
    }
}
//MARK: - Row

private struct ChatRow: View {
    let conversation: Conversation

    var body: some View {
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

    private func preview(for m: Message) -> String {
        switch m.kind {
        case .text(let s): return s
        case .file(let name, _, _, _): return "📎 \(name)"
        }
    }
}

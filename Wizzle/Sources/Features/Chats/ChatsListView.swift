import SwiftUI
import Combine

struct ChatsListView: View {
    let currentUser: User
    @State private var conversations: [Conversation] = []
    @State private var isRefreshing = false

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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {}) {
                            Image(systemName: "square.and.pencil")
                        }
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
    }
}

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
    }

    private func preview(for m: Message) -> String {
        switch m.kind {
        case .text(let s): return s
        case .file(let name, _, _, _): return "📎 \(name)"
        }
    }
}

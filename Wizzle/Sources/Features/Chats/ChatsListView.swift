import SwiftUI
import Combine

struct ChatsListView: View {
    let currentUser: User
    @State private var conversations: [Conversation] = []

    // Initialize dummy chat data safely
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
            List(conversations) { c in
                NavigationLink(destination: ChatView(conversation: c, currentUser: currentUser)) {
                    VStack(alignment: .leading) {
                        Text(c.title ?? "Direct chat")
                            .font(.headline)
                        if let m = c.lastMessage {
                            Text(preview(for: m))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // new chat creation will go here later
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
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

// MARK: - ChatView (for preview/testing)

struct ChatView: View {
    let conversation: Conversation
    let currentUser: User
    @State private var input = ""
    @State private var messages: [Message] = []
    @StateObject private var socket = WebSocketService()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { msg in
                        HStack {
                            if msg.senderId == currentUser.id {
                                Spacer()
                                Text(text(for: msg))
                                    .padding(8)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            } else {
                                Text(text(for: msg))
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                TextField("Message", text: $input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Send") {
                    Task {
                        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

                        let repo = RemoteMessageRepository()
                        do {
                            let msg = try await repo.sendMessage(
                                to: conversation.id,
                                body: .init(senderId: currentUser.id, content: input)
                            )
                            messages.append(msg)
                            socket.send(msg)
                            input = ""
                        } catch {
                            print("❌ Send error:", error)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle(conversation.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        // 👇 each modifier chained directly on the view
        .onAppear {
            socket.connect(currentUserId: currentUser.id)
            Task {
                let repo = RemoteMessageRepository()
                do {
                    messages = try await repo.fetchMessages(for: conversation.id)
                } catch {
                    print("❌ Fetch error:", error)
                }
            }
        }
        .onDisappear {
            socket.disconnect()
        }
        .onReceive(socket.$incomingMessage.compactMap { $0 }) { msg in
            if msg.conversationId == conversation.id {
                messages.append(msg)
            }
        }
    }

    private func text(for message: Message) -> String {
        switch message.kind {
        case .text(let s): return s
        case .file(let name, _, _, _): return "📎 \(name)"
        }
    }
}

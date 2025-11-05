import SwiftUI
import Combine

struct ChatView: View {
    let conversation: Conversation
    let currentUser: User

    @State private var input = ""
    @State private var messages: [Message] = []
    @StateObject private var socket = WebSocketService()

    var body: some View {
        VStack(spacing: 0) {
            MessagesList(messages: messages, currentUser: currentUser)
            Composer(input: $input, sendAction: sendTapped)
                .padding()
                .background(.ultraThinMaterial)
        }
        .navigationTitle(conversation.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            socket.connect(currentUserId: currentUser.id)
            Task { await initialLoad() }
            // Clear unread for this conversation (don’t touch ChatsListView’s state here)
            UnreadStore.shared.clearUnread(for: conversation.id)
        }
        .onDisappear {
            socket.disconnect()
        }
        .onReceive(socket.$incomingMessage.compactMap { $0 }) { msg in
            // Append only messages for this conversation
            guard msg.conversationId == conversation.id else { return }
            messages.append(msg)

            // Acknowledge delivery to the sender
            socket.sendDeliveryStatus(msg.id, to: msg.senderId, status: .delivered)

            // If the message is not mine, also mark read (since I’m looking at the screen)
            if msg.senderId != currentUser.id {
                socket.sendDeliveryStatus(msg.id, to: msg.senderId, status: .read)
            }
        }
        .onReceive(socket.$deliveryUpdate.compactMap { $0 }) { (messageId, newStatus) in
            if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                var m = messages[idx]
                m = Message(
                    id: m.id,
                    conversationId: m.conversationId,
                    senderId: m.senderId,
                    sentAt: m.sentAt,
                    kind: m.kind,
                    status: newStatus
                )
                messages[idx] = m
            }
        }
    }

    // MARK: - Actions

    private func sendTapped() {
        Task {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            let repo = RemoteMessageRepository()
            do {
                let msg = try await repo.sendMessage(
                    to: conversation.id,
                    body: .init(senderId: currentUser.id, content: trimmed)
                )
                messages.append(msg)
                socket.sendMessage(msg)
                EncryptedMessageStore.shared.save(msg)
                input = ""
            } catch {
                print("❌ Send error:", error)
            }
        }
    }

    private func initialLoad() async {
        do {
            // Load cached first for instant UI
            let cached = EncryptedMessageStore.shared.load(for: conversation.id)
            await MainActor.run { self.messages = cached }

            // Then sync from server
            let repo = RemoteMessageRepository()
            let fresh = try await repo.fetchMessages(for: conversation.id)
            await MainActor.run { self.messages = fresh }

            // Mark any not-mine as read (I’m viewing the thread)
            for msg in fresh where msg.senderId != currentUser.id && msg.status != .read {
                socket.sendDeliveryStatus(msg.id, to: msg.senderId, status: .read)
            }
        } catch {
            print("❌ Fetch error:", error)
        }
    }
}

// MARK: - Subviews (small, compiler-friendly)

private struct MessagesList: View {
    let messages: [Message]
    let currentUser: User

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(messages, id: \.id) { msg in
                    MessageRow(message: msg, isMine: msg.senderId == currentUser.id)
                }
            }
            .padding()
        }
    }
}

private struct MessageRow: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer() }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(text(for: message))
                    .padding(8)
                    .background(isMine ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
                Text(statusIcon(for: message.status))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !isMine { Spacer() }
        }
        .animation(.default, value: message.id)
    }

    private func text(for message: Message) -> String {
        switch message.kind {
        case .text(let s): return s
        case .file(let name, _, _, _): return "📎 \(name)"
        }
    }

    private func statusIcon(for status: DeliveryStatus) -> String {
        switch status {
        case .pending: return "⏳"
        case .sent: return "✓"
        case .delivered: return "✓✓"
        case .read: return "✓✓✓"
        }
    }
}

private struct Composer: View {
    @Binding var input: String
    let sendAction: () -> Void

    var body: some View {
        HStack {
            TextField("Message", text: $input)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Send") { sendAction() }
                .buttonStyle(.borderedProminent)
        }
    }
}

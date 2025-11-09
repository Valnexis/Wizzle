import SwiftUI
import Combine

struct ChatView: View {
    let conversation: Conversation
    let currentUser: User

    @State private var input = ""
    @State private var messages: [Message] = []
    @StateObject private var socket = WebSocketService()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            MessagesList(messages: messages, currentUser: currentUser)
            Composer(input: $input, sendAction: sendTapped)
                .padding()
                .background(.ultraThinMaterial)
                .focused($isInputFocused)
        }
        .navigationTitle(conversation.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            socket.connect(currentUserId: currentUser.id)
            Task { await initialLoad() }
            UnreadStore.shared.clearUnread(for: conversation.id)
        }
        .onDisappear {
            socket.disconnect()
        }
        .onReceive(socket.$incomingMessage.compactMap { $0 }) { msg in
            guard msg.conversationId == conversation.id else { return }
            withAnimation(.spring()) { messages.append(msg) }

            socket.sendDeliveryStatus(msg.id, to: msg.senderId, status: .delivered)
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

    // MARK: - Send
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
                await MainActor.run {
                    withAnimation(.spring()) {
                        messages.append(msg)
                        socket.sendMessage(msg)
                        EncryptedMessageStore.shared.save(msg)
                        input = ""
                        isInputFocused = true
                    }
                }
            } catch {
                print("❌ Send error:", error)
            }
        }
    }

    // MARK: - Initial Load
    private func initialLoad() async {
        do {
            let cached = EncryptedMessageStore.shared.load(for: conversation.id)
            await MainActor.run { self.messages = cached }

            let repo = RemoteMessageRepository()
            let fresh = try await repo.fetchMessages(for: conversation.id)
            await MainActor.run { self.messages = fresh }

            for msg in fresh where msg.senderId != currentUser.id && msg.status != .read {
                socket.sendDeliveryStatus(msg.id, to: msg.senderId, status: .read)
            }
        } catch {
            print("❌ Fetch error:", error)
        }
    }
}

// MARK: - Subviews

private struct MessagesList: View {
    let messages: [Message]
    let currentUser: User

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages, id: \.id) { msg in
                        MessageRow(message: msg, isMine: msg.isOutgoing(for: currentUser.id))
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last?.id {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct MessageRow: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(text(for: message))
                    .padding(10)
                    .background(isMine ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                    .cornerRadius(12)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isMine ? .trailing : .leading)

                HStack(spacing: 4) {
                    Text(message.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if isMine {
                        Text(message.status.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 4)
        .transition(.move(edge: isMine ? .trailing : .leading).combined(with: .opacity))
    }

    private func text(for message: Message) -> String {
        switch message.kind {
        case .text(let s): return s
        case .file(let name, _, _, _): return "📎 \(name)"
        }
    }
}

private struct Composer: View {
    @Binding var input: String
    let sendAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button(action: sendAction) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .rotationEffect(.degrees(45))
            }
            .buttonStyle(.borderedProminent)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

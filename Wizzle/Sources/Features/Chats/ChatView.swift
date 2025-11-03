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
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { msg in
                        HStack {
                            if msg.senderId == currentUser.id {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(text(for: msg))
                                        .padding(8)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                    Text(statusIcon(for: msg.status))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(text(for: msg))
                                        .padding(8)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
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
                            socket.sendMessage(msg)
                            EncryptedMessageStore.shared.save(msg)
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
        .onAppear {
            socket.connect(currentUserId: currentUser.id)
            Task {
                let repo = RemoteMessageRepository()
                do {
                    messages = EncryptedMessageStore.shared.load(for: conversation.id)
                    messages = try await repo.fetchMessages(for: conversation.id)
                    for msg in messages where msg.senderId != currentUser.id && msg.status != .read {
                        socket.sendDeliveryStatus(msg.id, to: msg.senderId, status: .read)
                    }
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
                socket.sendDeliveryStatus(msg.id, to: msg.senderId, status: .delivered)
            }
        }
        .onReceive(socket.$deliveryUpdate.compactMap { $0 }) { (ud, newStatus) in
            if let index = messages.firstIndex(where: { $0.id == ud }) {
                messages[index] = Message(
                    id: messages[index].id,
                    conversationId: messages[index].conversationId,
                    senderId: messages[index].senderId,
                    sentAt: messages[index].sentAt,
                    kind: messages[index].kind,
                    status: newStatus
                )
            }
        }
    }

    // MARK: - Helpers
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

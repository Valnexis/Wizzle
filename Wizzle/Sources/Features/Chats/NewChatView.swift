import SwiftUI

struct NewChatView: View {
    let currentUser: User
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isRecipientFocused: Bool

    @State private var recipientId = ""
    @State private var title = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var navigateToChat: Conversation?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient ID") {
                    TextField("Enter user ID (e.g. a1b2c3d4)", text: $recipientId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isRecipientFocused)
                }

                Section("Chat Title (optional)") {
                    TextField("e.g. Study Group", text: $title)
                        .autocorrectionDisabled()
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .transition(.opacity)
                }

                if let success = successMessage {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.footnote)
                        .transition(.opacity)
                }

                Section {
                    Button {
                        Task { await createChat() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Label("Create Chat", systemImage: "plus.message.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreating || recipientId.isEmpty)
                }
            }
            .navigationTitle("New Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isRecipientFocused = true
                }
            }
            // NavigationLink to auto-open new conversation automatically
            .background(
                NavigationLink(
                    destination: destinationChatView,
                    isActive: Binding(
                        get: { navigateToChat != nil },
                        set: { if !$0 { navigateToChat = nil }}
                    ),
                    label: { EmptyView() }
              )
            )
        }
    }
    
    // MARK: - Destination
    @ViewBuilder
    private var destinationChatView: some View {
        if let chat = navigateToChat {
            ChatView(conversation: chat, currentUser: currentUser)
        }
    }

    // MARK: - Actions
    private func createChat() async {
        guard !recipientId.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a recipient ID."
            return
        }

        isCreating = true
        errorMessage = nil
        successMessage = nil

        do {
            // verify user exists — backend check
            let req = CreateChatRequest(
                memberIds: [currentUser.id, recipientId],
                title: title.isEmpty ? nil : title
            )
            let conv = try await RemoteChatRepository.shared.createChat(req)

            await MainActor.run {
                Haptic.play(.success)
                navigateToChat = conv // Automatically navigate to ChatView
            }
            print("✅ Created conversation:", conv)
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create chat: \(error.localizedDescription)"
                Haptic.play(.error)
            }
            print("❌ Create chat error:", error)
        }

        isCreating = false
    }
}

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
            // (Optional) verify user exists — backend check
            let req = CreateChatRequest(
                memberIds: [currentUser.id, recipientId],
                title: title.isEmpty ? nil : title
            )
            let conv = try await RemoteChatRepository.shared.createChat(req)

            await MainActor.run {
                successMessage = "✅ Chat created successfully!"
                // small delay before dismiss for UX clarity
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    dismiss()
                }
            }
            print("✅ Created conversation:", conv)
        } catch {
            print("❌ Create chat error:", error)
            await MainActor.run {
                errorMessage = "Failed to create chat. Please check the ID and try again."
            }
        }

        isCreating = false
    }
}

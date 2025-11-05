import SwiftUI

struct NewChatView: View {
    let currentUser: User
    @Environment(\.dismiss) private var dismiss
    @State private var recipientId = ""
    @State private var title = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient ID") {
                    TextField("Enter user ID", text: $recipientId)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                }

                Section("Chat Title (optional)") {
                    TextField("e.g. Study Group", text: $title)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                Section {
                    Button {
                        Task { await createChat() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Label("Create Chat", systemImage: "plus.message")
                        }
                    }
                    .disabled(recipientId.isEmpty || isCreating)
                }
            }
            .navigationTitle("New Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createChat() async {
        guard !recipientId.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isCreating = true
        errorMessage = nil

        do {
            let req = CreateChatRequest(memberIds: [currentUser.id, recipientId],
                                        title: title.isEmpty ? nil : title)
            let conv = try await RemoteChatRepository.shared.createChat(req)
            print("✅ Created conversation:", conv)
            await MainActor.run { dismiss() }
        } catch {
            print("❌ Create chat error:", error)
            await MainActor.run {
                errorMessage = "Failed to create chat. Please try again."
            }
        }

        isCreating = false
    }
}

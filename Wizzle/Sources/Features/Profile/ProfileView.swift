import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    let currentUser: User
    var onLogout: () -> Void

    @State private var copied = false
    @State private var showLogoutAlert = false

    var body: some View {
        List {
            // MARK: - Header
            Section {
                HStack(spacing: 16) {
                    InitialsAvatar(text: initials(from: currentUser.displayName))
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentUser.displayName)
                            .font(.title2).bold()
                        if !currentUser.email.isEmpty {
                            Text(currentUser.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // MARK: - Account Info
            Section("Account") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("User ID")
                            .font(.subheadline)
                        Text(currentUser.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.setValue(currentUser.id,
                                                      forPasteboardType: UTType.plainText.identifier)
                        withAnimation { copied = true }
                        Haptic.play(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .font(.subheadline)
                }
            }

            // MARK: - Actions
            Section("Actions") {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .alert("Log Out?", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                onLogout()
                Haptic.play(.warning)
            }
        } message: {
            Text("You will need to sign in again to access your messages.")
        }
    }

    // MARK: - Helpers
    private func initials(from fullName: String) -> String {
        let parts = fullName.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = (parts.dropFirst().first?.first).map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

struct InitialsAvatar: View {
    let text: String
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.3)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
            Text(text.isEmpty ? "?" : text)
                .font(.title2).bold()
                .foregroundStyle(.blue)
        }
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

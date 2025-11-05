import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    let currentUser: User
    var onLogout: () -> Void

    @State private var copied = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    InitialsAvatar(text: initials(from: currentUser.displayName))
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentUser.displayName)
                            .font(.title3).bold()
                        Text(currentUser.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Account") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("User ID")
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section {
                Button(role: .destructive) {
                    onLogout()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

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
            Circle().fill(Color.blue.opacity(0.2))
            Text(text.isEmpty ? "?" : text)
                .font(.title2).bold()
        }
        .clipShape(Circle())
    }
}

import SwiftUI

struct DeleteAccountSection: View {
    @Binding var isLoggedIn: Bool
    @Binding var loggedInEmail: String

    @State private var showConfirm = false
    @State private var busy = false
    @State private var status: String?
    @State private var error: String?

    var body: some View {
        Form {
            Section("Account") {
                Text("Signed in as \(loggedInEmail)")
                    .foregroundColor(.secondary)

                if let status {
                    Text(status).foregroundColor(.secondary)
                }
                if let error {
                    Text(error).foregroundColor(.red)
                }

                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Text("Delete Account")
                }
                .disabled(busy || loggedInEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .overlay {
            if busy {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("Delete your account?", isPresented: $showConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove your account and data.")
        }
    }

    @MainActor
    private func deleteAccount() async {
        status = "Deleting…"
        error = nil
        busy = true
        defer { busy = false }

        // performDelete(email:) returns (ok: Bool, detail: String)
        let res = await performDelete(email: loggedInEmail)

        if res.ok {
            status = "Account deleted."
            // Sign out locally
            isLoggedIn = false
            loggedInEmail = ""
        } else {
            status = nil
            // Surface exact server/HTTP detail to help diagnose
            error = res.detail.isEmpty ? "Delete failed. Please try again." : res.detail
        }
    }
}


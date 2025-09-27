import SwiftUI

struct MainView: View {
    @Binding var loggedInEmail: String

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome back,")
                .font(.title3)
                .foregroundColor(.secondary)

            Text(loggedInEmail.isEmpty ? "Signed-in user" : loggedInEmail)
                .font(.title2.bold())

            // Add any signed-in only content here
            // e.g., personalized items, synced reminders, etc.

            Spacer()
        }
        .padding()
    }
}

struct MainView_Previews: PreviewProvider {
    @State static var previewEmail = "test@example.com"
    static var previews: some View {
        NavigationStack { MainView(loggedInEmail: $previewEmail) }
    }
}


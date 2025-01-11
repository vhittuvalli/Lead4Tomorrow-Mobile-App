import SwiftUI

struct CreateAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?
    @State private var profiles: [String: [String: String]] = [:]

    private var profilesFilePath: String {
        return "/Users/varun/Desktop/Coding/Lead4Tomorrow-Mobile-App/backend/storage/profiles.json"
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Enter Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

            TextField("Enter Password", text: $password)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

            TextField("Confirm Password", text: $confirmPassword)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }

            Button(action: createAccount) {
                Text("Create Account")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(8)
            }

            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Text("Back to Login")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .onAppear(perform: loadProfiles)
        .navigationBarHidden(true) // Hides the navigation bar for this view
    }

    private func createAccount() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "All fields are required."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        if profiles[email] != nil {
            errorMessage = "An account with this email already exists."
            return
        }

        profiles[email] = ["password": password]
        saveProfiles()
        presentationMode.wrappedValue.dismiss()
    }

    private func loadProfiles() {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: profilesFilePath))
            profiles = try JSONDecoder().decode([String: [String: String]].self, from: data)
        } catch {
            profiles = [:]
            print("Error loading profiles: \(error)")
        }
    }

    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: URL(fileURLWithPath: profilesFilePath))
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }
}


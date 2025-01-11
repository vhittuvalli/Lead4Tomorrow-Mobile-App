import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var loggedInEmail: String
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var profiles: [String: [String: String]] = [:]

    private var profilesFilePath: String {
        return "/Users/varun/Desktop/Coding/Lead4Tomorrow-Mobile-App/backend/storage/profiles.json"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Log In")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextField("Enter Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

                SecureField("Enter Password", text: $password)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }

                Button(action: login) {
                    Text("Log In")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }

                NavigationLink(destination: CreateAccountView()) {
                    Text("Create Account")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .onAppear(perform: loadProfiles)
        }
    }

    private func login() {
        guard let profile = profiles[email],
              let savedPassword = profile["password"],
              savedPassword == password else {
            errorMessage = "Invalid email or password."
            return
        }
        loggedInEmail = email
        isLoggedIn = true
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
}


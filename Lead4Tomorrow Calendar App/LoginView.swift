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
        print("Starting login process...")
        print("Entered email: \(email)")
        print("Entered password: \(password)")

        for (profileName, profileData) in profiles {
            print("Checking profile: \(profileName)")
            if profileName == email {
                print("Username matches: \(profileName)")
                if let savedPassword = profileData["password"] {
                    print("Saved password for \(profileName): \(savedPassword)")
                    if savedPassword == password {
                        print("Password matches for \(profileName). Logging in...")
                        loggedInEmail = email
                        isLoggedIn = true
                        errorMessage = nil
                        return
                    } else {
                        print("Password does not match for \(profileName).")
                    }
                } else {
                    print("Password not found for \(profileName).")
                }
            } else {
                print("Username does not match: \(profileName)")
            }
        }

        errorMessage = "Invalid username or password."
        print("Login failed for email: \(email)")
    }

    private func loadProfiles() {
        print("Loading profiles from: \(profilesFilePath)")
        let url = URL(fileURLWithPath: profilesFilePath)
        do {
            let data = try Data(contentsOf: url)
            profiles = try JSONDecoder().decode([String: [String: String]].self, from: data)
            print("Successfully loaded profiles: \(profiles)")
        } catch {
            profiles = [:]
            print("Error loading profiles: \(error)")
        }
    }
}


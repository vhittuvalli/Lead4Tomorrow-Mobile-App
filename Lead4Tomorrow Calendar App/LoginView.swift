import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var loggedInEmail: String
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?

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
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }

        guard let url = URL(string: "https://lead4tomorrow-mobile-app.onrender.com/login") else {
            errorMessage = "Invalid backend URL."
            return
        }

        let loginData: [String: String] = [
            "email": email,
            "password": password
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(loginData)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let profile = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let _ = profile["email"] as? String else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid email or password."
                }
                return
            }

            DispatchQueue.main.async {
                loggedInEmail = email
                isLoggedIn = true
                errorMessage = nil
            }
        }.resume()
    }
}

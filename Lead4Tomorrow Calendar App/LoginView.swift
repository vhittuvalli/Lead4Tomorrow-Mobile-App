// FILE: LoginView.swift
import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var loggedInEmail: String
    let onCreateAccount: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Log In").font(.largeTitle).fontWeight(.bold)

            TextField("Enter Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

            SecureField("Enter Password", text: $password)
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

            if let errorMessage {
                Text(errorMessage).foregroundColor(.red).multilineTextAlignment(.center).padding(.top, 10)
            }

            Button(action: login) {
                Text("Log In")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .contentShape(Rectangle())

            Button(action: onCreateAccount) {
                Text("Create Account").foregroundColor(.blue)
            }
        }
        .padding()
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."; return
        }
        guard let url = URL(string: "\(APIConfig.baseURL)/login") else {
            errorMessage = "Invalid backend URL."; return
        }

        let payload: [String: String] = ["email": email, "password": password]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                DispatchQueue.main.async { errorMessage = "Network error: \(err.localizedDescription)" }
                return
            }
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                DispatchQueue.main.async { errorMessage = "Invalid email or password." }
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


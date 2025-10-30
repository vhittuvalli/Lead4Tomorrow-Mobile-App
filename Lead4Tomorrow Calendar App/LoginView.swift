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
            // Title
            Text("Log In")
                .font(AppTheme.heading(28, weight: .bold))
                .foregroundColor(AppTheme.green)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Email
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(AppTheme.body(14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("Enter Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(AppTheme.body(16))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.textSecondary.opacity(0.35), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                )
            }

            // Password
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(AppTheme.body(14, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 10) {
                    Image(systemName: "lock")
                        .foregroundColor(AppTheme.textSecondary)
                    SecureField("Enter Password", text: $password)
                        .font(AppTheme.body(16))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.textSecondary.opacity(0.35), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                )
            }

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTheme.body(14))
                    .foregroundColor(AppTheme.rose)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            // Primary action
            Button(action: login) {
                Text("Log In")
                    .font(AppTheme.body(16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.brightGreen)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
            }
            .contentShape(Rectangle())

            // Secondary action
            Button(action: onCreateAccount) {
                Text("Create Account")
                    .font(AppTheme.body(16, weight: .medium))
                    .foregroundColor(AppTheme.link)
            }
            .padding(.top, -6)

            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.backgroundSoft.ignoresSafeArea())
        .tint(AppTheme.accent)
    }

    // MARK: - Networking

    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        guard let url = URL(string: "\(APIConfig.baseURL)/login") else {
            errorMessage = "Invalid backend URL."
            return
        }

        let payload: [String: String] = ["email": email, "password": password]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: req) { _, resp, err in
            if let err = err {
                DispatchQueue.main.async {
                    errorMessage = "Network error: \(err.localizedDescription)"
                }
                return
            }
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
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


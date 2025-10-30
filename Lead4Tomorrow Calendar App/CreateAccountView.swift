// FILE: CreateAccountView.swift
import SwiftUI

struct CreateAccountView: View {
    let onBackToLogin: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Create Account")
                .font(AppTheme.heading(28, weight: .bold))
                .foregroundColor(AppTheme.green)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Email
            LabeledInput(
                label: "Email",
                systemImage: "envelope",
                content: {
                    TextField("Enter Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(AppTheme.body(16))
                }
            )

            // Password
            LabeledInput(
                label: "Password",
                systemImage: "lock",
                content: {
                    SecureField("Enter Password", text: $password)
                        .textContentType(.newPassword)
                        .font(AppTheme.body(16))
                }
            )

            // Confirm Password
            LabeledInput(
                label: "Confirm Password",
                systemImage: "lock.rotation",
                content: {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .font(AppTheme.body(16))
                }
            )

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTheme.body(14))
                    .foregroundColor(AppTheme.rose)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            // Primary action
            Button(action: createAccount) {
                Text("Create Account")
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
            Button(action: onBackToLogin) {
                Text("Back to Login")
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

    private func createAccount() {
        // Basic client-side validation
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "Email and both password fields are required."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard let url = URL(string: "\(APIConfig.baseURL)/create_profile") else {
            errorMessage = "Invalid backend URL."
            return
        }

        let payload: [String: String] = ["email": email, "password": password]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                DispatchQueue.main.async { errorMessage = "Network error: \(err.localizedDescription)" }
                return
            }
            guard let http = resp as? HTTPURLResponse else {
                DispatchQueue.main.async { errorMessage = "Invalid response from server." }
                return
            }
            if http.statusCode == 200 {
                DispatchQueue.main.async { onBackToLogin() }
            } else if let data = data,
                      let msg = try? JSONDecoder().decode([String: String].self, from: data) {
                DispatchQueue.main.async { errorMessage = msg["error"] ?? "Failed to create account." }
            } else {
                DispatchQueue.main.async { errorMessage = "Unknown error occurred." }
            }
        }.resume()
    }
}

// MARK: - Reusable Input Wrapper

private struct LabeledInput<Content: View>: View {
    let label: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppTheme.body(14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(AppTheme.textSecondary)
                content
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.textSecondary.opacity(0.35), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white))
            )
        }
    }
}


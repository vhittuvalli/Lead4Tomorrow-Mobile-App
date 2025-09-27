// FILE: SettingsRootView.swift
import SwiftUI

enum AuthMode { case login, create }

struct SettingsRootView: View {
    @Binding var isLoggedIn: Bool
    @Binding var loggedInEmail: String
    @State private var mode: AuthMode = .login

    var body: some View {
        Group {
            if isLoggedIn {
                // Show your real settings page when signed in
                VStack(spacing: 0) {
                    SettingsPageView(loggedInEmail: loggedInEmail)
                        .navigationTitle("Settings")

                    Divider().padding(.vertical, 8)

                    // Delete Account section (below)
                    DeleteAccountSection(isLoggedIn: $isLoggedIn, loggedInEmail: $loggedInEmail)
                }
            } else {
                VStack(spacing: 16) {
                    Picker("", selection: $mode) {
                        Text("Sign In").tag(AuthMode.login)
                        Text("Create Account").tag(AuthMode.create)
                    }
                    .pickerStyle(.segmented)

                    if mode == .login {
                        LoginView(
                            isLoggedIn: $isLoggedIn,
                            loggedInEmail: $loggedInEmail,
                            onCreateAccount: { mode = .create }
                        )
                    } else {
                        CreateAccountView(onBackToLogin: { mode = .login })
                    }

                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("Settings")
            }
        }
    }
}


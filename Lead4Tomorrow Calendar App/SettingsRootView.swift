import SwiftUI

enum AuthMode { case login, create }

struct SettingsRootView: View {
    @Binding var isLoggedIn: Bool
    @Binding var loggedInEmail: String
    @State private var mode: AuthMode = .login

    var body: some View {
        Group {
            if isLoggedIn {
                // ✅ Show your actual settings page when logged in
                SettingsPageView(loggedInEmail: loggedInEmail)
                    .navigationTitle("Settings")
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
                        CreateAccountView(
                            onBackToLogin: { mode = .login }
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("Settings")
            }
        }
    }
}


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
                SettingsPageView(isLoggedIn: $isLoggedIn, loggedInEmail: $loggedInEmail)
                    .navigationTitle("Settings")
            } else {
                VStack(spacing: 16) {
                    // Auth mode switch
                    Picker("", selection: $mode) {
                        Text("Sign In").tag(AuthMode.login)
                        Text("Create Account").tag(AuthMode.create)
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.accent)
                    .font(AppTheme.body(16))

                    if mode == .login {
                        LoginView(
                            isLoggedIn: $isLoggedIn,
                            loggedInEmail: $loggedInEmail,
                            onCreateAccount: { mode = .create }
                        )
                        .font(AppTheme.body(16))
                    } else {
                        CreateAccountView(onBackToLogin: { mode = .login })
                            .font(AppTheme.body(16))
                    }

                    Spacer(minLength: 0)
                }
                .padding()
                .background(AppTheme.backgroundSoft.ignoresSafeArea())
                .navigationTitle("Settings")
            }
        }
        // Global tweaks for this screen
        .font(AppTheme.body(16))
        .tint(AppTheme.accent)
        .scrollContentBackground(.hidden)
        .toolbarBackground(AppTheme.backgroundSoft, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}


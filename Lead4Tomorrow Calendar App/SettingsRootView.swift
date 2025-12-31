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
                VStack(spacing: 16) {

                    // 🔹 App description / About section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to Thriving Families")
                            .font(AppTheme.heading(18, weight: .semibold))
                            .foregroundColor(AppTheme.green)

                        Text("""
                        Developed by Lead for Tomorrow (L4T), Thriving Families supports nurturing families, thriving children, resilient communities, and healthy societies. This calendar app delivers a daily message of encouragement you can share with your children and family, grounded in L4T’s Family Hui positive parenting program.

                        You can choose to receive messages via email or push notifications.
                        """)
                        .font(AppTheme.body(14))
                        .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding()
                    .background(AppTheme.backgroundCard)
                    .cornerRadius(12)

                    // Existing settings page
                    SettingsPageView(
                        isLoggedIn: $isLoggedIn,
                        loggedInEmail: $loggedInEmail
                    )
                    .navigationTitle("Settings")
                }
                .padding()
                .background(AppTheme.backgroundSoft.ignoresSafeArea())

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


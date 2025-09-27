// FILE: ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var loggedInEmail = ""

    var body: some View {
        TabView {
            // PUBLIC Calendar tab
            NavigationStack {
                HomePageView()
                    .navigationTitle("Calendar")
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }

            // SETTINGS tab (Login/Create when signed out; SettingsPage + Delete when signed in)
            NavigationStack {
                SettingsRootView(
                    isLoggedIn: $isLoggedIn,
                    loggedInEmail: $loggedInEmail
                )
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}


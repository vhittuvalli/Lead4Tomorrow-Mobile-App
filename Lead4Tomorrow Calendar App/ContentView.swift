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
                // Or: Image(systemName: "calendar"); Text("Calendar")
            }

            // SETTINGS tab (shows login/create if signed out, settings page if signed in)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}


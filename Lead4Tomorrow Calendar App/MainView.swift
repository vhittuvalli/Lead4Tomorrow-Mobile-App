import SwiftUI

struct MainView: View {
    @Binding var loggedInEmail: String

    var body: some View {
        TabView {
            HomePageView(loggedInEmail: $loggedInEmail)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            SettingsPageView(loggedInEmail: loggedInEmail)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    @State static var previewEmail = "test@example.com"

    static var previews: some View {
        MainView(loggedInEmail: $previewEmail)
    }
}



import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var loggedInEmail = ""

    var body: some View {
        if isLoggedIn {
            MainView(loggedInEmail: $loggedInEmail)
        } else {
            LoginView(isLoggedIn: $isLoggedIn, loggedInEmail: $loggedInEmail)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


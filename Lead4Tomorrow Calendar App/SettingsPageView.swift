import SwiftUI

struct SettingsPageView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Settings")) {
                    Toggle("Enable Notifications", isOn: .constant(true))
                    Picker("Notification Time", selection: .constant("8:00 AM")) {
                        ForEach(["8:00 AM", "12:00 PM", "6:00 PM"], id: \.self) { time in
                            Text(time)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
    }
}


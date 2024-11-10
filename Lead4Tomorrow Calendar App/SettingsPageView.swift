import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    @State private var isNotificationsEnabled = false
    @State private var selectedTime = Date()
    @State private var isPickerExpanded = false
    @State private var theme: String = ""
    @State private var dailyMessage: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Settings")) {
                    Toggle("Enable Notifications", isOn: $isNotificationsEnabled)
                        .onChange(of: isNotificationsEnabled) { value in
                            if value {
                                requestNotificationAuthorization()
                                fetchEntries { theme, message in
                                    self.theme = theme
                                    self.dailyMessage = message
                                    scheduleNotification(at: selectedTime, theme: theme, message: message)
                                }
                            } else {
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                isPickerExpanded = false
                            }
                        }

                    if isNotificationsEnabled {
                        Button(action: {
                            withAnimation {
                                isPickerExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Text("Notification Time")
                                Spacer()
                                Text("\(formattedTime(selectedTime))")
                                    .foregroundColor(.gray)
                            }
                        }

                        if isPickerExpanded {
                            DatePicker(
                                "Select Time",
                                selection: $selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                            .onChange(of: selectedTime) { newDate in
                                fetchEntries { theme, message in
                                    self.theme = theme
                                    self.dailyMessage = message
                                    scheduleNotification(at: newDate, theme: theme, message: message)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Permission granted for notifications.")
            } else if let error = error {
                print("Error requesting notifications permission: \(error)")
            }
        }
    }

    private func scheduleNotification(at date: Date, theme: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = theme.isEmpty ? "Daily Reminder" : theme
        content.body = message.isEmpty ? "Don't forget to check your daily message!" : message
        content.sound = UNNotificationSound.default

        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
        dateComponents.second = 0  // Optional, to schedule on the minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    private func fetchEntries(completion: @escaping (String, String) -> Void) {
        guard let url = URL(string: "http://localhost:5000/get_entry") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let decodedResponse = try? JSONDecoder().decode([String: String].self, from: data) {
                    DispatchQueue.main.async {
                        let theme = decodedResponse["theme"] ?? "No theme available"
                        let message = decodedResponse["entry"] ?? "No entry available"
                        completion(theme, message)
                    }
                } else {
                    print("Failed to decode the response.")
                }
            } else if let error = error {
                print("Error fetching entries: \(error)")
            }
        }.resume()
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
    }
}


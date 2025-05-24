import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    let loggedInEmail: String

    @State private var phoneNumber = ""
    @State private var carrier = "att"
    @State private var preferredMethod = "Email"
    @State private var selectedTimezone = "America/New_York"
    @State private var notificationTime = Date()
    @State private var isNotificationsEnabled = false
    @State private var isProfileCollapsed = false

    private let carriers = ["att", "tmobile", "verizon", "sprint"]
    private let americanTimezones = [
        ("America/New_York", "Eastern Time (ET)"),
        ("America/Chicago", "Central Time (CT)"),
        ("America/Denver", "Mountain Time (MT)"),
        ("America/Phoenix", "Mountain Time - Arizona (MT)"),
        ("America/Los_Angeles", "Pacific Time (PT)"),
        ("America/Anchorage", "Alaska Time (AKT)"),
        ("Pacific/Honolulu", "Hawaii-Aleutian Time (HAT)")
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $isNotificationsEnabled)
                        .onChange(of: isNotificationsEnabled) { value in
                            if !value {
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                resetFields()
                            }
                        }

                    if isNotificationsEnabled {
                        if isProfileCollapsed {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notification Time: \(formattedTime(notificationTime))")
                                Text("Method: \(preferredMethod)")
                                Text("Phone: \(phoneNumber) (\(carrier.capitalized))")
                                Text("Timezone: \(selectedTimezone)")
                            }
                        } else {
                            Picker("Preferred Method", selection: $preferredMethod) {
                                Text("Email").tag("Email")
                                Text("Text").tag("Text")
                            }.pickerStyle(SegmentedPickerStyle())

                            DatePicker("Notification Time", selection: $notificationTime, displayedComponents: .hourAndMinute)

                            TextField("Enter Phone Number", text: $phoneNumber)
                                .keyboardType(.phonePad)

                            Picker("Select Timezone", selection: $selectedTimezone) {
                                ForEach(americanTimezones, id: \.0) { tz in
                                    Text(tz.1).tag(tz.0)
                                }
                            }
                        }

                        Button(action: saveProfile) {
                            Text(isProfileCollapsed ? "Edit Profile" : "Save Profile")
                                .foregroundColor(.white)
                                .padding()
                                .background(isProfileCollapsed ? Color.orange : Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: loadProfile)
        }
    }

    private func saveProfile() {
        guard let url = URL(string: "http://localhost:5000/update_profile") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": loggedInEmail,
            "time": formattedTime(notificationTime),
            "timezone": "\(utcOffset(for: selectedTimezone))",
            "phone": phoneNumber,
            "carrier": carrier,
            "method": preferredMethod.lowercased()
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if error == nil {
                DispatchQueue.main.async {
                    isProfileCollapsed = true
                }
            } else {
                print("Save error: \(error!)")
            }
        }.resume()
    }

    private func loadProfile() {
        guard let url = URL(string: "http://localhost:5000/get_profile?email=\(loggedInEmail)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let profile = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Failed to load profile")
                return
            }

            DispatchQueue.main.async {
                self.phoneNumber = profile["phone"] as? String ?? ""
                self.carrier = profile["carrier"] as? String ?? "att"
                self.preferredMethod = profile["method"] as? String ?? "Email"

                if let tzStr = profile["timezone"] as? String, let offset = Int(tzStr) {
                    self.selectedTimezone = americanTimezones.first(where: {
                        utcOffset(for: $0.0) == offset
                    })?.0 ?? "America/New_York"
                }

                self.notificationTime = parseTimeString(profile["time"] as? String ?? "09:00")
                self.isNotificationsEnabled = true
            }
        }.resume()
    }

    private func resetFields() {
        phoneNumber = ""
        carrier = "att"
        preferredMethod = "Email"
        selectedTimezone = "America/New_York"
        notificationTime = Date()
        isProfileCollapsed = false
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func parseTimeString(_ timeString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString) ?? Date()
    }

    private func utcOffset(for timeZoneIdentifier: String) -> Int {
        return (TimeZone(identifier: timeZoneIdentifier)?.secondsFromGMT() ?? 0) / 3600
    }
}


import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    let loggedInEmail: String

    @State private var profiles: [String: [String: Any]] = [:]
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var carrier: String = "att"
    @State private var preferredMethod: String = "Email"
    @State private var selectedTimezone: String = "America/New_York"
    @State private var notificationTime = Date()
    @State private var isNotificationsEnabled = false
    @State private var isProfileCollapsed = false

    private let profilesFilePath = "/Users/varun/Desktop/Coding/Lead4Tomorrow-Mobile-App/backend/storage/profiles.json"

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
                                Text("Email: \(email)")
                                Text("Phone: \(phoneNumber) (\(carrier.capitalized))")
                                Text("Timezone: \(selectedTimezone)")
                            }
                        } else {
                            Picker("Preferred Method", selection: $preferredMethod) {
                                Text("Email").tag("Email")
                                Text("Text").tag("Text")
                            }
                            .pickerStyle(SegmentedPickerStyle())

                            DatePicker(
                                "Notification Time",
                                selection: $notificationTime,
                                displayedComponents: .hourAndMinute
                            )

                            TextField("Enter Phone Number", text: $phoneNumber)
                                .keyboardType(.phonePad)

                            Picker("Select Timezone", selection: $selectedTimezone) {
                                ForEach(americanTimezones, id: \.0) { timeZone in
                                    Text(timeZone.1).tag(timeZone.0)
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
            .onAppear {
                loadProfile()
            }
        }
    }

    private func saveProfile() {
        guard var profile = profiles[loggedInEmail] else { return }

        profile["time"] = formattedTime(notificationTime)
        profile["timezone"] = String(utcOffset(for: selectedTimezone)) // Save timezone as a string
        profile["phone"] = phoneNumber
        profile["carrier"] = carrier
        profile["method"] = preferredMethod.lowercased()

        profiles[loggedInEmail] = profile
        saveProfiles(profiles)
        isProfileCollapsed.toggle()
    }

    private func resetFields() {
        phoneNumber = ""
        carrier = "att"
        preferredMethod = "Email"
        selectedTimezone = "America/New_York"
        notificationTime = Date()
        isProfileCollapsed = false
    }

    private func loadProfile() {
        profiles = loadProfiles() ?? [:]
        guard let profile = profiles[loggedInEmail] else { return }

        email = loggedInEmail
        phoneNumber = profile["phone"] as? String ?? ""
        carrier = profile["carrier"] as? String ?? "att"
        preferredMethod = profile["method"] as? String ?? "Email"

        // Parse timezone string
        if let timezoneOffsetString = profile["timezone"] as? String,
           let timezoneOffset = Int(timezoneOffsetString) {
            selectedTimezone = americanTimezones.first(where: { utcOffset(for: $0.0) == timezoneOffset })?.0 ?? "America/New_York"
        } else {
            selectedTimezone = "America/New_York"
        }

        notificationTime = parseTimeString(profile["time"] as? String ?? "09:00")
        isNotificationsEnabled = true
    }

    private func saveProfiles(_ profiles: [String: [String: Any]]) {
        let profilesURL = URL(fileURLWithPath: profilesFilePath)
        guard let data = try? JSONSerialization.data(withJSONObject: profiles, options: .prettyPrinted) else { return }
        try? data.write(to: profilesURL)
    }

    private func loadProfiles() -> [String: [String: Any]]? {
        let profilesURL = URL(fileURLWithPath: profilesFilePath)
        guard let data = try? Data(contentsOf: profilesURL),
              let profiles = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return nil }
        return profiles
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
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return 0 }
        return timeZone.secondsFromGMT() / 3600
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView(loggedInEmail: "test@example.com")
    }
}


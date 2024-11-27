import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    @State private var isNotificationsEnabled = false
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var carrier: String = "att" // Default carrier
    @State private var preferredMethod: String = "Email"
    @State private var selectedTimezone: String = "America/New_York" // Default to Eastern Time
    @State private var notificationTime = Date()

    @State private var isProfileCollapsed = false // Controls collapsibility

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
    private let profilesFileAbsolutePath = "/Users/varun/Desktop/Coding/Lead4Tomorrow-Mobile-App/backend/storage/profiles.json"

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
                            // Collapsed View of Profile Information
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notification Time: \(formattedTime(notificationTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Method: \(preferredMethod)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Email: \(email)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Phone: \(phoneNumber) (\(carrier.capitalized))")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("Timezone: UTC \(utcOffset(for: selectedTimezone))")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            // Editable Fields for Profile Information
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
                            .datePickerStyle(WheelDatePickerStyle())

                            TextField("Enter Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

                            TextField("Enter Phone Number", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

                            Picker("Select Timezone", selection: $selectedTimezone) {
                                ForEach(americanTimezones, id: \.0) { timeZone in
                                    Text(timeZone.1).tag(timeZone.0)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                        }

                        Button(action: saveProfile) {
                            Text(isProfileCollapsed ? "Edit Profile" : "Save Profile")
                                .foregroundColor(.white)
                                .padding()
                                .background(isProfileCollapsed ? Color.orange : Color.blue)
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Helper Methods

    private func saveProfile() {
        guard !email.isEmpty, !phoneNumber.isEmpty else {
            print("Email and phone number are required.")
            return
        }

        let profile: [String: Any] = [
            "time": formattedTime(notificationTime),
            "timezone": utcOffset(for: selectedTimezone), // Save UTC offset
            "phone": phoneNumber,
            "carrier": carrier,
            "email": email,
            "method": preferredMethod.lowercased()
        ]

        var profiles = loadProfiles()

        // Check for duplicates by email or phone number
        if let existingKey = profiles.first(where: {
            ($0.value["email"] as? String) == email || ($0.value["phone"] as? String) == phoneNumber
        })?.key {
            // Update existing profile
            profiles[existingKey] = profile
        } else {
            // Create new profile
            let newKey = String(profiles.count + 1)
            profiles[newKey] = profile
        }

        saveProfiles(profiles)
        isProfileCollapsed.toggle() // Collapse the fields
        print("Profile saved/updated successfully.")
    }

    private func resetFields() {
        isProfileCollapsed = false
        email = ""
        phoneNumber = ""
        carrier = "att"
        preferredMethod = "Email"
        selectedTimezone = "America/New_York" // Reset to default
        notificationTime = Date()
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func utcOffset(for timeZoneIdentifier: String) -> Int {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return 0 }
        return timeZone.secondsFromGMT() / 3600
    }

    private func displayName(for timeZoneIdentifier: String) -> String {
        guard let timeZone = americanTimezones.first(where: { $0.0 == timeZoneIdentifier }) else {
            return "Unknown Timezone"
        }
        return timeZone.1
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

    // MARK: - File Handling

    private func loadProfiles() -> [String: [String: Any]] {
        let profilesURL = getProfilesURL()
        guard let data = try? Data(contentsOf: profilesURL),
              let profiles = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return [:]
        }
        return profiles
    }

    private func saveProfiles(_ profiles: [String: [String: Any]]) {
        let profilesURL = getProfilesURL()
        guard let data = try? JSONSerialization.data(withJSONObject: profiles, options: .prettyPrinted) else {
            print("Failed to serialize profiles to JSON.")
            return
        }
        do {
            try data.write(to: profilesURL)
        } catch {
            print("Failed to write profiles to file: \(error)")
        }
    }

    private func getProfilesURL() -> URL {
        // Use the provided absolute path to `profiles.json`
        return URL(fileURLWithPath: profilesFileAbsolutePath)
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
    }
}


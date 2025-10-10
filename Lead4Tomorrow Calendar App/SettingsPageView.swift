// FILE: SettingsPageView.swift
import SwiftUI
import UserNotifications

struct SettingsPageView: View {
    @Binding var isLoggedIn: Bool
    @Binding var loggedInEmail: String

    @State private var phoneNumber = ""
    @State private var carrier = "att"
    @State private var preferredMethod = "Email"  // "Email" | "Text"
    @State private var selectedTimezone = "America/New_York"
    @State private var notificationTime = Date()
    @State private var isNotificationsEnabled = false
    @State private var isProfileCollapsed = false
    @State private var showSaveConfirmation = false

    // Inline delete UI
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

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
        Form {
            // ACCOUNT (compact; placed first so it’s visible without scrolling)
            Section(header: Text("Account")) {
                Text("Signed in as \(loggedInEmail)")
                    .font(.subheadline)

                Button("Sign Out") {
                    isLoggedIn = false
                    loggedInEmail = ""
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Delete Account")
                    }
                }
                .alert("Delete your account?",
                       isPresented: $showDeleteConfirm) {
                    Button("Delete", role: .destructive) { deleteAccount() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This permanently removes your profile and preferences.")
                }
            }

            // NOTIFICATIONS
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $isNotificationsEnabled)
                    .onChange(of: isNotificationsEnabled) { enabled in
                        if !enabled {
                            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            resetFields()
                        }
                    }

                if isNotificationsEnabled {
                    // Email vs Text
                    Picker("Delivery Method", selection: $preferredMethod) {
                        Text("Email").tag("Email")
                        Text("Text").tag("Text")
                    }
                    .pickerStyle(.segmented)

                    if isProfileCollapsed {
                        // Collapsed summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Method: \(preferredMethod)")
                            if preferredMethod == "Text" {
                                Text("Phone: \(phoneNumber) (\(carrier.capitalized))")
                            }
                            Text("Timezone: \(selectedTimezone)")
                            Text("Notification Time: \(formattedTime(notificationTime))")
                        }
                    } else {
                        // Editable fields
                        if preferredMethod == "Text" {
                            TextField("Enter Phone Number", text: $phoneNumber)
                                .keyboardType(.phonePad)

                            Picker("Carrier", selection: $carrier) {
                                ForEach(carriers, id: \.self) { c in
                                    Text(c.capitalized).tag(c)
                                }
                            }
                        }

                        Picker("Select Timezone", selection: $selectedTimezone) {
                            ForEach(americanTimezones, id: \.0) { tz in
                                Text(tz.1).tag(tz.0)
                            }
                        }

                        DatePicker(
                            "Notification Time",
                            selection: $notificationTime,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    if showSaveConfirmation {
                        Text("✅ Profile saved successfully!")
                            .foregroundColor(.green)
                            .font(.subheadline)
                            .padding(.vertical, 4)
                    }

                    Section {
                        Button(action: {
                            if isProfileCollapsed {
                                isProfileCollapsed = false
                            } else {
                                saveProfile()
                            }
                        }) {
                            Text(isProfileCollapsed ? "Edit Profile" : "Save Profile")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isProfileCollapsed ? Color.orange : Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadProfile)
    }

    // MARK: - Delete account (inline)
    private func deleteAccount() {
        guard !isDeleting else { return }
        isDeleting = true

        Task {
            defer { isDeleting = false }
            do {
                guard let base = URL(string: "https://lead4tomorrow-mobile-app.onrender.com") else { return }
                let endpoint = base.appendingPathComponent("delete_profile")
                let body = try JSONEncoder().encode(["email": loggedInEmail])

                // Try DELETE
                var del = URLRequest(url: endpoint)
                del.httpMethod = "DELETE"
                del.setValue("application/json", forHTTPHeaderField: "Content-Type")
                del.httpBody = body

                let (_, resp) = try await URLSession.shared.data(for: del)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    isLoggedIn = false
                    loggedInEmail = ""
                    return
                }

                // Fallback POST
                var post = URLRequest(url: endpoint)
                post.httpMethod = "POST"
                post.setValue("application/json", forHTTPHeaderField: "Content-Type")
                post.httpBody = body

                let (_, resp2) = try await URLSession.shared.data(for: post)
                if let http2 = resp2 as? HTTPURLResponse, http2.statusCode == 200 {
                    isLoggedIn = false
                    loggedInEmail = ""
                }
            } catch {
                // Optional: surface an error UI if you want.
                print("Delete error: \(error)")
            }
        }
    }

    // MARK: - Networking

    private func saveProfile() {
        guard let url = URL(string: "https://lead4tomorrow-mobile-app.onrender.com/update_profile") else { return }

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
            DispatchQueue.main.async {
                if error == nil {
                    isProfileCollapsed = true
                    showSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSaveConfirmation = false
                    }
                } else {
                    print("Save error: \(error!)")
                }
            }
        }.resume()
    }

    private func loadProfile() {
        guard let encodedEmail = loggedInEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lead4tomorrow-mobile-app.onrender.com/get_profile?email=\(encodedEmail)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let profile = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("Failed to load profile")
                return
            }

            DispatchQueue.main.async {
                self.phoneNumber = profile["phone"] as? String ?? ""
                self.carrier = profile["carrier"] as? String ?? "att"
                self.preferredMethod = (profile["method"] as? String)?.capitalized ?? "Email"

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

    // MARK: - Helpers

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
        if let d = formatter.date(from: timeString) {
            return d
        }
        // Fallback to 9am if the backend has empty/malformed time
        var comps = DateComponents()
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func utcOffset(for timeZoneIdentifier: String) -> Int {
        (TimeZone(identifier: timeZoneIdentifier)?.secondsFromGMT() ?? 0) / 3600
    }
}


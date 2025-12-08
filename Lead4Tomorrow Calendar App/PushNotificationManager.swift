//
//  PushNotificationManager.swift
//  Lead4Tomorrow Calendar App
//
//  Created by Varun Hittuvalli on 12/7/25.
//


// FILE: PushNotificationManager.swift
import SwiftUI
import UserNotifications
import UIKit

final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published var deviceTokenString: String? = nil

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Call this when the user enables notifications in SettingsPageView
    func registerForPushNotifications(for email: String) {
        // Save email so AppDelegate side can access it if needed
        UserDefaults.standard.set(email, forKey: "L4TLoggedInEmail")

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Push permission error: \(error)")
                return
            }

            guard granted else {
                print("Push permission not granted")
                return
            }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // Call this from AppDelegate when you get the token
    func updateDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceTokenString = token
        print("APNs Device Token: \(token)")

        // Send to backend
        sendDeviceTokenToBackend(token: token)
    }

    private func sendDeviceTokenToBackend(token: String) {
        guard let email = UserDefaults.standard.string(forKey: "L4TLoggedInEmail") else {
            print("No email stored for device token registration")
            return
        }

        guard let url = URL(string: "https://lead4tomorrow-mobile-app.onrender.com/register_device") else {
            print("Invalid register_device URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "device_token": token
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending device token: \(error)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("Device token sent, status: \(http.statusCode)")
            }
        }.resume()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    // Foreground notification handling if you want it
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

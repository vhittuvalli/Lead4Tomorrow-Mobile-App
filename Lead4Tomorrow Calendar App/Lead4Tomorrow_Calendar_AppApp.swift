//
//  Lead4Tomorrow_Calendar_AppApp.swift
//  Lead4Tomorrow Calendar App
//
//  Created by Varun Hittuvalli on 11/9/24.
//

import SwiftUI
import UserNotifications
import UIKit

@main
struct Lead4Tomorrow_Calendar_AppApp: App {
    // Bridge the old AppDelegate pattern into SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Handles push notification registration + callbacks
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Request permission for alerts / sound / badge
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
                return
            }

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("User denied notification permissions.")
            }
        }

        return true
    }

    // Called when APNs successfully returns a device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs device token: \(tokenString)")

        // Optionally persist locally so SettingsPageView / login flow can use it
        UserDefaults.standard.set(tokenString, forKey: "apns_device_token")

        // OPTIONAL: immediately send to your backend so it can use APNs
        sendDeviceTokenToBackend(tokenString)
    }

    // Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    // Handle notifications when app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner + sound even if app is open
        completionHandler([.banner, .sound, .badge])
    }

    // Handle user tapping a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // TODO: route the user to a specific screen if you want
        completionHandler()
    }

    // MARK: - Send device token to your backend

    private func sendDeviceTokenToBackend(_ token: String) {
        // Optional: include logged-in email if you want to associate token with a user
        let email = UserDefaults.standard.string(forKey: "loggedInEmail") ?? ""

        guard let url = URL(string: "https://lead4tomorrow-mobile-app.onrender.com/register_device_token") else {
            print("Invalid backend URL for device token registration")
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
                print("Error sending device token to backend: \(error)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("Device token backend response: \(http.statusCode)")
            }
        }.resume()
    }
}


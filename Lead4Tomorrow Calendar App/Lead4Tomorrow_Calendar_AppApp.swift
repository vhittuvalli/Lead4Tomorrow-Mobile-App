//
//  Lead4Tomorrow_Calendar_AppApp.swift
//  Lead4Tomorrow Calendar App
//
//  Created by Varun Hittuvalli on 11/9/24.
//

import SwiftUI
import UserNotifications
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
                return
            }

            if granted {
                print("✓ Notification permission granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("✗ Notification permission not granted.")
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("✓ APNs device token: \(tokenString)")
        UserDefaults.standard.set(tokenString, forKey: "apnsDeviceToken")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("✗ Failed to register for remote notifications: \(error)")
    }

    // IMPORTANT: This makes notifications show in notification center and stay in history
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        // .list ensures it appears in notification center history
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    // Handle when user taps the notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        
        let content = response.notification.request.content
        
        print("📱 User tapped notification!")
        print("   Title: \(content.title)")
        print("   Body: \(content.body)")
        
        // TODO: Navigate to a specific screen here if needed
        // For example, you could show the calendar entry view
        // NotificationCenter.default.post(name: NSNotification.Name("ShowCalendarEntry"), object: nil)
        
        completionHandler()
    }
}

@main
struct Lead4Tomorrow_Calendar_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

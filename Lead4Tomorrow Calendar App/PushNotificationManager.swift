// ============================================================
// FILE 2: PushNotificationManager.swift
// ============================================================

//
//  PushNotificationManager.swift
//  Lead4Tomorrow Calendar App
//
//  Created by Varun Hittuvalli on 12/7/25.
//

import SwiftUI
import UserNotifications
import UIKit

final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var deviceTokenString: String? = nil
    
    private override init() {
        super.init()
        // Delegate is set in AppDelegate, so we don't set it here
    }
    
    // Call this when the user enables notifications in SettingsPageView
    func registerForPushNotifications(for email: String) {
        // Save email so AppDelegate side can access it if needed
        UserDefaults.standard.set(email, forKey: "L4TLoggedInEmail")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Push permission error: \(error)")
                return
            }
            guard granted else {
                print("❌ Push permission not granted")
                return
            }
            
            print("✅ Push permission granted")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // Call this from AppDelegate when you get the token
    func updateDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceTokenString = token
        print("✅ APNs Device Token: \(token)")
        
        // Send to backend
        sendDeviceTokenToBackend(token: token)
    }
    
    private func sendDeviceTokenToBackend(token: String) {
        guard let email = UserDefaults.standard.string(forKey: "L4TLoggedInEmail") else {
            print("❌ No email stored for device token registration")
            return
        }
        
        guard let url = URL(string: "\(APIConfig.baseURL)/register_device") else {
            print("❌ Invalid register_device URL")
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
        
        print("📤 Sending device token to backend for email: \(email)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error sending device token: \(error)")
                return
            }
            
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    print("✅ Device token sent successfully, status: \(http.statusCode)")
                } else {
                    print("⚠️ Device token sent, but unexpected status: \(http.statusCode)")
                }
            }
        }.resume()
    }
}

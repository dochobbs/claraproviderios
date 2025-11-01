import Foundation
import UserNotifications
import UIKit

class ProviderPushNotificationManager: NSObject {
    static let shared = ProviderPushNotificationManager()
    
    private override init() {
        super.init()
    }
    
    // Request permission and register for push notifications
    func registerForPushNotifications() {
        // Check current authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // First time - request with comprehensive options
                self.requestInitialPermission()
            case .denied:
                // User previously denied - we could show an explanation
                print("Push notifications were previously denied")
            case .authorized, .provisional:
                // Already authorized - just register for remote notifications
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .ephemeral:
                // App clips - limited permissions
                print("Ephemeral notification permissions")
            @unknown default:
                print("Unknown notification authorization status")
            }
        }
    }
    
    private func requestInitialPermission() {
        // Request with alert, sound, and badge
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Provider push notification permission granted: \(granted)")
            
            if let error = error {
                print("Push notification error: \(error)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // Handle successful registration
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Provider device token: \(tokenString)")
        
        // Store token in UserDefaults
        UserDefaults.standard.set(tokenString, forKey: "providerPushDeviceToken")
        
        // Note: Provider tokens might be stored differently than patient tokens
        // For MVP, we'll just store it locally
        // Future: Could store in a providers table in Supabase
    }
    
    // Handle registration failure
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Provider failed to register for push notifications: \(error)")
    }
    
    // Update badge count based on pending reviews
    func updateBadgeCount(pendingCount: Int) {
        DispatchQueue.main.async {
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(pendingCount)
            } else {
                UIApplication.shared.applicationIconBadgeNumber = pendingCount
            }
        }
    }
    
    // Handle notification when app is in foreground
    func handleNotification(userInfo: [AnyHashable: Any]) {
        // Check if this is a provider-specific notification
        if let conversationIdString = userInfo["conversationId"] as? String,
           let conversationId = UUID(uuidString: conversationIdString) {
            // Post notification to open conversation
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenConversationFromPush"),
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }
    }
    
    // Schedule local notification for testing
    func scheduleTestNotification(title: String, body: String, conversationId: UUID?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        if let conversationId = conversationId {
            content.userInfo = ["conversationId": conversationId.uuidString]
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Test notification scheduled")
            }
        }
    }
    
    // Get current device token
    func getDeviceToken() -> String? {
        return UserDefaults.standard.string(forKey: "providerPushDeviceToken")
    }
}

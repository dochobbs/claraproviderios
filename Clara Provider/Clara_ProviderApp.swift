//
//  Clara_ProviderApp.swift
//  Clara Provider
//
//  Created by Michael Hobbs on 10/22/25.
//

import SwiftUI
import UserNotifications
import UIKit
import os.log

@main
struct Clara_ProviderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProviderConversationStore()
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Verify fonts are loaded on app launch
        Font.debugListAvailableFonts()

        // Set search bar appearance globally (backup - also set in AppDelegate)
        let searchBarAppearance = UISearchBar.appearance()
        searchBarAppearance.searchTextField.backgroundColor = .white
        searchBarAppearance.searchTextField.textColor = .black
        if #available(iOS 13.0, *) {
            searchBarAppearance.searchTextField.layer.backgroundColor = UIColor.white.cgColor
        }
        searchBarAppearance.backgroundColor = .clear
        searchBarAppearance.barTintColor = .clear

        // Also set UITextField appearance for search fields
        let textFieldAppearance = UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        textFieldAppearance.backgroundColor = .white
        textFieldAppearance.textColor = .black
        if #available(iOS 13.0, *) {
            textFieldAppearance.layer.backgroundColor = UIColor.white.cgColor
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.state {
                case .unlocked:
                    ContentView()
                        .environmentObject(store)
                        .background(Color.paperBackground.ignoresSafeArea())
                        .onAppear {
                            Task {
                                await store.loadReviewRequests()
                            }
                        }
                case .needsSetup, .locked:
                    AuthenticationView()
                }
            }
            .environmentObject(authManager)
        }
        .onChange(of: authManager.state) { _, newState in
            os_log("[Clara_ProviderApp] Auth state changed to: %{public}s", log: .default, type: .info, String(describing: newState))
            if newState != .unlocked {
                // Clear data when locking the app
                os_log("[Clara_ProviderApp] App locked, clearing cached data", log: .default, type: .info)
                store.reviewRequests = []
                store.selectedConversationId = nil
            } else {
                // Force refresh data when unlocking
                // Use forceRefreshReviewRequests to bypass the 30-second debounce
                // so fresh data loads immediately after unlock
                os_log("[Clara_ProviderApp] App unlocked, triggering force refresh", log: .default, type: .info)
                Task {
                    os_log("[Clara_ProviderApp] Calling forceRefreshReviewRequests", log: .default, type: .info)
                    await store.forceRefreshReviewRequests()
                    os_log("[Clara_ProviderApp] forceRefreshReviewRequests completed", log: .default, type: .info)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                authManager.lock()
            }
        }
    }
}

// MARK: - AppDelegate for Push Notifications
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register for push notifications
        ProviderPushNotificationManager.shared.registerForPushNotifications()
        
        // Configure search bar appearance
        configureSearchBarAppearance()
        
        return true
    }
    
    private func configureSearchBarAppearance() {
        let appearance = UISearchBar.appearance()
        
        // Set search text field background to white
        appearance.searchTextField.backgroundColor = .white
        appearance.searchTextField.textColor = .black
        
        // Clear the search bar background
        appearance.backgroundColor = .clear
        appearance.barTintColor = .clear
        
        // Set the search bar background when searching
        if #available(iOS 13.0, *) {
            appearance.searchTextField.layer.backgroundColor = UIColor.white.cgColor
        }
        
        // Also configure UITextField appearance when in search bars
        let textFieldAppearance = UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        textFieldAppearance.backgroundColor = .white
        textFieldAppearance.textColor = .black
        if #available(iOS 13.0, *) {
            textFieldAppearance.layer.backgroundColor = UIColor.white.cgColor
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        ProviderPushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        ProviderPushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // Handle user tapping on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        ProviderPushNotificationManager.shared.handleNotification(userInfo: userInfo)
        completionHandler()
    }
}

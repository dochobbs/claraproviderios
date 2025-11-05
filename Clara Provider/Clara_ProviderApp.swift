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
import CoreText

@main
struct Clara_ProviderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProviderConversationStore()
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // CRITICAL FIX: Dynamically load fonts from bundle using CTFontManagerRegisterFontsForURL
        // This works better than Info.plist for fonts with metadata issues
        loadCustomFonts()

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

    /// Load custom fonts from bundle using CTFontManager
    /// This is more reliable than Info.plist for fonts with metadata issues
    private func loadCustomFonts() {
        let fontNames = [
            "RethinkSans-Regular.ttf",
            "RethinkSans-Bold.ttf",
            "RethinkSans-Italic.ttf",
            "RethinkSans-BoldItalic.ttf",
            "RethinkSans-Medium.ttf",
            "RethinkSans-MediumItalic.ttf",
            "RethinkSans-SemiBold.ttf",
            "RethinkSans-SemiBoldItalic.ttf",
            "RethinkSans-ExtraBold.ttf",
            "RethinkSans-ExtraBoldItalic.ttf"
        ]

        for fontName in fontNames {
            // Get path to font in app bundle
            guard let fontPath = Bundle.main.path(forResource: fontName, ofType: nil) else {
                os_log("[Clara_ProviderApp] Font file not found in bundle: %{public}s", log: .default, type: .error, fontName)
                continue
            }

            let fontURL = URL(fileURLWithPath: fontPath)

            // Register font with system using CTFontManager
            // This allows iOS to find the font even if metadata is non-standard
            var error: Unmanaged<CFError>?
            let registered = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)

            if registered {
                os_log("[Clara_ProviderApp] ✅ Successfully registered font: %{public}s", log: .default, type: .info, fontName)
            } else {
                if let error = error?.takeRetainedValue() {
                    os_log("[Clara_ProviderApp] ❌ Failed to register font %{public}s: %{public}s", log: .default, type: .error, fontName, CFErrorCopyDescription(error) as String)
                } else {
                    os_log("[Clara_ProviderApp] ❌ Failed to register font: %{public}s", log: .default, type: .error, fontName)
                }
            }
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
                // FIX: Don't clear cached data when app backgrounds
                // User may return within 12 hours and we want to show cached count
                // Data is only cleared when session actually expires (12 hour timeout)
                // Just stop auto-refresh timer to save battery
                os_log("[Clara_ProviderApp] App locked, stopping auto-refresh", log: .default, type: .info)
                store.stopAutoRefresh()
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

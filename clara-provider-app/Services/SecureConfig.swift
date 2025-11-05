import Foundation
import Security

/// Secure configuration manager for sensitive credentials
/// Stores API keys and secrets in Keychain instead of source code
class SecureConfig {
    static let shared = SecureConfig()

    private let keychainService = "com.vital.claraprovider"

    // MARK: - Supabase Configuration

    /// Supabase project URL - can be stored in config or environment
    /// In production, this should come from a secure config file or environment variable
    let supabaseProjectURL = "https://dmfsaoawhomuxabhdubw.supabase.co"

    /// Get Supabase API key from Keychain
    /// If not found, returns nil (app should handle gracefully)
    var supabaseAPIKey: String? {
        get {
            return retrieveFromKeychain(account: "supabase_api_key")
        }
        set {
            if let newValue = newValue {
                storeInKeychain(newValue, account: "supabase_api_key")
            } else {
                deleteFromKeychain(account: "supabase_api_key")
            }
        }
    }

    /// Store initial Supabase API key (should only be called during app setup/deployment)
    /// In production, this would be loaded from a secure configuration source
    func initializeSupabaseKey(_ key: String) {
        // Always set the key - this ensures it's in Keychain even if retrieval fails
        // (Keychain retrieval might fail on first app launch due to timing)
        supabaseAPIKey = key
        os_log("[SecureConfig] Supabase API key initialized in Keychain", log: .default, type: .info)
    }

    // MARK: - Keychain Operations

    /// Store a string value in Keychain
    /// - Parameters:
    ///   - value: The string to store
    ///   - account: The account identifier for retrieval
    private func storeInKeychain(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else {
            os_log("[SecureConfig] Failed to encode value for storage (account: %{public}s)", log: .default, type: .error, account)
            return
        }

        os_log("[SecureConfig] Storing value in Keychain (account: %{public}s, length: %d)", log: .default, type: .debug, account, data.count)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing entry first
        let deleteStatus = SecItemDelete(query as CFDictionary)
        os_log("[SecureConfig] Delete existing item status: %d (account: %{public}s)", log: .default, type: .debug, deleteStatus, account)

        // Add new entry
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            os_log("[SecureConfig] Successfully stored %{public}s in Keychain (status: %d)", log: .default, type: .info, account, status)
        } else {
            os_log("[SecureConfig] Failed to store in Keychain: %{public}s (status: %d)", log: .default, type: .error, account, status)
        }
    }

    /// Retrieve a string value from Keychain
    /// - Parameter account: The account identifier to retrieve
    /// - Returns: The stored string, or nil if not found
    private func retrieveFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne  // Only return first match
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                os_log("[SecureConfig] Error retrieving from Keychain: %d (account: %{public}s)", log: .default, type: .error, status, account)
            } else {
                os_log("[SecureConfig] Keychain item not found (account: %{public}s)", log: .default, type: .debug, account)
            }
            return nil
        }

        guard let data = item as? Data else {
            os_log("[SecureConfig] Retrieved data is not valid (account: %{public}s)", log: .default, type: .error, account)
            return nil
        }

        let value = String(data: data, encoding: .utf8)
        os_log("[SecureConfig] Successfully retrieved value from Keychain (account: %{public}s, length: %d)", log: .default, type: .debug, account, value?.count ?? 0)
        return value
    }

    /// Delete an entry from Keychain
    /// - Parameter account: The account identifier to delete
    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
        os_log("[SecureConfig] Deleted %{public}s from Keychain", log: .default, type: .info, account)
    }

    /// Clear all stored credentials (useful for logout/reset)
    func clearAllCredentials() {
        supabaseAPIKey = nil
        os_log("[SecureConfig] All credentials cleared from Keychain", log: .default, type: .info)
    }
}

import os.log

extension OSLog {
    static let `default` = OSLog(subsystem: "com.vital.claraprovider", category: "general")
}

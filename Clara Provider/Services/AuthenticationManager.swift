import Foundation
import Combine
import LocalAuthentication
import CryptoKit
import Security

@MainActor
final class AuthenticationManager: ObservableObject {
    enum State {
        case needsSetup
        case locked
        case unlocked
    }
    
    enum AuthenticationError: LocalizedError {
        case passwordMismatch
        case passwordTooShort
        case passwordNotSet
        case invalidPassword
        case biometricsUnavailable
        case biometricEvaluationFailed
        case keychainFailure

        var errorDescription: String? {
            switch self {
            case .passwordMismatch:
                return "Passwords do not match."
            case .passwordTooShort:
                return "Password must be at least 8 characters long."
            case .passwordNotSet:
                return "No password configured yet."
            case .invalidPassword:
                return "The password you entered is incorrect."
            case .biometricsUnavailable:
                return "Face ID is not available on this device."
            case .biometricEvaluationFailed:
                return "Face ID authentication failed."
            case .keychainFailure:
                return "Unable to store password securely."
            }
        }
    }

    @Published private(set) var state: State = .locked
    @Published private(set) var biometricType: LABiometryType = .none
    
    private let keychainService = "com.dochobbs.claraprov.auth"
    private let passwordAccount = "providerPasswordHash"
    private let maxSessionDuration: TimeInterval = 12 * 60 * 60 // 12 hours
    
    private var lastUnlockedAt: Date?
    private var sessionTimer: Timer?

    init() {
        refreshState()
        updateBiometricType()
    }

    deinit {
        sessionTimer?.invalidate()
    }

    func refreshState() {
        if let unlockDate = lastUnlockedAt {
            let elapsed = Date().timeIntervalSince(unlockDate)
            if elapsed >= maxSessionDuration {
                lock()
                return
            }
            state = .unlocked
            scheduleSessionExpiry()
            return
        }
        
        if fetchStoredPasswordHash() == nil {
            state = .needsSetup
        } else if state != .unlocked {
            state = .locked
        }
    }

    func lock() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        lastUnlockedAt = nil
        if fetchStoredPasswordHash() != nil {
            state = .locked
        } else {
            state = .needsSetup
        }
    }

    func configurePassword(newPassword: String, confirmPassword: String) throws {
        guard newPassword == confirmPassword else {
            throw AuthenticationError.passwordMismatch
        }

        guard newPassword.count >= 8 else {
            throw AuthenticationError.passwordTooShort
        }

        let hash = hashPassword(newPassword)
        try storePasswordHash(hash)
        state = .unlocked
        startSession()
    }

    func unlock(with password: String) throws {
        guard let storedHash = fetchStoredPasswordHash() else {
            throw AuthenticationError.passwordNotSet
        }

        let incomingHash = hashPassword(password)
        guard incomingHash == storedHash else {
            throw AuthenticationError.invalidPassword
        }

        state = .unlocked
        startSession()
    }

    func authenticateWithBiometrics() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthenticationError.biometricsUnavailable
        }

        let reason = "Unlock Clara Provider"

        let success = try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { result, evalError in
                if result {
                    continuation.resume(returning: true)
                } else {
                    if let evalError = evalError {
                        continuation.resume(throwing: evalError)
                    } else {
                        continuation.resume(throwing: AuthenticationError.biometricEvaluationFailed)
                    }
                }
            }
        }

        state = .unlocked
        startSession()
    }

    func updateBiometricType() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        } else {
            biometricType = .none
        }
    }

    private func hashPassword(_ password: String) -> Data {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }

    private func startSession() {
        lastUnlockedAt = Date()
        scheduleSessionExpiry()
    }

    private func scheduleSessionExpiry() {
        sessionTimer?.invalidate()
        guard let unlockDate = lastUnlockedAt else { return }
        let elapsed = Date().timeIntervalSince(unlockDate)
        let remaining = maxSessionDuration - elapsed
        guard remaining > 0 else {
            lock()
            return
        }
        sessionTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
    }

    private func fetchStoredPasswordHash() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordAccount,
            kSecReturnData as String: true
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        return item as? Data
    }

    private func storePasswordHash(_ hash: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordAccount
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = hash

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthenticationError.keychainFailure
        }
    }
}



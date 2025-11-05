import SwiftUI
import LocalAuthentication

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil
    @State private var isProcessing: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.primaryCoral)
                Text(title)
                    .font(.rethinkSansBold(24, relativeTo: .title))
                Text(subtitle)
                    .font(.rethinkSans(15, relativeTo: .subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            VStack(spacing: 16) {
                switch authManager.state {
                case .needsSetup:
                    setupFields
                case .locked:
                    unlockFields
                case .unlocked:
                    EmptyView()
                }
            }
            .padding(20)
            .background(Color.adaptiveSecondaryBackground(for: colorScheme))
            .cornerRadius(16)
            .padding(.horizontal, 24)
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.rethinkSans(13, relativeTo: .footnote))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .background(Color.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .task {
            authManager.updateBiometricType()
        }
        .onAppear {
            // Automatically trigger Face ID when the app first shows the locked screen
            if authManager.state == .locked && authManager.biometricType != .none && !isProcessing {
                unlockWithBiometrics()
            }
        }
    }
    
    private var title: String {
        switch authManager.state {
        case .needsSetup:
            return "Secure clara-provider-app"
        case .locked:
            return "Unlock clara-provider-app"
        case .unlocked:
            return ""
        }
    }
    
    private var subtitle: String {
        switch authManager.state {
        case .needsSetup:
            return "Create a password to protect patient conversations."
        case .locked:
            return "Enter your password or use Face ID to continue."
        case .unlocked:
            return ""
        }
    }
    
    private var setupFields: some View {
        VStack(spacing: 12) {
            SecureField("Create Password", text: $password)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
            
            SecureField("Confirm Password", text: $confirmPassword)
                .textContentType(.newPassword)
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
            
            Button(action: configurePassword) {
                HStack {
                    if isProcessing {
                        ProgressView()
                    }
                    Text(isProcessing ? "Saving…" : "Enable Protection")
                        .font(.rethinkSansBold(17, relativeTo: .body))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.primaryCoral)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isProcessing)
        }
    }
    
    private var unlockFields: some View {
        VStack(spacing: 12) {
            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .submitLabel(.go)
                .onSubmit {
                    unlockWithPassword()
                }
            
            Button(action: unlockWithPassword) {
                HStack {
                    if isProcessing {
                        ProgressView()
                    }
                    Text(isProcessing ? "Checking…" : "Unlock")
                        .font(.rethinkSansBold(17, relativeTo: .body))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.primaryCoral)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isProcessing)
            
            if authManager.biometricType != .none {
                Button(action: unlockWithBiometrics) {
                    HStack(spacing: 8) {
                        Image(systemName: authManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text("Use Face ID")
                            .font(.rethinkSansBold(15, relativeTo: .subheadline))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.adaptiveTertiaryBackground(for: colorScheme))
                    .cornerRadius(10)
                }
                .disabled(isProcessing)
            }
        }
    }
    
    private func configurePassword() {
        errorMessage = nil
        isProcessing = true
        Task {
            do {
                try authManager.configurePassword(newPassword: password, confirmPassword: confirmPassword)
                resetFields()
            } catch {
                handle(error)
            }
            isProcessing = false
        }
    }
    
    private func unlockWithPassword() {
        guard !password.isEmpty else { return }
        errorMessage = nil
        isProcessing = true
        Task {
            do {
                try authManager.unlock(with: password)
                resetFields()
            } catch {
                handle(error)
            }
            isProcessing = false
        }
    }
    
    private func unlockWithBiometrics() {
        errorMessage = nil
        isProcessing = true
        Task {
            do {
                try await authManager.authenticateWithBiometrics()
                resetFields()
            } catch {
                handle(error)
            }
            isProcessing = false
        }
    }
    
    private func resetFields() {
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
    
    private func handle(_ error: Error) {
        if let authError = error as? AuthenticationManager.AuthenticationError {
            errorMessage = authError.localizedDescription
        } else if let laError = error as? LAError {
            errorMessage = laError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
    }
}



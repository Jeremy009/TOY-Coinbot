import SwiftUI
import LocalAuthentication
import Security
import CryptoKit

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasSetupPasscode = false
    @Published var authenticationError: String?
    @Published var isLoading = false
    @Published var isFaceIDEnabled = true
    @Published var hasAPIKey = false
    
    private let context = LAContext()
    private let keychainService = AppConstants.bundleIdentifier
    private let passcodeKey = SecurityConstants.KeychainKeys.userPasscode
    private let apiKeyKey = SecurityConstants.KeychainKeys.bitvavoAPIKey
    private let apiSecretKey = SecurityConstants.KeychainKeys.bitvavoAPISecret
    private let faceIDEnabledKey = SecurityConstants.UserDefaultsKeys.faceIDEnabled
    
    init() {
        checkPasscodeSetup()
        loadSettings()
    }
    
    func checkPasscodeSetup() {
        hasSetupPasscode = getStoredPasscodeHash() != nil
    }
    
    func setupPasscode(_ passcode: String) -> Bool {
        let hashedPasscode = hashPasscode(passcode)
        
        if saveToKeychain(key: passcodeKey, data: hashedPasscode) {
            hasSetupPasscode = true
            return true
        }
        return false
    }
    
    func authenticateWithBiometrics() {
        guard hasSetupPasscode else {
            print("❌ Biometric auth failed: No passcode set up")
            authenticationError = "Please set up a passcode first"
            return
        }
        
        guard isFaceIDEnabled else {
            print("❌ Biometric auth failed: Face ID disabled in settings")
            authenticationError = "Face ID is disabled in settings"
            return
        }
        
        print("🔐 Starting Face ID authentication...")
        isLoading = true
        authenticationError = nil
        
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = SecurityConstants.BiometricAuthentication.reason
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authenticationError in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if success {
                        print("✅ Face ID authentication successful")
                        self?.isAuthenticated = true
                        self?.authenticationError = nil
                    } else {
                        if let error = authenticationError as? LAError {
                            print("❌ Face ID authentication failed: \(error.localizedDescription)")
                            self?.handleAuthenticationError(error)
                        }
                    }
                }
            }
        } else {
            print("❌ Biometric auth unavailable: \(error?.localizedDescription ?? "Unknown error")")
            isLoading = false
            authenticationError = error?.localizedDescription ?? "Biometric authentication not available"
        }
    }
    
    func authenticateWithPasscode(_ passcode: String) -> Bool {
        print("🔑 Attempting passcode authentication...")
        
        guard let storedHash = getStoredPasscodeHash() else {
            print("❌ Passcode auth failed: No stored passcode found")
            authenticationError = "No passcode found"
            return false
        }
        
        let enteredHash = hashPasscode(passcode)
        
        if enteredHash == storedHash {
            print("✅ Passcode authentication successful")
            isAuthenticated = true
            authenticationError = nil
            return true
        } else {
            print("❌ Passcode authentication failed: Incorrect passcode")
            authenticationError = "Incorrect passcode"
            return false
        }
    }
    
    func logout() {
        isAuthenticated = false
        context.invalidate()
    }
    
    func resetPasscode() {
        deleteFromKeychain(key: passcodeKey)
        hasSetupPasscode = false
        isAuthenticated = false
    }
    
    private func hashPasscode(_ passcode: String) -> String {
        let data = Data(passcode.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func handleAuthenticationError(_ error: LAError) {
        switch error.code {
        case .userCancel:
            authenticationError = "Face ID cancelled - Enter your app passcode below"
        case .userFallback:
            authenticationError = "Enter your app passcode below"
        case .biometryNotAvailable:
            authenticationError = "Face ID not available - Enter your app passcode below"
        case .biometryNotEnrolled:
            authenticationError = "Face ID not set up - Enter your app passcode below"
        case .biometryLockout:
            authenticationError = "Face ID locked - Enter your app passcode below"
        case .authenticationFailed:
            authenticationError = "Face ID failed - Enter your app passcode below"
        default:
            authenticationError = "Face ID unavailable - Enter your app passcode below"
        }
    }
    
    private func saveToKeychain(key: String, data: String) -> Bool {
        let keyData = data.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getStoredPasscodeHash() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passcodeKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let passcode = String(data: data, encoding: .utf8) {
            return passcode
        }
        
        return nil
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Settings Management
    
    func loadSettings() {
        if UserDefaults.standard.object(forKey: faceIDEnabledKey) != nil {
            isFaceIDEnabled = UserDefaults.standard.bool(forKey: faceIDEnabledKey)
        } else {
            isFaceIDEnabled = true
            UserDefaults.standard.set(true, forKey: faceIDEnabledKey)
        }
        hasAPIKey = getStoredAPIKey() != nil
    }
    
    func toggleFaceID(_ enabled: Bool) {
        isFaceIDEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: faceIDEnabledKey)
    }
    
    // MARK: - Biometric Authentication Helper
    
    func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - API Key Management
    
    func saveAPICredentials(apiKey: String, apiSecret: String) -> Bool {
        let keySuccess = saveToKeychain(key: apiKeyKey, data: apiKey)
        let secretSuccess = saveToKeychain(key: apiSecretKey, data: apiSecret)
        
        if keySuccess && secretSuccess {
            hasAPIKey = true
            return true
        }
        return false
    }
    
    func getStoredAPIKey() -> String? {
        return getFromKeychain(key: apiKeyKey)
    }
    
    func getStoredAPISecret() -> String? {
        return getFromKeychain(key: apiSecretKey)
    }
    
    func deleteAPICredentials() {
        deleteFromKeychain(key: apiKeyKey)
        deleteFromKeychain(key: apiSecretKey)
        hasAPIKey = false
    }
    
    func testAPIConnection() async -> Bool {
        print("🔌 Testing API connection...")
        
        guard let apiKey = getStoredAPIKey(),
              let apiSecret = getStoredAPISecret() else {
            print("❌ API test failed: No credentials stored")
            return false
        }
        
        let client = BitvavoAPIClient()
        let credentials = BitvavoAPIClient.APICredentials(apiKey: apiKey, apiSecret: apiSecret)
        
        do {
            let result = try await client.testConnection(credentials: credentials)
            if result {
                print("✅ API connection test successful")
            } else {
                print("❌ API connection test failed")
            }
            return result
        } catch {
            print("❌ API connection error: \(error.localizedDescription)")
            return false
        }
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
}
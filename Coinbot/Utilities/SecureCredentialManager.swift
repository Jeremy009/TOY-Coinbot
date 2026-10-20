import Foundation
import OSLog

/// Secure credential manager with automatic memory cleanup
class SecureCredentialManager {
    private static let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "SecureCredentialManager")
    
    /// Secure string wrapper that automatically clears memory on deallocation
    class SecureString {
        private var _value: String
        
        init(_ value: String) {
            self._value = value
        }
        
        var value: String {
            return _value
        }
        
        deinit {
            // Clear the string by overwriting memory
            _value = String(repeating: "\0", count: _value.count)
        }
        
        /// Temporarily access the value with automatic cleanup
        func withValue<T>(_ block: (String) throws -> T) rethrows -> T {
            return try block(_value)
        }
    }
    
    /// Securely handles API credentials with automatic cleanup
    struct SecureCredentials {
        private let _apiKey: SecureString
        private let _apiSecret: SecureString
        
        init(apiKey: String, apiSecret: String) {
            self._apiKey = SecureString(apiKey)
            self._apiSecret = SecureString(apiSecret)
        }
        
        /// Access API key with automatic cleanup
        func withApiKey<T>(_ block: (String) throws -> T) rethrows -> T {
            return try _apiKey.withValue(block)
        }
        
        /// Access API secret with automatic cleanup
        func withApiSecret<T>(_ block: (String) throws -> T) rethrows -> T {
            return try _apiSecret.withValue(block)
        }
        
        /// Convert to BitvavoAPIClient.APICredentials for API calls
        func toAPICredentials() -> BitvavoAPIClient.APICredentials {
            return BitvavoAPIClient.APICredentials(
                apiKey: _apiKey.value,
                apiSecret: _apiSecret.value
            )
        }
    }
    
    /// Loads credentials from keychain with secure handling
    /// - Returns: SecureCredentials if available, nil otherwise
    static func loadCredentials() -> SecureCredentials? {
        guard let apiKey = getFromKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPIKey),
              let apiSecret = getFromKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPISecret) else {
            logger.info("No stored API credentials found")
            return nil
        }
        
        logger.info("Successfully loaded API credentials from keychain")
        return SecureCredentials(apiKey: apiKey, apiSecret: apiSecret)
    }
    
    /// Saves credentials to keychain with validation
    /// - Parameters:
    ///   - apiKey: The API key to store
    ///   - apiSecret: The API secret to store
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func saveCredentials(apiKey: String, apiSecret: String) -> Bool {
        // Validate input
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !apiSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("Cannot save empty API credentials")
            return false
        }
        
        // Validate format (basic checks)
        guard apiKey.count >= 32, apiSecret.count >= 32 else {
            logger.error("API credentials appear to be invalid (too short)")
            return false
        }
        
        // Save to keychain
        let keyResult = saveToKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPIKey, value: apiKey)
        let secretResult = saveToKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPISecret, value: apiSecret)
        
        if keyResult && secretResult {
            logger.info("Successfully saved API credentials to keychain")
            return true
        } else {
            logger.error("Failed to save API credentials to keychain")
            // Clean up partial save
            _ = deleteCredentials()
            return false
        }
    }
    
    /// Deletes all stored credentials from keychain
    /// - Returns: True if successful or no credentials existed
    @discardableResult
    static func deleteCredentials() -> Bool {
        let keyResult = deleteFromKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPIKey)
        let secretResult = deleteFromKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPISecret)
        
        if keyResult && secretResult {
            logger.info("Successfully deleted API credentials from keychain")
        } else {
            logger.warning("Partial success deleting API credentials from keychain")
        }
        
        return keyResult && secretResult
    }
    
    /// Validates that stored credentials are accessible
    /// - Returns: True if credentials exist and are accessible
    static func validateStoredCredentials() -> Bool {
        guard let credentials = loadCredentials() else {
            return false
        }
        
        // Perform basic validation
        return credentials.withApiKey { key in
            credentials.withApiSecret { secret in
                return !key.isEmpty && !secret.isEmpty && key.count >= 32 && secret.count >= 32
            }
        }
    }
    
    // MARK: - Private Keychain Operations
    
    private static func saveToKeychain(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Failed to encode value for keychain storage")
            return false
        }
        
        // Delete existing item first
        deleteFromKeychain(key: key)
        
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ] as [String: Any]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            logger.debug("Successfully saved item to keychain: \(key)")
            return true
        } else {
            logger.error("Failed to save item to keychain: \(key), status: \(status)")
            return false
        }
    }
    
    private static func getFromKeychain(key: String) -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data {
                let value = String(data: retrievedData, encoding: .utf8)
                logger.debug("Successfully retrieved item from keychain: \(key)")
                return value
            }
        } else if status != errSecItemNotFound {
            logger.error("Failed to retrieve item from keychain: \(key), status: \(status)")
        }
        
        return nil
    }
    
    private static func deleteFromKeychain(key: String) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            logger.error("Failed to delete item from keychain: \(key), status: \(status)")
            return false
        }
    }
}
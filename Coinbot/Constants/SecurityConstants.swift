import Foundation

struct SecurityConstants {
    static let passcodeLength = 4
    
    struct KeychainKeys {
        static let userPasscode = "user-passcode"
        static let bitvavoAPIKey = "bitvavo-api-key"
        static let bitvavoAPISecret = "bitvavo-api-secret"
    }
    
    struct UserDefaultsKeys {
        static let faceIDEnabled = "face-id-enabled"
    }
    
    struct BiometricAuthentication {
        static let reason = "Authenticate to access your trading data"
    }
}
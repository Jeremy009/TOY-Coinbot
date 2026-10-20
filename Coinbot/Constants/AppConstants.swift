import Foundation

struct AppConstants {
    static let appName = "Coinbot"
    
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.takeitup.coinbot"
    }
    
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
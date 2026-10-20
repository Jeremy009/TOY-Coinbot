import Foundation

struct TestCredentials {
    static func loadAPICredentials() -> (apiKey: String, apiSecret: String)? {
        // Try to load from .env file first
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let envURL = projectRoot.appendingPathComponent(".env")
        
        if let envContent = try? String(contentsOf: envURL),
           let credentials = parseEnvContent(envContent) {
            print("✅ Loaded credentials from .env file")
            return credentials
        }
        
        // No fallback credentials - tests require .env file
        print("❌ No .env file found at: \(envURL.path)")
        print("❌ Tests require BITVAVO_API_KEY and BITVAVO_API_SECRET in .env file")
        return nil
    }
    
    private static func parseEnvContent(_ content: String) -> (apiKey: String, apiSecret: String)? {
        var apiKey: String?
        var apiSecret: String?
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("#") || trimmedLine.isEmpty {
                continue
            }
            
            let components = trimmedLine.components(separatedBy: "=")
            guard components.count == 2 else { continue }
            
            let key = components[0].trimmingCharacters(in: .whitespaces)
            let value = components[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "BITVAVO_API_KEY":
                apiKey = value
            case "BITVAVO_API_SECRET":
                apiSecret = value
            default:
                break
            }
        }
        
        guard let key = apiKey, let secret = apiSecret else {
            print("❌ Missing API credentials in .env file")
            return nil
        }
        
        return (apiKey: key, apiSecret: secret)
    }
}


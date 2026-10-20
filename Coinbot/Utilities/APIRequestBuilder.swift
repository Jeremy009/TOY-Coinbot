import Foundation
import CryptoKit
import OSLog

/// Utility class for building and managing API requests with proper security and logging
class APIRequestBuilder {
    private static let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "APIRequestBuilder")
    
    /// Generates HMAC-SHA256 signature for API authentication
    /// - Parameters:
    ///   - timestamp: Unix timestamp in milliseconds
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: API endpoint path
    ///   - body: Request body (empty for GET requests)
    ///   - secret: API secret key (treated as UTF-8 string, NOT hex)
    /// - Returns: HMAC-SHA256 signature as lowercase hex string
    static func generateSignature(timestamp: String, method: String, path: String, body: String, secret: String) -> String {
        // Bitvavo expects /v2 prefix in signature message
        let message = timestamp + method + "/v2" + path + body
        
        guard let messageData = message.data(using: .utf8),
              let secretData = secret.data(using: .utf8) else {
            logger.error("Failed to encode message or secret for signature generation")
            return ""
        }
        
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: SymmetricKey(data: secretData))
        return Data(signature).hexEncodedString()
    }
    
    /// Creates a timestamp for API requests
    /// - Returns: Current timestamp as string in milliseconds since Unix epoch
    static func createTimestamp() -> String {
        let currentTime = Date().timeIntervalSince1970 * 1000
        return String(Int(currentTime))
    }
    
    /// Builds authenticated request headers for Bitvavo API
    /// - Parameters:
    ///   - credentials: API credentials
    ///   - method: HTTP method
    ///   - path: API endpoint path
    ///   - body: Request body
    /// - Returns: Dictionary of headers for the request
    static func buildAuthenticatedHeaders(
        credentials: BitvavoAPIClient.APICredentials,
        method: String,
        path: String,
        body: String = ""
    ) -> [String: String] {
        let timestamp = createTimestamp()
        let signature = generateSignature(
            timestamp: timestamp,
            method: method,
            path: path,
            body: body,
            secret: credentials.apiSecret
        )
        
        return [
            APIConfiguration.Headers.accessKey: credentials.apiKey,
            APIConfiguration.Headers.accessSignature: signature,
            APIConfiguration.Headers.accessTimestamp: timestamp,
            APIConfiguration.Headers.accessWindow: APIConfiguration.accessWindowString,
            "Content-Type": "application/json"
        ]
    }
    
    /// Creates a URLRequest with proper authentication and configuration
    /// - Parameters:
    ///   - url: Target URL
    ///   - method: HTTP method
    ///   - credentials: API credentials (optional for public endpoints)
    ///   - body: Request body data
    ///   - timeout: Request timeout interval
    /// - Returns: Configured URLRequest
    static func createRequest(
        url: URL,
        method: String,
        credentials: BitvavoAPIClient.APICredentials? = nil,
        body: Data? = nil,
        timeout: TimeInterval = APIConfiguration.defaultTimeout
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = body
        }
        
        if let credentials = credentials {
            let bodyString = body != nil ? String(data: body!, encoding: .utf8) ?? "" : ""
            let headers = buildAuthenticatedHeaders(
                credentials: credentials,
                method: method,
                path: url.path,
                body: bodyString
            )
            
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        } else {
            // Public endpoint
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
}


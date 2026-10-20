import Foundation
import OSLog

/// Secure logging utility with privacy controls and data sanitization
class SecureLogger {
    
    private let logger: Logger
    private let category: String
    
    init(category: String) {
        self.category = category
        self.logger = Logger(subsystem: AppConstants.bundleIdentifier, category: category)
    }
    
    // MARK: - Logging Methods
    
    func info(_ message: String, sensitive: Bool = false) {
        if sensitive {
            logger.info("\(message, privacy: .private)")
        } else {
            logger.info("\(message)")
        }
    }
    
    func debug(_ message: String, sensitive: Bool = false) {
        if sensitive {
            logger.debug("\(message, privacy: .private)")
        } else {
            logger.debug("\(message)")
        }
    }
    
    func error(_ message: String, sensitive: Bool = false) {
        if sensitive {
            logger.error("\(message, privacy: .private)")
        } else {
            logger.error("\(message)")
        }
    }
    
    func warning(_ message: String, sensitive: Bool = false) {
        if sensitive {
            logger.warning("\(message, privacy: .private)")
        } else {
            logger.warning("\(message)")
        }
    }
    
    func fault(_ message: String, sensitive: Bool = false) {
        if sensitive {
            logger.fault("\(message, privacy: .private)")
        } else {
            logger.fault("\(message)")
        }
    }
    
    // MARK: - API Logging Methods
    
    func logAPIRequest(_ method: String, url: String, authenticated: Bool = false) {
        let sanitizedURL = sanitizeURL(url)
        if authenticated {
            info("🌐 API Request: \(method) \(sanitizedURL) (authenticated)", sensitive: false)
        } else {
            info("🌐 API Request: \(method) \(sanitizedURL) (public)", sensitive: false)
        }
    }
    
    func logAPIResponse(_ statusCode: Int, url: String, responseSize: Int? = nil) {
        let sanitizedURL = sanitizeURL(url)
        let sizeInfo = responseSize.map { " (\($0) bytes)" } ?? ""
        
        if statusCode >= 200 && statusCode < 300 {
            info("✅ API Success: \(statusCode) \(sanitizedURL)\(sizeInfo)")
        } else if statusCode >= 400 && statusCode < 500 {
            warning("⚠️ API Client Error: \(statusCode) \(sanitizedURL)")
        } else if statusCode >= 500 {
            error("❌ API Server Error: \(statusCode) \(sanitizedURL)")
        } else {
            info("📡 API Response: \(statusCode) \(sanitizedURL)\(sizeInfo)")
        }
    }
    
    func logAPIError(_ apiError: Error, url: String) {
        let sanitizedURL = sanitizeURL(url)
        error("❌ API Error: \(sanitizedURL) - \(sanitizeErrorMessage(apiError.localizedDescription))")
    }
    
    // MARK: - Data Sanitization
    
    private func sanitizeURL(_ url: String) -> String {
        // Remove query parameters that might contain sensitive data
        if let urlComponents = URLComponents(string: url) {
            var sanitized = urlComponents
            
            // Remove or sanitize sensitive query parameters
            if let queryItems = sanitized.queryItems {
                sanitized.queryItems = queryItems.compactMap { item in
                    switch item.name.lowercased() {
                    case "key", "secret", "token", "signature", "timestamp":
                        return URLQueryItem(name: item.name, value: "[REDACTED]")
                    case "market", "symbol", "limit", "offset":
                        return item // These are safe to log
                    default:
                        // For unknown parameters, sanitize the value
                        return URLQueryItem(name: item.name, value: sanitizeValue(item.value))
                    }
                }
            }
            
            return sanitized.string ?? url
        }
        
        return url
    }
    
    private func sanitizeValue(_ value: String?) -> String {
        guard let value = value else { return "[NULL]" }
        
        // Check if value looks like sensitive data
        if value.count > 20 && (value.allSatisfy { $0.isLetter || $0.isNumber }) {
            // Looks like an API key or token
            return "[REDACTED]"
        }
        
        return value
    }
    
    private func sanitizeErrorMessage(_ message: String) -> String {
        var sanitized = message
        
        // Common patterns to sanitize
        let patterns = [
            // API keys (32+ alphanumeric characters)
            ("\\b[A-Za-z0-9]{32,}\\b", "[API_KEY]"),
            // UUIDs
            ("[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", "[UUID]"),
            // Email addresses
            ("\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", "[EMAIL]"),
            // IP addresses
            ("\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b", "[IP_ADDRESS]")
        ]
        
        for (pattern, replacement) in patterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        
        return sanitized
    }
    
    // MARK: - Performance Logging
    
    func measureTime<T>(operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            debug("⏱️ \(operation): \(String(format: "%.3f", timeElapsed))s")
        }
        return try block()
    }
    
    func measureAsyncTime<T>(operation: String, block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            debug("⏱️ \(operation): \(String(format: "%.3f", timeElapsed))s")
        }
        return try await block()
    }
    
    // MARK: - Structured Logging
    
    func logBalance(_ symbol: String, amount: Double, inOrder: Double = 0) {
        if amount > 0 {
            info("💎 Balance: \(symbol) = \(CurrencyFormatter.formatCryptoAmount(amount, symbol: symbol))")
            if inOrder > 0 {
                info("📋 In Order: \(symbol) = \(CurrencyFormatter.formatCryptoAmount(inOrder, symbol: symbol))")
            }
        }
    }
    
    func logPriceUpdate(_ symbol: String, price: Double, change: Double? = nil) {
        var message = "💰 Price: \(symbol) = \(CurrencyFormatter.formatEUR(price))"
        if let change = change {
            let changeStr = CurrencyFormatter.formatPercentageChange(change)
            let arrow = change >= 0 ? "📈" : "📉"
            message += " \(arrow) \(changeStr)"
        }
        info(message)
    }
    
    func logOrder(_ orderId: String, market: String, side: String, amount: Double, price: Double?) {
        var message = "📤 Order: \(orderId) - \(side.uppercased()) \(amount) \(market)"
        if let price = price {
            message += " @ \(CurrencyFormatter.formatEUR(price))"
        }
        info(message)
    }
    
    func logTrade(_ tradeId: String, market: String, side: String, amount: Double, price: Double) {
        let value = amount * price
        info("💸 Trade: \(tradeId) - \(side.uppercased()) \(amount) \(market) @ \(CurrencyFormatter.formatEUR(price)) = \(CurrencyFormatter.formatEUR(value))")
    }
}

// MARK: - Global Logger Instances

extension SecureLogger {
    static let api = SecureLogger(category: "API")
    static let auth = SecureLogger(category: "Authentication")
    static let trading = SecureLogger(category: "Trading")
    static let ui = SecureLogger(category: "UI")
    static let performance = SecureLogger(category: "Performance")
    static let security = SecureLogger(category: "Security")
}
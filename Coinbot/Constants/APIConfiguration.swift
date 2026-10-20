import Foundation

struct APIConfiguration {
    static let baseURL = "https://api.bitvavo.com/v2"
    static let accessWindow: TimeInterval = 10000
    static let accessWindowString = String(Int(accessWindow))
    
    // MARK: - Timeout Configuration
    /// Default timeout for API requests (in seconds)
    static let defaultTimeout: TimeInterval = 30
    
    /// Timeout for authentication requests
    static let authTimeout: TimeInterval = 15
    
    /// Timeout for market data requests
    static let marketDataTimeout: TimeInterval = 10
    
    /// Timeout for trading operations
    static let tradingTimeout: TimeInterval = 45
    
    // MARK: - Rate Limiting
    /// Maximum requests per minute for authenticated endpoints
    static let maxRequestsPerMinute = 1000
    
    /// Maximum requests per minute for public endpoints
    static let maxPublicRequestsPerMinute = 300
    
    /// Minimum interval between requests (in seconds)
    static let minRequestInterval: TimeInterval = 0.1
    
    // MARK: - Retry Configuration
    /// Maximum number of retry attempts for failed requests
    static let maxRetryAttempts = 3
    
    /// Initial retry delay (in seconds)
    static let initialRetryDelay: TimeInterval = 1.0
    
    /// Multiplier for exponential backoff
    static let retryBackoffMultiplier: Double = 2.0
    
    struct Endpoints {
        static let time = "/time"
        static let balance = "/balance"
        static let ticker24h = "/ticker/24h"
        static let tickerPrice = "/ticker/price"
        static let orders = "/orders"
        static let ordersOpen = "/ordersOpen"
        static let orderHistory = "/orders"
        static let order = "/order"
        static let cancelOrder = "/order"
        static let assets = "/assets"
        static let markets = "/markets"
    }
    
    struct Headers {
        static let accessKey = "Bitvavo-Access-Key"
        static let accessSignature = "Bitvavo-Access-Signature"
        static let accessTimestamp = "Bitvavo-Access-Timestamp"
        static let accessWindow = "Bitvavo-Access-Window"
    }
    
    struct ResponseKeys {
        static let symbol = "symbol"
        static let available = "available"
        static let inOrder = "inOrder"
    }
    
    struct HTTPStatusCodes {
        static let success = 200
    }
}
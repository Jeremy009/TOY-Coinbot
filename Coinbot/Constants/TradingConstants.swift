import Foundation

/// Constants related to trading operations and market data
struct TradingConstants {
    
    // MARK: - Order Limits
    
    /// Minimum order value in EUR
    static let minOrderValue: Double = 5.0
    
    /// Maximum order value in EUR (safety limit)
    static let maxOrderValue: Double = 1_000_000.0
    
    /// Minimum balance threshold for display
    static let minBalanceThreshold: Double = 0.0001
    
    // MARK: - Major Markets
    
    /// Primary trading pairs for order history and analytics
    static let majorMarkets: [String] = [
        "BTC-EUR", "ETH-EUR", "ADA-EUR", "DOT-EUR", 
        "LINK-EUR", "LTC-EUR", "XRP-EUR", "SOL-EUR",
        "AVAX-EUR", "MATIC-EUR", "UNI-EUR", "ATOM-EUR"
    ]
    
    /// Default market for new orders
    static let defaultMarket = "BTC-EUR"
    
    // MARK: - Price Change Simulation
    
    /// Volatility ranges for different cryptocurrency types
    struct VolatilityRanges {
        /// Major cryptocurrencies (lower volatility)
        static let majorCoins: (min: Double, max: Double) = (-5.0, 5.0)
        
        /// Stablecoins (very low volatility)
        static let stablecoins: (min: Double, max: Double) = (-0.5, 0.5)
        
        /// Alternative cryptocurrencies (higher volatility)
        static let altcoins: (min: Double, max: Double) = (-15.0, 15.0)
        
        /// Maximum allowed percentage change (safety clamp)
        static let maxPercentageChange: Double = 50.0
    }
    
    /// Cryptocurrency categories for volatility determination
    struct CryptocurrencyCategories {
        static let majorCoins: Set<String> = ["BTC", "ETH"]
        static let stablecoins: Set<String> = ["USDT", "USDC", "EURC", "DAI", "BUSD"]
        
        /// Determines if a symbol is a major coin
        static func isMajorCoin(_ symbol: String) -> Bool {
            return majorCoins.contains(symbol.uppercased())
        }
        
        /// Determines if a symbol is a stablecoin
        static func isStablecoin(_ symbol: String) -> Bool {
            return stablecoins.contains(symbol.uppercased())
        }
    }
    
    // MARK: - Market Data
    
    /// Symbols that require special handling
    static let specialSymbols: [String: String] = [
        "LUNA2": "LUNA"  // LUNA2 uses LUNA icon
    ]
    
    /// Price change simulation multiplier ranges
    static let priceChangeMultiplierRange: (min: Double, max: Double) = (2.0, 8.0)
    
    /// Additional noise range for 24h price changes
    static let additionalNoiseRange: (min: Double, max: Double) = (-2.0, 2.0)
    
    // MARK: - Order Types
    
    /// Supported order types for the trading interface
    static let supportedOrderTypes: [BitvavoAPIClient.OrderType] = [
        .market, .limit, .stopLimit, .stopLoss
    ]
    
    /// Default order type for new orders
    static let defaultOrderType: BitvavoAPIClient.OrderType = .limit
    
    /// Default time in force for limit orders
    static let defaultTimeInForce: BitvavoAPIClient.TimeInForce = .gtc
    
    // MARK: - Display Formatting
    
    /// Number of decimal places for different value ranges
    struct DecimalPlaces {
        /// For amounts >= 1
        static let standardAmount = 4
        
        /// For amounts < 1
        static let smallAmount = 8
        
        /// For percentage values
        static let percentage = 2
        
        /// For EUR prices
        static let eurPrice = 2
    }
    
    // MARK: - Performance Settings
    
    /// Maximum number of concurrent API requests
    static let maxConcurrentRequests = 10
    
    /// Batch size for bulk operations
    static let batchSize = 50
    
    /// Cache duration for market data (in seconds)
    static let marketDataCacheTime: TimeInterval = 30
    
    /// Cache duration for price data (in seconds)
    static let priceDataCacheTime: TimeInterval = 10
}
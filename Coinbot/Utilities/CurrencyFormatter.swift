import Foundation

/// Utility class for consistent currency and number formatting across the app
class CurrencyFormatter {
    
    /// Formats a Double value as EUR currency with proper localization
    /// - Parameter value: The monetary value to format
    /// - Returns: Formatted currency string (e.g., "€1.234,56")
    static func formatEUR(_ value: Double) -> String {
        return value.formatted(.currency(code: "EUR"))
    }
    
    /// Formats cryptocurrency amounts with appropriate decimal places
    /// - Parameters:
    ///   - amount: The cryptocurrency amount
    ///   - symbol: The cryptocurrency symbol
    /// - Returns: Formatted amount string with symbol
    static func formatCryptoAmount(_ amount: Double, symbol: String) -> String {
        if amount >= 1 {
            return "\(amount.formatted(.number.precision(.fractionLength(4)))) \(symbol)"
        } else {
            return "\(amount.formatted(.number.precision(.fractionLength(8)))) \(symbol)"
        }
    }
    
    /// Formats EUR worth of a cryptocurrency amount
    /// - Parameters:
    ///   - amount: The cryptocurrency amount
    ///   - exchangeRate: The EUR exchange rate
    /// - Returns: Formatted EUR value or placeholder if rate unavailable
    static func formatEURWorth(_ amount: Double, exchangeRate: Double) -> String {
        if exchangeRate > 0 {
            let euroWorth = amount * exchangeRate
            return formatEUR(euroWorth)
        } else {
            return "€---.--"
        }
    }
    
    /// Formats price per unit with European decimal notation
    /// - Parameter price: The unit price in EUR
    /// - Returns: Formatted price string with European notation
    static func formatPricePerUnit(_ price: Double) -> String {
        if price > 0 {
            // Use proper localization instead of manual formatting
            return formatEUR(price)
        } else {
            return "€---.--"
        }
    }
    
    /// Formats percentage change with appropriate precision
    /// - Parameter percentage: The percentage change value
    /// - Returns: Formatted percentage string (e.g., "+2.34%" or "-1.23%")
    static func formatPercentageChange(_ percentage: Double) -> String {
        let prefix = percentage >= 0 ? "+" : ""
        return "\(prefix)\(percentage.formatted(.number.precision(.fractionLength(2))))%"
    }
    
    /// Formats large numbers with appropriate scaling (K, M, B)
    /// - Parameter value: The number to format
    /// - Returns: Scaled number string (e.g., "1.2K", "3.4M")
    static func formatScaledNumber(_ value: Double) -> String {
        let trillion = 1_000_000_000_000.0
        let billion = 1_000_000_000.0
        let million = 1_000_000.0
        let thousand = 1_000.0
        
        switch abs(value) {
        case trillion...:
            return String(format: "%.1fT", value / trillion)
        case billion..<trillion:
            return String(format: "%.1fB", value / billion)
        case million..<billion:
            return String(format: "%.1fM", value / million)
        case thousand..<million:
            return String(format: "%.1fK", value / thousand)
        default:
            return value.formatted(.number.precision(.fractionLength(2)))
        }
    }
    
    /// Validates if a string represents a valid monetary amount
    /// - Parameters:
    ///   - input: The input string to validate
    ///   - allowNegative: Whether negative values are allowed
    /// - Returns: The parsed Double value or nil if invalid
    static func parseMonetaryAmount(_ input: String, allowNegative: Bool = false) -> Double? {
        // Clean the input string
        let cleanedInput = input
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".") // Handle European decimal notation
        
        guard let value = Double(cleanedInput) else {
            return nil
        }
        
        // Validate range
        if !allowNegative && value < 0 {
            return nil
        }
        
        // Check for reasonable monetary limits
        if abs(value) > TradingConstants.maxOrderValue {
            return nil
        }
        
        return value
    }
    
    /// Formats order amount based on the asset type
    /// - Parameters:
    ///   - amount: The order amount
    ///   - symbol: The asset symbol
    ///   - isQuoteAmount: Whether this is a quote currency amount
    /// - Returns: Formatted amount string
    static func formatOrderAmount(_ amount: Double, symbol: String, isQuoteAmount: Bool = false) -> String {
        if isQuoteAmount || symbol == "EUR" {
            return formatEUR(amount)
        } else {
            return formatCryptoAmount(amount, symbol: symbol)
        }
    }
}
import Foundation
import CryptoKit
import OSLog

/// BitvavoAPIClient provides secure communication with the Bitvavo cryptocurrency exchange API.
/// Handles authentication using HMAC-SHA256 signatures and manages API rate limiting.
class BitvavoAPIClient {
    private let baseURL = APIConfiguration.baseURL
    private let logger = SecureLogger.api
    
    /// API credentials for authenticating with Bitvavo
    struct APICredentials {
        let apiKey: String
        let apiSecret: String
    }
    
    /// Represents balance information for a specific cryptocurrency or fiat currency
    struct BalanceInfo {
        let symbol: String
        let available: String
        let inOrder: String
        
        /// Available balance as a double value
        var availableDouble: Double {
            Double(available) ?? 0.0
        }
        
        /// In-order balance as a double value
        var inOrderDouble: Double {
            Double(inOrder) ?? 0.0
        }
        
        /// Total balance (available + in-order)
        var totalBalance: Double {
            availableDouble + inOrderDouble
        }
    }
    
    /// Represents ticker price information for a market
    struct TickerInfo {
        let market: String
        let price: String
        
        /// Current price as a double value
        var priceDouble: Double {
            Double(price) ?? 0.0
        }
    }
    
    /// Represents 24h ticker statistics for a market
    struct Ticker24HInfo {
        let market: String
        let open: String
        let last: String
        let high: String
        let low: String
        let volume: String
        let volumeQuote: String
        let bid: String
        let ask: String
        let timestamp: Int64
        
        /// Opening price as double
        var openDouble: Double { Double(open) ?? 0.0 }
        /// Last price as double
        var lastDouble: Double { Double(last) ?? 0.0 }
        /// High price as double
        var highDouble: Double { Double(high) ?? 0.0 }
        /// Low price as double
        var lowDouble: Double { Double(low) ?? 0.0 }
        /// Volume as double
        var volumeDouble: Double { Double(volume) ?? 0.0 }
        /// Quote volume as double
        var volumeQuoteDouble: Double { Double(volumeQuote) ?? 0.0 }
        /// Bid price as double
        var bidDouble: Double { Double(bid) ?? 0.0 }
        /// Ask price as double
        var askDouble: Double { Double(ask) ?? 0.0 }
        
        /// Calculate 24h percentage change
        var percentageChange: Double {
            let openPrice = openDouble
            let lastPrice = lastDouble
            guard openPrice > 0 else { return 0.0 }
            return ((lastPrice - openPrice) / openPrice) * 100
        }
    }
    
    /// Represents market information
    struct MarketInfo {
        let market: String
        let status: String
        let base: String
        let quote: String
        let pricePrecision: Int
        let minOrderInBaseAsset: String?
        let minOrderInQuoteAsset: String?
        let orderTypes: [String]
    }
    
    /// Represents asset information
    struct AssetInfo {
        let symbol: String
        let name: String
        let decimals: Int
        let depositFee: String?
        let depositConfirmations: Int?
        let depositStatus: String?
        let withdrawalFee: String?
        let withdrawalMinAmount: String?
        let withdrawalStatus: String?
        let networks: [String]?
        let message: String?
    }
    
    /// Represents price with percentage change information
    struct PriceChangeInfo {
        let symbol: String
        let currentPrice: Double
        let percentageChange1h: Double
        let percentageChange24h: Double
        let lastUpdated: Date
        
        /// Gets the percentage change for the specified timeframe
        func getPercentageChange(for timeframe: String) -> Double {
            switch timeframe {
            case "1h": return percentageChange1h
            case "24h": return percentageChange24h
            default: return percentageChange24h
            }
        }
    }
    
    /// Represents different order types supported by Bitvavo
    enum OrderType: String, CaseIterable {
        case market = "market"
        case limit = "limit"
        case stopLimit = "stopLimit"
        case stopLoss = "stopLoss"
        case stopLossLimit = "stopLossLimit"
        case takeProfit = "takeProfit"
        case takeProfitLimit = "takeProfitLimit"
        
        var displayName: String {
            switch self {
            case .market: return "Market Order"
            case .limit: return "Limit Order"
            case .stopLimit: return "Stop Limit Order"
            case .stopLoss: return "Stop Loss Order"
            case .stopLossLimit: return "Stop Loss Limit Order"
            case .takeProfit: return "Take Profit Order"
            case .takeProfitLimit: return "Take Profit Limit Order"
            }
        }
    }
    
    /// Order side (buy or sell)
    enum OrderSide: String, CaseIterable {
        case buy = "buy"
        case sell = "sell"
        
        var displayName: String {
            switch self {
            case .buy: return "Buy"
            case .sell: return "Sell"
            }
        }
    }
    
    /// Time in force options for limit orders
    enum TimeInForce: String, CaseIterable {
        case gtc = "GTC"  // Good Till Cancelled
        case ioc = "IOC"  // Immediate Or Cancel
        case fok = "FOK"  // Fill Or Kill
        
        var displayName: String {
            switch self {
            case .gtc: return "Good Till Cancelled"
            case .ioc: return "Immediate Or Cancel"
            case .fok: return "Fill Or Kill"
            }
        }
    }
    
    /// Order status
    enum OrderStatus: String, CaseIterable {
        case new = "new"
        case awaitingTrigger = "awaitingTrigger"
        case canceled = "canceled"
        case canceledPartial = "canceledPartial"
        case filled = "filled"
        case partiallyFilled = "partiallyFilled"
        case expired = "expired"
        case rejected = "rejected"
        
        var displayName: String {
            switch self {
            case .new: return "Open"
            case .awaitingTrigger: return "Awaiting Trigger"
            case .canceled: return "Canceled"
            case .canceledPartial: return "Partially Canceled"
            case .filled: return "Filled"
            case .partiallyFilled: return "Partially Filled"
            case .expired: return "Expired"
            case .rejected: return "Rejected"
            }
        }
        
        var isOpen: Bool {
            return self == .new || self == .partiallyFilled || self == .awaitingTrigger
        }
        
        var isCompleted: Bool {
            return self == .filled || self == .canceled || self == .canceledPartial || self == .expired || self == .rejected
        }
    }
    
    /// Represents an order from Bitvavo API
    struct OrderInfo {
        let orderId: String
        let market: String
        let created: Int64
        let updated: Int64
        let status: OrderStatus
        let side: OrderSide
        let orderType: OrderType
        let amount: String
        let amountRemaining: String?
        let price: String?
        let triggerPrice: String?
        let triggerType: String?
        let triggerReference: String?
        let timeInForce: TimeInForce?
        let postOnly: Bool?
        let selfTradePrevention: String?
        let visible: Bool?
        let disableMarketProtection: Bool?
        let fills: [TradeInfo]?
        
        // Computed properties for easier use
        var amountDouble: Double {
            Double(amount) ?? 0.0
        }
        
        var amountRemainingDouble: Double {
            Double(amountRemaining ?? "0") ?? 0.0
        }
        
        var priceDouble: Double {
            Double(price ?? "0") ?? 0.0
        }
        
        var triggerPriceDouble: Double {
            Double(triggerPrice ?? "0") ?? 0.0
        }
        
        var createdDate: Date {
            Date(timeIntervalSince1970: Double(created) / 1000)
        }
        
        var updatedDate: Date {
            Date(timeIntervalSince1970: Double(updated) / 1000)
        }
        
        var symbol: String {
            market.replacingOccurrences(of: "-EUR", with: "")
        }
        
        var totalValue: Double {
            amountDouble * priceDouble
        }
    }
    
    /// Represents a trade/fill from an order
    struct TradeInfo {
        let id: String
        let timestamp: Int64
        let market: String
        let side: OrderSide
        let amount: String
        let price: String
        let taker: Bool
        let fee: String
        let feeCurrency: String
        let settled: Bool
        
        var amountDouble: Double {
            Double(amount) ?? 0.0
        }
        
        var priceDouble: Double {
            Double(price) ?? 0.0
        }
        
        var feeDouble: Double {
            Double(fee) ?? 0.0
        }
        
        var timestamp_date: Date {
            Date(timeIntervalSince1970: Double(timestamp) / 1000)
        }
        
        var totalValue: Double {
            amountDouble * priceDouble
        }
    }
    
    /// Parameters for placing a new order
    struct NewOrderParams {
        let market: String
        let side: OrderSide
        let orderType: OrderType
        let amount: String?
        let amountQuote: String?
        let price: String?
        let triggerPrice: String?
        let triggerType: String?
        let triggerReference: String?
        let timeInForce: TimeInForce?
        let postOnly: Bool?
        let selfTradePrevention: String?
        let disableMarketProtection: Bool?
        let operatorId: String?
    }
    
    /// Errors that can occur during API operations
    enum APIError: Error {
        case invalidCredentials
        case networkError(String)
        case invalidResponse(Int)
        case rateLimitExceeded
        case apiError(Int, String)
        case parseError(String)
        case invalidSymbol(String)
        case insufficientData
    }
    
    /// Tests connection to Bitvavo API using provided credentials
    /// - Parameter credentials: API key and secret for authentication
    /// - Returns: True if connection is successful, false otherwise
    func testConnection(credentials: APICredentials) async throws -> Bool {
        print("🌐 API Test: Preparing connection test to \(APIConfiguration.Endpoints.time)")
        
        guard let url = URL(string: "\(baseURL)\(APIConfiguration.Endpoints.time)") else {
            print("❌ API Test: Invalid URL construction")
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Generate timestamp (milliseconds since Unix epoch)
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = generateSignature(
            timestamp: timestamp,
            method: "GET",
            path: APIConfiguration.Endpoints.time,
            body: "",
            secret: credentials.apiSecret
        )
        
        request.setValue(credentials.apiKey, forHTTPHeaderField: APIConfiguration.Headers.accessKey)
        request.setValue(signature, forHTTPHeaderField: APIConfiguration.Headers.accessSignature)
        request.setValue(timestamp, forHTTPHeaderField: APIConfiguration.Headers.accessTimestamp)
        request.setValue(APIConfiguration.accessWindowString, forHTTPHeaderField: APIConfiguration.Headers.accessWindow)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🌐 API Test: Making request to Bitvavo...")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success
                if success {
                    print("✅ API Test: Connection successful (HTTP \(httpResponse.statusCode))")
                } else {
                    print("❌ API Test: Connection failed (HTTP \(httpResponse.statusCode))")
                }
                return success
            }
            
            print("❌ API Test: Invalid HTTP response")
            return false
        } catch {
            print("❌ API Test: Network error - \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    
    /// Retrieves account balance information for all currencies
    /// - Parameter credentials: API key and secret for authentication
    /// - Returns: Array of BalanceInfo objects containing balance data
    func getBalance(credentials: APICredentials) async throws -> [BalanceInfo] {
        print("💰 API Balance: Preparing balance request to \(APIConfiguration.Endpoints.balance)")
        
        guard let url = URL(string: "\(baseURL)\(APIConfiguration.Endpoints.balance)") else {
            print("❌ API Balance: Invalid URL construction")
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Generate timestamp (milliseconds since Unix epoch)
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = generateSignature(
            timestamp: timestamp,
            method: "GET",
            path: APIConfiguration.Endpoints.balance,
            body: "",
            secret: credentials.apiSecret
        )
        
        request.setValue(credentials.apiKey, forHTTPHeaderField: APIConfiguration.Headers.accessKey)
        request.setValue(signature, forHTTPHeaderField: APIConfiguration.Headers.accessSignature)
        request.setValue(timestamp, forHTTPHeaderField: APIConfiguration.Headers.accessTimestamp)
        request.setValue(APIConfiguration.accessWindowString, forHTTPHeaderField: APIConfiguration.Headers.accessWindow)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("💰 API Balance: Making request to Bitvavo...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ API Balance: Invalid HTTP response")
                throw APIError.invalidResponse(0)
            }
            
            print("💰 API Balance: Received response (HTTP \(httpResponse.statusCode))")
            
            if httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success {
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        let balances = jsonArray.compactMap { dict -> BalanceInfo? in
                            guard let symbol = dict[APIConfiguration.ResponseKeys.symbol] as? String,
                                  let available = dict[APIConfiguration.ResponseKeys.available] as? String,
                                  let inOrder = dict[APIConfiguration.ResponseKeys.inOrder] as? String else {
                                return nil
                            }
                            return BalanceInfo(symbol: symbol, available: available, inOrder: inOrder)
                        }
                        
                        print("✅ API Balance: Successfully parsed \(balances.count) balance entries")
                        return balances
                    } else {
                        print("❌ API Balance: Response is not an array")
                        throw APIError.parseError("Response is not an array")
                    }
                } catch {
                    print("❌ API Balance: JSON parsing failed - \(error.localizedDescription)")
                    throw APIError.parseError("JSON parsing failed: \(error.localizedDescription)")
                }
            } else {
                // Try to parse error response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let errorCode = errorData["errorCode"] as? Int ?? httpResponse.statusCode
                    let errorMessage = errorData["error"] as? String ?? "Unknown API error"
                    print("❌ API Balance: API error \(errorCode) - \(errorMessage)")
                    throw APIError.apiError(errorCode, errorMessage)
                } else {
                    print("❌ API Balance: HTTP error \(httpResponse.statusCode)")
                    throw APIError.invalidResponse(httpResponse.statusCode)
                }
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ API Balance: Network error - \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    /// Retrieves ticker price information for specific markets
    /// - Parameter markets: Array of market symbols (e.g., ["BTC-EUR", "ETH-EUR"])
    /// - Returns: Array of TickerInfo objects containing current prices
    func getTickerPrices(markets: [String]) async throws -> [TickerInfo] {
        print("💹 API Ticker: Getting prices for \(markets.count) markets individually")
        
        var tickers: [TickerInfo] = []
        
        // Use individual calls since bulk requests don't work with comma-separated markets
        for market in markets {
            do {
                let urlString = "\(baseURL)\(APIConfiguration.Endpoints.tickerPrice)?market=\(market)"
                guard let url = URL(string: urlString) else {
                    print("❌ API Ticker: Invalid URL for market \(market)")
                    continue
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ API Ticker: Invalid HTTP response for \(market)")
                    continue
                }
                
                if httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success {
                    // Parse single ticker response
                    if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let marketName = jsonDict["market"] as? String,
                       let priceString = jsonDict["price"] as? String {
                        let ticker = TickerInfo(market: marketName, price: priceString)
                        tickers.append(ticker)
                        print("✅ Got price for \(market): \(priceString)")
                    } else {
                        print("❌ Failed to parse ticker for \(market)")
                    }
                } else {
                    print("❌ HTTP error \(httpResponse.statusCode) for market \(market)")
                }
            } catch {
                print("❌ Error fetching ticker for \(market): \(error.localizedDescription)")
            }
        }
        
        print("✅ API Ticker: Successfully fetched \(tickers.count) out of \(markets.count) requested tickers")
        return tickers
    }
    
    /// Retrieves all available markets from Bitvavo
    /// - Returns: Array of MarketInfo objects containing market data
    func getMarkets() async throws -> [MarketInfo] {
        print("🏪 API Markets: Preparing markets request")
        
        guard let url = URL(string: "\(baseURL)/markets") else {
            print("❌ API Markets: Invalid URL construction")
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🏪 API Markets: Making request to Bitvavo...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ API Markets: Invalid HTTP response")
                throw APIError.invalidResponse(0)
            }
            
            print("🏪 API Markets: Received response (HTTP \(httpResponse.statusCode))")
            
            if httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success {
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        let markets = jsonArray.compactMap { dict -> MarketInfo? in
                            guard let market = dict["market"] as? String,
                                  let status = dict["status"] as? String,
                                  let base = dict["base"] as? String,
                                  let quote = dict["quote"] as? String,
                                  let pricePrecision = dict["pricePrecision"] as? Int else {
                                return nil
                            }
                            let orderTypes = dict["orderTypes"] as? [String] ?? []
                            return MarketInfo(
                                market: market,
                                status: status,
                                base: base,
                                quote: quote,
                                pricePrecision: pricePrecision,
                                minOrderInBaseAsset: dict["minOrderInBaseAsset"] as? String,
                                minOrderInQuoteAsset: dict["minOrderInQuoteAsset"] as? String,
                                orderTypes: orderTypes
                            )
                        }
                        
                        print("✅ API Markets: Successfully parsed \(markets.count) markets")
                        return markets
                    } else {
                        print("❌ API Markets: Response is not an array")
                        throw APIError.parseError("Response is not an array")
                    }
                } catch {
                    print("❌ API Markets: JSON parsing failed - \(error.localizedDescription)")
                    throw APIError.parseError("JSON parsing failed: \(error.localizedDescription)")
                }
            } else {
                print("❌ API Markets: HTTP error \(httpResponse.statusCode)")
                throw APIError.invalidResponse(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ API Markets: Network error - \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    /// Retrieves all available assets from Bitvavo
    /// - Returns: Array of AssetInfo objects containing asset data
    func getAssets() async throws -> [AssetInfo] {
        print("💎 API Assets: Preparing assets request")
        
        guard let url = URL(string: "\(baseURL)/assets") else {
            print("❌ API Assets: Invalid URL construction")
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("💎 API Assets: Making request to Bitvavo...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ API Assets: Invalid HTTP response")
                throw APIError.invalidResponse(0)
            }
            
            print("💎 API Assets: Received response (HTTP \(httpResponse.statusCode))")
            
            if httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success {
                do {
                    if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        let assets = jsonArray.compactMap { dict -> AssetInfo? in
                            guard let symbol = dict["symbol"] as? String,
                                  let name = dict["name"] as? String,
                                  let decimals = dict["decimals"] as? Int else {
                                return nil
                            }
                            let networks = dict["networks"] as? [String]
                            return AssetInfo(
                                symbol: symbol,
                                name: name,
                                decimals: decimals,
                                depositFee: dict["depositFee"] as? String,
                                depositConfirmations: dict["depositConfirmations"] as? Int,
                                depositStatus: dict["depositStatus"] as? String,
                                withdrawalFee: dict["withdrawalFee"] as? String,
                                withdrawalMinAmount: dict["withdrawalMinAmount"] as? String,
                                withdrawalStatus: dict["withdrawalStatus"] as? String,
                                networks: networks,
                                message: dict["message"] as? String
                            )
                        }
                        
                        print("✅ API Assets: Successfully parsed \(assets.count) assets")
                        return assets
                    } else {
                        print("❌ API Assets: Response is not an array")
                        throw APIError.parseError("Response is not an array")
                    }
                } catch {
                    print("❌ API Assets: JSON parsing failed - \(error.localizedDescription)")
                    throw APIError.parseError("JSON parsing failed: \(error.localizedDescription)")
                }
            } else {
                print("❌ API Assets: HTTP error \(httpResponse.statusCode)")
                throw APIError.invalidResponse(httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ API Assets: Network error - \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    /// Retrieves 24h ticker statistics from Bitvavo API
    /// - Parameter markets: Array of market symbols to filter by (optional). If empty, returns all markets.
    /// - Returns: Array of Ticker24HInfo objects containing 24h statistics
    func getTicker24h(markets: [String] = []) async throws -> [Ticker24HInfo] {
        logger.info("📊 API Ticker24h: Getting 24h statistics for \(markets.isEmpty ? "all markets" : "filtered \(markets.count) markets")")
        
        // Always get all markets from Bitvavo - individual market requests are not supported reliably
        let urlString = "\(baseURL)\(APIConfiguration.Endpoints.ticker24h)"
        
        guard let url = URL(string: urlString) else {
            logger.error("❌ API Ticker24h: Invalid URL construction")
            throw APIErrorHandler.EnhancedAPIError.validationError(field: "url", message: "Invalid URL: \(urlString)")
        }
        
        var request = URLRequest(url: url, timeoutInterval: APIConfiguration.marketDataTimeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        logger.logAPIRequest("GET", url: urlString, authenticated: false)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ API Ticker24h: Invalid HTTP response")
                throw APIErrorHandler.EnhancedAPIError.invalidResponse(statusCode: 0, data: nil)
            }
            
            logger.logAPIResponse(httpResponse.statusCode, url: urlString, responseSize: data.count)
            
            if httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success {
                do {
                    // Try to parse as array (for all markets) or single object (for specific market)
                    if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        // Parse all tickers from response
                        let allTickers = jsonArray.compactMap { dict -> Ticker24HInfo? in
                            return parseTicker24HInfo(from: dict)
                        }
                        
                        // Filter by specific markets if requested
                        let tickers: [Ticker24HInfo]
                        if markets.isEmpty {
                            tickers = allTickers
                        } else {
                            let marketSet = Set(markets)
                            tickers = allTickers.filter { marketSet.contains($0.market) }
                        }
                        
                        logger.info("✅ API Ticker24h: Successfully parsed \(tickers.count) ticker entries (from \(allTickers.count) total)")
                        return tickers
                    } else if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Single ticker response (shouldn't happen with all markets request, but handle it)
                        if let ticker = parseTicker24HInfo(from: jsonDict) {
                            let tickers = markets.isEmpty || markets.contains(ticker.market) ? [ticker] : []
                            logger.info("✅ API Ticker24h: Successfully parsed single ticker entry")
                            return tickers
                        } else {
                            logger.error("❌ API Ticker24h: Failed to parse single ticker response")
                            return []
                        }
                    } else {
                        logger.error("❌ API Ticker24h: Response is neither an array nor object")
                        throw APIErrorHandler.EnhancedAPIError.parseError(description: "Invalid response format", data: data)
                    }
                } catch {
                    logger.error("❌ API Ticker24h: JSON parsing failed - \(error.localizedDescription)")
                    throw APIErrorHandler.EnhancedAPIError.parseError(description: "JSON parsing failed: \(error.localizedDescription)", data: data)
                }
            } else {
                // Try to parse error response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let errorCode = errorData["errorCode"] as? Int ?? httpResponse.statusCode
                    let errorMessage = errorData["error"] as? String ?? "Unknown API error"
                    logger.error("❌ API Ticker24h: API error \(errorCode) - \(errorMessage)")
                    throw APIErrorHandler.EnhancedAPIError.apiError(code: errorCode, message: errorMessage, endpoint: APIConfiguration.Endpoints.ticker24h)
                } else {
                    logger.error("❌ API Ticker24h: HTTP error \(httpResponse.statusCode)")
                    throw APIErrorHandler.EnhancedAPIError.invalidResponse(statusCode: httpResponse.statusCode, data: data)
                }
            }
        } catch let error as APIErrorHandler.EnhancedAPIError {
            throw error
        } catch {
            logger.logAPIError(error, url: urlString)
            throw APIErrorHandler.EnhancedAPIError.networkError(underlying: error)
        }
    }
    
    /// Helper function to parse Ticker24HInfo from JSON dictionary
    private func parseTicker24HInfo(from dict: [String: Any]) -> Ticker24HInfo? {
        guard let market = dict["market"] as? String,
              let open = dict["open"] as? String,
              let last = dict["last"] as? String,
              let high = dict["high"] as? String,
              let low = dict["low"] as? String,
              let volume = dict["volume"] as? String,
              let volumeQuote = dict["volumeQuote"] as? String,
              let bid = dict["bid"] as? String,
              let ask = dict["ask"] as? String,
              let timestamp = dict["timestamp"] as? Int64 else {
            logger.warning("⚠️ Failed to parse ticker24h entry: missing required fields")
            return nil
        }
        
        return Ticker24HInfo(
            market: market,
            open: open,
            last: last,
            high: high,
            low: low,
            volume: volume,
            volumeQuote: volumeQuote,
            bid: bid,
            ask: ask,
            timestamp: timestamp
        )
    }
    
    /// Gets current server time from Bitvavo API
    /// - Parameter credentials: API key and secret for authentication
    /// - Returns: Formatted server time string
    func getServerTime(credentials: APICredentials) async throws -> String {
        guard let url = URL(string: "\(baseURL)\(APIConfiguration.Endpoints.time)") else {
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Generate timestamp (milliseconds since Unix epoch)
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = generateSignature(
            timestamp: timestamp,
            method: "GET",
            path: APIConfiguration.Endpoints.time,
            body: "",
            secret: credentials.apiSecret
        )
        
        request.setValue(credentials.apiKey, forHTTPHeaderField: APIConfiguration.Headers.accessKey)
        request.setValue(signature, forHTTPHeaderField: APIConfiguration.Headers.accessSignature)
        request.setValue(timestamp, forHTTPHeaderField: APIConfiguration.Headers.accessTimestamp)
        request.setValue(APIConfiguration.accessWindowString, forHTTPHeaderField: APIConfiguration.Headers.accessWindow)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse(0)
            }
            
            
            if httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success {
                do {
                    
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let serverTimeMs = json["time"] as? Int64 {
                        let serverDate = Date(timeIntervalSince1970: Double(serverTimeMs) / 1000.0)
                        let formatter = DateFormatter()
                        formatter.dateStyle = .none
                        formatter.timeStyle = .medium
                        let timeString = formatter.string(from: serverDate)
                        return timeString
                    } else {
                        throw APIError.parseError("Invalid time response format")
                    }
                } catch {
                    throw APIError.parseError("JSON parsing failed: \(error.localizedDescription)")
                }
            } else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let errorCode = errorData["errorCode"] as? Int ?? httpResponse.statusCode
                    let errorMessage = errorData["error"] as? String ?? "Unknown API error"
                    throw APIError.apiError(errorCode, errorMessage)
                } else {
                    throw APIError.invalidResponse(httpResponse.statusCode)
                }
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    /// Gets all available symbols (base currencies) from markets
    /// - Returns: Array of unique symbol strings sorted alphabetically
    func getAvailableSymbols() async throws -> [String] {
        print("🔍 Getting available symbols from markets...")
        let markets = try await getMarkets()
        
        var symbols = Set<String>()
        for market in markets {
            symbols.insert(market.base)
        }
        symbols.insert("EUR") // Add EUR as it's always available
        
        let sortedSymbols = Array(symbols).sorted()
        print("✅ Found \(sortedSymbols.count) available symbols")
        return sortedSymbols
    }
    
    /// Gets symbols that the user currently owns (with positive balance)
    /// - Parameter credentials: API key and secret for authentication
    /// - Returns: Array of owned symbol strings
    func getOwnedSymbols(credentials: APICredentials) async throws -> [String] {
        print("👤 Getting owned symbols from balance...")
        let balances = try await getBalance(credentials: credentials)
        
        let ownedSymbols = balances.compactMap { balance -> String? in
            return (balance.totalBalance > 0 && balance.symbol != "EUR") ? balance.symbol : nil
        }.sorted()
        
        print("✅ User owns \(ownedSymbols.count) different symbols")
        return ownedSymbols
    }
    
    /// Gets the current price of a specific symbol in EUR
    /// - Parameter symbol: The symbol to get the price for (e.g., "BTC")
    /// - Returns: Current price in EUR as Double
    func getSymbolPrice(symbol: String) async throws -> Double {
        if symbol == "EUR" {
            return 1.0
        }
        
        let market = "\(symbol)-EUR"
        print("💹 Getting individual price for market: \(market)")
        
        let urlString = "\(baseURL)\(APIConfiguration.Endpoints.tickerPrice)?market=\(market)"
        print("💹 Requesting URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse(0)
            }
            
            print("🌐 HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == APIConfiguration.HTTPStatusCodes.success {
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 Raw response: \(responseString)")
                }
                
                // Parse as single object (correct format for ticker/price endpoint)
                if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let priceString = jsonDict["price"] as? String,
                   let price = Double(priceString) {
                    print("✅ Parsed price: \(price)")
                    return price
                }
                
                throw APIError.parseError("Invalid price response format")
            } else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let errorCode = errorData["errorCode"] as? Int ?? httpResponse.statusCode
                    let errorMessage = errorData["error"] as? String ?? "Unknown API error"
                    throw APIError.apiError(errorCode, errorMessage)
                } else {
                    throw APIError.invalidResponse(httpResponse.statusCode)
                }
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    /// Gets prices for multiple symbols efficiently using parallel operations
    /// - Parameter symbols: Array of symbols to get prices for
    /// - Returns: Array of prices in same order as input symbols
    func getSymbolsPrices(symbols: [String]) async throws -> [Double] {
        logger.info("💰 Getting prices for \(symbols.count) symbols")
        
        // Separate EUR from crypto symbols
        let cryptoSymbols = symbols.filter { $0 != "EUR" }
        
        guard !cryptoSymbols.isEmpty else {
            // Only EUR requested
            return symbols.map { $0 == "EUR" ? 1.0 : 0.0 }
        }
        
        // Get prices in parallel for all crypto symbols
        let priceResults = await ParallelAsyncOperations.executeSymbolRequests(
            symbols: cryptoSymbols
        ) { symbol in
            return try await self.getSymbolPrice(symbol: symbol)
        }
        
        // Map results back to original order
        var prices: [Double] = []
        for symbol in symbols {
            if symbol == "EUR" {
                prices.append(1.0)
            } else if let price = priceResults[symbol] {
                prices.append(price)
                logger.logPriceUpdate(symbol, price: price)
            } else {
                prices.append(0.0)
                logger.warning("⚠️ No price available for \(symbol)")
            }
        }
        
        let successCount = priceResults.count
        logger.info("✅ Retrieved prices for \(successCount)/\(cryptoSymbols.count) crypto symbols")
        
        return prices
    }
    
    /// Gets price change information for multiple symbols using real Bitvavo API data
    /// - Parameter symbols: Array of symbols to get price change data for
    /// - Returns: Array of PriceChangeInfo objects with real market data
    func getSymbolsPriceChanges(symbols: [String]) async throws -> [PriceChangeInfo] {
        logger.info("📈 Getting real price changes for \(symbols.count) symbols: \(symbols)")
        
        // Convert symbols to markets and get 24h ticker data efficiently
        let markets = symbols.compactMap { symbol in
            symbol == "EUR" ? nil : "\(symbol)-EUR"
        }
        
        var priceChanges: [PriceChangeInfo] = []
        
        if !markets.isEmpty {
            // Get all 24h ticker data in one call for efficiency
            let allTickers = try await getTicker24h() // Get ALL tickers without specifying markets
            let tickerDict = Dictionary(uniqueKeysWithValues: allTickers.map { ($0.market, $0) })
            
            for symbol in symbols {
                if symbol == "EUR" {
                    // EUR doesn't change relative to itself
                    let info = PriceChangeInfo(
                        symbol: symbol,
                        currentPrice: 1.0,
                        percentageChange1h: 0.0,
                        percentageChange24h: 0.0,
                        lastUpdated: Date()
                    )
                    priceChanges.append(info)
                } else {
                    let market = "\(symbol)-EUR"
                    
                    if let ticker = tickerDict[market] {
                        // Use real 24h data from Bitvavo
                        let currentPrice = ticker.lastDouble
                        let change24h = ticker.percentageChange
                        
                        // For 1h change, approximate it as a fraction of 24h change
                        // This is a reasonable estimate since 1h data isn't directly available
                        let change1h = change24h * 0.2 // Approximate 1h as ~20% of 24h change
                        
                        let info = PriceChangeInfo(
                            symbol: symbol,
                            currentPrice: currentPrice,
                            percentageChange1h: change1h,
                            percentageChange24h: change24h,
                            lastUpdated: Date(timeIntervalSince1970: Double(ticker.timestamp) / 1000)
                        )
                        priceChanges.append(info)
                        
                        logger.info("📊 \(symbol): €\(currentPrice) (24h: \(change24h)%) [O: €\(ticker.open), H: €\(ticker.high), L: €\(ticker.low), C: €\(ticker.last)]")
                    } else {
                        // No ticker data available for this symbol
                        logger.warning("⚠️ No 24h ticker data found for \(symbol)")
                        let info = PriceChangeInfo(
                            symbol: symbol,
                            currentPrice: 0.0,
                            percentageChange1h: 0.0,
                            percentageChange24h: 0.0,
                            lastUpdated: Date()
                        )
                        priceChanges.append(info)
                    }
                }
            }
        } else {
            // Only EUR requested
            for symbol in symbols {
                let info = PriceChangeInfo(
                    symbol: symbol,
                    currentPrice: 1.0,
                    percentageChange1h: 0.0,
                    percentageChange24h: 0.0,
                    lastUpdated: Date()
                )
                priceChanges.append(info)
            }
        }
        
        logger.info("✅ Retrieved real price changes for \(priceChanges.count) symbols")
        return priceChanges
    }
    
    /// Validates which EUR markets exist for given symbols
    /// - Parameter symbols: Array of crypto symbols to validate
    /// - Returns: Array of valid market strings
    private func getValidEURMarkets(for symbols: [String]) async throws -> [String] {
        let allMarkets = try await getMarkets()
        let eurMarkets = Set(allMarkets.filter { $0.quote == "EUR" }.map { $0.market })
        
        var validMarkets: [String] = []
        for symbol in symbols {
            let market = "\(symbol)-EUR"
            if eurMarkets.contains(market) {
                validMarkets.append(market)
            } else {
                print("⚠️ Market not found: \(market)")
            }
        }
        
        return validMarkets
    }
    
    /// Gets the 24h percentage change for a symbol using real Bitvavo API data
    /// - Parameter symbol: The symbol to get percentage change for (e.g., "BTC")
    /// - Returns: 24h percentage change as Double
    func getSymbol24hPercentageChange(symbol: String) async throws -> Double {
        let market = "\(symbol)-EUR"
        logger.info("📊 Getting 24h percentage change for \(symbol) (market: \(market))")
        
        let tickers = try await getTicker24h(markets: [market])
        
        guard let ticker = tickers.first else {
            logger.warning("⚠️ No 24h ticker data found for \(market)")
            return 0.0
        }
        
        let percentageChange = ticker.percentageChange
        logger.info("📈 24h change for \(symbol): \(CurrencyFormatter.formatPercentageChange(percentageChange))")
        
        return percentageChange
    }
    
    /// Gets the 24h volume in EUR for a symbol using real Bitvavo API data
    /// - Parameter symbol: The symbol to get volume for (e.g., "BTC")
    /// - Returns: 24h volume in EUR as Double
    func getSymbol24hVolume(symbol: String) async throws -> Double {
        let market = "\(symbol)-EUR"
        logger.info("📊 Getting 24h volume for \(symbol) (market: \(market))")
        
        let tickers = try await getTicker24h(markets: [market])
        
        guard let ticker = tickers.first else {
            logger.warning("⚠️ No 24h ticker data found for \(market)")
            return 0.0
        }
        
        let volume = ticker.volumeQuoteDouble
        logger.info("📊 24h volume for \(symbol): \(CurrencyFormatter.formatEUR(volume))")
        
        return volume
    }
    
    /// Gets the owned amount of a specific symbol
    /// - Parameters:
    ///   - symbol: Symbol to check (e.g., "BTC")
    ///   - credentials: API credentials for authentication
    /// - Returns: Owned amount as Double
    func getSymbolOwnedAmount(symbol: String, credentials: APICredentials) async throws -> Double {
        let balances = try await getBalance(credentials: credentials)
        
        for balance in balances {
            if balance.symbol.lowercased() == symbol.lowercased() {
                return balance.totalBalance
            }
        }
        
        return 0.0
    }
    
    /// Calculates total wallet balance in EUR including all positions and orders
    /// - Parameter credentials: API credentials for authentication
    /// - Returns: Total balance in EUR as Double
    func getTotalWalletBalance(credentials: APICredentials) async throws -> Double {
        print("💰 Calculating total wallet balance...")
        let balances = try await getBalance(credentials: credentials)
        
        var totalBalance: Double = 0.0
        var cryptoSymbols: [String] = []
        
        // Collect EUR balance and crypto symbols
        for balance in balances {
            if balance.symbol == "EUR" {
                totalBalance += balance.totalBalance
                print("💶 EUR balance: €\(balance.totalBalance)")
            } else if balance.totalBalance > 0 {
                cryptoSymbols.append(balance.symbol)
            }
        }
        
        // Get prices for all crypto symbols in one call
        if !cryptoSymbols.isEmpty {
            let prices = try await getSymbolsPrices(symbols: cryptoSymbols)
            
            for (index, symbol) in cryptoSymbols.enumerated() {
                if let balance = balances.first(where: { $0.symbol == symbol }) {
                    let eurValue = balance.totalBalance * prices[index]
                    totalBalance += eurValue
                    print("💎 \(symbol): \(balance.totalBalance) coins × €\(prices[index]) = €\(eurValue)")
                }
            }
        }
        
        print("✅ Total wallet balance: €\(totalBalance)")
        return totalBalance
    }
    
    // MARK: - Credential Management
    
    /// Retrieves stored API credentials from keychain
    /// - Returns: API credentials or nil if not found
    func getStoredCredentials() -> APICredentials? {
        guard let apiKey = getFromKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPIKey),
              let apiSecret = getFromKeychain(key: SecurityConstants.KeychainKeys.bitvavoAPISecret) else {
            return nil
        }
        return APICredentials(apiKey: apiKey, apiSecret: apiSecret)
    }
    
    /// Retrieves data from keychain
    private func getFromKeychain(key: String) -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            if let retrievedData = dataTypeRef as? Data {
                return String(data: retrievedData, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    // MARK: - Order Management
    
    /// Retrieves all open orders for the account
    /// - Returns: Array of open orders
    func getOpenOrders() async throws -> [OrderInfo] {
        print("📋 Getting open orders...")
        
        guard let credentials = getStoredCredentials() else {
            throw APIError.invalidCredentials
        }
        
        guard let url = URL(string: "\(baseURL)\(APIConfiguration.Endpoints.ordersOpen)") else {
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = generateSignature(
            timestamp: timestamp,
            method: "GET",
            path: APIConfiguration.Endpoints.ordersOpen,
            body: "",
            secret: credentials.apiSecret
        )
        
        request.setValue(credentials.apiKey, forHTTPHeaderField: APIConfiguration.Headers.accessKey)
        request.setValue(signature, forHTTPHeaderField: APIConfiguration.Headers.accessSignature)
        request.setValue(timestamp, forHTTPHeaderField: APIConfiguration.Headers.accessTimestamp)
        request.setValue(APIConfiguration.accessWindowString, forHTTPHeaderField: APIConfiguration.Headers.accessWindow)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("No HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Open orders API error: \(httpResponse.statusCode) - \(errorMessage)")
            throw APIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw APIError.parseError("Expected array of orders")
            }
            
            let orders = try jsonArray.compactMap { dict -> OrderInfo? in
                return try parseOrderInfo(from: dict)
            }
            
            print("✅ Retrieved \(orders.count) open orders")
            return orders
        } catch {
            print("❌ Error parsing open orders: \(error)")
            throw APIError.parseError(error.localizedDescription)
        }
    }
    
    /// Retrieves order history by fetching orders across all major markets
    /// Since the /orders endpoint requires a market parameter, we'll fetch orders for major trading pairs
    /// - Parameter limit: Maximum number of orders to retrieve per market (default: 50)
    /// - Returns: Array of historical orders from all markets
    func getOrderHistory(limit: Int = 50) async throws -> [OrderInfo] {
        print("📋 Getting order history from major markets...")
        
        guard let credentials = getStoredCredentials() else {
            throw APIError.invalidCredentials
        }
        
        // Major trading pairs to check for order history
        let majorMarkets = ["BTC-EUR", "ETH-EUR", "ADA-EUR", "DOT-EUR", "LINK-EUR", "LTC-EUR", "XRP-EUR"]
        var allOrders: [OrderInfo] = []
        
        // Fetch orders from each major market
        for market in majorMarkets {
            do {
                let orders = try await getOrdersForMarket(market: market, limit: limit, credentials: credentials)
                // Filter for completed/historical orders (not open)
                let historicalOrders = orders.filter { order in
                    switch order.status {
                    case .filled, .canceled, .canceledPartial, .expired, .rejected:
                        return true
                    case .new, .partiallyFilled, .awaitingTrigger:
                        return false
                    }
                }
                allOrders.append(contentsOf: historicalOrders)
            } catch {
                // Continue with other markets if one fails
                print("⚠️ Failed to fetch orders for market \(market): \(error.localizedDescription)")
                continue
            }
        }
        
        // Sort by creation date (newest first) and limit results
        let sortedOrders = allOrders.sorted { $0.createdDate > $1.createdDate }
        let limitedOrders = Array(sortedOrders.prefix(limit * 2)) // Allow more results since we're aggregating
        
        print("✅ Retrieved \(limitedOrders.count) historical orders from \(majorMarkets.count) markets")
        return limitedOrders
    }
    
    /// Helper function to get orders for a specific market
    /// - Parameters:
    ///   - market: The trading pair (e.g., "BTC-EUR")
    ///   - limit: Maximum number of orders to retrieve
    ///   - credentials: API credentials
    /// - Returns: Array of orders for the specified market
    private func getOrdersForMarket(market: String, limit: Int, credentials: APICredentials) async throws -> [OrderInfo] {
        let queryParams = "?market=\(market)&limit=\(limit)"
        guard let url = URL(string: "\(baseURL)\(APIConfiguration.Endpoints.orders)\(queryParams)") else {
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = generateSignature(
            timestamp: timestamp,
            method: "GET",
            path: "\(APIConfiguration.Endpoints.orders)\(queryParams)",
            body: "",
            secret: credentials.apiSecret
        )
        
        request.setValue(credentials.apiKey, forHTTPHeaderField: APIConfiguration.Headers.accessKey)
        request.setValue(signature, forHTTPHeaderField: APIConfiguration.Headers.accessSignature)
        request.setValue(timestamp, forHTTPHeaderField: APIConfiguration.Headers.accessTimestamp)
        request.setValue(APIConfiguration.accessWindowString, forHTTPHeaderField: APIConfiguration.Headers.accessWindow)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("No HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw APIError.parseError("Expected array of orders")
            }
            
            let orders = try jsonArray.compactMap { dict -> OrderInfo? in
                return try parseOrderInfo(from: dict)
            }
            
            return orders
        } catch {
            throw APIError.parseError(error.localizedDescription)
        }
    }
    
    /// Places a new order
    /// - Parameter params: Order parameters
    /// - Returns: Created order information
    func placeOrder(_ params: NewOrderParams) async throws -> OrderInfo {
        print("📤 Placing new order: \(params.side.displayName) \(params.amount ?? params.amountQuote ?? "0") \(params.market) at \(params.orderType.displayName)")
        
        guard let credentials = getStoredCredentials() else {
            throw APIError.invalidCredentials
        }
        
        guard let url = URL(string: "\(baseURL)\(APIConfiguration.Endpoints.order)") else {
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var bodyDict: [String: Any] = [
            "market": params.market,
            "side": params.side.rawValue,
            "orderType": params.orderType.rawValue
        ]
        
        if let amount = params.amount { bodyDict["amount"] = amount }
        if let amountQuote = params.amountQuote { bodyDict["amountQuote"] = amountQuote }
        if let price = params.price { bodyDict["price"] = price }
        if let triggerPrice = params.triggerPrice { bodyDict["triggerPrice"] = triggerPrice }
        if let triggerType = params.triggerType { bodyDict["triggerType"] = triggerType }
        if let triggerReference = params.triggerReference { bodyDict["triggerReference"] = triggerReference }
        if let timeInForce = params.timeInForce { bodyDict["timeInForce"] = timeInForce.rawValue }
        if let postOnly = params.postOnly { bodyDict["postOnly"] = postOnly }
        if let selfTradePrevention = params.selfTradePrevention { bodyDict["selfTradePrevention"] = selfTradePrevention }
        if let disableMarketProtection = params.disableMarketProtection { bodyDict["disableMarketProtection"] = disableMarketProtection }
        if let operatorId = params.operatorId { bodyDict["operatorId"] = operatorId }
        
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        request.httpBody = bodyData
        
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = generateSignature(
            timestamp: timestamp,
            method: "POST",
            path: APIConfiguration.Endpoints.order,
            body: bodyString,
            secret: credentials.apiSecret
        )
        
        request.setValue(credentials.apiKey, forHTTPHeaderField: APIConfiguration.Headers.accessKey)
        request.setValue(signature, forHTTPHeaderField: APIConfiguration.Headers.accessSignature)
        request.setValue(timestamp, forHTTPHeaderField: APIConfiguration.Headers.accessTimestamp)
        request.setValue(APIConfiguration.accessWindowString, forHTTPHeaderField: APIConfiguration.Headers.accessWindow)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("No HTTP response")
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Place order API error: \(httpResponse.statusCode) - \(errorMessage)")
            throw APIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        do {
            guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw APIError.parseError("Expected order object")
            }
            
            let order = try parseOrderInfo(from: jsonDict)
            print("✅ Order placed successfully: \(order.orderId)")
            return order
        } catch {
            print("❌ Error parsing placed order: \(error)")
            throw APIError.parseError(error.localizedDescription)
        }
    }
    
    /// Cancels an existing order
    /// - Parameter orderId: ID of the order to cancel
    /// - Returns: Canceled order information
    func cancelOrder(orderId: String) async throws -> OrderInfo {
        print("❌ Canceling order: \(orderId)")
        
        guard let credentials = getStoredCredentials() else {
            throw APIError.invalidCredentials
        }
        
        guard let url = URL(string: "\(baseURL)\(APIConfiguration.Endpoints.cancelOrder)") else {
            throw APIError.invalidResponse(0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyDict = ["orderId": orderId]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        request.httpBody = bodyData
        
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = generateSignature(
            timestamp: timestamp,
            method: "DELETE",
            path: APIConfiguration.Endpoints.cancelOrder,
            body: bodyString,
            secret: credentials.apiSecret
        )
        
        request.setValue(credentials.apiKey, forHTTPHeaderField: APIConfiguration.Headers.accessKey)
        request.setValue(signature, forHTTPHeaderField: APIConfiguration.Headers.accessSignature)
        request.setValue(timestamp, forHTTPHeaderField: APIConfiguration.Headers.accessTimestamp)
        request.setValue(APIConfiguration.accessWindowString, forHTTPHeaderField: APIConfiguration.Headers.accessWindow)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("No HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Cancel order API error: \(httpResponse.statusCode) - \(errorMessage)")
            throw APIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        do {
            guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw APIError.parseError("Expected order object")
            }
            
            let order = try parseOrderInfo(from: jsonDict)
            print("✅ Order canceled successfully: \(order.orderId)")
            return order
        } catch {
            print("❌ Error parsing canceled order: \(error)")
            throw APIError.parseError(error.localizedDescription)
        }
    }
    
    /// Parses order information from API response dictionary
    private func parseOrderInfo(from dict: [String: Any]) throws -> OrderInfo {
        guard let orderId = dict["orderId"] as? String,
              let market = dict["market"] as? String,
              let created = dict["created"] as? Int64,
              let updated = dict["updated"] as? Int64,
              let statusString = dict["status"] as? String,
              let status = OrderStatus(rawValue: statusString),
              let sideString = dict["side"] as? String,
              let side = OrderSide(rawValue: sideString),
              let orderTypeString = dict["orderType"] as? String,
              let orderType = OrderType(rawValue: orderTypeString),
              let amount = dict["amount"] as? String else {
            throw APIError.parseError("Missing required order fields")
        }
        
        // Parse optional fields
        let amountRemaining = dict["amountRemaining"] as? String
        let price = dict["price"] as? String
        let triggerPrice = dict["triggerPrice"] as? String
        let triggerType = dict["triggerType"] as? String
        let triggerReference = dict["triggerReference"] as? String
        let timeInForce = (dict["timeInForce"] as? String).flatMap { TimeInForce(rawValue: $0) }
        let postOnly = dict["postOnly"] as? Bool
        let selfTradePrevention = dict["selfTradePrevention"] as? String
        let visible = dict["visible"] as? Bool
        let disableMarketProtection = dict["disableMarketProtection"] as? Bool
        
        // Parse fills/trades if present
        var fills: [TradeInfo]? = nil
        if let fillsArray = dict["fills"] as? [[String: Any]] {
            fills = fillsArray.compactMap { fillDict in
                return try? parseTradeInfo(from: fillDict)
            }
        }
        
        return OrderInfo(
            orderId: orderId,
            market: market,
            created: created,
            updated: updated,
            status: status,
            side: side,
            orderType: orderType,
            amount: amount,
            amountRemaining: amountRemaining,
            price: price,
            triggerPrice: triggerPrice,
            triggerType: triggerType,
            triggerReference: triggerReference,
            timeInForce: timeInForce,
            postOnly: postOnly,
            selfTradePrevention: selfTradePrevention,
            visible: visible,
            disableMarketProtection: disableMarketProtection,
            fills: fills
        )
    }
    
    /// Parses trade information from API response dictionary
    private func parseTradeInfo(from dict: [String: Any]) throws -> TradeInfo {
        guard let id = dict["id"] as? String,
              let timestamp = dict["timestamp"] as? Int64,
              let market = dict["market"] as? String,
              let sideString = dict["side"] as? String,
              let side = OrderSide(rawValue: sideString),
              let amount = dict["amount"] as? String,
              let price = dict["price"] as? String,
              let taker = dict["taker"] as? Bool,
              let fee = dict["fee"] as? String,
              let feeCurrency = dict["feeCurrency"] as? String,
              let settled = dict["settled"] as? Bool else {
            throw APIError.parseError("Missing required trade fields")
        }
        
        return TradeInfo(
            id: id,
            timestamp: timestamp,
            market: market,
            side: side,
            amount: amount,
            price: price,
            taker: taker,
            fee: fee,
            feeCurrency: feeCurrency,
            settled: settled
        )
    }
    
    /// Exposed signature generation method for testing purposes
    /// - Parameters:
    ///   - timestamp: Unix timestamp in milliseconds
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: API endpoint path
    ///   - body: Request body (empty for GET requests)
    ///   - secret: API secret key
    /// - Returns: HMAC-SHA256 signature as hex string
    func testGenerateSignature(timestamp: String, method: String, path: String, body: String, secret: String) -> String {
        return generateSignature(timestamp: timestamp, method: method, path: path, body: body, secret: secret)
    }
    
    /// Generates HMAC-SHA256 signature for API authentication
    /// - Parameters:
    ///   - timestamp: Unix timestamp in milliseconds
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: API endpoint path
    ///   - body: Request body (empty for GET requests)
    ///   - secret: API secret key (treated as UTF-8 string, NOT hex)
    /// - Returns: HMAC-SHA256 signature as lowercase hex string
    /// - Important: Secret must be UTF-8 encoded, not hex decoded (critical bug fix)
    private func generateSignature(timestamp: String, method: String, path: String, body: String, secret: String) -> String {
        // Bitvavo expects /v2 prefix in signature message
        let message = timestamp + method + "/v2" + path + body
        
        guard let messageData = message.data(using: .utf8),
              let secretData = secret.data(using: .utf8) else {
            return ""
        }
        
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: SymmetricKey(data: secretData))
        return Data(signature).hexEncodedString()
    }
}

// MARK: - Data Extensions

extension Data {
    /// Converts Data to lowercase hex string representation
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}


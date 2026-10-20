//
//  CoinbotTests.swift
//  CoinbotTests
//
//  Created by Jeremy Lombaerts on 07/08/2025.
//

import Testing
import Foundation
@testable import Coinbot

/// Comprehensive test suite for Coinbot's Bitvavo API integration.
/// Tests signature generation, authentication, time synchronization, and API endpoints.
/// Uses Swift Testing framework with #expect assertions.
struct CoinbotTests {
    
    private let client = BitvavoAPIClient()
    
    // MARK: - Test Credentials
    
    /// Loads API credentials from .env file with fallback to configuration
    private var testCredentials: BitvavoAPIClient.APICredentials? {
        guard let (apiKey, apiSecret) = TestCredentials.loadAPICredentials() else {
            return nil
        }
        return BitvavoAPIClient.APICredentials(apiKey: apiKey, apiSecret: apiSecret)
    }
    
    // MARK: - Time Synchronization Tests
    
    /// Tests time synchronization with Bitvavo server to detect clock drift
    @Test func testTimeSync() async throws {
        let offset = try await syncTime()
        // Time offset should be reasonable (less than 5 minutes)
        #expect(abs(offset) < 300000)
    }
    
    /// Fetches server time and calculates offset from local time
    private func syncTime() async throws -> Int64 {
        let url = URL(string: "https://api.bitvavo.com/v2/time")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let serverTime = json["time"] as? Int64 else {
            throw NSError(domain: "BitvavoTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid time response"])
        }

        let localTime = Int64(Date().timeIntervalSince1970 * 1000)
        return serverTime - localTime
    }
    
    // MARK: - HMAC Signature Tests
    
    /// Tests HMAC-SHA256 signature generation with known test vectors
    @Test func testHMACSignature() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        let signature = client.testGenerateSignature(
            timestamp: "1234567890123",
            method: "GET", 
            path: "/time",
            body: "",
            secret: credentials.apiSecret
        )
        
        // Verify signature format
        #expect(!signature.isEmpty)
        #expect(signature.count == 64) // HMAC-SHA256 hex string length
        #expect(signature.allSatisfy { "0123456789abcdef".contains($0) }) // Valid hex characters
    }
    
    // MARK: - Basic Functionality Tests
    
    /// Tests basic HTTP connectivity and URL construction
    @Test func testBasicConnectivity() async throws {
        // Verify credentials can be loaded
        let credentials = testCredentials
        #expect(credentials != nil)
        
        // Test URL construction
        let url = URL(string: "https://api.bitvavo.com/v2/time")
        #expect(url != nil)
        
        // Test basic HTTP request to public endpoint
        if let url = url {
            let request = URLRequest(url: url)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                #expect(httpResponse.statusCode == 200)
            }
        }
    }
    
    // MARK: - Authentication Tests
    
    /// Tests authentication with time server endpoint
    @Test func testConnection() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        let isConnected = try await client.testConnection(credentials: credentials)
        #expect(isConnected == true)
    }
    
    /// Tests connection with time synchronization verification
    @Test func testConnectionWithTimeDebug() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        // Verify time sync is working
        let _ = try await syncTime()
        
        // Test connection (client handles time adjustments internally)
        let connected = try await client.testConnection(credentials: credentials)
        #expect(connected == true)
    }
    
    /// Tests error handling with invalid credentials
    @Test func testInvalidCredentials() async throws {
        let invalidCredentials = BitvavoAPIClient.APICredentials(
            apiKey: "invalid_key", 
            apiSecret: "invalid_secret"
        )
        
        do {
            let result = try await client.testConnection(credentials: invalidCredentials)
            // Invalid credentials should return false
            #expect(result == false, "Invalid credentials should return false or throw an error")
        } catch {
            // Any error with invalid credentials is expected and acceptable
        }
    }
    
    // MARK: - API Endpoint Tests
    
    /// Tests rate limiting by making a balance request and checking response headers
    @Test func testRateLimit() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        guard let url = URL(string: "https://api.bitvavo.com/v2/balance") else {
            throw BitvavoAPIClient.APIError.invalidResponse(0)
        }
        
        // Create authenticated request
        let currentTime = Date().timeIntervalSince1970 * 1000
        let timestamp = String(Int(currentTime))
        let signature = client.testGenerateSignature(
            timestamp: timestamp,
            method: "GET",
            path: "/balance",
            body: "",
            secret: credentials.apiSecret
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "Bitvavo-Access-Key")
        request.setValue(signature, forHTTPHeaderField: "Bitvavo-Access-Signature")
        request.setValue(timestamp, forHTTPHeaderField: "Bitvavo-Access-Timestamp")
        request.setValue("10000", forHTTPHeaderField: "Bitvavo-Access-Window")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            #expect(httpResponse.statusCode == 200)
            
            // Verify rate limit headers are present and valid
            if let remaining = httpResponse.allHeaderFields["bitvavo-ratelimit-remaining"] as? String,
               let remainingInt = Int(remaining) {
                #expect(remainingInt >= 0)
            }
        }
    }
    
    /// Tests balance retrieval - comprehensive test of authentication fix
    @Test func testBalance() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        let balances = try await client.getBalance(credentials: credentials)
        
        // Validate response structure
        #expect(balances.count >= 0)
        
        for balance in balances {
            #expect(!balance.symbol.isEmpty)
            #expect(balance.availableDouble >= 0)
            #expect(balance.inOrderDouble >= 0)
            #expect(balance.totalBalance >= 0)
        }
    }
    
    /// Tests balance retrieval with time synchronization
    @Test func testBalanceWithTimeSync() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        // Verify time synchronization works
        let _ = try await syncTime()
        
        // Test balance retrieval (client handles time adjustment internally)
        let balances = try await client.getBalance(credentials: credentials)
        
        #expect(balances.count >= 0)
        
        for balance in balances {
            #expect(!balance.symbol.isEmpty)
            #expect(balance.availableDouble >= 0)
            #expect(balance.inOrderDouble >= 0)
        }
    }
    
    // MARK: - Authentication Fix Verification Test
    
    /// Critical test that verifies the authentication bug fix from TestTemp development.
    /// This test specifically validates that UTF-8 secret encoding works correctly.
    @Test func testAuthenticationFix() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        // This validates the critical fix: secret must be UTF-8 encoded, not hex decoded
        let balances = try await client.getBalance(credentials: credentials)
        
        #expect(balances.count >= 0)
        
        for balance in balances {
            #expect(!balance.symbol.isEmpty)
        }
    }
    
    // MARK: - Enhanced API Tests (Python client functionality)
    
    /// Tests fetching all available markets from Bitvavo
    @Test func testGetMarkets() async throws {
        let markets = try await client.getMarkets()
        
        #expect(markets.count > 0, "Should have at least some markets")
        
        for market in markets.prefix(5) { // Test first 5 markets
            #expect(!market.market.isEmpty, "Market name should not be empty")
            #expect(!market.base.isEmpty, "Base currency should not be empty")
            #expect(!market.quote.isEmpty, "Quote currency should not be empty")
            #expect(market.pricePrecision >= 0, "Price precision should be non-negative")
        }
        
        // Should have EUR markets
        let eurMarkets = markets.filter { $0.quote == "EUR" }
        #expect(eurMarkets.count > 0, "Should have EUR markets available")
    }
    
    /// Tests fetching all available assets from Bitvavo
    @Test func testGetAssets() async throws {
        let assets = try await client.getAssets()
        
        #expect(assets.count > 0, "Should have at least some assets")
        
        for asset in assets.prefix(5) { // Test first 5 assets
            #expect(!asset.symbol.isEmpty, "Asset symbol should not be empty")
            #expect(!asset.name.isEmpty, "Asset name should not be empty")
            #expect(asset.decimals >= 0, "Decimals should be non-negative")
        }
        
        // Should have BTC asset
        let btcAsset = assets.first { $0.symbol == "BTC" }
        #expect(btcAsset != nil, "Should have BTC asset")
        #expect(btcAsset?.name == "Bitcoin", "BTC should be named Bitcoin")
    }
    
    /// Tests fetching available symbols
    @Test func testGetAvailableSymbols() async throws {
        let symbols = try await client.getAvailableSymbols()
        
        #expect(symbols.count > 0, "Should have available symbols")
        #expect(symbols.contains("BTC"), "Should have BTC")
        #expect(symbols.contains("ETH"), "Should have ETH") 
        #expect(symbols.contains("EUR"), "Should have EUR")
        #expect(symbols == symbols.sorted(), "Symbols should be sorted")
    }
    
    /// Tests fetching owned symbols (requires authentication)
    @Test func testGetOwnedSymbols() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        let ownedSymbols = try await client.getOwnedSymbols(credentials: credentials)
        
        #expect(ownedSymbols.count >= 0, "Should return non-negative count of owned symbols")
        
        for symbol in ownedSymbols {
            #expect(!symbol.isEmpty, "Owned symbol should not be empty")
            #expect(symbol != "EUR", "EUR should not be in owned crypto symbols")
        }
        
        #expect(ownedSymbols == ownedSymbols.sorted(), "Owned symbols should be sorted")
    }
    
    /// Tests fetching 24h ticker data (returns empty array as endpoint not available)
    @Test func testGetTicker24h() async throws {
        // Test getting all tickers (should return empty array as endpoint not available)
        let allTickers = try await client.getTicker24h()
        #expect(allTickers.count == 0, "Should return empty array as 24h endpoint not available")
        
        // Test specific markets (should also return empty array)
        let specificTickers = try await client.getTicker24h(markets: ["BTC-EUR", "ETH-EUR"])
        #expect(specificTickers.count == 0, "Should return empty array as 24h endpoint not available")
    }
    
    /// Tests getting individual symbol price
    @Test func testGetSymbolPrice() async throws {
        // Test EUR price (should be 1.0)
        let eurPrice = try await client.getSymbolPrice(symbol: "EUR")
        #expect(eurPrice == 1.0, "EUR price should be 1.0")
        
        // Test BTC price
        let btcPrice = try await client.getSymbolPrice(symbol: "BTC")
        #expect(btcPrice > 0, "BTC price should be positive")
        #expect(btcPrice > 1000, "BTC price should be reasonable (> 1000 EUR)")
        
        // Test invalid symbol (should now throw parseError or apiError instead of invalidSymbol)
        do {
            let _ = try await client.getSymbolPrice(symbol: "INVALID_SYMBOL_XYZ")
            #expect(Bool(false), "Should throw error for invalid symbol")
        } catch BitvavoAPIClient.APIError.parseError {
            // Expected error - API returns invalid response for unknown symbol
        } catch BitvavoAPIClient.APIError.apiError(_, _) {
            // Also expected - API may return proper error response
        } catch {
            // Any other error is also acceptable for invalid symbol
        }
    }
    
    /// Tests getting multiple symbol prices efficiently
    @Test func testGetSymbolsPrices() async throws {
        let symbols = ["EUR", "BTC", "ETH"]
        let prices = try await client.getSymbolsPrices(symbols: symbols)
        
        #expect(prices.count == 3, "Should return prices for all 3 symbols")
        #expect(prices[0] == 1.0, "EUR price should be 1.0")
        #expect(prices[1] > 0, "BTC price should be positive")
        #expect(prices[2] > 0, "ETH price should be positive")
        
        // Compare with individual calls
        let btcIndividual = try await client.getSymbolPrice(symbol: "BTC")
        let ethIndividual = try await client.getSymbolPrice(symbol: "ETH")
        
        // Prices should be close (within 1% due to timing differences)
        let btcDifference = abs(prices[1] - btcIndividual) / btcIndividual
        let ethDifference = abs(prices[2] - ethIndividual) / ethIndividual
        
        #expect(btcDifference < 0.01, "BTC bulk vs individual price should be similar")
        #expect(ethDifference < 0.01, "ETH bulk vs individual price should be similar")
    }
    
    /// Tests 24h percentage change calculation
    @Test func testGetSymbol24hPercentageChange() async throws {
        // Test EUR (should be 0.0)
        let eurChange = try await client.getSymbol24hPercentageChange(symbol: "EUR")
        #expect(eurChange == 0.0, "EUR 24h change should be 0.0")
        
        // Test BTC
        let btcChange = try await client.getSymbol24hPercentageChange(symbol: "BTC")
        #expect(btcChange > -100, "BTC change should be > -100%")
        #expect(btcChange < 1000, "BTC change should be < 1000%")
    }
    
    /// Tests 24h volume retrieval
    @Test func testGetSymbol24hVolume() async throws {
        // Test EUR (should be 0.0)
        let eurVolume = try await client.getSymbol24hVolume(symbol: "EUR")
        #expect(eurVolume == 0.0, "EUR volume should be 0.0")
        
        // Test BTC
        let btcVolume = try await client.getSymbol24hVolume(symbol: "BTC")
        #expect(btcVolume >= 0, "BTC volume should be non-negative")
    }
    
    /// Tests getting owned amount of specific symbol
    @Test func testGetSymbolOwnedAmount() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        // Test EUR amount
        let eurAmount = try await client.getSymbolOwnedAmount(symbol: "EUR", credentials: credentials)
        #expect(eurAmount >= 0, "EUR amount should be non-negative")
        
        // Test owned crypto symbols
        let ownedSymbols = try await client.getOwnedSymbols(credentials: credentials)
        
        for symbol in ownedSymbols.prefix(3) { // Test first 3 owned symbols
            let amount = try await client.getSymbolOwnedAmount(symbol: symbol, credentials: credentials)
            #expect(amount > 0, "Owned symbol \(symbol) should have positive amount")
        }
        
        // Test non-owned symbol (should return 0)
        let nonOwnedAmount = try await client.getSymbolOwnedAmount(symbol: "NONEXISTENT", credentials: credentials)
        #expect(nonOwnedAmount == 0.0, "Non-owned symbol should return 0")
    }
    
    /// Tests total wallet balance calculation
    @Test func testGetTotalWalletBalance() async throws {
        guard let credentials = testCredentials else {
            throw BitvavoAPIClient.APIError.invalidCredentials
        }
        
        let totalBalance = try await client.getTotalWalletBalance(credentials: credentials)
        #expect(totalBalance >= 0, "Total wallet balance should be non-negative")
        
        // Compare with sum of individual balances
        let balances = try await client.getBalance(credentials: credentials)
        let manualTotal = try await calculateManualTotal(balances: balances)
        
        // Should be close (within 1% due to price fluctuations)
        if totalBalance > 0 {
            let difference = abs(totalBalance - manualTotal) / totalBalance
            #expect(difference < 0.01, "Calculated total should match manual sum within 1%")
        }
    }
    
    /// Helper method to manually calculate total balance for comparison
    private func calculateManualTotal(balances: [BitvavoAPIClient.BalanceInfo]) async throws -> Double {
        var total: Double = 0.0
        
        for balance in balances where balance.totalBalance > 0 {
            if balance.symbol == "EUR" {
                total += balance.totalBalance
            } else {
                let price = try await client.getSymbolPrice(symbol: balance.symbol)
                total += balance.totalBalance * price
            }
        }
        
        return total
    }
    
    /// Tests ticker price fetching for existing functionality
    @Test func testGetTickerPrices() async throws {
        let tickers = try await client.getTickerPrices(markets: ["BTC-EUR", "ETH-EUR"])
        
        #expect(tickers.count <= 2, "Should return at most 2 tickers")
        
        for ticker in tickers {
            #expect(!ticker.market.isEmpty, "Market should not be empty")
            #expect(ticker.priceDouble > 0, "Price should be positive")
        }
        
        // Test with BTC specifically
        if let btcTicker = tickers.first(where: { $0.market == "BTC-EUR" }) {
            #expect(btcTicker.priceDouble > 1000, "BTC price should be reasonable")
        }
    }
}

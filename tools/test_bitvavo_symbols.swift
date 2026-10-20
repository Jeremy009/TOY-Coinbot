#!/usr/bin/env swift

import Foundation

// MARK: - Bitvavo API Structures

struct BitvavoMarket: Codable {
    let market: String
    let status: String
    let base: String
    let quote: String
    let pricePrecision: Int
    let minOrderInBaseAsset: String?
    let minOrderInQuoteAsset: String?
    let orderTypes: [String]
    
    enum CodingKeys: String, CodingKey {
        case market, status, base, quote, pricePrecision
        case minOrderInBaseAsset, minOrderInQuoteAsset, orderTypes
    }
}

struct BitvavoAsset: Codable {
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

// MARK: - API Client

class BitvavoSymbolFetcher {
    private let baseURL = "https://api.bitvavo.com/v2"
    
    func fetchMarkets() async throws -> [BitvavoMarket] {
        guard let url = URL(string: "\(baseURL)/markets") else {
            throw URLError(.badURL)
        }
        
        print("🔍 Fetching markets from: \(url)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let markets = try JSONDecoder().decode([BitvavoMarket].self, from: data)
        print("✅ Successfully fetched \(markets.count) markets")
        
        return markets
    }
    
    func fetchAssets() async throws -> [BitvavoAsset] {
        guard let url = URL(string: "\(baseURL)/assets") else {
            throw URLError(.badURL)
        }
        
        print("🔍 Fetching assets from: \(url)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let assets = try JSONDecoder().decode([BitvavoAsset].self, from: data)
        print("✅ Successfully fetched \(assets.count) assets")
        
        return assets
    }
}

// MARK: - Main Execution

func main() async {
    print("🚀 Bitvavo Symbol Fetcher")
    print("=" * 50)
    
    let fetcher = BitvavoSymbolFetcher()
    
    do {
        // Fetch Markets
        print("\n📊 MARKETS")
        print("-" * 30)
        
        let markets = try await fetcher.fetchMarkets()
        
        // Filter EUR markets (most relevant for European users)
        let eurMarkets = markets.filter { $0.quote == "EUR" }
        print("\n💶 EUR Markets (\(eurMarkets.count) total):")
        for market in eurMarkets.sorted(by: { $0.base < $1.base }) {
            print("  \(market.base)/\(market.quote) - Status: \(market.status)")
        }
        
        // Show unique base assets
        let uniqueBases = Set(eurMarkets.map { $0.base }).sorted()
        print("\n📈 Unique EUR Base Assets (\(uniqueBases.count) total):")
        print(uniqueBases.joined(separator: ", "))
        
        // Fetch Assets
        print("\n\n🪙 ASSETS")
        print("-" * 30)
        
        let assets = try await fetcher.fetchAssets()
        
        // Show tradeable assets (those that appear in EUR markets)
        let tradeableAssets = assets.filter { asset in
            uniqueBases.contains(asset.symbol)
        }
        
        print("\n💰 Tradeable Assets with EUR (\(tradeableAssets.count) total):")
        for asset in tradeableAssets.sorted(by: { $0.symbol < $1.symbol }) {
            print("  \(asset.symbol): \(asset.name)")
        }
        
        // Generate Swift code for cryptocurrency names
        print("\n\n📝 GENERATED SWIFT CODE")
        print("-" * 50)
        print("// Cryptocurrency full names mapping")
        print("private func getCryptocurrencyName(for symbol: String) -> String {")
        print("    switch symbol {")
        
        for asset in tradeableAssets.sorted(by: { $0.symbol < $1.symbol }) {
            print("    case \"\(asset.symbol)\": return \"\(asset.name)\"")
        }
        
        print("    case \"EUR\": return \"Euro\"")
        print("    case \"USD\": return \"US Dollar\"")
        print("    case \"GBP\": return \"British Pound\"")
        print("    default: return symbol // Fallback to symbol if name not found")
        print("    }")
        print("}")
        
        // Summary
        print("\n\n📊 SUMMARY")
        print("-" * 30)
        print("Total markets: \(markets.count)")
        print("EUR markets: \(eurMarkets.count)")
        print("Total assets: \(assets.count)")
        print("Tradeable EUR assets: \(tradeableAssets.count)")
        
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
    
    print("\n✅ Done!")
}

// String repeat helper
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// Run the script
await main()
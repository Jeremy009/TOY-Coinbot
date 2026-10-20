//
//  AssetsView.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 12/08/2025.
//

import SwiftUI


struct CryptoLogoView: View {
    let symbol: String
    let size: CGFloat
    
    init(symbol: String, size: CGFloat = 32) {
        self.symbol = symbol
        self.size = size
    }
    
    private var bundledIcons: Set<String> {
        return CryptocurrencyConstants.bundledIcons
    }
    
    private var fallbackView: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.6))
            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    var body: some View {
        Group {
            if symbol == "EUR" {
                // Euro symbol
                Image(systemName: "eurosign.circle.fill")
                    .font(.system(size: size * 0.8))
                    .foregroundColor(.blue)
            } else if CryptocurrencyConstants.hasIcon(for: symbol) {
                // Bundled icon with proper mapping
                let iconName = CryptocurrencyConstants.getIconName(for: symbol)
                Image(iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Use fallback for unknown symbols
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Sorting Enums
enum AssetSortOption: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case alphabetical = "alphabetical"
    case price = "price"
    case growth = "growth"
    case value = "value"
    
    var displayName: String {
        switch self {
        case .alphabetical: return "Alphabetical"
        case .price: return "Price"
        case .growth: return "Change"
        case .value: return "Total Value"
        }
    }
    
    var iconName: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .price: return "eurosign.circle"
        case .growth: return "chart.line.uptrend.xyaxis"
        case .value: return "eurosign.square.fill"
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case ascending = "ascending"
    case descending = "descending"
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
    
    var iconName: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

struct AssetsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            AssetsViewContent()
                .environmentObject(authManager)
                .navigationTitle("Assets")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            NotificationCenter.default.post(name: .refreshAssets, object: nil)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                }
        }
    }
}

struct AssetsViewContent: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var statusText = "Ready"
    @State private var balances: [BitvavoAPIClient.BalanceInfo] = []
    @State private var isLoadingBalance = false
    @State private var balanceError: String?
    @State private var serverTime = "Loading..."
    @State private var isLoadingServerTime = false
    @State private var exchangeRates: [String: Double] = [:]
    @State private var isLoadingRates = false
    @State private var assetNames: [String: String] = [:]
    @State private var priceChanges: [String: BitvavoAPIClient.PriceChangeInfo] = [:]
    @State private var isLoadingPriceChanges = false
    
    // MARK: - Sorting State
    @AppStorage("assetsSortOptionV2") private var assetsSortOption = AssetSortOption.value
    @AppStorage("assetsSortOrderV2") private var assetsSortOrder = SortOrder.descending
    @AppStorage("availableAssetsSortOption") private var availableAssetsSortOption = AssetSortOption.alphabetical
    @AppStorage("availableAssetsSortOrder") private var availableAssetsSortOrder = SortOrder.ascending
    @State private var showingAssetsSortSheet = false
    @State private var showingAvailableAssetsSortSheet = false
    @State private var isRefreshing = false
    
    private var filteredBalances: [BitvavoAPIClient.BalanceInfo] {
        balances.filter { $0.totalBalance > TradingConstants.minBalanceThreshold }.sorted { $0.symbol < $1.symbol }
    }
    
    private var euroBalance: BitvavoAPIClient.BalanceInfo? {
        balances.first { $0.symbol == "EUR" }
    }
    
    private var cryptoBalances: [BitvavoAPIClient.BalanceInfo] {
        let filtered = balances.filter { $0.symbol != "EUR" && $0.totalBalance > TradingConstants.minBalanceThreshold }
        return sortOwnedAssets(filtered)
    }
    
    private var availableSymbols: [String] {
        // Get all symbols from assetNames (loaded from API) and sort them
        // Filter out assets without 24h ticker data
        Array(assetNames.keys).filter { symbol in
            symbol != "EUR" && priceChanges[symbol] != nil
        }.sorted()
    }
    
    private var unownedSymbols: [String] {
        // Get symbols that are available but not currently owned
        let ownedSymbols = Set(balances.filter { $0.totalBalance > TradingConstants.minBalanceThreshold }.map { $0.symbol })
        let filtered = availableSymbols.filter { !ownedSymbols.contains($0) }
        return sortAvailableAssets(filtered)
    }
    
    private var totalWalletValue: Double {
        // Calculate total EUR value of all assets
        let euroValue = euroBalance?.totalBalance ?? 0.0
        let cryptoValue = cryptoBalances.reduce(0.0) { total, balance in
            let rate = getExchangeRate(for: balance.symbol)
            return total + (balance.totalBalance * rate)
        }
        return euroValue + cryptoValue
    }
    
    private func getExchangeRate(for symbol: String) -> Double {
        return exchangeRates[symbol] ?? 0.0
    }
    
    private func getCryptocurrencyName(for symbol: String) -> String {
        // First check our cached asset names from API
        if let name = assetNames[symbol] {
            return name
        }
        
        // Use centralized mapping from constants
        return CryptocurrencyConstants.getDisplayName(for: symbol)
    }
    
    // MARK: - Sorting Methods
    private func sortOwnedAssets(_ assets: [BitvavoAPIClient.BalanceInfo]) -> [BitvavoAPIClient.BalanceInfo] {
        switch assetsSortOption {
        case .alphabetical:
            return assets.sorted { asset1, asset2 in
                let name1 = getCryptocurrencyName(for: asset1.symbol)
                let name2 = getCryptocurrencyName(for: asset2.symbol)
                return assetsSortOrder == .ascending ? name1 < name2 : name1 > name2
            }
        case .price:
            return assets.sorted { asset1, asset2 in
                let rate1 = getExchangeRate(for: asset1.symbol)
                let rate2 = getExchangeRate(for: asset2.symbol)
                
                // Put items without price data (rate = 0) at the bottom
                if rate1 == 0 && rate2 != 0 {
                    return false // asset1 goes to bottom
                }
                if rate2 == 0 && rate1 != 0 {
                    return true // asset2 goes to bottom
                }
                if rate1 == 0 && rate2 == 0 {
                    // Both have no data, sort alphabetically
                    let name1 = getCryptocurrencyName(for: asset1.symbol)
                    let name2 = getCryptocurrencyName(for: asset2.symbol)
                    return name1 < name2
                }
                
                return assetsSortOrder == .ascending ? rate1 < rate2 : rate1 > rate2
            }
        case .value:
            return assets.sorted { asset1, asset2 in
                let rate1 = getExchangeRate(for: asset1.symbol)
                let rate2 = getExchangeRate(for: asset2.symbol)
                let totalValue1 = asset1.totalBalance * rate1
                let totalValue2 = asset2.totalBalance * rate2
                
                // Put items without price data (rate = 0) at the bottom
                if rate1 == 0 && rate2 != 0 {
                    return false // asset1 goes to bottom
                }
                if rate2 == 0 && rate1 != 0 {
                    return true // asset2 goes to bottom
                }
                if rate1 == 0 && rate2 == 0 {
                    // Both have no data, sort alphabetically
                    let name1 = getCryptocurrencyName(for: asset1.symbol)
                    let name2 = getCryptocurrencyName(for: asset2.symbol)
                    return name1 < name2
                }
                
                return assetsSortOrder == .ascending ? totalValue1 < totalValue2 : totalValue1 > totalValue2
            }
        case .growth:
            return assets.sorted { asset1, asset2 in
                let priceInfo1 = priceChanges[asset1.symbol]
                let priceInfo2 = priceChanges[asset2.symbol]
                let change1 = priceInfo1?.getPercentageChange(for: "24h") ?? 0
                let change2 = priceInfo2?.getPercentageChange(for: "24h") ?? 0
                
                // Put items without price change data at the bottom
                let hasData1 = priceInfo1 != nil && priceInfo1?.currentPrice ?? 0 > 0
                let hasData2 = priceInfo2 != nil && priceInfo2?.currentPrice ?? 0 > 0
                
                if !hasData1 && hasData2 {
                    return false // asset1 goes to bottom
                }
                if !hasData2 && hasData1 {
                    return true // asset2 goes to bottom
                }
                if !hasData1 && !hasData2 {
                    // Both have no data, sort alphabetically
                    let name1 = getCryptocurrencyName(for: asset1.symbol)
                    let name2 = getCryptocurrencyName(for: asset2.symbol)
                    return name1 < name2
                }
                
                return assetsSortOrder == .ascending ? change1 < change2 : change1 > change2
            }
        }
    }
    
    private func sortAvailableAssets(_ symbols: [String]) -> [String] {
        switch availableAssetsSortOption {
        case .alphabetical:
            return symbols.sorted { symbol1, symbol2 in
                let name1 = getCryptocurrencyName(for: symbol1)
                let name2 = getCryptocurrencyName(for: symbol2)
                return availableAssetsSortOrder == .ascending ? name1 < name2 : name1 > name2
            }
        case .price:
            return symbols.sorted { symbol1, symbol2 in
                let priceInfo1 = priceChanges[symbol1]
                let priceInfo2 = priceChanges[symbol2]
                let price1 = priceInfo1?.currentPrice ?? 0
                let price2 = priceInfo2?.currentPrice ?? 0
                
                // Put items without price data at the bottom
                let hasData1 = priceInfo1 != nil && price1 > 0
                let hasData2 = priceInfo2 != nil && price2 > 0
                
                if !hasData1 && hasData2 {
                    return false // symbol1 goes to bottom
                }
                if !hasData2 && hasData1 {
                    return true // symbol2 goes to bottom
                }
                if !hasData1 && !hasData2 {
                    // Both have no data, sort alphabetically
                    let name1 = getCryptocurrencyName(for: symbol1)
                    let name2 = getCryptocurrencyName(for: symbol2)
                    return name1 < name2
                }
                
                return availableAssetsSortOrder == .ascending ? price1 < price2 : price1 > price2
            }
        case .value:
            // For available assets, "value" is the same as "price" since we don't own them
            // Sort by current price of the asset
            return symbols.sorted { symbol1, symbol2 in
                let priceInfo1 = priceChanges[symbol1]
                let priceInfo2 = priceChanges[symbol2]
                let price1 = priceInfo1?.currentPrice ?? 0
                let price2 = priceInfo2?.currentPrice ?? 0
                
                // Put items without price data at the bottom
                let hasData1 = priceInfo1 != nil && price1 > 0
                let hasData2 = priceInfo2 != nil && price2 > 0
                
                if !hasData1 && hasData2 {
                    return false // symbol1 goes to bottom
                }
                if !hasData2 && hasData1 {
                    return true // symbol2 goes to bottom
                }
                if !hasData1 && !hasData2 {
                    // Both have no data, sort alphabetically
                    let name1 = getCryptocurrencyName(for: symbol1)
                    let name2 = getCryptocurrencyName(for: symbol2)
                    return name1 < name2
                }
                
                return availableAssetsSortOrder == .ascending ? price1 < price2 : price1 > price2
            }
        case .growth:
            return symbols.sorted { symbol1, symbol2 in
                let priceInfo1 = priceChanges[symbol1]
                let priceInfo2 = priceChanges[symbol2]
                let change1 = priceInfo1?.getPercentageChange(for: "24h") ?? 0
                let change2 = priceInfo2?.getPercentageChange(for: "24h") ?? 0
                
                // Put items without price change data at the bottom
                let hasData1 = priceInfo1 != nil && priceInfo1?.currentPrice ?? 0 > 0
                let hasData2 = priceInfo2 != nil && priceInfo2?.currentPrice ?? 0 > 0
                
                if !hasData1 && hasData2 {
                    return false // symbol1 goes to bottom
                }
                if !hasData2 && hasData1 {
                    return true // symbol2 goes to bottom
                }
                if !hasData1 && !hasData2 {
                    // Both have no data, sort alphabetically
                    let name1 = getCryptocurrencyName(for: symbol1)
                    let name2 = getCryptocurrencyName(for: symbol2)
                    return name1 < name2
                }
                
                return availableAssetsSortOrder == .ascending ? change1 < change2 : change1 > change2
            }
        }
    }
    
    var body: some View {
        List {
            // Wallet Summary Section (included in list during refresh)
            if isRefreshing {
                Section {
                    WalletSummaryRowView(totalValue: totalWalletValue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color(.systemGroupedBackground))
                }
            }
            
            // Euro Balance Section
            Section("Balance") {
                if isLoadingBalance {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading balance...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else if let error = balanceError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else {
                    EuroBalanceRowView(balance: euroBalance)
                }
            }
            
            // Assets Section
            Section {
                if isLoadingBalance {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading assets...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else if let error = balanceError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else if cryptoBalances.isEmpty {
                    HStack {
                        Image(systemName: "bitcoinsign.circle")
                            .font(.title)
                            .foregroundColor(.gray)
                        Text("No crypto assets found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else {
                    ForEach(cryptoBalances, id: \.symbol) { balance in
                        AssetRowView(
                            balance: balance,
                            exchangeRate: getExchangeRate(for: balance.symbol),
                            fullName: getCryptocurrencyName(for: balance.symbol)
                        )
                    }
                }
            } header: {
                SectionHeaderView(
                    title: "Assets",
                    sortOption: assetsSortOption,
                    sortOrder: assetsSortOrder,
                    onSortTapped: { showingAssetsSortSheet = true }
                )
            }
            
            // Available Symbols Section
            Section {
                if isLoadingBalance || isLoadingPriceChanges {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(isLoadingPriceChanges ? "Loading prices..." : "Loading available assets...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else if unownedSymbols.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("You own all available assets!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else {
                    ForEach(unownedSymbols, id: \.self) { symbol in
                        AvailableAssetRowView(
                            symbol: symbol,
                            fullName: getCryptocurrencyName(for: symbol),
                            priceChangeInfo: priceChanges[symbol],
                            timeframe: "24h"
                        )
                    }
                }
            } header: {
                SectionHeaderView(
                    title: "Available Assets",
                    sortOption: availableAssetsSortOption,
                    sortOrder: availableAssetsSortOrder,
                    onSortTapped: { showingAvailableAssetsSortSheet = true }
                )
            }
        }
        .listStyle(.insetGrouped)
        .task {
            await loadAssetNames()
            await loadBalance()
            await loadServerTime()
            await loadPriceChanges()
        }
        .refreshable {
            isRefreshing = true
            await loadBalance()
            await loadServerTime()
            await loadPriceChanges()
            isRefreshing = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshAssets)) { _ in
            statusText = "Refreshing..."
            Task {
                await loadBalance()
                await loadServerTime()
                await loadPriceChanges()
            }
        }
        .sheet(isPresented: $showingAssetsSortSheet) {
            SortSelectionSheet(
                title: "Sort Assets",
                selectedOption: $assetsSortOption,
                selectedOrder: $assetsSortOrder
            )
        }
        .sheet(isPresented: $showingAvailableAssetsSortSheet) {
            SortSelectionSheet(
                title: "Sort Available Assets",
                selectedOption: $availableAssetsSortOption,
                selectedOrder: $availableAssetsSortOrder
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // Wallet Summary Row (hidden during refresh to avoid duplication)
            if !isRefreshing {
                VStack(spacing: 0) {
                    WalletSummaryRowView(totalValue: totalWalletValue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGroupedBackground))
                    Divider()
                }
            }
        }
    }
    
    private func loadBalance() async {
        guard let apiKey = authManager.getStoredAPIKey(),
              let apiSecret = authManager.getStoredAPISecret() else {
            print("❌ Balance load failed: API credentials not configured")
            await MainActor.run {
                balanceError = "API credentials not configured"
                statusText = "API credentials missing"
            }
            return
        }
        
        print("💰 Loading account balance...")
        await MainActor.run {
            isLoadingBalance = true
            balanceError = nil
            statusText = "Loading balance..."
        }
        
        let client = BitvavoAPIClient()
        let credentials = BitvavoAPIClient.APICredentials(apiKey: apiKey, apiSecret: apiSecret)
        
        do {
            let fetchedBalances = try await client.getBalance(credentials: credentials)
            print("✅ Balance loaded successfully: \(fetchedBalances.count) currencies")
            
            // Log asset details
            for balance in fetchedBalances {
                if balance.totalBalance > 0 {
                    print("💎 Asset: \(balance.symbol) = \(balance.totalBalance)")
                }
            }
            
            await MainActor.run {
                balances = fetchedBalances
                isLoadingBalance = false
                statusText = "Balance updated - \(fetchedBalances.count) currencies"
            }
            
            // Load exchange rates after balances are loaded
            await loadExchangeRates()
        } catch {
            let errorMessage: String
            if let apiError = error as? BitvavoAPIClient.APIError {
                switch apiError {
                case .invalidCredentials:
                    errorMessage = "Invalid API credentials"
                    print("❌ Balance error: Invalid API credentials")
                case .networkError(let description):
                    errorMessage = "Network: \(description)"
                    print("❌ Balance error: Network - \(description)")
                case .invalidResponse(let code):
                    errorMessage = "HTTP \(code)"
                    print("❌ Balance error: HTTP \(code)")
                case .rateLimitExceeded:
                    errorMessage = "Rate limit exceeded"
                    print("❌ Balance error: Rate limit exceeded")
                case .apiError(let code, let message):
                    errorMessage = "API \(code): \(message)"
                    print("❌ Balance error: API \(code) - \(message)")
                case .parseError(let description):
                    errorMessage = "Parse: \(description)"
                    print("❌ Balance error: Parse error - \(description)")
                case .invalidSymbol(let symbol):
                    errorMessage = "Invalid symbol: \(symbol)"
                    print("❌ Balance error: Invalid symbol - \(symbol)")
                case .insufficientData:
                    errorMessage = "Insufficient data"
                    print("❌ Balance error: Insufficient data")
                }
            } else {
                errorMessage = error.localizedDescription
                print("❌ Balance error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                balanceError = errorMessage
                isLoadingBalance = false
                statusText = "Error: \(errorMessage)"
            }
        }
    }
    
    private func loadExchangeRates() async {
        print("💱 Loading exchange rates...")
        await MainActor.run {
            isLoadingRates = true
        }
        
        let client = BitvavoAPIClient()
        
        // Get symbols for all crypto balances (excluding EUR)
        let cryptoSymbols = balances
            .filter { $0.symbol != "EUR" && $0.totalBalance > 0 }
            .map { $0.symbol }
        
        guard !cryptoSymbols.isEmpty else {
            print("⚠️ Exchange rates: No crypto balances found")
            await MainActor.run {
                isLoadingRates = false
            }
            return
        }
        
        do {
            // Use the new efficient bulk price fetching method
            let prices = try await client.getSymbolsPrices(symbols: cryptoSymbols)
            print("✅ Exchange rates loaded: \(prices.count) rates")
            
            var newRates: [String: Double] = [:]
            for (index, symbol) in cryptoSymbols.enumerated() {
                if index < prices.count {
                    let price = prices[index]
                    newRates[symbol] = price
                    if price > 0 {
                        print("💰 Rate: \(symbol) = €\(price)")
                    } else {
                        print("⚠️ No market price for \(symbol) (may not have EUR market)")
                    }
                }
            }
            
            await MainActor.run {
                exchangeRates = newRates
                isLoadingRates = false
            }
        } catch {
            if let apiError = error as? BitvavoAPIClient.APIError {
                switch apiError {
                case .networkError(let description):
                    print("❌ Exchange rates error: Network - \(description)")
                case .invalidResponse(let code):
                    print("❌ Exchange rates error: HTTP \(code)")
                case .apiError(let code, let message):
                    print("❌ Exchange rates error: API \(code) - \(message)")
                case .parseError(let description):
                    print("❌ Exchange rates error: Parse - \(description)")
                case .invalidCredentials:
                    print("❌ Exchange rates error: Invalid credentials")
                case .rateLimitExceeded:
                    print("❌ Exchange rates error: Rate limit exceeded")
                case .invalidSymbol(let symbol):
                    print("❌ Exchange rates error: Invalid symbol - \(symbol)")
                case .insufficientData:
                    print("❌ Exchange rates error: Insufficient data")
                }
            } else {
                print("❌ Exchange rates error: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isLoadingRates = false
            }
        }
    }
    
    private func loadServerTime() async {
        guard let apiKey = authManager.getStoredAPIKey(),
              let apiSecret = authManager.getStoredAPISecret() else {
            await MainActor.run {
                serverTime = "API credentials not configured"
            }
            return
        }
        
        await MainActor.run {
            isLoadingServerTime = true
        }
        
        let client = BitvavoAPIClient()
        let credentials = BitvavoAPIClient.APICredentials(apiKey: apiKey, apiSecret: apiSecret)
        
        do {
            print("🕐 Loading server time...")
            let time = try await client.getServerTime(credentials: credentials)
            print("✅ Server time received: \(time)")
            await MainActor.run {
                serverTime = time
                isLoadingServerTime = false
            }
        } catch {
            print("❌ Server time error: \(error)")
            if let apiError = error as? BitvavoAPIClient.APIError {
                print("🔍 API Error details: \(apiError)")
            }
            await MainActor.run {
                serverTime = "Error: \(error.localizedDescription)"
                isLoadingServerTime = false
            }
        }
    }
    
    private func loadAssetNames() async {
        print("📋 Loading asset names...")
        let client = BitvavoAPIClient()
        
        do {
            let assets = try await client.getAssets()
            print("✅ Asset names loaded: \(assets.count) assets")
            
            var names: [String: String] = [:]
            for asset in assets {
                names[asset.symbol] = asset.name
            }
            
            await MainActor.run {
                assetNames = names
            }
        } catch {
            print("❌ Asset names error: \(error.localizedDescription)")
            // Continue without asset names - fallback will be used
        }
    }
    
    private func loadPriceChanges() async {
        print("📈 Loading price changes...")
        await MainActor.run {
            isLoadingPriceChanges = true
        }
        
        let client = BitvavoAPIClient()
        
        do {
            // Get all available symbols to load price changes for (before filtering by ticker data)
            let symbolsToLoad = Array(assetNames.keys).filter { $0 != "EUR" }.sorted()
            guard !symbolsToLoad.isEmpty else {
                print("⚠️ Price changes: No symbols to load")
                await MainActor.run {
                    isLoadingPriceChanges = false
                }
                return
            }
            
            let priceChangeInfos = try await client.getSymbolsPriceChanges(symbols: symbolsToLoad)
            print("✅ Price changes loaded: \(priceChangeInfos.count)/\(symbolsToLoad.count) symbols")
            
            var priceChangeDict: [String: BitvavoAPIClient.PriceChangeInfo] = [:]
            for priceInfo in priceChangeInfos {
                priceChangeDict[priceInfo.symbol] = priceInfo
            }
            
            // Log filtering results
            let allAvailableSymbols = Array(assetNames.keys).filter { $0 != "EUR" }
            let symbolsWithTickerData = Set(priceChangeDict.keys)
            let filteredOutSymbols = allAvailableSymbols.filter { !symbolsWithTickerData.contains($0) }.sorted()
            
            if !filteredOutSymbols.isEmpty {
                print("🚫 Available assets filtered out (no ticker data): \(filteredOutSymbols.count)")
                for symbol in filteredOutSymbols.prefix(10) {
                    let name = assetNames[symbol] ?? symbol
                    print("   \(symbol) (\(name))")
                }
                if filteredOutSymbols.count > 10 {
                    print("   ... and \(filteredOutSymbols.count - 10) more")
                }
            }
            
            await MainActor.run {
                priceChanges = priceChangeDict
                isLoadingPriceChanges = false
            }
        } catch {
            print("❌ Price changes error: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingPriceChanges = false
            }
        }
    }
}

struct EuroBalanceRowView: View {
    let balance: BitvavoAPIClient.BalanceInfo?
    
    var body: some View {
        HStack {
            // Euro Logo
            CryptoLogoView(symbol: "EUR")
            
            // Euro Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text("Euro")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("EUR")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Balance Information
            VStack(alignment: .trailing, spacing: 2) {
                if let balance = balance {
                    Text(CurrencyFormatter.formatEUR(balance.totalBalance))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if balance.inOrderDouble > 0 {
                        Text("In Order: \(CurrencyFormatter.formatEUR(balance.inOrderDouble))")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("€0.00")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct AssetRowView: View {
    let balance: BitvavoAPIClient.BalanceInfo
    let exchangeRate: Double
    let fullName: String
    
    var body: some View {
        HStack {
            // Cryptocurrency Logo
            CryptoLogoView(symbol: balance.symbol)
            
            // Asset Name and Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(fullName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("\(balance.symbol) (\(formatPricePerUnit(exchangeRate)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Balance Information
            VStack(alignment: .trailing, spacing: 2) {
                // Euro worth (prominent)
                Text(formatEuroWorth(balance.totalBalance))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Coin amount (smaller underneath)
                Text(formatCoinAmount(balance.totalBalance))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if balance.inOrderDouble > 0 {
                    Text("In Order: \(formatCoinAmount(balance.inOrderDouble))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private func formatEuroWorth(_ amount: Double) -> String {
        return CurrencyFormatter.formatEURWorth(amount, exchangeRate: exchangeRate)
    }
    
    private func formatCoinAmount(_ amount: Double) -> String {
        return CurrencyFormatter.formatCryptoAmount(amount, symbol: balance.symbol)
    }
    
    private func formatPricePerUnit(_ price: Double) -> String {
        return CurrencyFormatter.formatPricePerUnit(price)
    }
}

struct AvailableAssetRowView: View {
    let symbol: String
    let fullName: String
    let priceChangeInfo: BitvavoAPIClient.PriceChangeInfo?
    let timeframe: String
    
    var body: some View {
        HStack {
            // Cryptocurrency Logo
            CryptoLogoView(symbol: symbol)
            
            // Asset Name and Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(fullName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Price and percentage change
            VStack(alignment: .trailing, spacing: 2) {
                if let priceInfo = priceChangeInfo, priceInfo.currentPrice > 0 {
                    Text(CurrencyFormatter.formatEUR(priceInfo.currentPrice))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    let percentageChange = priceInfo.getPercentageChange(for: timeframe)
                    HStack(spacing: 2) {
                        Image(systemName: percentageChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(CurrencyFormatter.formatPercentageChange(percentageChange))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(percentageChange >= 0 ? .green : .red)
                } else {
                    Text("€---.--")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("No data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct WalletSummaryRowView: View {
    let totalValue: Double
    
    var body: some View {
        HStack {
            // Wallet Icon
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
                .frame(width: 32, height: 32)
            
            // Wallet Label
            VStack(alignment: .leading, spacing: 2) {
                Text("Wallet")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Total Portfolio Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Total Value
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.formatEUR(totalValue))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("All Assets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct SectionHeaderView: View {
    let title: String
    let sortOption: AssetSortOption
    let sortOrder: SortOrder
    let onSortTapped: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
            
            Spacer()
            
            Button(action: onSortTapped) {
                HStack(spacing: 3) {
                    Text(sortOption.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: sortOrder.iconName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct SortSelectionSheet: View {
    let title: String
    @Binding var selectedOption: AssetSortOption
    @Binding var selectedOrder: SortOrder
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Sort By") {
                    ForEach(AssetSortOption.allCases, id: \.self) { option in
                        HStack {
                            Image(systemName: option.iconName)
                                .font(.body)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(option.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedOption == option {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedOption = option
                        }
                    }
                }
                
                Section("Order") {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        HStack {
                            Image(systemName: order.iconName)
                                .font(.body)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(order.displayName)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedOrder == order {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedOrder = order
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let refreshAssets = Notification.Name("refreshAssets")
}

#Preview {
    AssetsView()
        .environmentObject(AuthenticationManager())
}
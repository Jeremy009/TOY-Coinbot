//
//  NewOrderView.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 12/08/2025.
//

import SwiftUI

struct NewOrderView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMarket = "BTC-EUR"
    @State private var selectedSide: BitvavoAPIClient.OrderSide = .buy
    @State private var selectedOrderType: BitvavoAPIClient.OrderType? = nil
    @State private var amount = ""
    @State private var price = ""
    @State private var triggerPrice = ""
    @State private var selectedTimeInForce: BitvavoAPIClient.TimeInForce = .gtc
    @State private var postOnly = false
    @State private var disableMarketProtection = false
    
    @State private var isPlacingOrder = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    @State private var placedOrder: BitvavoAPIClient.OrderInfo?
    
    @State private var availableMarkets: [BitvavoAPIClient.MarketInfo] = []
    @State private var currentPrice: Double = 0.0
    @State private var balances: [BitvavoAPIClient.BalanceInfo] = []
    @State private var isLoadingData = false
    
    private var sortedMarkets: [String] {
        let ownedSymbols = Set(balances.filter { $0.availableDouble > 0.0001 }.map { $0.symbol })
        
        // Filter only EUR markets
        let eurMarkets = availableMarkets.filter { $0.market.hasSuffix("-EUR") }.map { $0.market }
        
        // Split into owned and not owned
        let ownedMarkets = eurMarkets.filter { market in
            let baseSymbol = market.components(separatedBy: "-").first ?? ""
            return ownedSymbols.contains(baseSymbol)
        }.sorted()
        
        let notOwnedMarkets = eurMarkets.filter { market in
            let baseSymbol = market.components(separatedBy: "-").first ?? ""
            return !ownedSymbols.contains(baseSymbol)
        }.sorted()
        
        return ownedMarkets + notOwnedMarkets
    }
    
    private var selectedMarketBalance: BitvavoAPIClient.BalanceInfo? {
        let baseSymbol = symbolFromMarket
        return balances.first { $0.symbol == baseSymbol }
    }
    
    private var eurBalance: BitvavoAPIClient.BalanceInfo? {
        balances.first { $0.symbol == "EUR" }
    }
    
    private var isFormValid: Bool {
        guard let orderType = selectedOrderType else { return false }
        
        // Basic field validation
        let basicValidation = !selectedMarket.isEmpty && 
        !amount.isEmpty && 
        parseDoubleValue(amount) != nil &&
        (orderType == .market || (!price.isEmpty && parseDoubleValue(price) != nil)) &&
        (orderType != .stopLimit && orderType != .stopLoss && orderType != .stopLossLimit && orderType != .takeProfit && orderType != .takeProfitLimit || 
         (!triggerPrice.isEmpty && parseDoubleValue(triggerPrice) != nil))
        
        // Additional validation: check minimum order value
        return basicValidation && orderValueError == nil
    }
    
    private func parseDoubleValue(_ string: String) -> Double? {
        // Try parsing with current locale first (handles commas automatically)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: string) {
            return number.doubleValue
        }
        
        // Fallback: try with dot decimal separator
        if let dotValue = Double(string) {
            return dotValue
        }
        
        // Fallback: try converting comma to dot and parse
        let dotString = string.replacingOccurrences(of: ",", with: ".")
        return Double(dotString)
    }
    
    private func convertToAPIFormat(_ string: String) -> String? {
        guard !string.isEmpty else { return nil }
        
        // Parse the value to ensure it's valid
        guard let doubleValue = parseDoubleValue(string) else { return nil }
        
        // Format with appropriate precision for Bitvavo API (max 5-6 significant digits)
        return formatPriceForAPI(doubleValue)
    }
    
    private func formatPriceForAPI(_ value: Double) -> String {
        // Bitvavo requires max 5-6 significant digits for prices
        // Examples from API: 11313, 7500.10, 7500.20, 500.12, 0.0012345
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 5
        formatter.minimumSignificantDigits = 1
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
    
    private func calculateOrderValue() -> Double? {
        guard let orderType = selectedOrderType else { return nil }
        guard let amountValue = parseDoubleValue(amount) else { return nil }
        
        switch orderType {
        case .market:
            // For market orders, use current market price
            return amountValue * currentPrice
        case .limit, .stopLimit, .stopLossLimit, .takeProfitLimit:
            // For limit orders, use the specified price
            guard let priceValue = parseDoubleValue(price) else { return nil }
            return amountValue * priceValue
        case .stopLoss, .takeProfit:
            // For market stop orders, use current market price
            return amountValue * currentPrice
        }
    }
    
    private var orderValueError: String? {
        guard selectedOrderType != nil else { return nil }
        guard !amount.isEmpty else { return nil }
        
        // Parse the amount to validate base asset minimum
        guard let amountValue = parseDoubleValue(amount) else { return nil }
        
        // Check base asset minimum first (e.g., BTC minimum for BTC-EUR)
        if let baseMinimum = getMinimumBaseAssetAmount() {
            if amountValue < baseMinimum {
                let symbol = symbolFromMarket
                let formattedAmount = amountValue.formatted(.number.precision(.fractionLength(8)))
                let formattedMinimum = baseMinimum.formatted(.number.precision(.fractionLength(8)))
                return "Minimum \(symbol) amount is \(formattedMinimum). Your order of \(formattedAmount) \(symbol) is below the minimum."
            }
        }
        
        // Calculate total order value
        guard let orderValue = calculateOrderValue() else { return nil }
        
        // Check minimum €5 requirement
        // Note: Bitvavo applies a consistent €5 minimum across all EUR markets
        if orderValue < 5.0 {
            let formatted = orderValue.formatted(.currency(code: "EUR"))
            return "Minimum order value is €5.00. Your order of \(formatted) is below the minimum."
        }
        
        return nil
    }
    
    private var pricePrecisionError: String? {
        guard let orderType = selectedOrderType else { return nil }
        guard orderType != .market && !price.isEmpty else { return nil }
        
        // Check if the price precision exceeds Bitvavo's requirements
        guard let priceValue = parseDoubleValue(price) else { return nil }
        let formattedPrice = formatPriceForAPI(priceValue)
        let originalPrice = String(priceValue)
        
        // If formatted price differs significantly from original, warn user
        if let formattedDouble = Double(formattedPrice), 
           let originalDouble = Double(originalPrice) {
            let difference = abs(formattedDouble - originalDouble) / originalDouble
            if difference > 0.001 { // If difference is more than 0.1%
                return "Price precision adjusted from €\(originalPrice) to €\(formattedPrice) to meet exchange requirements."
            }
        }
        
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    marketSelectionSection
                    orderTypeSection
                    orderSideSection
                    amountAndPricingSection
                    if selectedOrderType == .limit {
                        advancedOptionsSection
                    }
                    if selectedOrderType == .market {
                        marketOrderOptionsSection
                    }
                    orderSummarySection
                    if let error = orderValueError {
                        orderValueErrorSection(error)
                    }
                    if let warning = pricePrecisionError {
                        pricePrecisionWarningSection(warning)
                    }
                    if selectedOrderType != nil {
                        orderInformationSection
                    }
                    placeOrderButton
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .onTapGesture {
                // Dismiss keyboard when tapping outside of text fields
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationTitle("New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadInitialData()
            }
            .onChange(of: selectedMarket) { _, _ in
                Task {
                    await loadCurrentPrice()
                }
            }
            .overlay {
                if isLoadingData {
                    loadingOverlay
                }
            }
        }
        .alert("Order Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .alert("Order Placed", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if let order = placedOrder {
                Text("Your \(order.side.displayName.lowercased()) order for \(String(format: "%.6f", order.amountDouble)) \(order.symbol) has been placed successfully.")
            }
        }
    }
    
    private var marketSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                Picker("Trading Pair", selection: $selectedMarket) {
                    ForEach(sortedMarkets, id: \.self) { market in
                        HStack {
                            Text(market)
                            Spacer()
                            // Show if user owns this symbol
                            let baseSymbol = market.components(separatedBy: "-").first ?? ""
                            if balances.first(where: { $0.symbol == baseSymbol })?.availableDouble ?? 0 > 0.0001 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        .tag(market)
                    }
                }
                .pickerStyle(.menu)
                
                // Market Information
                VStack(spacing: 6) {
                    HStack {
                        Text("Available EUR")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text((eurBalance?.availableDouble ?? 0.0), format: .currency(code: "EUR"))
                            .fontWeight(.medium)
                    }
                    
                    if currentPrice > 0 {
                        HStack {
                            Text("Current Price")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currentPrice, format: .currency(code: "EUR"))
                                .fontWeight(.medium)
                        }
                    }
                    
                    HStack {
                        Text("Available \(symbolFromMarket)")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text((selectedMarketBalance?.availableDouble ?? 0.0), format: .number.precision(.fractionLength(6)))
                            .fontWeight(.medium)
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var orderTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Type")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let orderType = selectedOrderType {
                // Show selected order type with info - tappable to deselect
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(orderType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(orderTypeDescription(orderType))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        selectedOrderType = nil
                    }
                }
            } else {
                // Show all order types for selection
                VStack(spacing: 8) {
                    ForEach(BitvavoAPIClient.OrderType.allCases, id: \.self) { orderType in
                        Button(action: {
                            selectedOrderType = orderType
                            // Clear price for market orders
                            if orderType == .market {
                                price = ""
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(orderType.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text(orderTypeDescription(orderType))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private var orderSideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Side")
                .font(.headline)
                .foregroundColor(.primary)
            
            Picker("Side", selection: $selectedSide) {
                ForEach(BitvavoAPIClient.OrderSide.allCases, id: \.self) { side in
                    Text(side.displayName).tag(side)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var amountAndPricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount & Pricing")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount (\(symbolFromMarket))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("0.0", text: $amount)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if selectedOrderType != .market && selectedOrderType != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Price (EUR)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.0", text: $price)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    if !amount.isEmpty && !price.isEmpty,
                       let amountValue = parseDoubleValue(amount),
                       let priceValue = parseDoubleValue(price) {
                        HStack {
                            Text("Total Value")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text((amountValue * priceValue), format: .currency(code: "EUR"))
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                }
                
                // Trigger price for stop orders
                if requiresTriggerPrice && selectedOrderType != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trigger Price (EUR)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0.0", text: $triggerPrice)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced Options")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time in Force")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Time in Force", selection: $selectedTimeInForce) {
                        ForEach(BitvavoAPIClient.TimeInForce.allCases, id: \.self) { tif in
                            Text(tif.displayName).tag(tif)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Toggle("Post Only", isOn: $postOnly)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var marketOrderOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Order Options")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Toggle("Disable Market Protection", isOn: $disableMarketProtection)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(selectedSide.displayName.uppercased())
                        .fontWeight(.bold)
                        .foregroundColor(selectedSide == .buy ? .green : .red)
                    
                    Spacer()
                    
                    Text(selectedOrderType?.displayName ?? "No Type Selected")
                        .fontWeight(.medium)
                }
                
                if !amount.isEmpty {
                    Text("Amount: \(amount) \(symbolFromMarket)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if selectedOrderType != .market && !price.isEmpty {
                    Text("Price: €\(price)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if requiresTriggerPrice && !triggerPrice.isEmpty {
                    Text("Trigger: €\(triggerPrice)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func orderValueErrorSection(_ errorMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Order Amount Warning")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
            
            if calculateOrderValue() != nil {
                // Show appropriate suggestion based on which minimum was violated
                if let baseMinimum = getMinimumBaseAssetAmount(),
                   let amountValue = parseDoubleValue(amount),
                   amountValue < baseMinimum {
                    Text("Required minimum: \(baseMinimum.formatted(.number.precision(.fractionLength(8)))) \(symbolFromMarket)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Suggested minimum: €5.00 (\(String(format: "%.8f", 5.0 / currentPrice)) \(symbolFromMarket))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .background(Color.orange.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    private func pricePrecisionWarningSection(_ warningMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Price Precision Info")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(warningMessage)
                .font(.subheadline)
                .foregroundColor(.blue)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("Bitvavo requires prices with maximum 5 significant digits for optimal matching.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(Color.blue.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
    
    private var orderInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("About \(selectedOrderType?.displayName ?? "Order") Information")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text(detailedOrderTypeDescription(selectedOrderType))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let riskWarning = orderTypeRiskWarning(selectedOrderType) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(riskWarning)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var placeOrderButton: some View {
        Button(action: {
            Task {
                await placeOrder()
            }
        }) {
            HStack {
                if isPlacingOrder {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                Text(isPlacingOrder ? "Placing Order..." : 
                     orderValueError != nil ? "Minimum €5.00 Required" :
                     "Place \(selectedSide.displayName.capitalized) Order")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isFormValid && !isPlacingOrder ? 
                      (selectedSide == .buy ? Color.green : Color.red) : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isFormValid || isPlacingOrder)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Loading Market Data...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    
    private var symbolFromMarket: String {
        selectedMarket.components(separatedBy: "-").first ?? ""
    }
    
    private func getMinimumBaseAssetAmount() -> Double? {
        guard let marketInfo = availableMarkets.first(where: { $0.market == selectedMarket }) else {
            return nil
        }
        
        guard let minBaseString = marketInfo.minOrderInBaseAsset else {
            return nil
        }
        
        return Double(minBaseString)
    }
    
    private var requiresTriggerPrice: Bool {
        guard let orderType = selectedOrderType else { return false }
        
        switch orderType {
        case .stopLimit, .stopLoss, .stopLossLimit, .takeProfit, .takeProfitLimit:
            return true
        default:
            return false
        }
    }
    
    private func orderTypeDescription(_ orderType: BitvavoAPIClient.OrderType) -> String {
        switch orderType {
        case .market:
            return "Execute immediately at current market price"
        case .limit:
            return "Execute only at specified price or better"
        case .stopLimit:
            return "Limit order triggered at specific price"
        case .stopLoss:
            return "Market order triggered to limit losses"
        case .stopLossLimit:
            return "Limit order triggered to limit losses"
        case .takeProfit:
            return "Market order triggered to take profits"
        case .takeProfitLimit:
            return "Limit order triggered to take profits"
        }
    }
    
    private func detailedOrderTypeDescription(_ orderType: BitvavoAPIClient.OrderType?) -> String {
        guard let orderType = orderType else {
            return "Please select an order type above to see detailed information and place your order."
        }
        switch orderType {
        case .market:
            return "A market order executes immediately at the current market price. It guarantees execution but not the exact price. Best for when you want to buy or sell quickly."
        case .limit:
            return "A limit order only executes at your specified price or better. For buy orders, it won't execute above your price. For sell orders, it won't execute below your price. This gives you price control but doesn't guarantee execution."
        case .stopLimit:
            return "A stop-limit order becomes a limit order when the trigger price is reached. It combines the price control of a limit order with the trigger mechanism of a stop order."
        case .stopLoss:
            return "A stop-loss order becomes a market order when the trigger price is reached, helping to limit losses on a position. It will execute at the next available market price."
        case .stopLossLimit:
            return "A stop-loss limit order becomes a limit order when the trigger price is reached. It provides more price control than a regular stop-loss but risks not executing if the market moves quickly."
        case .takeProfit:
            return "A take-profit order becomes a market order when the trigger price is reached, helping to secure profits on a position. It will execute at the next available market price."
        case .takeProfitLimit:
            return "A take-profit limit order becomes a limit order when the trigger price is reached. It provides more price control but risks not executing if the market moves quickly."
        }
    }
    
    private func orderTypeRiskWarning(_ orderType: BitvavoAPIClient.OrderType?) -> String? {
        guard let orderType = orderType else { return nil }
        
        switch orderType {
        case .market:
            return "Market orders may execute at unexpected prices during volatile market conditions."
        case .stopLoss, .takeProfit:
            return "Stop and take-profit orders may execute at prices significantly different from the trigger price in fast-moving markets."
        case .stopLossLimit, .takeProfitLimit, .stopLimit:
            return "Stop-limit orders may not execute if the market price gaps past your limit price."
        case .limit:
            return nil
        }
    }
    
    private func loadInitialData() async {
        await MainActor.run {
            isLoadingData = true
        }
        
        let client = BitvavoAPIClient()
        
        do {
            // Get credentials first
            guard let credentials = client.getStoredCredentials() else {
                throw BitvavoAPIClient.APIError.invalidCredentials
            }
            
            async let marketsTask = client.getMarkets()
            async let balancesTask = client.getBalance(credentials: credentials)
            
            let (markets, balances) = try await (marketsTask, balancesTask)
            await loadCurrentPrice()
            
            await MainActor.run {
                self.availableMarkets = markets
                self.balances = balances
                isLoadingData = false
            }
        } catch {
            await MainActor.run {
                isLoadingData = false
                errorMessage = "Failed to load market data: \(error.localizedDescription)"
            }
            print("❌ Error loading initial data: \(error)")
        }
    }
    
    private func loadCurrentPrice() async {
        let client = BitvavoAPIClient()
        
        do {
            let symbol = symbolFromMarket
            let prices = try await client.getSymbolsPrices(symbols: [symbol])
            
            await MainActor.run {
                currentPrice = prices.first ?? 0.0
            }
        } catch {
            print("❌ Error loading current price: \(error)")
        }
    }
    
    private func placeOrder() async {
        await MainActor.run {
            isPlacingOrder = true
            errorMessage = nil
        }
        
        let client = BitvavoAPIClient()
        
        // Ensure order type is selected
        guard let orderType = selectedOrderType else {
            await MainActor.run {
                isPlacingOrder = false
                errorMessage = "Please select an order type"
            }
            return
        }
        
        // Convert amounts to API format (dot decimal separator)
        let apiAmount = convertToAPIFormat(amount)
        let apiPrice = convertToAPIFormat(price)
        let apiTriggerPrice = convertToAPIFormat(triggerPrice)
        
        // Build order parameters
        let params = BitvavoAPIClient.NewOrderParams(
            market: selectedMarket,
            side: selectedSide,
            orderType: orderType,
            amount: orderType == .market && selectedSide == .buy ? nil : apiAmount,
            amountQuote: orderType == .market && selectedSide == .buy ? apiAmount : nil,
            price: orderType == .market ? nil : apiPrice,
            triggerPrice: requiresTriggerPrice ? apiTriggerPrice : nil,
            triggerType: requiresTriggerPrice ? "price" : nil,
            triggerReference: requiresTriggerPrice ? "lastTrade" : nil,
            timeInForce: orderType == .limit ? selectedTimeInForce : nil,
            postOnly: orderType == .limit ? postOnly : nil,
            selfTradePrevention: "decrementAndCancel",
            disableMarketProtection: orderType == .market ? disableMarketProtection : nil,
            operatorId: String(Int(Date().timeIntervalSince1970 * 1000000))
        )
        
        do {
            let order = try await client.placeOrder(params)
            
            await MainActor.run {
                isPlacingOrder = false
                placedOrder = order
                showingSuccess = true
            }
            
            // Notify other views to refresh
            NotificationCenter.default.post(name: .refreshOrders, object: nil)
            NotificationCenter.default.post(name: .refreshAssets, object: nil)
            
        } catch {
            await MainActor.run {
                isPlacingOrder = false
                errorMessage = "Failed to place order: \(error.localizedDescription)"
            }
            print("❌ Error placing order: \(error)")
        }
    }
}

#Preview {
    NewOrderView()
        .environmentObject(AuthenticationManager())
}
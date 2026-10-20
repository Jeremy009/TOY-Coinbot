//
//  OrderDetailView.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 12/08/2025.
//

import SwiftUI

struct OrderDetailView: View {
    let order: BitvavoAPIClient.OrderInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Basic Information
                Section("Order Information") {
                    DetailRow(title: "Order ID", value: order.orderId)
                    DetailRow(title: "Market", value: order.market)
                    DetailRow(title: "Status", value: order.status.displayName, valueColor: statusColor)
                    DetailRow(title: "Side", value: order.side.displayName, valueColor: order.side == .buy ? .green : .red)
                    DetailRow(title: "Order Type", value: order.orderType.displayName)
                }
                
                // Amount and Pricing
                Section("Amount & Pricing") {
                    DetailRow(title: "Amount", value: "\(order.amountDouble.formatted(.number.precision(.fractionLength(8)))) \(order.symbol)")
                    
                    if let remaining = order.amountRemaining, !remaining.isEmpty, order.amountRemainingDouble > 0 {
                        DetailRow(title: "Remaining", value: "\(order.amountRemainingDouble.formatted(.number.precision(.fractionLength(8)))) \(order.symbol)")
                        
                        let filledAmount = order.amountDouble - order.amountRemainingDouble
                        let fillPercentage = (filledAmount / order.amountDouble) * 100
                        DetailRow(title: "Filled", value: "\(filledAmount.formatted(.number.precision(.fractionLength(8)))) \(order.symbol) (\(fillPercentage.formatted(.number.precision(.fractionLength(1))))%)")
                    }
                    
                    if order.orderType != .market, order.priceDouble > 0 {
                        DetailRow(title: "Price", value: order.priceDouble.formatted(.currency(code: "EUR")))
                        
                        let totalValue = order.amountDouble * order.priceDouble
                        DetailRow(title: "Total Value", value: totalValue.formatted(.currency(code: "EUR")))
                    }
                    
                    if order.triggerPriceDouble > 0 {
                        DetailRow(title: "Trigger Price", value: order.triggerPriceDouble.formatted(.currency(code: "EUR")))
                    }
                }
                
                // Advanced Details
                if hasAdvancedDetails {
                    Section("Advanced") {
                        if let timeInForce = order.timeInForce {
                            DetailRow(title: "Time in Force", value: timeInForce.displayName)
                        }
                        
                        if let triggerType = order.triggerType {
                            DetailRow(title: "Trigger Type", value: triggerType)
                        }
                        
                        if let triggerReference = order.triggerReference {
                            DetailRow(title: "Trigger Reference", value: triggerReference)
                        }
                        
                        if let postOnly = order.postOnly {
                            DetailRow(title: "Post Only", value: postOnly ? "Yes" : "No")
                        }
                        
                        if let visible = order.visible {
                            DetailRow(title: "Visible", value: visible ? "Yes" : "No")
                        }
                        
                        if let disableMarketProtection = order.disableMarketProtection {
                            DetailRow(title: "Market Protection", value: disableMarketProtection ? "Disabled" : "Enabled")
                        }
                    }
                }
                
                // Timestamps
                Section("Timestamps") {
                    DetailRow(title: "Created", value: formatDate(order.createdDate))
                    DetailRow(title: "Last Updated", value: formatDate(order.updatedDate))
                    DetailRow(title: "Created (Relative)", value: order.createdDate.formatted(.relative(presentation: .named)))
                }
                
                // Fills/Trades
                if let fills = order.fills, !fills.isEmpty {
                    Section("Trades") {
                        ForEach(fills, id: \.id) { fill in
                            TradeRowView(trade: fill)
                        }
                    }
                }
            }
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch order.status {
        case .new, .partiallyFilled, .awaitingTrigger:
            return .blue
        case .filled:
            return .green
        case .canceled, .canceledPartial, .expired, .rejected:
            return .red
        }
    }
    
    private var hasAdvancedDetails: Bool {
        return order.timeInForce != nil || 
               order.triggerType != nil || 
               order.triggerReference != nil || 
               order.postOnly != nil || 
               order.visible != nil || 
               order.disableMarketProtection != nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let valueColor: Color?
    
    init(title: String, value: String, valueColor: Color? = nil) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor ?? .primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct TradeRowView: View {
    let trade: BitvavoAPIClient.TradeInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Trade #\(String(trade.id.prefix(8)))")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(trade.side.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(trade.side == .buy ? .green : .red)
            }
            
            HStack {
                Text("\(trade.amountDouble.formatted(.number.precision(.fractionLength(6)))) @ \(trade.priceDouble.formatted(.currency(code: "EUR")))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Fee: \(trade.feeDouble.formatted(.currency(code: "EUR")))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(trade.timestamp_date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let sampleOrder = BitvavoAPIClient.OrderInfo(
        orderId: "12345-67890-abcdef",
        market: "BTC-EUR",
        created: Int64(Date().timeIntervalSince1970 * 1000),
        updated: Int64(Date().timeIntervalSince1970 * 1000),
        status: .new,
        side: .buy,
        orderType: .limit,
        amount: "0.001",
        amountRemaining: "0.0005",
        price: "45000.00",
        triggerPrice: nil,
        triggerType: nil,
        triggerReference: nil,
        timeInForce: .gtc,
        postOnly: true,
        selfTradePrevention: "decrementAndCancel",
        visible: true,
        disableMarketProtection: false,
        fills: nil
    )
    
    OrderDetailView(order: sampleOrder)
}
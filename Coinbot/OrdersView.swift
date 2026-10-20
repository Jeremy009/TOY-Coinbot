//
//  OrdersView.swift
//  Coinbot
//
//  Created by Jeremy Lombaerts on 12/08/2025.
//

import SwiftUI

struct OrdersView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            OrdersViewContent()
                .environmentObject(authManager)
                .navigationTitle("Orders")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            // TODO: Show order filters
                        }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            NotificationCenter.default.post(name: .refreshOrders, object: nil)
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

struct OrdersViewContent: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var openOrders: [BitvavoAPIClient.OrderInfo] = []
    @State private var orderHistory: [BitvavoAPIClient.OrderInfo] = []
    @State private var isLoadingOpen = false
    @State private var isLoadingHistory = false
    @State private var errorMessage: String?
    @State private var showingNewOrder = false
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented control
            Picker("Order Type", selection: $selectedTab) {
                Text("Open Orders").tag(0)
                Text("Order History").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)
            
            TabView(selection: $selectedTab) {
                // Open Orders Tab
                openOrdersView
                    .tag(0)
                
                // Order History Tab
                orderHistoryView
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // New Order Button
            Button(action: {
                showingNewOrder = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    Text("Place New Order")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .task {
            await loadOrders()
        }
        .refreshable {
            await loadOrders()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshOrders)) { _ in
            Task {
                await loadOrders()
            }
        }
        .sheet(isPresented: $showingNewOrder) {
            NewOrderView()
                .environmentObject(authManager)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private var openOrdersView: some View {
        Group {
            if isLoadingOpen {
                LoadingOrdersView(title: "Loading Open Orders...")
            } else if openOrders.isEmpty {
                EmptyOrdersView(
                    title: "No Open Orders",
                    subtitle: "You don't have any active orders at the moment",
                    iconName: "clock.badge.exclamationmark"
                )
            } else {
                List {
                    ForEach(openOrders, id: \.orderId) { order in
                        OrderRowView(order: order) {
                            await cancelOrder(order)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private var orderHistoryView: some View {
        Group {
            if isLoadingHistory {
                LoadingOrdersView(title: "Loading Order History...")
            } else if orderHistory.isEmpty {
                EmptyOrdersView(
                    title: "No Order History",
                    subtitle: "Your completed orders will appear here",
                    iconName: "clock.arrow.circlepath"
                )
            } else {
                List {
                    ForEach(orderHistory, id: \.orderId) { order in
                        OrderRowView(order: order, onCancel: nil)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private func loadOrders() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await loadOpenOrders()
            }
            group.addTask {
                await loadOrderHistory()
            }
        }
    }
    
    private func loadOpenOrders() async {
        await MainActor.run {
            isLoadingOpen = true
            errorMessage = nil
        }
        
        let client = BitvavoAPIClient()
        
        do {
            let orders = try await client.getOpenOrders()
            await MainActor.run {
                openOrders = orders
                isLoadingOpen = false
            }
            print("✅ Loaded \(orders.count) open orders")
        } catch {
            await MainActor.run {
                isLoadingOpen = false
                errorMessage = "Failed to load open orders: \(error.localizedDescription)"
            }
            print("❌ Error loading open orders: \(error)")
            
            // Additional debugging for API errors
            if let apiError = error as? BitvavoAPIClient.APIError {
                switch apiError {
                case .apiError(let code, let message):
                    print("🔍 API Error Details - Code: \(code), Message: \(message)")
                case .invalidCredentials:
                    print("🔍 Invalid API credentials - check API key/secret")
                case .networkError(let details):
                    print("🔍 Network error: \(details)")
                case .parseError(let details):
                    print("🔍 Parse error: \(details)")
                default:
                    print("🔍 Other API error: \(apiError)")
                }
            }
        }
    }
    
    private func loadOrderHistory() async {
        await MainActor.run {
            isLoadingHistory = true
        }
        
        let client = BitvavoAPIClient()
        
        do {
            let orders = try await client.getOrderHistory()
            await MainActor.run {
                orderHistory = orders
                isLoadingHistory = false
            }
            print("✅ Loaded \(orders.count) historical orders")
        } catch {
            await MainActor.run {
                isLoadingHistory = false
                if errorMessage == nil {
                    errorMessage = "Failed to load order history: \(error.localizedDescription)"
                }
            }
            print("❌ Error loading order history: \(error)")
            
            // Additional debugging for API errors
            if let apiError = error as? BitvavoAPIClient.APIError {
                switch apiError {
                case .apiError(let code, let message):
                    print("🔍 Order History API Error - Code: \(code), Message: \(message)")
                case .invalidCredentials:
                    print("🔍 Invalid API credentials for order history")
                case .networkError(let details):
                    print("🔍 Order history network error: \(details)")
                case .parseError(let details):
                    print("🔍 Order history parse error: \(details)")
                default:
                    print("🔍 Other order history error: \(apiError)")
                }
            }
        }
    }
    
    private func cancelOrder(_ order: BitvavoAPIClient.OrderInfo) async {
        let client = BitvavoAPIClient()
        
        do {
            let canceledOrder = try await client.cancelOrder(orderId: order.orderId)
            print("✅ Order canceled: \(canceledOrder.orderId)")
            
            // Refresh orders to reflect the cancellation
            await loadOrders()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to cancel order: \(error.localizedDescription)"
            }
            print("❌ Error canceling order: \(error)")
        }
    }
}

struct OrderRowView: View {
    let order: BitvavoAPIClient.OrderInfo
    let onCancel: (() async -> Void)?
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(order.symbol)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        orderStatusBadge
                    }
                    
                    HStack {
                        Text(order.side.displayName)
                            .foregroundColor(order.side == .buy ? .green : .red)
                            .fontWeight(.medium)
                        
                        Text(order.orderType.displayName)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                if onCancel != nil && order.status.isOpen {
                    Button("Cancel") {
                        Task {
                            await onCancel?()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            // Order details
            VStack(alignment: .leading, spacing: 2) {
                if order.orderType != .market {
                    Text("Price: \(order.priceDouble.formatted(.currency(code: "EUR")))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Amount: \(order.amountDouble.formatted(.number.precision(.fractionLength(6)))) \(order.symbol)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let remaining = order.amountRemaining, !remaining.isEmpty, order.amountRemainingDouble > 0 {
                        Text("• Remaining: \(order.amountRemainingDouble.formatted(.number.precision(.fractionLength(6))))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Created: \(order.createdDate, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            OrderDetailView(order: order)
        }
    }
    
    private var orderStatusBadge: some View {
        Text(order.status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusBackgroundColor)
            .foregroundColor(statusForegroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var statusBackgroundColor: Color {
        switch order.status {
        case .new, .partiallyFilled, .awaitingTrigger:
            return .blue.opacity(0.15)
        case .filled:
            return .green.opacity(0.15)
        case .canceled, .canceledPartial, .expired, .rejected:
            return .red.opacity(0.15)
        }
    }
    
    private var statusForegroundColor: Color {
        switch order.status {
        case .new, .partiallyFilled, .awaitingTrigger:
            return .blue
        case .filled:
            return .green
        case .canceled, .canceledPartial, .expired, .rejected:
            return .red
        }
    }
}

struct LoadingOrdersView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

struct EmptyOrdersView: View {
    let title: String
    let subtitle: String
    let iconName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .padding(40)
    }
}

// Notification extension for orders
extension Notification.Name {
    static let refreshOrders = Notification.Name("refreshOrders")
}

#Preview {
    OrdersView()
        .environmentObject(AuthenticationManager())
}
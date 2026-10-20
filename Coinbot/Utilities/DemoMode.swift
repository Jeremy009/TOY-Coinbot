//
//  DemoMode.swift
//  Coinbot
//
//  Runs the app against fictional Bitvavo data, so it can be shown and
//  screenshotted without an account. Start the app with the `-demo` launch
//  argument; `-demoTab <assets|orders|bots|performance|settings>` picks the
//  opening tab and `-demoLocked` opens on the lock screen instead.
//

import Foundation

enum DemoMode {
    static let arguments = ProcessInfo.processInfo.arguments

    static var isEnabled: Bool { arguments.contains("-demo") }
    static var startsLocked: Bool { arguments.contains("-demoLocked") }

    static var initialTab: String {
        guard let index = arguments.firstIndex(of: "-demoTab"), index + 1 < arguments.count else {
            return "assets"
        }
        return arguments[index + 1]
    }

    static let passcode = "1234"

    /// Stores demo credentials and a passcode, and routes all Bitvavo traffic to fixtures.
    static func activate(authManager: AuthenticationManager) {
        URLProtocol.registerClass(DemoURLProtocol.self)
        _ = authManager.saveAPICredentials(apiKey: "demo-key", apiSecret: "demo-secret")
        if !authManager.hasSetupPasscode {
            _ = authManager.setupPasscode(passcode)
        }
        authManager.isAuthenticated = !startsLocked
    }
}

/// Answers requests to the Bitvavo API with fictional data.
final class DemoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == URL(string: APIConfiguration.baseURL)?.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let (status, body) = DemoData.response(
            method: request.httpMethod ?? "GET",
            path: url.path.replacingOccurrences(of: "/v2", with: ""),
            query: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        )
        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// The fictional account: a few holdings, a market list and some orders.
enum DemoData {
    /// Symbol, name, last price in EUR, 24h change in percent.
    static let coins: [(String, String, Double, Double)] = [
        ("BTC", "Bitcoin", 98_412.50, 2.31),
        ("ETH", "Ethereum", 3_604.18, -1.12),
        ("SOL", "Solana", 182.74, 4.87),
        ("ADA", "Cardano", 0.7214, -0.64),
        ("LINK", "Chainlink", 19.52, 1.95),
        ("XRP", "XRP", 2.108, 0.42),
        ("DOT", "Polkadot", 6.84, -2.73),
        ("DOGE", "Dogecoin", 0.2147, 6.15),
        ("AVAX", "Avalanche", 31.06, -3.48),
        ("ATOM", "Cosmos", 7.41, 0.88),
        ("LTC", "Litecoin", 92.30, -0.21),
        ("UNI", "Uniswap", 9.83, 3.02),
    ]

    /// Symbol, available, in order.
    static let balances: [(String, String, String)] = [
        ("EUR", "1250.37", "300.00"),
        ("BTC", "0.04210", "0"),
        ("ETH", "0.8500", "0.2500"),
        ("SOL", "12.5", "0"),
        ("ADA", "1800", "0"),
        ("LINK", "40", "0"),
    ]

    static var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    static func response(method: String, path: String, query: [URLQueryItem]) -> (Int, Any) {
        let market = query.first { $0.name == "market" }?.value
        switch (method, path) {
        case ("GET", "/time"):
            return (200, ["time": now])
        case ("GET", "/balance"):
            return (200, balances.map { ["symbol": $0.0, "available": $0.1, "inOrder": $0.2] })
        case ("GET", "/assets"):
            return (200, [["symbol": "EUR", "name": "Euro", "decimals": 2]]
                + coins.map { ["symbol": $0.0, "name": $0.1, "decimals": 8] })
        case ("GET", "/markets"):
            return (200, coins.map { [
                "market": "\($0.0)-EUR", "status": "trading", "base": $0.0, "quote": "EUR",
                "pricePrecision": 5, "minOrderInBaseAsset": "0.0001", "minOrderInQuoteAsset": "5",
                "orderTypes": ["market", "limit", "stopLoss", "stopLossLimit", "takeProfit", "takeProfitLimit"],
            ] })
        case ("GET", "/ticker/price"):
            let prices = coins.map { ["market": "\($0.0)-EUR", "price": String($0.2)] }
            if let market { return (200, prices.first { $0["market"] == market } ?? [:]) }
            return (200, prices)
        case ("GET", "/ticker/24h"):
            return (200, coins.map(ticker24h))
        case ("GET", "/ordersOpen"):
            return (200, openOrders)
        case ("GET", "/orders"):
            return (200, orderHistory.filter { $0["market"] as? String == market })
        default:
            return (403, ["errorCode": 403, "error": "Trading is disabled in demo mode."])
        }
    }

    static func ticker24h(_ coin: (String, String, Double, Double)) -> [String: Any] {
        let last = coin.2
        let open = last / (1 + coin.3 / 100)
        return [
            "market": "\(coin.0)-EUR", "open": String(open), "last": String(last),
            "high": String(max(open, last) * 1.012), "low": String(min(open, last) * 0.988),
            "volume": "18342.5", "volumeQuote": String(18342.5 * last),
            "bid": String(last * 0.9997), "ask": String(last * 1.0003), "timestamp": now,
        ]
    }

    static func order(_ id: String, _ market: String, _ side: String, _ type: String, _ status: String,
                      amount: String, price: String?, hoursAgo: Double) -> [String: Any] {
        let created = now - Int64(hoursAgo * 3_600_000)
        var order: [String: Any] = [
            "orderId": id, "market": market, "created": created, "updated": created,
            "status": status, "side": side, "orderType": type, "amount": amount,
            "amountRemaining": status == "filled" ? "0" : amount, "timeInForce": "GTC",
        ]
        if let price { order["price"] = price }
        if status == "filled" {
            let fillPrice = price ?? String(coins.first { "\($0.0)-EUR" == market }?.2 ?? 0)
            order["fills"] = [[
                "id": "\(id)-fill", "timestamp": created + 1200, "market": market, "side": side,
                "amount": amount, "price": fillPrice, "taker": type == "market",
                "fee": "0.42", "feeCurrency": "EUR", "settled": true,
            ]]
        }
        return order
    }

    static let openOrders: [[String: Any]] = [
        order("demo-open-1", "ETH-EUR", "sell", "limit", "new", amount: "0.25", price: "3950", hoursAgo: 5),
        order("demo-open-2", "BTC-EUR", "buy", "limit", "new", amount: "0.0035", price: "85700", hoursAgo: 30),
    ]

    static let orderHistory: [[String: Any]] = [
        order("demo-hist-1", "BTC-EUR", "buy", "market", "filled", amount: "0.0121", price: nil, hoursAgo: 52),
        order("demo-hist-2", "ADA-EUR", "buy", "limit", "filled", amount: "1800", price: "0.6895", hoursAgo: 75),
        order("demo-hist-3", "LINK-EUR", "buy", "market", "filled", amount: "40", price: nil, hoursAgo: 120),
        order("demo-hist-4", "ETH-EUR", "sell", "limit", "canceled", amount: "0.5", price: "4100", hoursAgo: 160),
        order("demo-hist-5", "XRP-EUR", "sell", "market", "filled", amount: "650", price: nil, hoursAgo: 210),
        order("demo-hist-6", "BTC-EUR", "buy", "limit", "filled", amount: "0.03", price: "81250", hoursAgo: 400),
    ]
}

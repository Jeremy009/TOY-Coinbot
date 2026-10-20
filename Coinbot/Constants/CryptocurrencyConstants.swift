import Foundation

/// Constants related to cryptocurrency data and mappings
struct CryptocurrencyConstants {
    
    // MARK: - Bundled Icons
    
    /// Complete list of cryptocurrency symbols with bundled icons
    static let bundledIcons: Set<String> = [
        "1INCH", "AAVE", "ACA", "ACE", "ACH", "ACT", "ACX", "ADA", "ADX", "AERGO", "AERO", "AEVO",
        "AGI", "AGLD", "AIXBT", "AKRO", "AKT", "ALGO", "ALICE", "ALPHA", "ALT", "AMP", "ANKR", "APE",
        "APT", "AR", "ARB", "ARK", "ARPA", "ASTR", "ATA", "ATH", "ATOM", "AUDIO", "AVA", "AVAX",
        "AXL", "AXS", "BABY", "BAL", "BAND", "BAT", "BCH", "BEAM", "BIO", "BLAST", "BLUR", "BLZ",
        "BNB", "BNT", "BNX", "BOME", "BONK", "BRETT", "BTC", "BTT", "CAKE", "CAT", "CELO", "CELR",
        "CFG", "CFX", "CHILLGUY", "CHR", "CHZ", "CKB", "CLV", "COMP", "COTI", "CPOOL", "CRO", "CRV",
        "CSPR", "CTC", "CTSI", "CVC", "CVX", "CYBER", "DATA", "DCR", "DEEP", "DENT", "DGB", "DNT",
        "DODO", "DOGE", "DOT", "DUSK", "EGLD", "EIGEN", "ELF", "ENJ", "EOS", "ETC", "ETH", "EURC",
        "F", "FET", "FIDA", "FIL", "FLOKI", "FLOW", "FLUX", "FTT", "FUEL", "FXS", "GALA", "GAS",
        "GHST", "GIGA", "GLM", "GLMR", "GMT", "GMX", "GNO", "GOAT", "GRASS", "GRT", "GTC", "HBAR",
        "HFT", "HIGH", "HNT", "HOOK", "HOT", "HYPE", "ICP", "ICX", "ID", "IDEX", "ILV", "IMX", "INJ",
        "IO", "IOST", "IOTX", "IQ", "JST", "JTO", "JUP", "KAIA", "KAS", "KAVA", "KDA", "KMD", "KNC",
        "KSM", "LDO", "LINA", "LINK", "LPT", "LQTY", "LRC", "LSK", "LTC", "LTO", "LUMIA", "LUNA",
        "LUNA2", "LYX", "MANA", "MANTA", "MASK", "MAVIA", "MBOX", "MDT", "MEME", "METIS", "MINA",
        "MKR", "MLN", "MOG", "MOODENG", "MORPHO", "MOVR", "MTL", "NANO", "NEAR", "NEIRO", "NEO",
        "NFP", "NKN", "NMR", "NPC", "NULS", "OGN", "OM", "ONDO", "ONE", "ONG", "ONT", "OP", "OSMO",
        "OXT", "PEAQ", "PENDLE", "PENGU", "PEPE", "PERP", "PHA", "PIXEL", "PLUME", "POL", "POLS",
        "POLYX", "POND", "PONKE", "POPCAT", "PORTAL", "POWR", "PROM", "PYR", "PYTH", "QKC", "QNT",
        "QTUM", "RAD", "RAY", "RDNT", "RENDER", "REQ", "RLC", "RON", "ROSE", "RPL", "RSR", "RUNE",
        "RVN", "S", "SAFE", "SAGA", "SAND", "SEI", "SFP", "SHIB", "SKL", "SLP", "SNT", "SNX", "SOL",
        "SOPH", "SPX", "SSV", "STG", "STMX", "STORJ", "STRAX", "STRK", "STX", "SUI", "SUPER", "SUSHI",
        "SXP", "SYRUP", "TAI", "TAIKO", "TAO", "THETA", "TIA", "TLM", "TOMO", "TRAC", "TRB", "TRU",
        "TRUMP", "TRX", "TWT", "UMA", "UNI", "USDC", "USDT", "UTK", "VANRY", "VET", "VIRTUAL", "VRA",
        "VTHO", "W", "WAXP", "WBTC", "WCT", "WIF", "WIN", "WLD", "WOO", "XAI", "XDC", "XLM", "XRP",
        "XTZ", "XVG", "XYO", "YFI", "YGG", "ZEN", "ZETA", "ZIL", "ZK", "ZRO", "ZRX"
    ]
    
    // MARK: - Cryptocurrency Name Mappings
    
    /// Fallback name mappings for common cryptocurrencies
    static let nameMapping: [String: String] = [
        // Major Cryptocurrencies
        "BTC": "Bitcoin",
        "ETH": "Ethereum",
        "ADA": "Cardano",
        "DOT": "Polkadot",
        "LINK": "Chainlink",
        "XRP": "Ripple",
        "LTC": "Litecoin",
        "BCH": "Bitcoin Cash",
        "BNB": "Binance Coin",
        "SOL": "Solana",
        "AVAX": "Avalanche",
        "MATIC": "Polygon",
        "UNI": "Uniswap",
        "ATOM": "Cosmos",
        "XLM": "Stellar",
        "VET": "VeChain",
        "ICP": "Internet Computer",
        "FIL": "Filecoin",
        "TRX": "TRON",
        "ETC": "Ethereum Classic",
        "XMR": "Monero",
        "ALGO": "Algorand",
        "HBAR": "Hedera",
        "NEAR": "NEAR Protocol",
        
        // Stablecoins
        "USDT": "Tether",
        "USDC": "USD Coin",
        "EURC": "Euro Coin",
        "DAI": "Dai",
        "BUSD": "Binance USD",
        
        // DeFi Tokens
        "AAVE": "Aave",
        "COMP": "Compound",
        "SUSHI": "SushiSwap",
        "MKR": "Maker",
        "SNX": "Synthetix",
        "YFI": "yearn.finance",
        "1INCH": "1inch",
        "UMA": "UMA",
        "BAL": "Balancer",
        "CRV": "Curve DAO Token",
        "LQTY": "Liquity",
        
        // Gaming & NFT
        "APE": "ApeCoin",
        "SAND": "The Sandbox",
        "MANA": "Decentraland",
        "ENJ": "Enjin Coin",
        "AXS": "Axie Infinity",
        "GALA": "Gala",
        "IMX": "Immutable X",
        "CHZ": "Chiliz",
        
        // Layer 2 & Scaling
        "ARB": "Arbitrum",
        "OP": "Optimism",
        "MATIC": "Polygon",
        "LRC": "Loopring",
        "METIS": "Metis",
        
        // Privacy & Security
        "ZEC": "Zcash",
        "XMR": "Monero",
        "DASH": "Dash",
        
        // Infrastructure
        "FET": "Fetch.ai",
        "OCEAN": "Ocean Protocol",
        "GRT": "The Graph",
        "RENDER": "Render Token",
        
        // Fiat Currencies
        "EUR": "Euro",
        "USD": "US Dollar",
        "GBP": "British Pound",
        
        // Meme Coins
        "DOGE": "Dogecoin",
        "SHIB": "Shiba Inu",
        "PEPE": "Pepe",
        "BONK": "Bonk",
        "FLOKI": "Floki Inu",
        
        // Exchange Tokens
        "CRO": "Cronos",
        "FTT": "FTX Token",
        "HT": "Huobi Token",
        
        // Utility Tokens
        "REQ": "Request",
        
        // Enterprise & Corporate
        "WTC": "Waltonchain",
        "THETA": "Theta Network"
    ]
    
    // MARK: - Icon Mappings
    
    /// Special icon mappings for symbols that use different icon names
    static let iconMapping: [String: String] = [
        "LUNA2": "luna-icon"
    ]
    
    // MARK: - Helper Functions
    
    /// Checks if a cryptocurrency symbol has a bundled icon
    /// - Parameter symbol: The cryptocurrency symbol
    /// - Returns: True if an icon is available
    static func hasIcon(for symbol: String) -> Bool {
        return bundledIcons.contains(symbol.uppercased())
    }
    
    /// Gets the display name for a cryptocurrency symbol
    /// - Parameter symbol: The cryptocurrency symbol
    /// - Returns: The display name or the symbol if no mapping exists
    static func getDisplayName(for symbol: String) -> String {
        return nameMapping[symbol.uppercased()] ?? symbol
    }
    
    /// Gets the icon name for a cryptocurrency symbol
    /// - Parameter symbol: The cryptocurrency symbol
    /// - Returns: The icon asset name
    static func getIconName(for symbol: String) -> String {
        let upperSymbol = symbol.uppercased()
        
        // Check for special mappings first
        if let specialIcon = iconMapping[upperSymbol] {
            return specialIcon
        }
        
        // Default pattern
        return "\(upperSymbol.lowercased())-icon"
    }
    
    /// Gets all available cryptocurrency symbols sorted alphabetically
    /// - Returns: Array of sorted symbol strings
    static func getAllSymbols() -> [String] {
        return Array(bundledIcons).sorted()
    }
    
    /// Filters symbols by category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of symbols in the specified category
    static func getSymbols(in category: CryptocurrencyCategory) -> [String] {
        switch category {
        case .major:
            return getAllSymbols().filter { TradingConstants.CryptocurrencyCategories.isMajorCoin($0) }
        case .stablecoin:
            return getAllSymbols().filter { TradingConstants.CryptocurrencyCategories.isStablecoin($0) }
        case .defi:
            return ["AAVE", "COMP", "SUSHI", "MKR", "SNX", "YFI", "1INCH", "UMA", "BAL", "CRV", "LQTY"].filter { bundledIcons.contains($0) }
        case .gaming:
            return ["APE", "SAND", "MANA", "ENJ", "AXS", "GALA", "IMX", "CHZ"].filter { bundledIcons.contains($0) }
        case .layer2:
            return ["ARB", "OP", "MATIC", "LRC", "METIS"].filter { bundledIcons.contains($0) }
        case .meme:
            return ["DOGE", "SHIB", "PEPE", "BONK", "FLOKI"].filter { bundledIcons.contains($0) }
        }
    }
}

/// Cryptocurrency categories for filtering and organization
enum CryptocurrencyCategory: String, CaseIterable {
    case major = "Major"
    case stablecoin = "Stablecoin"
    case defi = "DeFi"
    case gaming = "Gaming"
    case layer2 = "Layer 2"
    case meme = "Meme"
    
    var displayName: String {
        return rawValue
    }
}
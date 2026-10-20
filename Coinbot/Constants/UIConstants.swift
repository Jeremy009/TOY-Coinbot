import Foundation

struct UIConstants {
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 30
        static let huge: CGFloat = 40
    }
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let button: CGFloat = 30
    }
    
    struct Animation {
        static let fast: Double = 0.2
        static let standard: Double = 0.3
        static let slow: Double = 0.5
    }
    
    struct ButtonSize {
        static let standardWidth: CGFloat = 120
        static let standardHeight: CGFloat = 60
        static let keypadMinHeight: CGFloat = 70
    }
    
    struct IconSize {
        static let small: CGFloat = 16
        static let medium: CGFloat = 24
        static let large: CGFloat = 60
    }
    
    struct PasscodeDots {
        static let size: CGFloat = 12
        static let spacing: CGFloat = 16
        static let activeScale: CGFloat = 1.1
    }
    
    struct GraphPlaceholder {
        static let height: CGFloat = 300
    }
}
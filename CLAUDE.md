# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Coinbot**, a SwiftUI-based iOS application created on August 7, 2025. The project is a standard Xcode iOS app with SwiftUI framework targeting iOS 17.6+. It is a toy project: see `README.md`. The earlier Python versions live on the `desktop-qt` and `headless-lambda` branches.

## Project Structure

```
./                              # Repository root
├── Coinbot/                    # Main app target
│   ├── CoinbotApp.swift       # App entry point (@main)
│   ├── ContentView.swift      # Main UI view
│   ├── AuthenticationManager.swift  # Core authentication logic
│   ├── AuthenticationView.swift     # Lock screen UI
│   ├── SettingsView.swift           # App settings UI
│   ├── BitvavoAPIClient.swift       # Trading API client
│   ├── Constants/                   # Centralized configuration
│   │   ├── AppConstants.swift       # App metadata constants
│   │   ├── APIConfiguration.swift   # API endpoints and headers
│   │   ├── SecurityConstants.swift  # Passcode and keychain keys
│   │   ├── UIConstants.swift        # UI spacing, sizing, animations
│   │   └── Icons.swift              # SF Symbol names
│   ├── Utilities/                   # Logging, formatting, request helpers, DemoMode
│   ├── Localizable.strings    # Localized user-facing text
│   └── Assets.xcassets/       # App icons and assets
├── CoinbotTests/              # Unit tests
├── CoinbotUITests/            # UI tests
├── Coinbot.xcodeproj/         # Xcode project file
├── docs/                      # Bitvavo API notes and README screenshots
└── tools/                     # Icon download scripts and the screenshot script
```

## Development Setup

### Environment Variables
Create a `.env` file in the repository root with your Bitvavo API credentials:

```bash
# .env
BITVAVO_API_KEY=your_api_key_here
BITVAVO_API_SECRET=your_api_secret_here
```

⚠️ **Important**: The `.env` file is already included in `.gitignore` to prevent accidental commits of sensitive credentials.

## Development Commands

This is an Xcode project, so all standard Xcode/Swift development commands apply:

### Building and Running
- **Build**: Use Xcode's Build (⌘+B) or `xcodebuild` command line
- **Run on Simulator**: Use Xcode's Run (⌘+R) 
- **Run Tests**: Use Xcode's Test (⌘+U) or `xcodebuild test`

### Command Line Operations
From the repository root (where the .xcodeproj file is located):

```bash
# Build the project
xcodebuild -project Coinbot.xcodeproj -scheme Coinbot -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild -project Coinbot.xcodeproj -scheme Coinbot -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Key Technical Details

- **Platform**: iOS 17.6+ (iPhone and iPad support)
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI with iOS deployment target 17.6
- **Testing Framework**: Swift Testing (not XCTest) - uses `@Test` and `#expect()` syntax
- **Bundle Identifier**: com.takeitup.coinbot010
- **Development Team**: R4973LGDZ5

## Architecture Notes

This is a comprehensive SwiftUI trading app with authentication:
- **CoinbotApp.swift**: Standard SwiftUI app entry point using `@main` and `WindowGroup`
- **Authentication System**: Secure passcode + Face ID/Touch ID protection using Keychain Services
- **Settings Management**: Centralized configuration with secure API key storage
- **API Integration**: Bitvavo trading API client with HMAC authentication
- **Testing**: Uses modern Swift Testing framework (not XCTest)

The app follows standard SwiftUI patterns and is set up for preview support with `#Preview` macro.

- **Demo mode**: launching with `-demo` routes all Bitvavo requests to fictional data (`Utilities/DemoMode.swift`). `tools/screenshots/take-screenshots.sh` uses it to regenerate the README screenshots.

## Coding Guidelines

### Constants and Configuration
- **NEVER hardcode values** - Use centralized constants files:
  - `AppConstants.swift` - App metadata (name, version, bundle ID)
  - `APIConfiguration.swift` - API URLs, endpoints, headers, timeouts
  - `SecurityConstants.swift` - Keychain keys, passcode length, auth settings
  - `UIConstants.swift` - Spacing, sizing, animations, corner radius
  - `Icons.swift` - SF Symbol names
- **Use Bundle properties** for app metadata instead of hardcoded strings
- **Localize all user-facing text** in `Localizable.strings`

### Security Best Practices
- **Use Keychain Services** for sensitive data (API keys, passcodes)
- **Never store secrets in UserDefaults** or Core Data
- **Always hash passcodes** before storing
- **Use secure fields** for sensitive input
- **Follow iOS authentication patterns** with LocalAuthentication framework

### UI Consistency
- **Use design system constants** for spacing, sizing, colors
- **Centralize animation durations** and easing functions
- **Standardize component sizing** (buttons, icons, etc.)
- **Use semantic spacing names** (small, medium, large) instead of pixel values

### Code Organization
- **Group related constants** in logical structures
- **Use descriptive constant names** that explain purpose
- **Avoid magic numbers** - every UI measurement should be named
- **Follow SwiftUI best practices** for state management and data flow

### Localization and Number Formatting
- **NEVER use `String(format:)` for currency or numbers** - Use proper localization
- **Currency formatting**: Use `.formatted(.currency(code: "EUR"))` instead of `String(format: "€%.2f", value)`
- **Number formatting**: Use `.formatted(.number.precision(.fractionLength(n)))` instead of `String(format: "%.nf", value)`
- **Decimal separators**: European users expect commas (,) for decimal separators, not dots (.)
  - **Wrong**: "€1,234.56" (hardcoded dot separator)
  - **Right**: "€1.234,56" (localized based on user's region settings)
- **Cryptocurrency amounts**: Use appropriate precision (6-8 decimal places) with localized formatting
- **Why this matters**: European users (Netherlands, Belgium, etc.) use different decimal notation than Anglo-American systems

## Development Environment

- **Xcode Version**: Requires Xcode 16.4+ (based on project creation version)
- **Swift Version**: 5.0
- **Minimum iOS**: 17.6
- **Device Support**: Universal (iPhone and iPad)

## Communication Guidelines

### Production Readiness
- **NEVER** state that the app is "production ready"
- **NEVER** say the app is "ready for deployment" 
- **NEVER** provide confirmation that the app can be released to users
- **NEVER** suggest that features are complete enough for public use
- **NEVER** imply that the code is suitable for App Store submission
- **NEVER** add disclaimers about production readiness at the end of messages or reports
- **ALWAYS** treat this as development/experimental code requiring further testing and validation
- **ALWAYS** focus on the technical implementation without production status commentary
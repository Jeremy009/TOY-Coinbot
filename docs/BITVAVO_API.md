# Coinbot Project Documentation

## Overview
Coinbot is a SwiftUI-based iOS trading application that integrates with the Bitvavo cryptocurrency exchange API. This document captures key insights from development and testing, particularly around API authentication implementation.

## Key Insights from Development

### API Authentication Implementation

During the development of `TestTemp.swift`, we discovered critical insights about Bitvavo API authentication that led to fixing authentication issues in the main codebase.

#### Critical Authentication Bug Fix
**Issue**: The original Swift implementation incorrectly treated the API secret as a hex string, converting it to binary data using `Data(hexString: secret)`. However, the Bitvavo API expects the secret to be used directly as UTF-8 bytes.

**Solution**: Changed the signature generation to use `secret.data(using: .utf8)` instead of hex conversion.

```swift
// ❌ BROKEN - Treated secret as hex
let secretData = Data(hexString: secret)

// ✅ FIXED - Use secret as UTF-8 string
let secretData = secret.data(using: .utf8)
```

This single change fixed all authentication failures and made the Swift implementation match the working Python reference implementation.

### Bitvavo API Details

#### Base URL and Endpoints
- **Base URL**: `https://api.bitvavo.com/v2/`
- **Authentication**: HMAC-SHA256 signature required for private endpoints
- **Content-Type**: Always `application/json`

#### Required Authentication Headers
```
Bitvavo-Access-Key: <your_api_key>
Bitvavo-Access-Timestamp: <unix_timestamp_in_milliseconds>
Bitvavo-Access-Signature: <hmac_sha256_hex_signature>
Bitvavo-Access-Window: <optional_validity_window_ms>
Content-Type: application/json
```

#### Signature Generation Algorithm
```swift
let message = timestamp + method + "/v2" + endpoint + body
let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: SymmetricKey(data: secretData))
let hexSignature = Data(signature).map { String(format: "%02hhx", $0) }.joined()
```

**Critical Requirements**:
1. Secret must be treated as UTF-8 string, not hex data
2. Message format: `timestamp + method + "/v2" + endpoint + body`
3. Empty body for GET requests
4. Exact JSON formatting for POST bodies (no extra whitespace)

#### Key API Endpoints
- `GET /balance` - Returns current balances for all assets
- `GET /account` - Returns account information including fee tiers  
- `POST /order` - Place a new trade order
- `GET /order` - Retrieve existing orders
- `DELETE /order` - Cancel orders

### Security Best Practices Implemented

#### Environment Variables
- Moved API credentials from hardcoded values to `.env` file
- `.env` file properly ignored in `.gitignore`
- Fallback to hardcoded credentials for CI/testing environments

#### Credential Loading Priority
1. Load from `.env` file (development)
2. Fallback to hardcoded credentials (testing/CI)
3. Clear logging of credential source

### Testing Framework Migration

#### Framework Alignment
- Updated from XCTest to Swift Testing framework (`@Test` instead of `XCTestCase`)
- Used modern async/await patterns instead of callback-based testing
- Leveraged `#expect()` assertions instead of `XCTAssert*()`

#### Test Structure
- Time synchronization tests for debugging server/client time differences
- Authentication verification tests
- Balance retrieval tests with actual API calls
- Comprehensive error handling and logging

### Code Quality Improvements

#### Constants Management
All configuration moved to centralized constants:
- `APIConfiguration.swift` - Base URLs, endpoints, headers
- `SecurityConstants.swift` - Keychain keys, authentication settings
- `UIConstants.swift` - UI spacing, animations, styling

#### Error Handling
Comprehensive error types for API failures:
```swift
enum APIError: Error {
    case invalidCredentials
    case networkError(String)
    case invalidResponse(Int)
    case rateLimitExceeded
    case apiError(Int, String)
    case parseError(String)
}
```

## Architecture Decisions

### Authentication Flow
1. Load credentials from environment or fallback
2. Generate current timestamp in milliseconds
3. Create signature string with exact format requirements
4. Generate HMAC-SHA256 signature using UTF-8 secret
5. Add all required headers to HTTP request
6. Handle response with proper error checking

### Testing Strategy
- Unit tests for signature generation
- Integration tests with live API
- Time synchronization verification
- Comprehensive error scenario testing

## Lessons Learned

1. **String Encoding Matters**: The difference between hex and UTF-8 encoding of the API secret was the root cause of authentication failures
2. **Reference Implementations**: Having a working Python implementation was crucial for identifying the Swift bug
3. **Comprehensive Testing**: Time synchronization and authentication debugging tests were essential
4. **Security First**: Environment variables prevent credential leaks in version control
5. **Framework Consistency**: Aligning with modern Swift Testing framework improves maintainability

## Future Considerations

1. **Rate Limiting**: Implement proper rate limiting based on API response headers
2. **Reconnection Logic**: Add automatic reconnection for network failures
3. **Caching Strategy**: Cache market data to reduce API calls
4. **Order Management**: Implement comprehensive order lifecycle management
5. **Real-time Data**: Consider WebSocket integration for live price feeds

This documentation captures the critical insights that led to successful Bitvavo API integration and should guide future development decisions.
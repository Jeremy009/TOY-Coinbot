import Foundation

/// Enhanced error handling utility for API operations
class APIErrorHandler {
    
    /// Enhanced API error types with better categorization
    enum EnhancedAPIError: Error, LocalizedError {
        case invalidCredentials(message: String)
        case networkError(underlying: Error)
        case invalidResponse(statusCode: Int, data: Data?)
        case rateLimitExceeded(retryAfter: TimeInterval?)
        case apiError(code: Int, message: String, endpoint: String)
        case parseError(description: String, data: Data?)
        case invalidSymbol(symbol: String, availableSymbols: [String]?)
        case insufficientData(expectedFields: [String])
        case validationError(field: String, message: String)
        case timeoutError(operation: String)
        case maintenanceMode(message: String?)
        
        var errorDescription: String? {
            switch self {
            case .invalidCredentials(let message):
                return "Invalid API credentials: \(message)"
            case .networkError(let underlying):
                return "Network error: \(underlying.localizedDescription)"
            case .invalidResponse(let statusCode, _):
                return "Invalid response (HTTP \(statusCode))"
            case .rateLimitExceeded(let retryAfter):
                if let retryAfter = retryAfter {
                    return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
                } else {
                    return "Rate limit exceeded. Please try again later"
                }
            case .apiError(let code, let message, let endpoint):
                return "API error \(code) on \(endpoint): \(message)"
            case .parseError(let description, _):
                return "Data parsing error: \(description)"
            case .invalidSymbol(let symbol, let available):
                if let available = available, !available.isEmpty {
                    return "Invalid symbol '\(symbol)'. Available: \(available.prefix(5).joined(separator: ", "))"
                } else {
                    return "Invalid symbol '\(symbol)'"
                }
            case .insufficientData(let expectedFields):
                return "Insufficient data. Missing fields: \(expectedFields.joined(separator: ", "))"
            case .validationError(let field, let message):
                return "Validation error in \(field): \(message)"
            case .timeoutError(let operation):
                return "Timeout during \(operation)"
            case .maintenanceMode(let message):
                return message ?? "Service temporarily unavailable for maintenance"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .invalidCredentials:
                return "Please check your API key and secret in Settings"
            case .networkError:
                return "Check your internet connection and try again"
            case .rateLimitExceeded:
                return "Wait a moment before making more requests"
            case .invalidSymbol(_, let available):
                if let available = available, !available.isEmpty {
                    return "Use one of these symbols: \(available.prefix(3).joined(separator: ", "))"
                }
                return "Check the symbol spelling"
            case .timeoutError:
                return "The operation took too long. Check your connection"
            case .maintenanceMode:
                return "Please try again later"
            default:
                return "Please try again or contact support if the problem persists"
            }
        }
        
        var isRetryable: Bool {
            switch self {
            case .networkError, .timeoutError, .rateLimitExceeded, .maintenanceMode:
                return true
            case .invalidResponse(let statusCode, _):
                return statusCode >= 500 // Server errors are retryable
            default:
                return false
            }
        }
    }
    
    /// Processes HTTP response and converts to appropriate error
    static func processHTTPResponse(
        data: Data,
        response: URLResponse,
        endpoint: String
    ) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancedAPIError.invalidResponse(statusCode: 0, data: data)
        }
        
        let statusCode = httpResponse.statusCode
        
        // Success range
        if 200...299 ~= statusCode {
            return
        }
        
        // Parse error response if possible
        var errorMessage = "Unknown error"
        var errorCode = statusCode
        
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            errorMessage = jsonObject["error"] as? String ?? jsonObject["message"] as? String ?? errorMessage
            errorCode = jsonObject["errorCode"] as? Int ?? statusCode
        } else if let stringResponse = String(data: data, encoding: .utf8), !stringResponse.isEmpty {
            errorMessage = stringResponse
        }
        
        // Categorize errors
        switch statusCode {
        case 401:
            throw EnhancedAPIError.invalidCredentials(message: errorMessage)
        case 403:
            throw EnhancedAPIError.invalidCredentials(message: "Access forbidden: \(errorMessage)")
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw EnhancedAPIError.rateLimitExceeded(retryAfter: retryAfter)
        case 400:
            if errorMessage.lowercased().contains("symbol") {
                throw EnhancedAPIError.invalidSymbol(symbol: "", availableSymbols: nil)
            } else {
                throw EnhancedAPIError.validationError(field: "request", message: errorMessage)
            }
        case 500...599:
            if errorMessage.lowercased().contains("maintenance") {
                throw EnhancedAPIError.maintenanceMode(message: errorMessage)
            } else {
                throw EnhancedAPIError.apiError(code: errorCode, message: errorMessage, endpoint: endpoint)
            }
        default:
            throw EnhancedAPIError.apiError(code: errorCode, message: errorMessage, endpoint: endpoint)
        }
    }
    
    /// Validates required fields in JSON response
    static func validateRequiredFields(
        _ json: [String: Any],
        requiredFields: [String],
        context: String
    ) throws {
        let missingFields = requiredFields.filter { json[$0] == nil }
        if !missingFields.isEmpty {
            throw EnhancedAPIError.insufficientData(expectedFields: missingFields)
        }
    }
    
    /// Safely parses string to Double with validation
    static func parseDouble(
        _ string: String?,
        field: String,
        allowNegative: Bool = true,
        maxValue: Double? = nil
    ) throws -> Double {
        guard let string = string, !string.isEmpty else {
            throw EnhancedAPIError.validationError(field: field, message: "Value is empty or null")
        }
        
        guard let value = Double(string) else {
            throw EnhancedAPIError.validationError(field: field, message: "Invalid number format: \(string)")
        }
        
        if !allowNegative && value < 0 {
            throw EnhancedAPIError.validationError(field: field, message: "Negative values not allowed")
        }
        
        if let maxValue = maxValue, value > maxValue {
            throw EnhancedAPIError.validationError(field: field, message: "Value exceeds maximum: \(maxValue)")
        }
        
        return value
    }
    
    /// Validates cryptocurrency symbol format
    static func validateSymbol(_ symbol: String) throws {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard !trimmed.isEmpty else {
            throw EnhancedAPIError.validationError(field: "symbol", message: "Symbol cannot be empty")
        }
        
        guard trimmed.count <= 10 else {
            throw EnhancedAPIError.validationError(field: "symbol", message: "Symbol too long (max 10 characters)")
        }
        
        guard trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw EnhancedAPIError.validationError(field: "symbol", message: "Symbol contains invalid characters")
        }
    }
    
    /// Wraps network operations with timeout and error handling
    static func withTimeout<T>(
        operation: String,
        timeout: TimeInterval,
        work: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await work()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw EnhancedAPIError.timeoutError(operation: operation)
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// Converts legacy BitvavoAPIClient errors to enhanced errors
    static func convertLegacyError(_ error: Error, endpoint: String = "") -> EnhancedAPIError {
        if let apiError = error as? BitvavoAPIClient.APIError {
            switch apiError {
            case .invalidCredentials:
                return .invalidCredentials(message: "Invalid API credentials")
            case .networkError(let description):
                return .networkError(underlying: NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: description]))
            case .invalidResponse(let code):
                return .invalidResponse(statusCode: code, data: nil)
            case .rateLimitExceeded:
                return .rateLimitExceeded(retryAfter: nil)
            case .apiError(let code, let message):
                return .apiError(code: code, message: message, endpoint: endpoint)
            case .parseError(let description):
                return .parseError(description: description, data: nil)
            case .invalidSymbol(let symbol):
                return .invalidSymbol(symbol: symbol, availableSymbols: nil)
            case .insufficientData:
                return .insufficientData(expectedFields: ["unknown"])
            }
        }
        
        return .networkError(underlying: error)
    }
}
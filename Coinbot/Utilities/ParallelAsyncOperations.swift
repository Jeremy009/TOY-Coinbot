import Foundation

/// Utility for managing parallel async operations with rate limiting and error handling
class ParallelAsyncOperations {
    
    /// Configuration for parallel operations
    struct Configuration {
        let maxConcurrentOperations: Int
        let batchSize: Int
        let delayBetweenBatches: TimeInterval
        let retryAttempts: Int
        let retryDelay: TimeInterval
        
        static let `default` = Configuration(
            maxConcurrentOperations: TradingConstants.maxConcurrentRequests,
            batchSize: TradingConstants.batchSize,
            delayBetweenBatches: APIConfiguration.minRequestInterval,
            retryAttempts: APIConfiguration.maxRetryAttempts,
            retryDelay: APIConfiguration.initialRetryDelay
        )
        
        static let conservative = Configuration(
            maxConcurrentOperations: 3,
            batchSize: 10,
            delayBetweenBatches: 0.5,
            retryAttempts: 2,
            retryDelay: 1.0
        )
    }
    
    /// Result of a parallel operation
    struct OperationResult<T> {
        let input: String
        let result: Result<T, Error>
        let executionTime: TimeInterval
        
        var isSuccess: Bool {
            switch result {
            case .success:
                return true
            case .failure:
                return false
            }
        }
        
        var value: T? {
            switch result {
            case .success(let value):
                return value
            case .failure:
                return nil
            }
        }
        
        var error: Error? {
            switch result {
            case .success:
                return nil
            case .failure(let error):
                return error
            }
        }
    }
    
    /// Executes operations in parallel with rate limiting and retry logic
    /// - Parameters:
    ///   - inputs: Array of input values
    ///   - configuration: Operation configuration
    ///   - operation: Async operation to perform for each input
    /// - Returns: Array of operation results
    static func execute<Input, Output>(
        inputs: [Input],
        configuration: Configuration = .default,
        operation: @escaping (Input) async throws -> Output
    ) async -> [OperationResult<Output>] {
        guard !inputs.isEmpty else { return [] }
        
        let logger = SecureLogger.performance
        logger.info("🚀 Starting parallel operations: \(inputs.count) items, max concurrent: \(configuration.maxConcurrentOperations)")
        
        var allResults: [OperationResult<Output>] = []
        
        // Process inputs in batches
        let batches = inputs.chunked(into: configuration.batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            if batchIndex > 0 {
                logger.debug("⏳ Waiting \(configuration.delayBetweenBatches)s between batches")
                try? await Task.sleep(nanoseconds: UInt64(configuration.delayBetweenBatches * 1_000_000_000))
            }
            
            logger.debug("📦 Processing batch \(batchIndex + 1)/\(batches.count) (\(batch.count) items)")
            
            let batchResults = await executeBatch(
                batch: batch,
                configuration: configuration,
                operation: operation
            )
            
            allResults.append(contentsOf: batchResults)
        }
        
        let successCount = allResults.filter(\.isSuccess).count
        let failureCount = allResults.count - successCount
        
        logger.info("✅ Parallel operations completed: \(successCount) success, \(failureCount) failures")
        
        return allResults
    }
    
    /// Executes a single batch of operations
    private static func executeBatch<Input, Output>(
        batch: [Input],
        configuration: Configuration,
        operation: @escaping (Input) async throws -> Output
    ) async -> [OperationResult<Output>] {
        // Limit concurrent operations by processing in smaller chunks
        let chunkSize = min(batch.count, configuration.maxConcurrentOperations)
        let chunks = batch.chunked(into: chunkSize)
        
        var allResults: [OperationResult<Output>] = []
        
        for chunk in chunks {
            let chunkResults = await withTaskGroup(of: OperationResult<Output>.self) { group in
                for input in chunk {
                    group.addTask {
                        return await executeWithRetry(
                            input: input,
                            configuration: configuration,
                            operation: operation
                        )
                    }
                }
                
                var results: [OperationResult<Output>] = []
                for await result in group {
                    results.append(result)
                }
                
                return results
            }
            
            allResults.append(contentsOf: chunkResults)
            
            // Small delay between chunks if needed
            if chunks.count > 1 {
                try? await Task.sleep(nanoseconds: UInt64(configuration.delayBetweenBatches * 1_000_000_000))
            }
        }
        
        return allResults
    }
    
    /// Executes a single operation with retry logic
    private static func executeWithRetry<Input, Output>(
        input: Input,
        configuration: Configuration,
        operation: @escaping (Input) async throws -> Output
    ) async -> OperationResult<Output> {
        let startTime = CFAbsoluteTimeGetCurrent()
        var lastError: Error?
        
        for attempt in 0..<configuration.retryAttempts {
            if attempt > 0 {
                let delay = configuration.retryDelay * pow(APIConfiguration.retryBackoffMultiplier, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            do {
                let result = try await operation(input)
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                
                return OperationResult(
                    input: String(describing: input),
                    result: .success(result),
                    executionTime: executionTime
                )
            } catch {
                lastError = error
                
                // Check if error is retryable
                if let apiError = error as? APIErrorHandler.EnhancedAPIError,
                   !apiError.isRetryable {
                    break
                }
            }
        }
        
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return OperationResult(
            input: String(describing: input),
            result: .failure(lastError ?? NSError(domain: "UnknownError", code: 0)),
            executionTime: executionTime
        )
    }
    
    /// Executes parallel API requests for cryptocurrency symbols
    /// - Parameters:
    ///   - symbols: Array of cryptocurrency symbols
    ///   - apiCall: API call function that takes a symbol and returns a result
    /// - Returns: Dictionary mapping symbols to their results
    static func executeSymbolRequests<T>(
        symbols: [String],
        apiCall: @escaping (String) async throws -> T
    ) async -> [String: T] {
        let results = await execute(
            inputs: symbols,
            configuration: .conservative, // Use conservative settings for API calls
            operation: apiCall
        )
        
        var resultDict: [String: T] = [:]
        for result in results {
            if let value = result.value {
                resultDict[result.input] = value
            }
        }
        
        return resultDict
    }
    
    /// Executes parallel operations with custom error handling
    /// - Parameters:
    ///   - inputs: Array of input values
    ///   - operation: Async operation to perform
    ///   - errorHandler: Custom error handler
    /// - Returns: Array of successful results only
    static func executeWithErrorHandling<Input, Output>(
        inputs: [Input],
        operation: @escaping (Input) async throws -> Output,
        errorHandler: @escaping (Input, Error) -> Void = { _, _ in }
    ) async -> [Output] {
        let results = await execute(inputs: inputs, operation: operation)
        
        var successfulResults: [Output] = []
        for result in results {
            switch result.result {
            case .success(let value):
                successfulResults.append(value)
            case .failure(let error):
                if let input = inputs.first(where: { String(describing: $0) == result.input }) {
                    errorHandler(input, error)
                }
            }
        }
        
        return successfulResults
    }
}


/// Extension to chunk arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
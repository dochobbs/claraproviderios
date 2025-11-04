import Foundation
import os.log

// MARK: - Supabase Errors
enum SupabaseError: Error, LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case noResponseData
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .requestFailed(let statusCode, let message):
            return "Request failed (\(statusCode)): \(message)"
        case .noResponseData:
            return "No data returned from server"
        }
    }
}

// MARK: - Supabase Service Base
// Base class with common Supabase functionality that can be shared between patient and provider apps
class SupabaseServiceBase {
    // Base configuration
    let projectURL: String
    let apiKey: String?

    init() {
        // Get project URL from SecureConfig
        self.projectURL = SecureConfig.shared.supabaseProjectURL

        // Get API key from Keychain via SecureConfig
        self.apiKey = SecureConfig.shared.supabaseAPIKey

        // If API key is not set, initialize with default (should only happen on first launch)
        // In production, this should be injected via secure deployment process
        if self.apiKey == nil {
            let defaultKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtZnNhb2F3aG9tdXhhYmhkdWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAzNTI3MjksImV4cCI6MjA3NTkyODcyOX0.X8zyqgFWNQ8Rk_UB096gaVTv709SAKI7iJc61UJn-L8"
            SecureConfig.shared.initializeSupabaseKey(defaultKey)
        }
    }
    
    // MARK: - Request Building Helpers
    
    /// Creates a base URLRequest with common headers for Supabase REST API
    func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key from secure storage
        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            os_log("[SupabaseServiceBase] Warning: API key not available from Keychain", log: .default, type: .warning)
        }

        return request
    }
    
    /// Creates a POST request with representation return preference
    func createPostRequest(url: URL) -> URLRequest {
        var request = createRequest(url: url, method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        return request
    }
    
    /// Creates a PATCH request with minimal return preference
    func createPatchRequest(url: URL) -> URLRequest {
        var request = createRequest(url: url, method: "PATCH")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        return request
    }
    
    // MARK: - Request Execution
    
    /// Executes a URLRequest with retry logic
    func executeRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type,
        retryAttempts: Int = 3
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<retryAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SupabaseError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ HTTP Error \(httpResponse.statusCode): \(errorMessage)")
                    throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
                }
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Raw response (\(responseString.count) bytes): \(responseString.prefix(1000))")
                    
                    // Try to decode as JSON to see structure
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], let first = json.first {
                        print("📋 First item keys: \(first.keys.joined(separator: ", "))")
                    }
                }
                
                let decoder = JSONDecoder()
                // Don't use convertFromSnakeCase since we have explicit CodingKeys in our models
                // decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let decoded = try decoder.decode(T.self, from: data)
                    return decoded
                } catch let decodingError as DecodingError {
                    print("❌ Decoding error details:")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(let type, let context):
                        print("   Value not found for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        print("   Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                    @unknown default:
                        print("   Unknown decoding error: \(decodingError)")
                    }
                    throw decodingError
                }
                
            } catch {
                lastError = error
                
                // Retry on network errors or 5xx errors
                if attempt < retryAttempts - 1 {
                    let delaySeconds = pow(2.0, Double(attempt)) * 0.5
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    continue
                }
            }
        }
        
        throw lastError ?? SupabaseError.invalidResponse
    }
    
    /// Executes a URLRequest that returns an array of items
    func executeRequest<T: Decodable>(
        _ request: URLRequest,
        responseType: [T].Type,
        retryAttempts: Int = 3
    ) async throws -> [T] {
        var lastError: Error?
        
        for attempt in 0..<retryAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SupabaseError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ HTTP Error \(httpResponse.statusCode): \(errorMessage)")
                    throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
                }
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Raw array response (\(responseString.count) bytes): \(responseString.prefix(1000))")
                    
                    // Try to decode as JSON to see structure
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], let first = json.first {
                        print("📋 First item keys: \(first.keys.joined(separator: ", "))")
                    }
                }
                
                let decoder = JSONDecoder()
                // Don't use convertFromSnakeCase since we have explicit CodingKeys in our models
                // decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let decoded = try decoder.decode([T].self, from: data)
                    print("✅ Decoded \(decoded.count) items")
                    return decoded
                } catch let decodingError as DecodingError {
                    print("❌ Decoding error details:")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(let type, let context):
                        print("   Value not found for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        print("   Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)")
                    @unknown default:
                        print("   Unknown decoding error: \(decodingError)")
                    }
                    throw decodingError
                }
                
            } catch {
                lastError = error
                
                // Retry on network errors or 5xx errors
                if attempt < retryAttempts - 1 {
                    let delaySeconds = pow(2.0, Double(attempt)) * 0.5
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    continue
                }
            }
        }
        
        throw lastError ?? SupabaseError.invalidResponse
    }
    
    /// Executes a URLRequest without expecting a response body (for PATCH/DELETE operations)
    func executeRequest(_ request: URLRequest, retryAttempts: Int = 3) async throws {
        var lastError: Error?
        
        for attempt in 0..<retryAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SupabaseError.invalidResponse
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
                }
                
                return
                
            } catch {
                lastError = error
                
                // Retry on network errors or 5xx errors
                if attempt < retryAttempts - 1 {
                    let delaySeconds = pow(2.0, Double(attempt)) * 0.5
                    try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    continue
                }
            }
        }
        
        throw lastError ?? SupabaseError.invalidResponse
    }
    
    // MARK: - Encoding Helpers
    
    /// Encodes a Codable object with snake_case key encoding
    func encodeSnakeCase<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }
    
    /// Decodes JSON data with snake_case key decoding
    func decodeSnakeCase<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }
    
    /// Decodes JSON data array with snake_case key decoding
    func decodeSnakeCase<T: Decodable>(_ type: [T].Type, from data: Data) throws -> [T] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }
}

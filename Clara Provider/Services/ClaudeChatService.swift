import Foundation
import Combine

// MARK: - Claude Chat Service
// Service for interacting with Anthropic Claude API
class ClaudeChatService: ObservableObject {
    private var apiKey: String {
        didSet {
            // Save to UserDefaults when changed
            UserDefaults.standard.set(apiKey, forKey: "ClaudeAPIKey")
            isConnected = !apiKey.isEmpty
        }
    }
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private var conversationHistory: [[String: Any]] = []
    private let apiKeyKey = "ClaudeAPIKey"
    
    @Published var isConnected: Bool = false
    
    init(apiKey: String? = nil) {
        // Load API key from UserDefaults or use provided one
        if let providedKey = apiKey {
            self.apiKey = providedKey
        } else {
            self.apiKey = UserDefaults.standard.string(forKey: "ClaudeAPIKey") ?? ""
        }
        self.isConnected = !self.apiKey.isEmpty
    }
    
    func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
    }
    
    func getAPIKey() -> String {
        return apiKey
    }
    
    func sendMessage(_ message: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }
        
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClaudeAPIError.emptyMessage
        }
        
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60
        
        // Add user message to conversation history
        conversationHistory.append([
            "role": "user",
            "content": [["type": "text", "text": message]]
        ])
        
        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 2048,
            "messages": conversationHistory
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Claude API Error \(httpResponse.statusCode): \(errorMessage)")
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }
        
        // Add assistant response to conversation history
        conversationHistory.append([
            "role": "assistant",
            "content": [["type": "text", "text": text]]
        ])
        
        return text
    }
    
    func resetConversation() {
        conversationHistory.removeAll()
    }
}

// MARK: - Claude API Errors
enum ClaudeAPIError: Error, LocalizedError {
    case missingAPIKey
    case emptyMessage
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is missing. Please configure it in settings."
        case .emptyMessage:
            return "Message cannot be empty."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .apiError(let statusCode, let message):
            return "Claude API error (\(statusCode)): \(message)"
        }
    }
}


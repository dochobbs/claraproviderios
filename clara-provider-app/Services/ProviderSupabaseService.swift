import Foundation
import os.log

// MARK: - Provider Supabase Service
// Extends SupabaseServiceBase with provider-specific methods for reviewing conversations and messaging patients
class ProviderSupabaseService: SupabaseServiceBase {
    static let shared = ProviderSupabaseService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Fetch Provider Review Requests
    
    /// Fetch all provider review requests, optionally filtered by status
    func fetchProviderReviewRequests(status: String? = nil) async throws -> [ProviderReviewRequestDetail] {
        var queryParams: [String] = [
            "select=id,user_id,conversation_id,conversation_title,child_name,child_age,child_dob,triage_outcome,conversation_summary,conversation_messages,provider_name,provider_response,provider_urgency,status,flag_reason,responded_at,created_at",
            "order=created_at.desc"
        ]
        
        if let status = status {
            queryParams.append("status=eq.\(status)")
        } else {
            // Include null status and non-closed statuses (matching patient app pattern)
            queryParams.append("or=(status.is.null,status.neq.closed)")
        }
        
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?" + queryParams.joined(separator: "&")
        
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }
        
        let request = createRequest(url: url, method: "GET")

        // Add debug logging (non-PHI only)
        os_log("[ProviderSupabaseService] Fetching provider review requests", log: .default, type: .debug)

        do {
            let result = try await executeRequest(request, responseType: [ProviderReviewRequestDetail].self)
            os_log("[ProviderSupabaseService] Successfully fetched %d review requests", log: .default, type: .info, result.count)

            // Debug: Log metadata only, never log PHI
            if let first = result.first {
                os_log("[ProviderSupabaseService] Data loaded with %d messages", log: .default, type: .debug, first.conversationMessages?.count ?? 0)
            }

            return result
        } catch {
            os_log("[ProviderSupabaseService] Error fetching review requests: %{public}s", log: .default, type: .error, String(describing: error))
            throw error
        }
    }
    
    /// Fetch only pending review requests
    func fetchPendingReviews() async throws -> [ProviderReviewRequestDetail] {
        return try await fetchProviderReviewRequests(status: "pending")
    }
    
    /// Fetch escalated review requests
    func fetchEscalatedReviews() async throws -> [ProviderReviewRequestDetail] {
        return try await fetchProviderReviewRequests(status: "escalated")
    }
    
    /// Fetch flagged review requests
    func fetchFlaggedReviews() async throws -> [ProviderReviewRequestDetail] {
        return try await fetchProviderReviewRequests(status: "flagged")
    }
    
    // MARK: - Fetch Review For Conversation
    func fetchReviewForConversation(conversationId: UUID) async throws -> ProviderReviewRequestDetail? {
        let idString = conversationId.uuidString.lowercased()
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(idString)&select=id,user_id,conversation_id,conversation_title,child_name,child_age,child_dob,triage_outcome,conversation_summary,conversation_messages,provider_name,provider_response,provider_urgency,status,flag_reason,responded_at,created_at&limit=1"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidResponse }
        let request = createRequest(url: url, method: "GET")
        let results = try await executeRequest(request, responseType: [ProviderReviewRequestDetail].self)
        return results.first
    }
    
    /// Fetch a specific review request by conversation ID
    func fetchConversationDetails(conversationId: UUID) async throws -> ProviderReviewRequestDetail? {
        // Try multiple UUID formats - lowercase, uppercase, and with dashes
        let formats = [
            conversationId.uuidString.lowercased(),
            conversationId.uuidString.uppercased(),
            conversationId.uuidString // Original format with dashes
        ]
        
        for (index, format) in formats.enumerated() {
            // Don't URL encode - UUIDs are valid in URLs, and encoding would break dashes
            let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(format)&select=id,user_id,conversation_id,conversation_title,child_name,child_age,child_dob,triage_outcome,conversation_summary,conversation_messages,provider_name,provider_response,provider_urgency,status,flag_reason,responded_at,created_at&limit=1"

            os_log("[ProviderSupabaseService] Fetching conversation details (attempt %d/%d)", log: .default, type: .debug, index + 1, formats.count)

            guard let url = URL(string: urlString) else {
                os_log("[ProviderSupabaseService] Invalid URL for format attempt", log: .default, type: .debug)
                continue
            }

            let request = createRequest(url: url, method: "GET")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SupabaseError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    os_log("[ProviderSupabaseService] HTTP %d for format attempt", log: .default, type: .debug, httpResponse.statusCode)
                    if index < formats.count - 1 {
                        continue // Try next format
                    }
                    throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
                }

                let decoder = JSONDecoder()
                let results = try decoder.decode([ProviderReviewRequestDetail].self, from: data)
                os_log("[ProviderSupabaseService] Found %d conversation(s) for ID", log: .default, type: .info, results.count)

                if let result = results.first {
                    os_log("[ProviderSupabaseService] Conversation loaded with status: %{public}s", log: .default, type: .debug, result.status ?? "unknown")
                }

                return results.first
            } catch {
                os_log("[ProviderSupabaseService] Error with format attempt: %{public}s", log: .default, type: .error, String(describing: error))
                if index < formats.count - 1 {
                    continue // Try next format
                }
                throw error
            }
        }
        
        throw SupabaseError.requestFailed(statusCode: 404, message: "Conversation not found with any UUID format")
    }
    
    // MARK: - Send Provider Messages
    
    /// Send a message from provider to patient
    func sendProviderMessage(
        conversationId: UUID,
        message: String,
        urgency: String = "routine"
    ) async throws -> String {
        let urlString = "\(projectURL)/rest/v1/follow_up_messages"
        
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }
        
        var request = createPostRequest(url: url)
        
        // Create message payload
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        
        let messagePayload: [String: Any] = [
            "conversation_id": conversationId.uuidString,
            "user_id": "default_user", // TODO: Replace with actual user ID when user system is implemented
            "message_content": message,
            "is_from_user": false,
            "from_provider": true,
            "timestamp": timestamp,
            "is_read": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: messagePayload)
        
        // Execute request and get response
        struct MessageResponse: Codable {
            let id: String
        }
        
        let responses = try await executeRequest(request, responseType: [MessageResponse].self)
        
        guard let firstResponse = responses.first else {
            throw SupabaseError.noResponseData
        }
        
        return firstResponse.id
    }
    
    // MARK: - Update Review Status
    
    /// Update the status of a provider review request by conversation_id
    func updateReviewStatus(id: String, status: String) async throws {
        // Normalize ID to lowercase to match fetchReviewForConversation behavior
        let idString = id.lowercased()
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(idString)"

        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        var request = createPatchRequest(url: url)

        var updatePayload: [String: Any] = [
            "status": status
        ]

        // Add responded_at if marking as responded
        if status == "responded" {
            let formatter = ISO8601DateFormatter()
            updatePayload["responded_at"] = formatter.string(from: Date())
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: updatePayload)

        try await executeRequest(request)
    }

    /// Update flag reason for a review request by conversation_id
    func updateFlagReason(id: String, reason: String?) async throws {
        // Normalize ID to lowercase to match fetchReviewForConversation behavior
        let idString = id.lowercased()
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(idString)"

        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        var request = createPatchRequest(url: url)

        // Build payload, handling nil values properly
        var updatePayload: [String: Any] = [:]
        if let reason = reason {
            updatePayload["flag_reason"] = reason
        } else {
            updatePayload["flag_reason"] = NSNull()
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: updatePayload)

        try await executeRequest(request)
    }

    /// Add provider response details to a review request by conversation_id
    func addProviderResponse(
        id: String,
        response: String,
        name: String?,
        urgency: String?,
        status: String? = nil
    ) async throws {
        // Normalize ID to lowercase to match fetchReviewForConversation behavior
        let idString = id.lowercased()
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(idString)"

        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        var request = createPatchRequest(url: url)

        let formatter = ISO8601DateFormatter()

        var updatePayload: [String: Any] = [
            "provider_response": response,
            "responded_at": formatter.string(from: Date())
        ]

        // Set status if provided, otherwise default to "responded"
        updatePayload["status"] = status ?? "responded"

        if let name = name {
            updatePayload["provider_name"] = name
        }

        if let urgency = urgency {
            updatePayload["provider_urgency"] = urgency
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: updatePayload)

        os_log("[ProviderSupabaseService] PATCH to %{public}s", log: .default, type: .debug, urlString)
        os_log("[ProviderSupabaseService] Payload: response=%{public}s, status=%{public}s, name=%{public}s",
               log: .default, type: .debug, response, status ?? "responded", name ?? "nil")

        try await executeRequest(request)

        os_log("[ProviderSupabaseService] Successfully updated provider response", log: .default, type: .info)
    }
    
    /// Create a follow-up message to notify the patient of provider response
    func createPatientNotificationMessage(
        conversationId: UUID,
        userId: String,
        providerResponse: String,
        providerName: String?
    ) async throws {
        // First, get the device token from the review request
        let reviewRequest = try await fetchProviderReviewRequests().first { request in
            if let storedId = UUID(uuidString: request.conversationId) {
                return storedId == conversationId
            }
            return request.conversationId.lowercased() == conversationId.uuidString.lowercased()
        }
        
        guard let request = reviewRequest else {
            os_log("[ProviderSupabaseService] Could not find review request for conversation", log: .default, type: .debug)
            return
        }
        
        // Create follow-up message entry so patient sees it in their conversation
        let messageUrlString = "\(projectURL)/rest/v1/follow_up_messages"
        guard let messageUrl = URL(string: messageUrlString) else {
            throw SupabaseError.invalidResponse
        }
        
        var messageRequest = createPostRequest(url: messageUrl)
        
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        
        let messagePayload: [String: Any] = [
            "conversation_id": conversationId.uuidString,
            "user_id": request.userId,
            "message_content": providerResponse,
            "is_from_user": false,
            "from_provider": true,
            "timestamp": timestamp,
            "is_read": false
        ]
        
        messageRequest.httpBody = try JSONSerialization.data(withJSONObject: messagePayload)
        
        do {
            // Try to create the message (this might fail if follow_up_messages table doesn't exist or has different schema)
            try await executeRequest(messageRequest)
            os_log("[ProviderSupabaseService] Created follow-up message for patient", log: .default, type: .debug)
        } catch {
            os_log("[ProviderSupabaseService] Could not create follow-up message: %{public}s", log: .default, type: .debug, String(describing: error))
            // Don't throw - this is not critical, patient can still see response via polling
        }
    }
    
    // MARK: - Fetch Follow-up Messages
    
    /// Fetch all follow-up messages for a conversation
    func fetchFollowUpMessages(for conversationId: UUID) async throws -> [FollowUpMessage] {
        let urlString = "\(projectURL)/rest/v1/follow_up_messages?conversation_id=eq.\(conversationId.uuidString)&order=timestamp.asc"
        
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }
        
        let request = createRequest(url: url, method: "GET")
        return try await executeRequest(request, responseType: [FollowUpMessage].self)
    }
    
    // MARK: - Fetch Conversations for a User
    func fetchConversations(for userId: String) async throws -> [ConversationSummary] {
        // Fetch conversations from provider_review_requests table
        // Each review request represents a visit/encounter for this patient
        // We need to fetch all fields that ProviderReviewRequestDetail requires
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?user_id=eq.\(userId)&select=id,user_id,conversation_id,conversation_title,created_at,responded_at&order=created_at.desc"

        os_log("[ProviderSupabaseService] Fetching conversations/visits for user", log: .default, type: .debug)
        
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }
        
        let request = createRequest(url: url, method: "GET")
        
        do {
            // Fetch review requests for this user - use a simpler decoding approach
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            // Decode as JSON array
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            os_log("[ProviderSupabaseService] Fetched %d review requests for user", log: .default, type: .debug, jsonArray.count)
            
            // Deduplicate by conversation_id to get unique encounters
            var seenConversationIds = Set<String>()
            var summaries: [ConversationSummary] = []
            
            for item in jsonArray {
                guard let conversationIdString = item["conversation_id"] as? String,
                      !seenConversationIds.contains(conversationIdString),
                      let conversationId = UUID(uuidString: conversationIdString) else {
                    continue
                }
                
                seenConversationIds.insert(conversationIdString)
                
                let title = item["conversation_title"] as? String
                let createdAt = item["created_at"] as? String
                let respondedAt = item["responded_at"] as? String
                let updatedAt = respondedAt ?? createdAt
                
                let summary = ConversationSummary(
                    id: conversationId,
                    userId: userId,
                    title: title,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
                summaries.append(summary)
            }
            
            os_log("[ProviderSupabaseService] Found %d unique conversations/visits for user", log: .default, type: .debug, summaries.count)
            return summaries
        } catch {
            os_log("[ProviderSupabaseService] Error fetching conversations: %{public}s", log: .default, type: .error, String(describing: error))
            throw error
        }
    }
    
    // MARK: - Device Token Registration
    
    /// Register or update provider device token in Supabase
    /// - Parameters:
    ///   - deviceToken: APNs device token string
    ///   - providerId: Provider's user identifier (optional, defaults to "default_provider")
    func registerDeviceToken(deviceToken: String, providerId: String? = nil) async throws {
        // Use a default provider ID if none provided
        // In production, this should come from authentication
        let userId = providerId ?? "default_provider"
        
        // Check if provider already exists
        let checkUrlString = "\(projectURL)/rest/v1/providers?user_id=eq.\(userId)&select=id"
        guard let checkUrl = URL(string: checkUrlString) else {
            throw SupabaseError.invalidResponse
        }
        
        let checkRequest = createRequest(url: checkUrl, method: "GET")
        
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        
        do {
            // Try to fetch existing provider
            let existing: [[String: String]] = try await executeRequest(checkRequest, responseType: [[String: String]].self)
            
            if let existingId = existing.first?["id"] {
                // Update existing provider
                let updateUrlString = "\(projectURL)/rest/v1/providers?id=eq.\(existingId)"
                guard let updateUrl = URL(string: updateUrlString) else {
                    throw SupabaseError.invalidResponse
                }
                
                var updateRequest = createPatchRequest(url: updateUrl)
                
                let updatePayload: [String: Any] = [
                    "device_token": deviceToken,
                    "device_type": "ios",
                    "updated_at": now
                ]
                
                updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updatePayload)
                
                try await executeRequest(updateRequest)
                os_log("[ProviderSupabaseService] Updated device token for provider", log: .default, type: .debug)
            } else {
                // Create new provider record
                let createUrlString = "\(projectURL)/rest/v1/providers"
                guard let createUrl = URL(string: createUrlString) else {
                    throw SupabaseError.invalidResponse
                }

                var createRequest = createPostRequest(url: createUrl)

                let createPayload: [String: Any] = [
                    "user_id": userId,
                    "device_token": deviceToken,
                    "device_type": "ios",
                    "created_at": now,
                    "updated_at": now
                ]

                createRequest.httpBody = try JSONSerialization.data(withJSONObject: createPayload)

                try await executeRequest(createRequest)
                os_log("[ProviderSupabaseService] Registered new device token for provider", log: .default, type: .debug)
            }
        } catch {
            os_log("[ProviderSupabaseService] Error registering device token: %{public}s", log: .default, type: .error, String(describing: error))
            // Don't throw - this is not critical for app functionality
            // The webhook can still work if tokens are added manually
        }
    }
    
    // MARK: - Fetch Patients
    func fetchPatients() async throws -> [PatientSummary] {
        // Adjust selected fields to match your `patients` schema
        let urlString = "\(projectURL)/rest/v1/patients?select=id,user_id,name&order=name.asc"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidResponse }
        let request = createRequest(url: url, method: "GET")
        return try await executeRequest(request, responseType: [PatientSummary].self)
    }
    
    // MARK: - Dashboard Statistics
    
    /// Fetch dashboard statistics
    func fetchDashboardStats() async throws -> ProviderDashboardStats {
        // Fetch all reviews to calculate stats
        let allReviews = try await fetchProviderReviewRequests()
        
        let pendingCount = allReviews.filter { $0.status == "pending" }.count
        let escalatedCount = allReviews.filter { $0.status == "escalated" }.count
        
        // Calculate responded today
        let today = Calendar.current.startOfDay(for: Date())
        let respondedToday = allReviews.filter { review in
            guard let respondedAt = review.respondedAt,
                  let respondedDate = ISO8601DateFormatter().date(from: respondedAt) else {
                return false
            }
            return Calendar.current.isDate(respondedDate, inSameDayAs: today)
        }.count
        
        // Calculate average response time
        let respondedReviews = allReviews.filter { $0.status == "responded" && $0.createdAt != nil && $0.respondedAt != nil }
        
        var totalResponseTime: TimeInterval = 0
        let formatter = ISO8601DateFormatter()
        
        for review in respondedReviews {
            if let createdAt = review.createdAt,
               let respondedAt = review.respondedAt,
               let createdDate = formatter.date(from: createdAt),
               let respondedDate = formatter.date(from: respondedAt) {
                totalResponseTime += respondedDate.timeIntervalSince(createdDate)
            }
        }
        
        let averageResponseTime = respondedReviews.isEmpty ? 0 : totalResponseTime / Double(respondedReviews.count)
        
        return ProviderDashboardStats(
            pendingReviews: pendingCount,
            respondedToday: respondedToday,
            escalatedConversations: escalatedCount,
            averageResponseTime: averageResponseTime
        )
    }
}

// MARK: - Dashboard Statistics Model
struct ProviderDashboardStats: Codable {
    let pendingReviews: Int
    let respondedToday: Int
    let escalatedConversations: Int
    let averageResponseTime: TimeInterval // in seconds
    
    var averageResponseTimeMinutes: Int {
        Int(averageResponseTime / 60)
    }
    
    var averageResponseTimeFormatted: String {
        let hours = averageResponseTimeMinutes / 60
        let minutes = averageResponseTimeMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Conversation Summary Model
struct ConversationSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: String
    let title: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title = "title"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Patient Summary Model
struct PatientSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
    }
}

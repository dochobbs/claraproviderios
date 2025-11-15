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
            "select=id,user_id,conversation_id,conversation_title,child_name,child_age,child_dob,triage_outcome,conversation_summary,conversation_messages,provider_name,provider_response,provider_urgency,status,is_flagged,flag_reason,flagged_at,flagged_by,unflagged_at,schedule_followup,responded_at,created_at",
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
    
    /// Fetch flagged review requests (now uses is_flagged column)
    func fetchFlaggedReviews() async throws -> [ProviderReviewRequestDetail] {
        let queryParams: [String] = [
            "select=id,user_id,conversation_id,conversation_title,child_name,child_age,child_dob,triage_outcome,conversation_summary,conversation_messages,provider_name,provider_response,provider_urgency,status,is_flagged,flag_reason,flagged_at,flagged_by,unflagged_at,schedule_followup,responded_at,created_at",
            "is_flagged=eq.true",
            "order=created_at.desc"
        ]

        let urlString = "\(projectURL)/rest/v1/provider_review_requests?" + queryParams.joined(separator: "&")
        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        let request = createRequest(url: url, method: "GET")
        return try await executeRequest(request, responseType: [ProviderReviewRequestDetail].self)
    }
    
    // MARK: - Fetch Review For Conversation
    func fetchReviewForConversation(conversationId: UUID) async throws -> ProviderReviewRequestDetail? {
        let idString = conversationId.uuidString.lowercased()
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(idString)&select=id,user_id,conversation_id,conversation_title,child_name,child_age,child_dob,triage_outcome,conversation_summary,conversation_messages,provider_name,provider_response,provider_urgency,status,is_flagged,flag_reason,flagged_at,flagged_by,unflagged_at,schedule_followup,responded_at,created_at&limit=1"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidResponse }
        os_log("[ProviderSupabaseService] Fetching review for conversation_id=%{public}s", log: .default, type: .debug, idString)
        let request = createRequest(url: url, method: "GET")
        let results = try await executeRequest(request, responseType: [ProviderReviewRequestDetail].self)
        if let result = results.first {
            os_log("[ProviderSupabaseService] Found review: status=%{public}s, has_response=%{public}s",
                   log: .default, type: .debug, result.status ?? "nil", result.providerResponse != nil ? "yes" : "no")
        } else {
            os_log("[ProviderSupabaseService] No review found for conversation_id=%{public}s", log: .default, type: .debug, idString)
        }
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
            let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(format)&select=id,user_id,conversation_id,conversation_title,child_name,child_age,child_dob,triage_outcome,conversation_summary,conversation_messages,provider_name,provider_response,provider_urgency,status,is_flagged,flag_reason,flagged_at,flagged_by,unflagged_at,schedule_followup,responded_at,created_at&limit=1"

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

    /// Flag a review request (sets is_flagged=true and adds flag metadata)
    func flagReview(id: String, reason: String?, flaggedBy: String) async throws {
        let idString = id.lowercased()
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(idString)"

        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        var request = createPatchRequest(url: url)

        let formatter = ISO8601DateFormatter()
        var updatePayload: [String: Any] = [
            "is_flagged": true,
            "flagged_at": formatter.string(from: Date()),
            "flagged_by": flaggedBy
        ]

        if let reason = reason, !reason.isEmpty {
            updatePayload["flag_reason"] = reason
        } else {
            updatePayload["flag_reason"] = NSNull()
        }

        // Clear unflagged_at when flagging
        updatePayload["unflagged_at"] = NSNull()

        request.httpBody = try JSONSerialization.data(withJSONObject: updatePayload)

        try await executeRequest(request)
    }

    /// Unflag a review request (sets is_flagged=false and adds unflag metadata)
    func unflagReview(id: String) async throws {
        let idString = id.lowercased()
        let urlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(idString)"

        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        var request = createPatchRequest(url: url)

        let formatter = ISO8601DateFormatter()
        let updatePayload: [String: Any] = [
            "is_flagged": false,
            "unflagged_at": formatter.string(from: Date()),
            "flag_reason": NSNull()  // Clear reason text from UI, keep audit trail fields
            // Note: We keep flagged_at, flagged_by for audit trail
        ]

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

        os_log("[ProviderSupabaseService] PATCH provider response - conversation_id=%{public}s, status=%{public}s",
               log: .default, type: .debug, idString, status ?? "responded")
        os_log("[ProviderSupabaseService] PATCH to %{public}s", log: .default, type: .debug, urlString)
        os_log("[ProviderSupabaseService] Payload: response=%{public}s (length=%d), name=%{public}s",
               log: .default, type: .debug, response, response.count, name ?? "nil")

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
            "timestamp": timestamp,
            "is_read": false
        ]
        
        messageRequest.httpBody = try JSONSerialization.data(withJSONObject: messagePayload)

        os_log("[ProviderSupabaseService] Creating follow-up message for conversation: %{public}s", log: .default, type: .debug, conversationId.uuidString)

        do {
            // Try to create the message (this might fail if follow_up_messages table doesn't exist or has different schema)
            try await executeRequest(messageRequest)
            os_log("[ProviderSupabaseService] Successfully created follow-up message for patient", log: .default, type: .info)
        } catch {
            os_log("[ProviderSupabaseService] Could not create follow-up message: %{public}s", log: .default, type: .debug, String(describing: error))
            // Don't throw - this is not critical, patient can still see response via polling
        }
    }
    
    // MARK: - Schedule Follow-up

    /// Schedule a follow-up request for a conversation
    func scheduleFollowUp(
        conversationId: UUID,
        userId: String,
        childName: String?,
        childAge: String?,
        scheduledFor: Date,
        urgency: String,
        message: String,
        followUpDays: Int?,
        followUpHours: Int?,
        followUpMinutes: Int?
    ) async throws -> String {
        // Create follow-up request
        let urlString = "\(projectURL)/rest/v1/follow_up_requests"

        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        var request = createPostRequest(url: url)

        let formatter = ISO8601DateFormatter()
        let scheduledTimestamp = formatter.string(from: scheduledFor)

        var followUpPayload: [String: Any] = [
            "conversation_id": conversationId.uuidString,
            "user_id": userId,
            "scheduled_for": scheduledTimestamp,
            "urgency": urgency,
            "display_text": message,
            "original_message": message,
            "status": "scheduled"
        ]

        if let childName = childName {
            followUpPayload["child_name"] = childName
        }

        if let childAge = childAge {
            followUpPayload["child_age"] = childAge
        }

        if let days = followUpDays {
            followUpPayload["follow_up_days"] = days
        }

        if let hours = followUpHours {
            followUpPayload["follow_up_hours"] = hours
        }

        if let minutes = followUpMinutes {
            followUpPayload["follow_up_minutes"] = minutes
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: followUpPayload)

        os_log("[ProviderSupabaseService] Creating follow-up request for conversation: %{public}s",
               log: .default, type: .debug, conversationId.uuidString)

        // Execute request and get response
        struct FollowUpResponse: Codable {
            let id: String
        }

        let responses = try await executeRequest(request, responseType: [FollowUpResponse].self)

        guard let firstResponse = responses.first else {
            throw SupabaseError.noResponseData
        }

        // Update provider_review_requests to set schedule_followup = true
        let updateUrlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())"

        guard let updateUrl = URL(string: updateUrlString) else {
            throw SupabaseError.invalidResponse
        }

        var updateRequest = createPatchRequest(url: updateUrl)

        let updatePayload: [String: Any] = [
            "schedule_followup": true
        ]

        updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updatePayload)

        try await executeRequest(updateRequest)

        os_log("[ProviderSupabaseService] Successfully scheduled follow-up: %{public}s",
               log: .default, type: .info, firstResponse.id)

        return firstResponse.id
    }

    /// Cancel a scheduled follow-up request
    func cancelFollowUp(conversationId: UUID) async throws {
        os_log("[ProviderSupabaseService] Cancelling follow-up for conversation: %{public}s",
               log: .default, type: .info, conversationId.uuidString)

        // Update follow_up_requests status to "cancelled"
        let followUpUrlString = "\(projectURL)/rest/v1/follow_up_requests?conversation_id=eq.\(conversationId.uuidString)&status=eq.scheduled"

        guard let followUpUrl = URL(string: followUpUrlString) else {
            throw SupabaseError.invalidResponse
        }

        var followUpRequest = createPatchRequest(url: followUpUrl)

        let followUpPayload: [String: Any] = [
            "status": "cancelled"
        ]

        followUpRequest.httpBody = try JSONSerialization.data(withJSONObject: followUpPayload)

        try await executeRequest(followUpRequest)

        // Update provider_review_requests to set schedule_followup = false
        let reviewUrlString = "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())"

        guard let reviewUrl = URL(string: reviewUrlString) else {
            throw SupabaseError.invalidResponse
        }

        var reviewRequest = createPatchRequest(url: reviewUrl)

        let reviewPayload: [String: Any] = [
            "schedule_followup": false
        ]

        reviewRequest.httpBody = try JSONSerialization.data(withJSONObject: reviewPayload)

        try await executeRequest(reviewRequest)

        os_log("[ProviderSupabaseService] Successfully cancelled follow-up",
               log: .default, type: .info)
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
        // Note: patients table doesn't have user_id column, so we select only id and name
        // The app falls back to getting patients from review requests if this fails
        let urlString = "\(projectURL)/rest/v1/patients?select=id,name&order=name.asc"
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidResponse }
        let request = createRequest(url: url, method: "GET")
        return try await executeRequest(request, responseType: [PatientSummary].self)
    }

    // MARK: - Fetch Messages for Conversation

    /// Fetch all messages for a specific conversation from messages table
    func fetchMessagesForConversation(conversationId: UUID) async throws -> [MessageDetail] {
        let urlString = "\(projectURL)/rest/v1/messages?conversation_id=eq.\(conversationId.uuidString)&select=id,content,timestamp,is_from_user&order=timestamp.asc"

        guard let url = URL(string: urlString) else {
            throw SupabaseError.invalidResponse
        }

        let request = createRequest(url: url, method: "GET")

        os_log("[ProviderSupabaseService] Fetching messages for conversation_id: %{public}s", log: .default, type: .debug, conversationId.uuidString)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            os_log("[ProviderSupabaseService] Fetched %d messages for conversation", log: .default, type: .info, jsonArray.count)

            let formatter = ISO8601DateFormatter()
            let messages = jsonArray.compactMap { item -> MessageDetail? in
                guard let id = item["id"] as? String,
                      let content = item["content"] as? String,
                      let timestampString = item["timestamp"] as? String,
                      let timestamp = formatter.date(from: timestampString) else {
                    return nil
                }

                let isFromUser = item["is_from_user"] as? Bool ?? false

                return MessageDetail(
                    id: id,
                    content: content,
                    timestamp: timestamp,
                    isFromUser: isFromUser
                )
            }

            return messages
        } catch {
            os_log("[ProviderSupabaseService] Error fetching messages for conversation: %{public}s", log: .default, type: .error, String(describing: error))
            throw error
        }
    }

    // MARK: - Fetch All Conversations from Messages Table

    /// Fetch all conversations from messages table, grouped by conversation_id
    /// Returns a list of conversations with their latest message timestamp
    func fetchAllConversationsFromMessages() async throws -> [MessageConversationSummary] {
        // Query the messages table and select distinct conversation_ids with latest timestamp
        // Note: Supabase doesn't have a GROUP BY with aggregates in REST API,
        // so we fetch all messages and group them client-side
        // IMPORTANT: Supabase has a server-side limit of 1000 rows, so we paginate

        os_log("[ProviderSupabaseService] Fetching all messages from messages table (with pagination)", log: .default, type: .debug)

        var allMessages: [[String: Any]] = []
        var offset = 0
        let pageSize = 1000

        // Fetch messages in batches of 1000 until we get less than a full page
        while true {
            let urlString = "\(projectURL)/rest/v1/messages?select=conversation_id,timestamp,content,is_from_user&order=timestamp.desc&limit=\(pageSize)&offset=\(offset)"

            guard let url = URL(string: urlString) else {
                throw SupabaseError.invalidResponse
            }

            let request = createRequest(url: url, method: "GET")

            os_log("[ProviderSupabaseService] Fetching page at offset=%d", log: .default, type: .debug, offset)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            // Decode this page of messages
            let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            os_log("[ProviderSupabaseService] Fetched %d messages in this page (offset=%d)", log: .default, type: .info, jsonArray.count, offset)

            // Add to accumulator
            allMessages.append(contentsOf: jsonArray)

            // If we got less than a full page, we're done
            if jsonArray.count < pageSize {
                break
            }

            // Move to next page
            offset += pageSize
        }

        os_log("[ProviderSupabaseService] Total fetched: %d messages from messages table", log: .default, type: .info, allMessages.count)

        // Group by conversation_id and create summaries
        // Also track which conversations have both user and assistant messages
        var conversationsDict: [String: MessageConversationSummary] = [:]
        var conversationMessageTypes: [String: (hasUser: Bool, hasAssistant: Bool)] = [:]

        for item in allMessages {
            guard let conversationIdString = item["conversation_id"] as? String else {
                continue
            }

            let timestamp = item["timestamp"] as? String
            let messageContent = item["content"] as? String
            let isFromUser = item["is_from_user"] as? Bool ?? false

            // Track message types for this conversation
            var types = conversationMessageTypes[conversationIdString] ?? (hasUser: false, hasAssistant: false)
            if isFromUser {
                types.hasUser = true
            } else {
                types.hasAssistant = true
            }
            conversationMessageTypes[conversationIdString] = types

            // If this conversation doesn't exist yet, or if this message is newer, update the summary
            if conversationsDict[conversationIdString] == nil {
                // Create new conversation summary (userId will be nil since messages table doesn't have it)
                conversationsDict[conversationIdString] = MessageConversationSummary(
                    conversationId: conversationIdString,
                    userId: nil,
                    latestTimestamp: timestamp,
                    latestMessagePreview: messageContent,
                    latestIsFromUser: isFromUser
                )
            }
        }

        // Debug logging: Count message type combinations
        var bothCount = 0
        var userOnlyCount = 0
        var assistantOnlyCount = 0
        var neitherCount = 0

        for (_, types) in conversationMessageTypes {
            if types.hasUser && types.hasAssistant {
                bothCount += 1
            } else if types.hasUser {
                userOnlyCount += 1
            } else if types.hasAssistant {
                assistantOnlyCount += 1
            } else {
                neitherCount += 1
            }
        }

        os_log("[ProviderSupabaseService] Message type breakdown - Both: %d, User-only: %d, Assistant-only: %d, Neither: %d, Total: %d",
               log: .default, type: .info, bothCount, userOnlyCount, assistantOnlyCount, neitherCount, conversationMessageTypes.count)

        // Filter to only include conversations with BOTH user and assistant messages
        let completeConversations = conversationsDict.filter { conversation in
            guard let types = conversationMessageTypes[conversation.key] else {
                return false
            }
            return types.hasUser && types.hasAssistant
        }

        // Convert to array and sort by latest timestamp (descending)
        let summaries = completeConversations.values.sorted { (a, b) in
            guard let aTime = a.latestTimestamp, let bTime = b.latestTimestamp else {
                return false
            }
            return aTime > bTime
        }

        os_log("[ProviderSupabaseService] Found %d complete conversations (with both user and assistant messages) from %d total unique conversations", log: .default, type: .info, summaries.count, conversationsDict.count)
        return summaries
    }
    
    // MARK: - Mark Messages as Read

    /// Mark all messages as read for a specific conversation
    /// Updates both messages and follow_up_messages tables
    func markMessagesAsRead(conversationId: UUID) async throws {
        os_log("[ProviderSupabaseService] Marking messages as read for conversation: %{public}s",
               log: .default, type: .info, conversationId.uuidString)

        // Update messages table
        let messagesUrlString = "\(projectURL)/rest/v1/messages?conversation_id=eq.\(conversationId.uuidString)&is_from_user=eq.true"

        guard let messagesUrl = URL(string: messagesUrlString) else {
            throw SupabaseError.invalidResponse
        }

        var messagesRequest = createPatchRequest(url: messagesUrl)
        let messagesPayload: [String: Any] = ["is_read": true]
        messagesRequest.httpBody = try JSONSerialization.data(withJSONObject: messagesPayload)

        // Update follow_up_messages table
        let followUpUrlString = "\(projectURL)/rest/v1/follow_up_messages?conversation_id=eq.\(conversationId.uuidString)&is_from_user=eq.true"

        guard let followUpUrl = URL(string: followUpUrlString) else {
            throw SupabaseError.invalidResponse
        }

        var followUpRequest = createPatchRequest(url: followUpUrl)
        let followUpPayload: [String: Any] = ["is_read": true]
        followUpRequest.httpBody = try JSONSerialization.data(withJSONObject: followUpPayload)

        // Execute both requests (don't throw if one fails - not all conversations have both)
        do {
            try await executeRequest(messagesRequest)
            os_log("[ProviderSupabaseService] Marked messages as read in messages table",
                   log: .default, type: .debug)
        } catch {
            os_log("[ProviderSupabaseService] Could not update messages table: %{public}s",
                   log: .default, type: .debug, String(describing: error))
        }

        do {
            try await executeRequest(followUpRequest)
            os_log("[ProviderSupabaseService] Marked messages as read in follow_up_messages table",
                   log: .default, type: .debug)
        } catch {
            os_log("[ProviderSupabaseService] Could not update follow_up_messages table: %{public}s",
                   log: .default, type: .debug, String(describing: error))
        }
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
    let userId: String?  // Optional since patients table doesn't have user_id column
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
    }
}

// MARK: - Message Conversation Summary Model
struct MessageConversationSummary: Identifiable, Hashable {
    let id: String  // conversation_id as identifier
    let conversationId: String
    let userId: String?
    let latestTimestamp: String?
    let latestMessagePreview: String?
    let latestIsFromUser: Bool

    init(conversationId: String, userId: String?, latestTimestamp: String?, latestMessagePreview: String?, latestIsFromUser: Bool) {
        self.id = conversationId
        self.conversationId = conversationId
        self.userId = userId
        self.latestTimestamp = latestTimestamp
        self.latestMessagePreview = latestMessagePreview
        self.latestIsFromUser = latestIsFromUser
    }
}

// MARK: - Message Detail Model
struct MessageDetail: Identifiable {
    let id: String
    let content: String
    let timestamp: Date
    let isFromUser: Bool
}

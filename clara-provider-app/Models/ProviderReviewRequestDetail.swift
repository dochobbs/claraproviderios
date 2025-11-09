import Foundation

// MARK: - Provider Review Request Model (from Supabase)
// This represents a provider review request as stored in Supabase
struct ProviderReviewRequestDetail: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let conversationId: String
    let conversationTitle: String?
    let childName: String?
    let childAge: String?
    let childDOB: String?
    let triageOutcome: String?
    let conversationSummary: String?
    let conversationMessages: [ConversationMessage]?
    var status: String?  // pending, responded, dismissed (no longer includes 'flagged')
    var isFlagged: Bool?  // NEW: Separate boolean for flagging
    var flagReason: String?  // Reason for flagging, if flagged
    var flaggedAt: String?  // NEW: When flagged
    var flaggedBy: String?  // NEW: Who flagged it
    var unflaggedAt: String?  // NEW: When unflagged
    var scheduleFollowup: Bool?  // Whether a follow-up is scheduled
    let providerName: String?
    let providerResponse: String?
    let providerUrgency: String?
    let respondedAt: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case conversationId = "conversation_id"
        case conversationTitle = "conversation_title"
        case childName = "child_name"
        case childAge = "child_age"
        case childDOB = "child_dob"
        case triageOutcome = "triage_outcome"
        case conversationSummary = "conversation_summary"
        case conversationMessages = "conversation_messages"
        case status
        case isFlagged = "is_flagged"
        case flagReason = "flag_reason"
        case flaggedAt = "flagged_at"
        case flaggedBy = "flagged_by"
        case unflaggedAt = "unflagged_at"
        case scheduleFollowup = "schedule_followup"
        case providerName = "provider_name"
        case providerResponse = "provider_response"
        case providerUrgency = "provider_urgency"
        case respondedAt = "responded_at"
        case createdAt = "created_at"
    }
    
    // Custom init to handle JSONB arrays and ensure proper decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields - these should always be present
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        conversationId = try container.decode(String.self, forKey: .conversationId)
        
        // Decode optional fields
        conversationTitle = try container.decodeIfPresent(String.self, forKey: .conversationTitle)
        childName = try container.decodeIfPresent(String.self, forKey: .childName)
        childAge = try container.decodeIfPresent(String.self, forKey: .childAge)
        childDOB = try container.decodeIfPresent(String.self, forKey: .childDOB)
        triageOutcome = try container.decodeIfPresent(String.self, forKey: .triageOutcome)
        conversationSummary = try container.decodeIfPresent(String.self, forKey: .conversationSummary)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        isFlagged = try container.decodeIfPresent(Bool.self, forKey: .isFlagged)
        flagReason = try container.decodeIfPresent(String.self, forKey: .flagReason)
        flaggedAt = try container.decodeIfPresent(String.self, forKey: .flaggedAt)
        flaggedBy = try container.decodeIfPresent(String.self, forKey: .flaggedBy)
        unflaggedAt = try container.decodeIfPresent(String.self, forKey: .unflaggedAt)
        scheduleFollowup = try container.decodeIfPresent(Bool.self, forKey: .scheduleFollowup)
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName)
        providerResponse = try container.decodeIfPresent(String.self, forKey: .providerResponse)
        providerUrgency = try container.decodeIfPresent(String.self, forKey: .providerUrgency)
        respondedAt = try container.decodeIfPresent(String.self, forKey: .respondedAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        // Handle conversation_messages - JSONB array can be null, empty array, or array of objects
        // Try multiple decoding strategies
        if container.contains(.conversationMessages) {
            // First, try to decode as an array directly
            if let messages = try? container.decode([ConversationMessage].self, forKey: .conversationMessages) {
                conversationMessages = messages.isEmpty ? nil : messages
            } else {
                // If that fails, the field might be null or malformed
                conversationMessages = nil
            }
        } else {
            conversationMessages = nil
        }
    }
    
    // Regular initializer for creating instances manually
    init(
        id: String,
        userId: String,
        conversationId: String,
        conversationTitle: String? = nil,
        childName: String? = nil,
        childAge: String? = nil,
        childDOB: String? = nil,
        triageOutcome: String? = nil,
        conversationSummary: String? = nil,
        conversationMessages: [ConversationMessage]? = nil,
        status: String? = nil,
        isFlagged: Bool? = nil,
        flagReason: String? = nil,
        flaggedAt: String? = nil,
        flaggedBy: String? = nil,
        unflaggedAt: String? = nil,
        scheduleFollowup: Bool? = nil,
        providerName: String? = nil,
        providerResponse: String? = nil,
        providerUrgency: String? = nil,
        respondedAt: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.conversationId = conversationId
        self.conversationTitle = conversationTitle
        self.childName = childName
        self.childAge = childAge
        self.childDOB = childDOB
        self.triageOutcome = triageOutcome
        self.conversationSummary = conversationSummary
        self.conversationMessages = conversationMessages
        self.status = status
        self.isFlagged = isFlagged
        self.flagReason = flagReason
        self.flaggedAt = flaggedAt
        self.flaggedBy = flaggedBy
        self.unflaggedAt = unflaggedAt
        self.scheduleFollowup = scheduleFollowup
        self.providerName = providerName
        self.providerResponse = providerResponse
        self.providerUrgency = providerUrgency
        self.respondedAt = respondedAt
        self.createdAt = createdAt
    }
}

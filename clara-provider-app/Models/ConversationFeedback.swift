import Foundation

// MARK: - Conversation Feedback Model
// Maps to the conversation_feedback table in Supabase
// Used for provider notes and tags synced across web dashboard and mobile app

struct ConversationFeedback: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    let createdBy: String?  // Provider ID/name who created the feedback
    let feedback: String?   // Provider notes (internal, not shown to patient)
    let tags: [String]?     // Array of tags for categorization
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case createdBy = "created_by"
        case feedback
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // Initializer for creating new feedback
    init(
        id: String = UUID().uuidString,
        conversationId: String,
        createdBy: String?,
        feedback: String?,
        tags: [String]? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.createdBy = createdBy
        self.feedback = feedback
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

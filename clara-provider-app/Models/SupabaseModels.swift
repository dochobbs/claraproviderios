import Foundation

struct ConversationMessage: Codable, Equatable {
    let content: String
    let isFromUser: Bool
    let timestamp: String
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case content
        case isFromUser = "is_from_user"
        case timestamp
        case imageURL = "image_url"
    }
}

struct FollowUpMessage: Codable {
    let id: String
    let conversationId: String
    let userId: String
    let messageContent: String
    let isFromUser: Bool
    let timestamp: String
    let isRead: Bool
    let followUpId: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case messageContent = "message_content"
        case isFromUser = "is_from_user"
        case timestamp
        case isRead = "is_read"
        case followUpId = "follow_up_id"
        case createdAt = "created_at"
    }
}

struct FollowUpRequest: Codable {
    let id: String?
    let conversationId: String
    let userId: String
    let childName: String?
    let childAge: String?
    let scheduledFor: String
    let urgency: String
    let displayText: String
    let originalMessage: String
    let status: String?
    let deviceToken: String?
    let createdAt: String?
    let sentAt: String?
    let followUpDays: Int?
    let followUpHours: Int?
    let followUpMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case userId = "user_id"
        case childName = "child_name"
        case childAge = "child_age"
        case scheduledFor = "scheduled_for"
        case urgency
        case displayText = "display_text"
        case originalMessage = "original_message"
        case status
        case deviceToken = "device_token"
        case createdAt = "created_at"
        case sentAt = "sent_at"
        case followUpDays = "follow_up_days"
        case followUpHours = "follow_up_hours"
        case followUpMinutes = "follow_up_minutes"
    }
}

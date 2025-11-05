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

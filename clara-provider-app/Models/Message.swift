import Foundation

struct Message: Identifiable, Codable {
    var id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let triageOutcome: String?
    let followUpDays: Int?
    let followUpHours: Int?
    let followUpMinutes: Int?
    let imageURL: String?
    let providerName: String?
    var isRead: Bool
    
    init(content: String, isFromUser: Bool, triageOutcome: String? = nil, followUpDays: Int? = nil, followUpHours: Int? = nil, followUpMinutes: Int? = nil, imageURL: String? = nil, providerName: String? = nil, isRead: Bool = true) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.triageOutcome = triageOutcome
        self.followUpDays = followUpDays
        self.followUpHours = followUpHours
        self.followUpMinutes = followUpMinutes
        self.imageURL = imageURL
        self.providerName = providerName
        self.isRead = isRead
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        content = try container.decode(String.self, forKey: .content)
        isFromUser = try container.decode(Bool.self, forKey: .isFromUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        triageOutcome = try container.decodeIfPresent(String.self, forKey: .triageOutcome)
        followUpDays = try container.decodeIfPresent(Int.self, forKey: .followUpDays)
        followUpHours = try container.decodeIfPresent(Int.self, forKey: .followUpHours)
        followUpMinutes = try container.decodeIfPresent(Int.self, forKey: .followUpMinutes)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? true
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, content, isFromUser, timestamp, triageOutcome, followUpDays, followUpHours, followUpMinutes, imageURL, providerName, isRead
    }
}

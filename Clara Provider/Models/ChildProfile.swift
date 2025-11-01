import Foundation

struct ChildProfile: Identifiable, Codable {
    let id: UUID
    var parentName: String
    var childName: String
    var dateOfBirth: Date
    var gender: String
    var challenges: [Challenge]
    
    // MARK: - Memory/History Fields
    var allergies: [String] = []
    var medications: [String] = []
    var pastConditions: [String] = []
    var notes: String = ""
    var nicknames: [String] = []
    
    init(id: UUID = UUID(), parentName: String, childName: String, dateOfBirth: Date, gender: String, challenges: [Challenge] = [], allergies: [String] = [], medications: [String] = [], pastConditions: [String] = [], notes: String = "", nicknames: [String] = []) {
        self.id = id
        self.parentName = parentName
        self.childName = childName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.challenges = challenges
        self.allergies = allergies
        self.medications = medications
        self.pastConditions = pastConditions
        self.notes = notes
        self.nicknames = nicknames
    }
    
    var age: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: dateOfBirth, to: now)
        
        if let years = components.year, let months = components.month, let days = components.day {
            if years > 0 {
                return "\(years) year\(years == 1 ? "" : "s") old"
            } else if months > 0 {
                return "\(months) month\(months == 1 ? "" : "s") old"
            } else {
                if days < 7 {
                    return "\(days) day\(days == 1 ? "" : "s") old"
                } else {
                    let weeks = days / 7
                    return "\(weeks) week\(weeks == 1 ? "" : "s") old"
                }
            }
        }
        return "unknown age"
    }
}

struct Challenge: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), name: String, isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.isCompleted = isCompleted
    }
}

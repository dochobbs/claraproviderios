import SwiftUI

struct PatientProfileView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    let childId: UUID?
    let childName: String?
    let childAge: String?
    
    @State private var childProfile: ChildProfile? = nil
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    // Patient header
                    PatientHeaderView(
                        name: childName ?? childProfile?.childName ?? "Unknown",
                        age: childAge ?? childProfile?.age ?? "Unknown",
                        gender: childProfile?.gender
                    )
                    
                    // Medical history sections
                    if let profile = childProfile {
                        MedicalHistorySection(title: "Allergies", items: profile.allergies)
                        MedicalHistorySection(title: "Medications", items: profile.medications)
                        MedicalHistorySection(title: "Past Conditions", items: profile.pastConditions)
                        
                        if !profile.notes.isEmpty {
                            NotesSection(notes: profile.notes)
                        }
                    } else {
                        Text("Medical history not available")
                            .font(.rethinkSans(15, relativeTo: .subheadline))
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    // Conversation history
                    ConversationHistorySection(
                        store: store,
                        childId: childId,
                        childName: childName
                    )
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle("Patient Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfile()
        }
    }
    
    private func loadProfile() {
        // For now, we don't have a direct API to fetch child profile
        // This would need to be implemented if child profiles are stored separately
        // For MVP, we'll show what we have from the review request
        isLoading = false
    }
}

struct PatientHeaderView: View {
    let name: String
    let age: String
    let gender: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.primaryCoral)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.rethinkSansBold(22, relativeTo: .title2))
                
                HStack(spacing: 12) {
                    Label {
                        Text(age)
                            .font(.system(.subheadline, design: .monospaced))
                    } icon: {
                        Image(systemName: "birthday.cake")
                    }
                    if let gender = gender {
                        Label(gender, systemImage: "figure.child")
                            .font(.rethinkSans(15, relativeTo: .subheadline))
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct MedicalHistorySection: View {
    let title: String
    let items: [String]
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.rethinkSansBold(17, relativeTo: .headline))
            
            if items.isEmpty {
                Text("None recorded")
                    .font(.rethinkSans(15, relativeTo: .subheadline))
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Image(systemName: "pill.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.primaryCoral)
                        Text(item)
                            .font(.rethinkSans(15, relativeTo: .subheadline))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct NotesSection: View {
    let notes: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.rethinkSansBold(17, relativeTo: .headline))
            
            Text(notes)
                .font(.rethinkSans(15, relativeTo: .subheadline))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct ConversationHistorySection: View {
    @ObservedObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    let childId: UUID?
    let childName: String?
    
    var conversations: [ProviderReviewRequestDetail] {
        store.reviewRequests.filter { request in
            // Filter by child name since we don't have child ID in review requests
            return request.childName == childName
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation History")
                .font(.rethinkSansBold(17, relativeTo: .headline))
            
            if conversations.isEmpty {
                Text("No conversations found")
                    .font(.rethinkSans(15, relativeTo: .subheadline))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(conversations.prefix(5), id: \.id) { request in
                    NavigationLink(
                        destination: ConversationDetailView(conversationId: UUID(uuidString: request.conversationId) ?? UUID())
                            .environmentObject(store)
                    ) {
                        ConversationHistoryRow(request: request)
                    }
                }
                
                if conversations.count > 5 {
                    Text("And \(conversations.count - 5) more conversations...")
                        .font(.rethinkSans(12, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct ConversationHistoryRow: View {
    let request: ProviderReviewRequestDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
                        Text(request.conversationTitle ?? "Untitled Conversation")
                .font(.rethinkSansBold(15, relativeTo: .subheadline))
                .lineLimit(1)
            
            HStack {
                if let createdAt = request.createdAt {
                    Text(formatDate(createdAt))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: request.status ?? "pending")
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

import SwiftUI

struct ConversationDetailView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    let conversationId: UUID
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var showingMessageInput = false
    @State private var errorMessage: String? = nil
    @State private var replyText: String = ""
    @State private var selectedResponse: ProviderResponseType = .agree
    @State private var isSubmitting = false
    @State private var conversationReview: ProviderReviewRequestDetail? = nil
    
    var conversationDetail: ProviderReviewRequestDetail? {
        store.getConversationDetails(for: conversationId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Patient info card
                    if let detail = conversationDetail {
                        NavigationLink(
                            destination: PatientProfileView(
                                childId: UUID(uuidString: detail.conversationId),
                                childName: detail.childName,
                                childAge: detail.childAge
                            )
                            .environmentObject(store)
                        ) {
                            PatientInfoCard(detail: detail)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                    }
                    
                    // Messages
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if messages.isEmpty {
                        Text("No messages yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                            }
                            
                            // Review Result - appended at bottom after messages
                            // Only show if review is completed (has a status other than pending)
                            if let review = conversationReview, 
                               let status = review.status,
                               status.lowercased() != "pending" {
                                ReviewResultView(review: review)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // If no messages but we have a completed review, show it anyway
                    if messages.isEmpty, 
                       let review = conversationReview,
                       let status = review.status,
                       status.lowercased() != "pending" {
                        ReviewResultView(review: review)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(Color.adaptiveBackground(for: colorScheme))
            
            // Provider Reply Box
            if let detail = conversationDetail, detail.status != "responded" {
                ProviderReplyBox(
                    replyText: $replyText,
                    selectedResponse: $selectedResponse,
                    isSubmitting: $isSubmitting,
                    onSubmit: {
                        submitReview()
                    }
                )
            }
        }
        .navigationTitle(conversationDetail?.conversationTitle ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingMessageInput) {
            ProviderMessageInputView(conversationId: conversationId)
                .environmentObject(store)
        }
        .onAppear {
            Task {
                await loadConversationData()
            }
        }
        .refreshable {
            await loadConversationData()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
            Button("Retry") {
                errorMessage = nil
                Task {
                    await loadConversationData()
                }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    private func loadConversationData() async {
        print("🔍 Loading conversation data for: \(conversationId)")
        
        // Load conversation details first
        await store.loadConversationDetails(id: conversationId)
        
        // Check if we have details
        if let detail = store.getConversationDetails(for: conversationId) {
            print("✅ Found conversation details: \(detail.conversationTitle ?? "No title")")
        } else {
            print("⚠️ No conversation details found for: \(conversationId)")
        }
        
        // Load messages from Supabase
        await MainActor.run {
            isLoading = true
        }
        
        do {
            print("🔍 Fetching follow-up messages for: \(conversationId)")
            let followUpMessages = try await ProviderSupabaseService.shared.fetchFollowUpMessages(for: conversationId)
            print("✅ Found \(followUpMessages.count) follow-up messages")
            
            // Convert follow-up messages to Message format
            let formatter = ISO8601DateFormatter()
            var newMessages = followUpMessages.compactMap { followUpMsg -> Message? in
                guard formatter.date(from: followUpMsg.timestamp) != nil else { return nil }
                return Message(
                    content: followUpMsg.messageContent,
                    isFromUser: followUpMsg.isFromUser,
                    imageURL: nil,
                    providerName: followUpMsg.isFromUser ? nil : "Provider",
                    isRead: followUpMsg.isRead
                )
            }
            
            // Add conversation messages from review request
            if let detail = conversationDetail, let convMessages = detail.conversationMessages {
                let formatter = ISO8601DateFormatter()
                let messages = convMessages.compactMap { convMsg -> Message? in
                    guard formatter.date(from: convMsg.timestamp) != nil else { return nil }
                    return Message(
                        content: convMsg.content,
                        isFromUser: convMsg.isFromUser,
                        imageURL: convMsg.imageURL,
                        providerName: convMsg.isFromUser ? nil : "Clara",
                        isRead: true
                    )
                }
                newMessages.append(contentsOf: messages)
            }
            
            // Sort by timestamp
            newMessages.sort { $0.timestamp < $1.timestamp }
            
            await MainActor.run {
                messages = newMessages
                isLoading = false
            }
            
            // Load associated review for this conversation
            let review = await store.fetchReviewForConversation(id: conversationId)
            await MainActor.run { conversationReview = review }
            
        } catch {
            await MainActor.run {
                print("❌ Error loading conversation data: \(error)")
                if let supabaseError = error as? SupabaseError {
                    print("   Supabase error: \(supabaseError)")
                }
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func submitReview() {
        guard let detail = conversationDetail else { return }
        
        isSubmitting = true
        
        Task {
            do {
                // Determine status based on response type
                let status: String
                switch selectedResponse {
                case .agree, .agreeWithThoughts:
                    status = "responded"
                case .disagreeWithThoughts:
                    status = "flagged"
                case .escalationNeeded:
                    status = "escalated"
                }
                
                // Add provider response if text is provided
                if !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    try await ProviderSupabaseService.shared.addProviderResponse(
                        id: detail.id,
                        response: replyText,
                        name: nil,
                        urgency: selectedResponse == .escalationNeeded ? "urgent" : nil,
                        status: status
                    )
                    
                    // Create follow-up message to notify patient
                    if let conversationUUID = UUID(uuidString: detail.conversationId) {
                        try? await ProviderSupabaseService.shared.createPatientNotificationMessage(
                            conversationId: conversationUUID,
                            userId: detail.userId,
                            providerResponse: replyText,
                            providerName: nil
                        )
                    }
                } else {
                    // If no text, just update status
                    try await store.updateReviewStatus(id: detail.id, status: status)
                }
                
                // Refresh data
                await store.loadReviewRequests()
                
                // Refresh the review display
                let updatedReview = await store.fetchReviewForConversation(id: conversationId)
                await MainActor.run {
                    conversationReview = updatedReview
                    isSubmitting = false
                    replyText = ""
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

enum ProviderResponseType: String, CaseIterable {
    case agree = "agree"
    case agreeWithThoughts = "agree_with_thoughts"
    case disagreeWithThoughts = "disagree_with_thoughts"
    case escalationNeeded = "escalation_needed"
    
    var displayName: String {
        switch self {
        case .agree:
            return "Agree"
        case .agreeWithThoughts:
            return "Agree with Thoughts"
        case .disagreeWithThoughts:
            return "Disagree with Thoughts"
        case .escalationNeeded:
            return "Escalation Needed"
        }
    }
}

struct ProviderReplyBox: View {
    @Binding var replyText: String
    @Binding var selectedResponse: ProviderResponseType
    @Binding var isSubmitting: Bool
    @Environment(\.colorScheme) var colorScheme
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Response Type Dropdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Response")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Response Type", selection: $selectedResponse) {
                    ForEach(ProviderResponseType.allCases, id: \.self) { responseType in
                        Text(responseType.displayName).tag(responseType)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            
            // Reply Text Box
            VStack(alignment: .leading, spacing: 8) {
                Text("Reply (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Enter your reply...", text: $replyText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .frame(minHeight: 60, maxHeight: 120, alignment: .topLeading)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.adaptiveTertiaryBackground(for: colorScheme), lineWidth: 1)
                    )
                    .lineLimit(3...10)
                    .disabled(isSubmitting)
            }
            .padding(.horizontal)
            
            // Submit Button
            Button(action: onSubmit) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(isSubmitting ? "Submitting..." : "Submit Review")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.primaryCoral)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isSubmitting)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)
    }
}

struct PatientInfoCard: View {
    let detail: ProviderReviewRequestDetail
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.primaryCoral)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let childName = detail.childName {
                        Text(childName)
                            .font(.headline)
                        
                        if let age = detail.childAge {
                            Text("Age: \(age)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Patient")
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                if let triageOutcome = detail.triageOutcome {
                    TriageBadge(outcome: triageOutcome)
                }
            }
            
            if let summary = detail.conversationSummary, !summary.isEmpty {
                Divider()
                Text("Summary")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(summary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct MessageBubbleView: View {
    let message: Message
    
    var isFromPatient: Bool {
        message.isFromUser && message.providerName == nil
    }
    
    var isFromClara: Bool {
        message.providerName == "Clara"
    }
    
    var isFromProvider: Bool {
        message.providerName == "Provider" || (message.providerName != nil && message.providerName != "Clara")
    }
    
    var bubbleColor: Color {
        if isFromPatient {
            return Color.userBubbleBackground
        } else if isFromClara {
            return Color.blue.opacity(0.2)
        } else {
            return Color.primaryCoral.opacity(0.2)
        }
    }
    
    var senderLabel: String {
        if isFromPatient {
            return "Patient"
        } else if isFromClara {
            return "Clara AI"
        } else {
            return "You"
        }
    }
    
    var body: some View {
        HStack {
            if !isFromPatient {
                Spacer()
            }
            
            VStack(alignment: isFromPatient ? .leading : .trailing, spacing: 4) {
                Text(senderLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .padding(12)
                    .background(bubbleColor)
                    .cornerRadius(16)
                
                if let triageOutcome = message.triageOutcome {
                    TriageBadge(outcome: triageOutcome)
                }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: isFromPatient ? .leading : .trailing)
            .padding(.horizontal)
            
            if isFromPatient {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ReviewResultView: View {
    let review: ProviderReviewRequestDetail
    
    var statusColor: Color {
        switch review.status?.lowercased() {
        case "responded":
            return .green
        case "flagged":
            return .orange
        case "escalated":
            return .red
        default:
            return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(statusColor)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider Review")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(review.status?.capitalized ?? "Pending")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                    }
                    
                    Spacer()
                    
                    if let respondedAt = review.respondedAt,
                       let date = ISO8601DateFormatter().date(from: respondedAt) {
                        Text(formatTime(date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let response = review.providerResponse, !response.isEmpty {
                    Divider()
                    Text(response)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            .padding(12)
            .background(Color.primaryCoral.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


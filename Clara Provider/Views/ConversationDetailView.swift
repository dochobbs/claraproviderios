import SwiftUI
import os.log

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
    @State private var conversationDetail: ProviderReviewRequestDetail? = nil
    @State private var includeProviderName: Bool = false
    @State private var showingFlagModal = false
    @State private var flagReason = ""
    @State private var isFlagging = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Patient info card
                    if let detail = conversationDetail {
                        NavigationLink(
                            value: PatientProfileDestination(
                                childId: UUID(uuidString: detail.conversationId),
                                childName: detail.childName,
                                childAge: detail.childAge
                            )
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
                            .font(.rethinkSans(15, relativeTo: .subheadline))
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

                            // Flag Reason - display if conversation is flagged with a reason
                            if let review = conversationReview,
                               review.status?.lowercased() == "flagged",
                               let reason = review.flagReason,
                               !reason.isEmpty {
                                FlagReasonView(review: review)
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
            
            // Provider Reply Box - only show if status is "pending"
            // Once any response is submitted (responded, flagged, escalated, or dismissed), hide the reply box
            if let detail = conversationDetail, 
               let status = detail.status,
               status.lowercased() == "pending" {
                ProviderReplyBox(
                    replyText: $replyText,
                    selectedResponse: $selectedResponse,
                    isSubmitting: $isSubmitting,
                    includeProviderName: $includeProviderName,
                    onSubmit: {
                        submitReview()
                    },
                    onDismiss: {
                        dismissReview()
                    }
                )
            }
        }
        .navigationTitle(conversationDetail?.conversationTitle ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Show flagged indicator if status is flagged
                    if let detail = conversationDetail, detail.status?.lowercased() == "flagged" {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Flagged")
                                .font(.rethinkSans(12, relativeTo: .caption))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                    }

                    // Flag button - only show if not already flagged
                    if let detail = conversationDetail, detail.status?.lowercased() != "flagged" {
                        Button(action: { showingFlagModal = true }) {
                            Image(systemName: "flag")
                                .foregroundColor(.orange)
                        }
                        .accessibilityLabel("Flag conversation")
                    }
                }
            }
        }
        .sheet(isPresented: $showingMessageInput) {
            ProviderMessageInputView(conversationId: conversationId)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingFlagModal) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Flag Conversation")
                        .font(.rethinkSansBold(22, relativeTo: .title2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason (optional)")
                            .font(.rethinkSansBold(15, relativeTo: .subheadline))

                        TextEditor(text: $flagReason)
                            .font(.rethinkSans(15, relativeTo: .body))
                            .frame(minHeight: 80, maxHeight: 150)
                            .padding(8)
                            .border(Color.adaptiveSecondaryBackground(for: colorScheme))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    Text("Character limit: \(flagReason.count)/500")
                        .font(.rethinkSans(12, relativeTo: .caption))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)

                    Spacer()

                    Button(action: flagConversation) {
                        if isFlagging {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Flag Conversation")
                                .font(.rethinkSansBold(17, relativeTo: .body))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Color.primaryCoral)
                    .cornerRadius(12)
                    .disabled(isFlagging || flagReason.count > 500)
                    .padding()
                }
                .background(Color.adaptiveBackground(for: colorScheme))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingFlagModal = false
                            flagReason = ""
                        }
                    }
                }
            }
        }
        .onAppear {
            // Prepopulate reply with default "Agree" message since it's the default selection
            replyText = selectedResponse.defaultMessage
            Task {
                await loadConversationData()
            }
        }
        .onChange(of: showingFlagModal) { _, isShowing in
            // When flag modal is opened, populate existing flag reason if available
            if isShowing, let detail = conversationDetail, let reason = detail.flagReason {
                flagReason = reason
            } else if !isShowing {
                // Clear flag reason when closing modal
                flagReason = ""
            }
        }
        .refreshable {
            await loadConversationData()
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
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
        os_log("[ConversationDetailView] Loading conversation data", log: .default, type: .debug)

        // Load conversation details first
        await store.loadConversationDetails(id: conversationId)

        // Cache conversation detail in state to avoid repeated store lookups
        // This prevents circular dependencies and reduces view recalculations
        await MainActor.run {
            if let detail = store.getConversationDetails(for: conversationId) {
                conversationDetail = detail
                os_log("[ConversationDetailView] Found conversation details", log: .default, type: .debug)
            } else {
                os_log("[ConversationDetailView] No conversation details found", log: .default, type: .debug)
            }
        }
        
        // Load messages from Supabase
        await MainActor.run {
            isLoading = true
        }
        
        do {
            os_log("[ConversationDetailView] Fetching follow-up messages", log: .default, type: .debug)
            let followUpMessages = try await ProviderSupabaseService.shared.fetchFollowUpMessages(for: conversationId)
            os_log("[ConversationDetailView] Found %d follow-up messages", log: .default, type: .debug, followUpMessages.count)
            
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
            os_log("[ConversationDetailView] Error loading conversation data: %{public}s", log: .default, type: .error, String(describing: error))
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func submitReview() {
        guard let detail = conversationDetail else { return }
        
        HapticFeedback.medium()
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
                case .messageDrHobbs:
                    status = "responded"
                }
                
                // Add provider response if text is provided
                var finalResponse = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Include provider name if checkbox is checked
                if includeProviderName && !finalResponse.isEmpty {
                    finalResponse = "\(finalResponse)\n\n— Dr Michael Hobbs"
                } else if includeProviderName && finalResponse.isEmpty {
                    finalResponse = "— Dr Michael Hobbs"
                }
                
                if !finalResponse.isEmpty {
                    try await ProviderSupabaseService.shared.addProviderResponse(
                        id: detail.id,
                        response: finalResponse,
                        name: includeProviderName ? "Dr Michael Hobbs" : nil,
                        urgency: nil,
                        status: status
                    )
                    
                    // Create follow-up message to notify patient
                    if let conversationUUID = UUID(uuidString: detail.conversationId) {
                        try? await ProviderSupabaseService.shared.createPatientNotificationMessage(
                            conversationId: conversationUUID,
                            userId: detail.userId,
                            providerResponse: finalResponse,
                            providerName: includeProviderName ? "Dr Michael Hobbs" : nil
                        )
                    }
                } else {
                    // If no text, just update status
                    try await store.updateReviewStatus(id: detail.id, status: status)
                }
                
                // Immediately refresh conversation details to get updated status
                await store.loadConversationDetails(id: conversationId)
                
                // Refresh review requests list
                await store.loadReviewRequests()
                
                // Refresh the review display
                let updatedReview = await store.fetchReviewForConversation(id: conversationId)
                    await MainActor.run {
                        conversationReview = updatedReview
                        isSubmitting = false
                        replyText = ""
                        includeProviderName = false
                        HapticFeedback.success()
                    }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    HapticFeedback.error()
                }
            }
        }
    }
    
    private func dismissReview() {
        guard let detail = conversationDetail else { return }
        
        HapticFeedback.medium()
        isSubmitting = true
        
        Task {
            do {
                // Update status to "dismissed"
                try await store.updateReviewStatus(id: detail.id, status: "dismissed")
                
                // Immediately refresh conversation details to get updated status
                await store.loadConversationDetails(id: conversationId)
                
                // Refresh review requests list
                await store.loadReviewRequests()
                
                // Refresh the review display
                let updatedReview = await store.fetchReviewForConversation(id: conversationId)
                await MainActor.run {
                    conversationReview = updatedReview
                    isSubmitting = false
                    HapticFeedback.success()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    HapticFeedback.error()
                }
            }
        }
    }

    private func flagConversation() {
        HapticFeedback.medium()
        isFlagging = true

        Task {
            do {
                let trimmedReason = flagReason.trimmingCharacters(in: .whitespacesAndNewlines)
                try await store.flagConversation(id: conversationId, reason: trimmedReason.isEmpty ? nil : trimmedReason)

                await MainActor.run {
                    isFlagging = false
                    showingFlagModal = false
                    // Update local conversation detail to reflect flagged status and reason
                    if var detail = conversationDetail {
                        detail.status = "flagged"
                        if !trimmedReason.isEmpty {
                            detail.flagReason = trimmedReason
                        }
                        conversationDetail = detail
                    }
                    // Reload review to get the updated flag reason from store
                    Task {
                        let updatedReview = await store.fetchReviewForConversation(id: conversationId)
                        await MainActor.run {
                            conversationReview = updatedReview
                            flagReason = ""
                            HapticFeedback.success()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isFlagging = false
                    errorMessage = "Failed to flag conversation"
                    HapticFeedback.error()
                }
            }
        }
    }
}

enum ProviderResponseType: String, CaseIterable {
    case agree = "agree"
    case agreeWithThoughts = "agree_with_thoughts"
    case disagreeWithThoughts = "disagree_with_thoughts"
    case messageDrHobbs = "message_dr_hobbs"

    var displayName: String {
        switch self {
        case .agree:
            return "Agree"
        case .agreeWithThoughts:
            return "Agree with Thoughts"
        case .disagreeWithThoughts:
            return "Disagree with Thoughts"
        case .messageDrHobbs:
            return "Message Dr Hobbs"
        }
    }

    /// Default message template for auto-fill options
    var defaultMessage: String {
        switch self {
        case .agree:
            return "I agree! Clara did great! If things change, both she and I are here."
        case .messageDrHobbs:
            return "Dr Hobbs would love to connect with you on this. Nothing urgent, just to check in. Would you message him at xxx-xxx-xxxx?"
        default:
            return ""
        }
    }
}

struct ProviderReplyBox: View {
    @Binding var replyText: String
    @Binding var selectedResponse: ProviderResponseType
    @Binding var isSubmitting: Bool
    @Binding var includeProviderName: Bool
    @Environment(\.colorScheme) var colorScheme
    let onSubmit: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Response Type Dropdown with Dismiss Button
            VStack(alignment: .leading, spacing: 8) {
                Text("Response")
                    .font(.rethinkSans(12, relativeTo: .caption))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Picker("Response Type", selection: $selectedResponse) {
                        ForEach(ProviderResponseType.allCases, id: \.self) { responseType in
                            Text(responseType.displayName).tag(responseType)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primaryCoral)
                    .onChange(of: selectedResponse) { _, newValue in
                        HapticFeedback.selection()
                        // Update reply text based on selected response type
                        // - "Agree" and "Message Dr Hobbs" have default messages
                        // - "Agree with Thoughts" and "Disagree with Thoughts" have empty defaults
                        replyText = newValue.defaultMessage
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticFeedback.medium()
                        onDismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18))
                            Text("Dismiss")
                                .font(.rethinkSans(15, relativeTo: .subheadline))
                                .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSubmitting)
                }
            }
            .padding(.horizontal)
            
            // Reply Text Box
            VStack(alignment: .leading, spacing: 8) {
                Text("Reply (Optional)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .topLeading) {
                    // Placeholder text overlay (only shown when text is empty)
                    if replyText.isEmpty {
                        Text("Enter your reply...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4)) // Darker gray for better visibility
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false) // Don't block taps
                    }
                    
                    TextField("", text: $replyText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.black) // Explicit dark text color for readability
                        .accentColor(.primaryCoral) // Coral cursor color
                        .padding(12)
                        .frame(minHeight: 60, maxHeight: 120, alignment: .topLeading)
                }
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.adaptiveTertiaryBackground(for: colorScheme), lineWidth: 1)
                )
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
                        .font(.rethinkSansBold(17, relativeTo: .body))
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
                            .font(.rethinkSansBold(17, relativeTo: .headline))
                        
                        if let age = detail.childAge {
                            Text("Age: \(age)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Patient")
                            .font(.rethinkSansBold(17, relativeTo: .headline))
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
                    .font(.rethinkSans(12, relativeTo: .caption))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text(summary)
                    .font(.system(.subheadline, design: .monospaced))
            }
        }
        .padding()
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct MessageBubbleView: View {
    let message: Message
    @Environment(\.colorScheme) var colorScheme
    
    var isFromPatient: Bool {
        message.isFromUser && message.providerName == nil
    }
    
    var isFromClara: Bool {
        message.providerName == "Clara"
    }
    
    var isFromProvider: Bool {
        message.providerName == "Provider" || (message.providerName != nil && message.providerName != "Clara")
    }
    
    var body: some View {
        VStack(alignment: isFromPatient ? .trailing : .leading, spacing: 4) {
            if isFromPatient {
                // Patient message - beige bubble on the right
                HStack(alignment: .top, spacing: 8) {
                    Text(message.content)
                        .font(.rethinkSans(17, relativeTo: .body))
                        .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                        .textSelection(.enabled)
                    
                    // User initial circle
                    ZStack {
                        Circle()
                            .fill(Color.adaptiveTertiaryBackground(for: colorScheme))
                            .frame(width: 28, height: 28)
                        Text("P")
                            .font(.rethinkSansBold(12, relativeTo: .caption2))
                            .foregroundColor(Color.adaptiveSecondaryLabel(for: colorScheme))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.userBubbleBackground)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else if isFromClara {
                // Clara message - plain text on beige background, left aligned
                ClaraMarkdownView(text: message.content)
                    .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Provider message - coral bubble on the right
                Text(message.content)
                    .font(.rethinkSans(17, relativeTo: .body))
                    .padding(12)
                    .background(Color.primaryCoral.opacity(0.2))
                    .cornerRadius(16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            if let triageOutcome = message.triageOutcome {
                if isFromClara {
                    TriageBadge(outcome: triageOutcome)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TriageBadge(outcome: triageOutcome)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            
            Text(formatTime(message.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: isFromPatient ? .trailing : .leading)
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Clara Markdown View
struct ClaraMarkdownView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseBlocks(text)) { item in
                switch item.block {
                case .paragraph(let s):
                    Text(s)
                        .font(.rethinkSans(17, relativeTo: .body))
                        .fixedSize(horizontal: false, vertical: true)
                case .bullets(let items):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.primaryCoral)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(line)
                                    .font(.rethinkSans(17, relativeTo: .body))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                case .numbers(let items):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .foregroundColor(Color.primaryCoral)
                                    .font(.rethinkSansBold(17, relativeTo: .body))
                                Text(line)
                                    .font(.rethinkSans(17, relativeTo: .body))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                case .heading(_, let s):
                    Text(s)
                        .font(.rethinkSansBold(17, relativeTo: .headline))
                }
            }
        }
    }
    
    private enum BlockType {
        case paragraph(String)
        case bullets([String])
        case numbers([String])
        case heading(Int, String)
    }
    
    private struct ParsedBlock: Identifiable {
        let id = UUID()
        let block: BlockType
    }
    
    private func parseBlocks(_ text: String) -> [ParsedBlock] {
        var blocks: [ParsedBlock] = []
        var currentBullets: [String] = []
        var currentNumbers: [String] = []
        
        func flushLists() {
            if !currentBullets.isEmpty {
                blocks.append(ParsedBlock(block: .bullets(currentBullets)))
                currentBullets.removeAll()
            }
            if !currentNumbers.isEmpty {
                blocks.append(ParsedBlock(block: .numbers(currentNumbers)))
                currentNumbers.removeAll()
            }
        }
        
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushLists()
                continue
            }
            
            // Handle headings
            if line.hasPrefix("### ") {
                flushLists()
                blocks.append(ParsedBlock(block: .heading(3, String(line.dropFirst(4)))))
                continue
            }
            if line.hasPrefix("## ") {
                flushLists()
                blocks.append(ParsedBlock(block: .heading(2, String(line.dropFirst(3)))))
                continue
            }
            if line.hasPrefix("# ") {
                flushLists()
                blocks.append(ParsedBlock(block: .heading(1, String(line.dropFirst(2)))))
                continue
            }
            
            // Handle bullet points
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if (trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ")) && !trimmedLine.hasSuffix(":") {
                let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentBullets.append(content)
                continue
            }
            
            // Handle numbered lists
            if let dotIdx = line.firstIndex(of: "."),
               let n = Int(line[..<dotIdx].trimmingCharacters(in: .whitespaces)),
               n > 0 {
                currentNumbers.append(String(line[line.index(after: dotIdx)...].trimmingCharacters(in: .whitespaces)))
                continue
            }
            
            flushLists()
            blocks.append(ParsedBlock(block: .paragraph(line)))
        }
        
        // Flush at end
        flushLists()
        return blocks
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

    var backgroundColor: Color {
        switch review.status?.lowercased() {
        case "responded":
            return Color.green.opacity(0.1)
        case "flagged":
            return Color.orange.opacity(0.2)
        case "escalated":
            return Color.red.opacity(0.1)
        default:
            return Color.primaryCoral.opacity(0.1)
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
                            .font(.rethinkSans(12, relativeTo: .caption))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Text(review.status?.capitalized ?? "Pending")
                            .font(.rethinkSansBold(15, relativeTo: .subheadline))
                            .foregroundColor(statusColor)
                    }

                    Spacer()

                    if let respondedAt = review.respondedAt,
                       let date = ISO8601DateFormatter().date(from: respondedAt) {
                        Text(formatTime(date))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if let response = review.providerResponse, !response.isEmpty {
                    Divider()
                    Text(response)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .padding(12)
            .background(backgroundColor)
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

// MARK: - Flag Reason View
struct FlagReasonView: View {
    let review: ProviderReviewRequestDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Flag Reason")
                            .font(.rethinkSans(12, relativeTo: .caption))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }

                    Spacer()
                }

                if let reason = review.flagReason, !reason.isEmpty {
                    Divider()
                    Text(reason)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}


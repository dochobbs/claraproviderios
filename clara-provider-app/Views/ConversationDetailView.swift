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
    @State private var isCancellingFollowUp = false
    @State private var shareItem: ShareItem? = nil
    @State private var selectedTab: ConversationTab = .review
    @State private var unreadMessagesCount: Int = 0  // Demo only - will be real count later

    // MARK: - Tab Selection
    enum ConversationTab {
        case review
        case messages
    }

    // MARK: - Message Pagination
    @State private var allMessages: [Message] = []  // Store full message list
    @State private var messagesPerPage = 50         // Show 50 messages at a time
    @State private var currentPage = 1              // Track current page
    @State private var hasMoreMessages = false      // Track if there are more messages to load

    /// Returns the messages to display for current page
    var displayedMessages: [Message] {
        let startIndex = (currentPage - 1) * messagesPerPage
        let endIndex = min(startIndex + messagesPerPage, allMessages.count)
        return Array(allMessages[startIndex..<endIndex])
    }

    /// Total number of messages
    var totalMessageCount: Int {
        allMessages.count
    }

    /// Check if we can load more messages
    var canLoadMoreMessages: Bool {
        let totalPages = (totalMessageCount + messagesPerPage - 1) / messagesPerPage
        return currentPage < totalPages
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Patient info card (always visible)
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
                .padding()
            }

            // Tab selector
            HStack(spacing: 0) {
                TabSelectorButton(
                    title: "Review",
                    isSelected: selectedTab == .review,
                    badge: nil
                ) {
                    selectedTab = .review
                }

                TabSelectorButton(
                    title: "Messages",
                    isSelected: selectedTab == .messages,
                    badge: unreadMessagesCount > 0 ? "\(unreadMessagesCount)" : nil
                ) {
                    selectedTab = .messages
                    unreadMessagesCount = 0  // Mark as read when opening
                }
            }
            .padding(.horizontal)
            .background(Color.adaptiveBackground(for: colorScheme))

            Divider()

            // Tab content
            if selectedTab == .review {
                reviewTabContent
            } else {
                messagesTabContent
            }
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle(conversationDetail?.conversationTitle ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Actions menu, flag button, and follow-up indicator
                HStack(spacing: 12) {
                    if let detail = conversationDetail {
                        // iOS share button
                        Button(action: { shareAllContent() }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primaryCoral)
                        }
                        .accessibilityLabel("Share conversation")

                        // Show clock icon if follow-up is scheduled - tappable to cancel
                        if detail.scheduleFollowup == true {
                            cancelFollowUpButton
                        }

                        Button(action: {
                            if detail.isFlagged == true {
                                // Unflag
                                Task {
                                    await unflagConversation()
                                }
                            } else {
                                // Flag
                                showingFlagModal = true
                            }
                        }) {
                            Image(systemName: detail.isFlagged == true ? "flag.fill" : "flag")
                                .foregroundColor(.flaggedTeal)
                        }
                        .accessibilityLabel(detail.isFlagged == true ? "Unflag conversation" : "Flag conversation")
                    } else {
                        // Show loading state or placeholder
                        Image(systemName: "flag")
                            .foregroundColor(.gray)
                            .opacity(0.5)
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
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.content])
        }
        .onAppear {
            // Prepopulate reply with default "Agree" message since it's the default selection
            replyText = selectedResponse.defaultMessage
            Task {
                await loadConversationData()
            }
        }
        .onChange(of: conversationId) { oldId, newId in
            // When navigating to a NEW conversation, reset selectedResponse
            if oldId != newId {
                selectedResponse = .agree
                replyText = selectedResponse.defaultMessage
                os_log("[ConversationDetailView] Navigated to new conversation - reset selectedResponse to .agree", log: .default, type: .debug)
            }
            Task {
                await loadConversationData()
            }
        }
    }

    // MARK: - Review Tab Content

    private var reviewTabContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Messages
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if totalMessageCount > messagesPerPage {
                        // Show pagination info for large conversations
                        HStack {
                            Text("Showing \(displayedMessages.count) of \(totalMessageCount) messages")
                                .font(.rethinkSans(12, relativeTo: .caption))
                                .foregroundColor(.secondary)
                            Spacer()
                            if totalMessageCount > 1000 {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                    .help("Large conversation: messages are paginated")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
                    }

                    if allMessages.isEmpty {
                        Text("No messages yet")
                            .font(.rethinkSans(15, relativeTo: .subheadline))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            // Load earlier messages button (if not on first page)
                            if currentPage > 1 {
                                Button(action: { currentPage -= 1 }) {
                                    HStack {
                                        Image(systemName: "chevron.up")
                                        Text("Load Earlier Messages (\(totalMessageCount - (currentPage * messagesPerPage)) more)")
                                        Image(systemName: "chevron.up")
                                    }
                                    .font(.rethinkSans(14, relativeTo: .caption))
                                    .foregroundColor(.primaryCoral)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }

                            // Display paginated messages
                            ForEach(displayedMessages) { message in
                                MessageBubbleView(message: message)
                            }

                            // Load more messages button (if more available)
                            if canLoadMoreMessages {
                                Button(action: { currentPage += 1 }) {
                                    HStack {
                                        Image(systemName: "chevron.down")
                                        Text("Load More Messages (\(totalMessageCount - (currentPage * messagesPerPage)) remaining)")
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.rethinkSans(14, relativeTo: .caption))
                                    .foregroundColor(.primaryCoral)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }

                            // Review Result - appended at bottom after messages
                            // Includes flag reason if conversation is flagged
                            // Only show if review is completed (has a status other than pending)
                            if let review = conversationReview,
                               let status = review.status,
                               status.lowercased() != "pending" {
                                ReviewResultView(review: review, onReopen: reopenResponse)
                                    .onAppear {
                                        os_log("[ConversationDetailView] 📦 ReviewResultView APPEARED with status=%{public}s", log: .default, type: .info, status)
                                    }
                            } else {
                                Color.clear.frame(height: 0)
                                    .onAppear {
                                        os_log("[ConversationDetailView] ❌ ReviewResultView HIDDEN - conversationReview=%{public}s, status=%{public}s",
                                               log: .default, type: .info,
                                               conversationReview != nil ? "exists" : "nil",
                                               conversationReview?.status ?? "nil")
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // If no messages but we have a completed review, show it anyway
                    if allMessages.isEmpty,
                       let review = conversationReview,
                       let status = review.status,
                       status.lowercased() != "pending" {
                        ReviewResultView(review: review, onReopen: reopenResponse)
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
    }

    // MARK: - Messages Tab Content

    private var messagesTabContent: some View {
        MessagingDemoView(
            conversationId: conversationId,
            patientName: conversationDetail?.childName
        )
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
                allMessages = newMessages
                // Reset pagination when loading new conversation
                currentPage = 1
                let totalPages = (newMessages.count + messagesPerPage - 1) / messagesPerPage
                hasMoreMessages = totalPages > 1

                // Log pagination info for conversations with many messages
                if newMessages.count > 100 {
                    os_log("[ConversationDetailView] Loaded %d messages for pagination (showing %d per page, %d total pages)",
                           log: .default, type: .info, newMessages.count, messagesPerPage, totalPages)
                }

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
                // All response types save as "responded"
                // Flagging is handled separately via the flag button
                let status = "responded"

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
                        id: detail.conversationId,
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
                    try await store.updateReviewStatus(id: detail.conversationId, status: status)
                }

                // Immediately refresh conversation details to get updated status - force fresh from server
                await store.loadConversationDetails(id: conversationId, forceFresh: true)

                // Refresh review requests list - bypass debounce since user just submitted
                await store.loadReviewRequests(bypassDebounce: true)

                // Refresh the review display
                let updatedReview = await store.fetchReviewForConversation(id: conversationId)

                os_log("[ConversationDetailView] Fetched updated review after submit - status=%{public}s, hasResponse=%{public}s",
                       log: .default, type: .info,
                       updatedReview?.status ?? "nil",
                       updatedReview?.providerResponse != nil ? "yes" : "no")

                await MainActor.run {
                    // Update BOTH conversationReview AND conversationDetail to stay in sync
                    conversationReview = updatedReview
                    conversationDetail = updatedReview
                    isSubmitting = false
                    replyText = ""
                    includeProviderName = false
                    HapticFeedback.success()
                    os_log("[ConversationDetailView] ✅ UPDATED UI STATE - conversationReview status=%{public}s, conversationDetail status=%{public}s",
                           log: .default, type: .info,
                           conversationReview?.status ?? "nil",
                           conversationDetail?.status ?? "nil")
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
                // Update status to "dismissed" - use conversationId not row id
                try await store.updateReviewStatus(id: detail.conversationId, status: "dismissed")

                // Immediately refresh conversation details to get updated status - force fresh from server
                await store.loadConversationDetails(id: conversationId, forceFresh: true)

                // Refresh review requests list - bypass debounce since user just submitted
                await store.loadReviewRequests(bypassDebounce: true)
                
                // Refresh the review display
                let updatedReview = await store.fetchReviewForConversation(id: conversationId)
                await MainActor.run {
                    // Update BOTH to stay in sync
                    conversationReview = updatedReview
                    conversationDetail = updatedReview
                    isSubmitting = false
                    HapticFeedback.success()
                    os_log("[ConversationDetailView] Dismissed review - updated both state variables", log: .default, type: .info)
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
                    // Update local conversation detail to reflect flagged state and reason
                    if var detail = conversationDetail {
                        detail.isFlagged = true
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

    // MARK: - Cancel Follow-up Button

    private var cancelFollowUpButton: some View {
        Button(action: {
            isCancellingFollowUp = true
            Task {
                do {
                    try await store.cancelFollowUp(conversationId: conversationId)
                    // Refresh the detail to update UI
                    await store.loadConversationDetails(id: conversationId)
                    // Update local state
                    await MainActor.run {
                        conversationDetail?.scheduleFollowup = false
                    }
                } catch {
                    // Error handling
                    errorMessage = "Failed to cancel follow-up: \(error.localizedDescription)"
                }
                isCancellingFollowUp = false
            }
        }) {
            if isCancellingFollowUp {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
            }
        }
        .accessibilityLabel("Cancel follow-up")
    }

    private func unflagConversation() async {
        HapticFeedback.medium()

        do {
            // Remove flag and flag reason, but preserve review response
            try await store.unflagConversation(id: conversationId)

            // Reload BOTH conversation detail and review from store - force fresh from server
            // This ensures we get the correct restored status (not "pending")
            await store.loadConversationDetails(id: conversationId, forceFresh: true)
            let updatedReview = await store.fetchReviewForConversation(id: conversationId)
            if let updatedReview = updatedReview {
                await MainActor.run {
                    // Update both to stay in sync
                    conversationDetail = updatedReview
                    conversationReview = updatedReview
                    HapticFeedback.success()
                    os_log("[ConversationDetailView] Unflagged conversation - status now: %{public}s", log: .default, type: .info, updatedReview.status ?? "nil")
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to unflag conversation"
                HapticFeedback.error()
            }
        }
    }

    // MARK: - Share Methods

    private func shareAllContent() {
        guard let detail = conversationDetail else {
            print("[Share] No conversation detail available")
            return
        }

        var content = ""

        // Section 1: Summary
        content += "═══════════════════════════════\n"
        content += "CONVERSATION SUMMARY\n"
        content += "═══════════════════════════════\n\n"
        content += "Patient: \(detail.childName ?? "Unknown")\n"
        if let age = detail.childAge {
            content += "Age: \(age)\n"
        }
        content += "Status: \(detail.status?.capitalized ?? "Unknown")\n"
        if let triage = detail.triageOutcome {
            content += "Triage: \(triage)\n"
        }
        content += "Total Messages: \(allMessages.count)\n"
        if let createdAt = detail.createdAt {
            content += "Created: \(createdAt)\n"
        }
        content += "\n"

        // Add clinical summary from Clara
        if let summary = detail.conversationSummary, !summary.isEmpty {
            content += "CLINICAL SUMMARY:\n"
            content += summary
            content += "\n\n"
        }
        content += "\n"

        // Section 2: Full Conversation
        content += "═══════════════════════════════\n"
        content += "FULL CONVERSATION\n"
        content += "═══════════════════════════════\n\n"

        if allMessages.isEmpty {
            content += "(No messages in conversation)\n\n"
        } else {
            for message in allMessages {
                let sender = message.isFromUser ? "Parent" : "Clara"
                content += "[\(sender)]: \(message.content)\n\n"
            }
        }

        // Section 3: Provider Response
        if let response = detail.providerResponse, !response.isEmpty {
            content += "═══════════════════════════════\n"
            content += "PROVIDER RESPONSE\n"
            content += "═══════════════════════════════\n\n"
            content += response
            content += "\n"
        } else {
            content += "(No provider response yet)\n\n"
        }

        // Create share item directly with content
        // Note: iOS may log "Error acquiring assertion" - this is a benign system warning
        // and does not prevent the share sheet from working correctly
        shareItem = ShareItem(content: content)
    }

    /// Reopen a completed response to allow editing
    /// Long-press on document icon to trigger this
    private func reopenResponse() {
        HapticFeedback.medium()

        Task {
            do {
                // Revert status back to "pending" to show reply box again
                // This allows provider to re-enter a response without the old one being stuck
                try await store.updateReviewStatus(id: conversationId.uuidString, status: "pending")

                // Reload both conversation detail and review from store - force fresh from server
                await store.loadConversationDetails(id: conversationId, forceFresh: true)
                let updatedReview = await store.fetchReviewForConversation(id: conversationId)
                if let updatedReview = updatedReview {
                    await MainActor.run {
                        conversationDetail = updatedReview
                        conversationReview = updatedReview
                        // Clear form fields for re-entry
                        replyText = ""
                        // Note: DON'T reset selectedResponse here - preserve the user's choice
                        // selectedResponse should keep whatever they had selected
                        includeProviderName = false
                        HapticFeedback.success()
                        os_log("[ConversationDetailView] Response reopened for editing", log: .default, type: .info)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to reopen response: \(error.localizedDescription)"
                    HapticFeedback.error()
                    os_log("[ConversationDetailView] Error reopening response: %{public}s", log: .default, type: .error, error.localizedDescription)
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
            return "Dr Hobbs would love to connect with you on this. Nothing urgent, just to check in. Would you message him at 612-208-7283?"
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false) // Don't block taps
                    }

                    TextEditor(text: $replyText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.black) // Explicit dark text color for readability
                        .scrollContentBackground(.hidden) // Hide default background
                        .background(Color.clear) // Transparent to show parent background
                        .accentColor(.primaryCoral) // Coral cursor color
                        .padding(8)
                        .frame(minHeight: 100)
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
    @State private var summaryExpanded: Bool = true  // Start expanded

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

                // Tappable Summary header
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        summaryExpanded.toggle()
                    }
                    HapticFeedback.light()
                }) {
                    HStack {
                        Text("Summary")
                            .font(.rethinkSans(12, relativeTo: .caption))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        Image(systemName: summaryExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if summaryExpanded {
                    ScrollView {
                        Text(summary)
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)  // Limit height, allow scrolling for longer content
                }
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
    var onReopen: (() -> Void)? = nil
    @State private var responseExpanded: Bool = false  // Start collapsed

    var statusColor: Color {
        switch review.status?.lowercased() {
        case "responded":
            return .flaggedTeal
        case "escalated":
            return .red
        case "dismissed":
            return .gray
        default:
            return .blue
        }
    }

    var backgroundColor: Color {
        switch review.status?.lowercased() {
        case "responded":
            return Color.flaggedTeal.opacity(0.1)
        case "escalated":
            return Color.red.opacity(0.1)
        case "dismissed":
            return Color.gray.opacity(0.1)
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
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            onReopen?()
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Provider Review")
                            .font(.rethinkSans(12, relativeTo: .caption))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 6) {
                            Text(review.status?.capitalized ?? "Pending")
                                .font(.rethinkSansBold(15, relativeTo: .subheadline))
                                .foregroundColor(statusColor)

                            // Show flag badge if conversation is flagged
                            if review.isFlagged == true {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 3)
                                    .background(Color.flaggedTeal)
                                    .cornerRadius(4)
                            }
                        }
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

                    // Tappable Response header
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            responseExpanded.toggle()
                        }
                        HapticFeedback.light()
                    }) {
                        HStack {
                            Text("Response")
                                .font(.rethinkSans(12, relativeTo: .caption))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Spacer()

                            Image(systemName: responseExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if responseExpanded {
                        Text(response)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }

                // Display flag reason under review reason if flagged
                if let reason = review.flagReason, !reason.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.flaggedTeal)
                                .font(.caption)

                            Text("Reason for Flag")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.flaggedTeal)
                                .fontWeight(.semibold)
                        }

                        Text(reason)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.primary)
                    }
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


// MARK: - Share Item

struct ShareItem: Identifiable {
    let id = UUID()
    let content: String
}

// MARK: - ShareSheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Tab Selector Button

struct TabSelectorButton: View {
    let title: String
    let isSelected: Bool
    let badge: String?
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(isSelected ? .rethinkSansBold(15, relativeTo: .subheadline) : .rethinkSans(15, relativeTo: .subheadline))
                
                if let badge = badge {
                    Text(badge)
                        .font(.rethinkSansBold(12, relativeTo: .caption2))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primaryCoral)
                        .cornerRadius(10)
                }
            }
            .foregroundColor(isSelected ? Color.primaryCoral : Color.adaptiveLabel(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(isSelected ? Color.primaryCoral : Color.clear)
                        .frame(height: 3)
                }
            )
        }
    }
}

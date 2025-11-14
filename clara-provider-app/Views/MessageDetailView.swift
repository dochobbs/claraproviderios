import SwiftUI
import os.log

struct MessageDetailView: View {
    let conversationId: UUID
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    @State private var messages: [MessageDetail] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var shareItem: ShareItem? = nil
    @State private var showingFlagModal = false
    @State private var flagReason = ""
    @State private var isFlagging = false
    @State private var isFlagged = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.adaptiveBackground(for: colorScheme))
            } else if messages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Messages")
                        .font(.rethinkSansBold(22, relativeTo: .title2))
                    Text("No messages found in this conversation.")
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveBackground(for: colorScheme))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                }
                .scrollContentBackground(.hidden)
                .background(Color.adaptiveBackground(for: colorScheme))
            }
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { shareAllContent() }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primaryCoral)
                    }
                    .accessibilityLabel("Share conversation")

                    Button(action: {
                        if isFlagged {
                            // Unflag
                            Task {
                                await unflagConversation()
                            }
                        } else {
                            // Flag
                            showingFlagModal = true
                        }
                    }) {
                        Image(systemName: isFlagged ? "flag.fill" : "flag")
                            .foregroundColor(.flaggedTeal)
                    }
                    .accessibilityLabel(isFlagged ? "Unflag conversation" : "Flag conversation")
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.content])
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
            Task {
                await loadMessages()
                checkFlagStatus()
            }

            // Mark this conversation as read for AllMessagesView tracking
            store.markMessageConversationAsRead(conversationId: conversationId.uuidString)
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
                    await loadMessages()
                }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func loadMessages() async {
        await MainActor.run { isLoading = true }

        do {
            os_log("[MessageDetailView] Fetching messages for conversation_id: %{public}s", log: .default, type: .info, conversationId.uuidString)

            let fetchedMessages = try await ProviderSupabaseService.shared.fetchMessagesForConversation(conversationId: conversationId)

            await MainActor.run {
                messages = fetchedMessages
                isLoading = false
                os_log("[MessageDetailView] Loaded %d messages", log: .default, type: .info, fetchedMessages.count)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load messages: \(error.localizedDescription)"
                isLoading = false
                os_log("[MessageDetailView] Error loading messages: %{public}s", log: .default, type: .error, String(describing: error))
            }
        }
    }

    private func shareAllContent() {
        var content = ""

        // Section 1: Summary
        content += "═══════════════════════════════\n"
        content += "CONVERSATION EXPORT\n"
        content += "═══════════════════════════════\n\n"
        content += "Conversation ID: \(conversationId.uuidString)\n"
        content += "Total Messages: \(messages.count)\n"
        if let firstMessage = messages.first {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            content += "Started: \(formatter.string(from: firstMessage.timestamp))\n"
        }
        content += "\n"

        // Section 2: Full Conversation
        content += "═══════════════════════════════\n"
        content += "FULL CONVERSATION\n"
        content += "═══════════════════════════════\n\n"

        if messages.isEmpty {
            content += "(No messages in conversation)\n\n"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short

            for message in messages {
                let sender = message.isFromUser ? "User" : "AI"
                let timestamp = formatter.string(from: message.timestamp)
                content += "[\(timestamp)] \(sender): \(message.content)\n\n"
            }
        }

        // Create share item
        shareItem = ShareItem(content: content)
    }

    private func checkFlagStatus() {
        // Check if this conversation is flagged in the store
        if let detail = store.reviewRequests.first(where: { $0.conversationId == conversationId.uuidString }) {
            isFlagged = detail.isFlagged ?? false
            if let reason = detail.flagReason, !reason.isEmpty {
                flagReason = reason
            }
        }
    }

    private func flagConversation() {
        guard !isFlagging else { return }
        isFlagging = true

        Task {
            do {
                try await store.flagConversation(id: conversationId, reason: flagReason)
                await MainActor.run {
                    isFlagged = true
                    isFlagging = false
                    showingFlagModal = false
                    os_log("[MessageDetailView] Successfully flagged conversation", log: .default, type: .info)
                }
            } catch {
                await MainActor.run {
                    isFlagging = false
                    errorMessage = "Failed to flag conversation: \(error.localizedDescription)"
                    os_log("[MessageDetailView] Error flagging conversation: %{public}s", log: .default, type: .error, String(describing: error))
                }
            }
        }
    }

    private func unflagConversation() async {
        do {
            try await store.unflagConversation(id: conversationId)
            await MainActor.run {
                isFlagged = false
                flagReason = ""
                os_log("[MessageDetailView] Successfully unflagged conversation", log: .default, type: .info)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to unflag conversation: \(error.localizedDescription)"
                os_log("[MessageDetailView] Error unflagging conversation: %{public}s", log: .default, type: .error, String(describing: error))
            }
        }
    }
}

struct MessageBubble: View {
    let message: MessageDetail
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
            if message.isFromUser {
                // User message - beige bubble on the right
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
                        Text("U")
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
            } else {
                // AI/System message - plain text on left
                Text(message.content)
                    .font(.rethinkSans(17, relativeTo: .body))
                    .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(formatTime(message.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

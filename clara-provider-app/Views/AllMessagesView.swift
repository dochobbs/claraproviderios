import SwiftUI
import os.log

struct AllMessagesView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    @State private var conversations: [MessageConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedFilter: MessageFilter = .unread
    @State private var unreadConversationIds: Set<String> = []  // Track which conversations are unread
    @State private var notificationObserver: NSObjectProtocol?

    enum MessageFilter {
        case unread, flagged, all
    }

    var filteredConversations: [MessageConversationSummary] {
        var filtered = conversations

        // Apply filter
        switch selectedFilter {
        case .unread:
            filtered = filtered.filter { unreadConversationIds.contains($0.conversationId) }
        case .flagged:
            // TODO: Add flagged logic once we have flagging in messages
            break
        case .all:
            break
        }

        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { conversation in
                conversation.conversationId.localizedCaseInsensitiveContains(searchText) ||
                (conversation.latestMessagePreview?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return filtered
    }

    var unreadCount: Int {
        unreadConversationIds.count
    }

    var flaggedCount: Int {
        // TODO: Implement flagged count
        0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter buttons
            HStack(spacing: 12) {
                SubFilterButton(
                    title: "Unread",
                    count: unreadCount,
                    isSelected: selectedFilter == .unread
                ) {
                    selectedFilter = .unread
                }
                .frame(maxWidth: .infinity)

                SubFilterButton(
                    title: "Flagged",
                    count: flaggedCount,
                    isSelected: selectedFilter == .flagged
                ) {
                    selectedFilter = .flagged
                }
                .frame(maxWidth: .infinity)

                SubFilterButton(
                    title: "All",
                    count: conversations.count,
                    isSelected: selectedFilter == .all
                ) {
                    selectedFilter = .all
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.adaptiveBackground(for: colorScheme))

            Divider()

            if isLoading && conversations.isEmpty {
                ProgressView("Loading conversations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.adaptiveBackground(for: colorScheme))
            } else if conversations.isEmpty {
                EmptyStateView(
                    title: "No Messages",
                    message: "No conversations found in the messages table."
                )
                .background(Color.adaptiveBackground(for: colorScheme))
            } else {
                List {
                    ForEach(filteredConversations, id: \.id) { conversation in
                        if let validUUID = UUID(uuidString: conversation.conversationId) {
                            NavigationLink(destination: MessageDetailView(conversationId: validUUID).environmentObject(store)) {
                                MessageConversationRow(
                                    conversation: conversation,
                                    isUnread: unreadConversationIds.contains(conversation.conversationId)
                                )
                            }
                            .listRowBackground(Color.adaptiveBackground(for: colorScheme))
                        } else {
                            // Invalid conversation ID
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("Invalid Conversation")
                                        .font(.rethinkSansBold(16, relativeTo: .body))
                                    Text("Conversation ID format is invalid: \(conversation.conversationId)")
                                        .font(.rethinkSans(13, relativeTo: .footnote))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.red.opacity(0.1))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.adaptiveBackground(for: colorScheme))
                .refreshable {
                    await loadConversations()
                }
            }
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle("All Messages")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search conversations...")
        .onAppear {
            if conversations.isEmpty {
                Task {
                    await loadConversations()
                }
            }

            // Listen for mark-as-read notifications
            if let existingObserver = notificationObserver {
                NotificationCenter.default.removeObserver(existingObserver)
            }

            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("MarkMessageConversationAsRead"),
                object: nil,
                queue: .main
            ) { notification in
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    markConversationAsRead(conversationId: conversationId)
                }
            }
        }
        .onDisappear {
            // Clean up notification observer
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
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
                    await loadConversations()
                }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func loadConversations() async {
        await MainActor.run { isLoading = true }

        do {
            os_log("[AllMessagesView] Fetching conversations from messages table", log: .default, type: .info)
            let results = try await ProviderSupabaseService.shared.fetchAllConversationsFromMessages()

            await MainActor.run {
                conversations = results

                // Load unread status from UserDefaults
                loadUnreadStatus()

                // Initialize any new conversations as unread if not already tracked
                for conversation in results {
                    if !hasBeenTracked(conversationId: conversation.conversationId) {
                        unreadConversationIds.insert(conversation.conversationId)
                        markAsTracked(conversationId: conversation.conversationId)
                    }
                }

                // Save updated unread status
                saveUnreadStatus()

                isLoading = false
                os_log("[AllMessagesView] Loaded %d conversations, %d unread", log: .default, type: .info, results.count, unreadConversationIds.count)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                isLoading = false
                os_log("[AllMessagesView] Error loading conversations: %{public}s", log: .default, type: .error, String(describing: error))
            }
        }
    }

    // MARK: - Unread Status Persistence

    private func loadUnreadStatus() {
        if let data = UserDefaults.standard.data(forKey: "unreadMessageConversations"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            unreadConversationIds = decoded
        }
    }

    private func saveUnreadStatus() {
        if let encoded = try? JSONEncoder().encode(unreadConversationIds) {
            UserDefaults.standard.set(encoded, forKey: "unreadMessageConversations")
            // Notify that unread count changed so UI can update
            NotificationCenter.default.post(
                name: NSNotification.Name("UnreadMessageCountChanged"),
                object: nil
            )
        }
    }

    private func hasBeenTracked(conversationId: String) -> Bool {
        let trackedKey = "tracked_conversation_\(conversationId)"
        return UserDefaults.standard.bool(forKey: trackedKey)
    }

    private func markAsTracked(conversationId: String) {
        let trackedKey = "tracked_conversation_\(conversationId)"
        UserDefaults.standard.set(true, forKey: trackedKey)
    }

    private func markConversationAsRead(conversationId: String) {
        unreadConversationIds.remove(conversationId)
        saveUnreadStatus()
        os_log("[AllMessagesView] Marked conversation as read: %{public}s", log: .default, type: .info, conversationId)
    }
}

struct MessageConversationRow: View {
    let conversation: MessageConversationSummary
    let isUnread: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Unread indicator (blue dot)
                if isUnread {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }

                Text("Conversation")
                    .font(.rethinkSansBold(17, relativeTo: .headline))
                    .lineLimit(1)

                Spacer()

                if let timestamp = conversation.latestTimestamp {
                    Text(formatDate(timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            if let preview = conversation.latestMessagePreview {
                HStack(spacing: 4) {
                    if conversation.latestIsFromUser {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.blue)
                    } else {
                        Text("🤖")
                            .font(.system(size: 16))
                    }
                    Text(preview.prefix(100) + (preview.count > 100 ? "..." : ""))
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if let userId = conversation.userId {
                HStack(spacing: 4) {
                    Image(systemName: "person.text.rectangle")
                    Text("User: \(userId)")
                        .font(.rethinkSans(13, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }
            }

            Text("ID: \(conversation.conversationId)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let relativeFormatter = RelativeDateTimeFormatter()
            relativeFormatter.unitsStyle = .abbreviated
            return relativeFormatter.localizedString(for: date, relativeTo: Date())
        }
        return dateString
    }
}

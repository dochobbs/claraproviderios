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
    @State private var unreadRefreshTrigger = false  // Toggle this to force UI refresh
    @State private var notesRefreshTrigger = false  // Toggle this to force notes icons to refresh
    @State private var notificationObserver: NSObjectProtocol?
    @State private var notesChangedObserver: NSObjectProtocol?

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
        // Access the trigger to make this reactive
        _ = unreadRefreshTrigger
        return unreadConversationIds.count
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
                                    isUnread: unreadConversationIds.contains(conversation.conversationId.lowercased()),
                                    hasNotes: hasNotes(for: conversation.conversationId)
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
            os_log("[AllMessagesView] View appeared - reloading unread status",
                   log: .default, type: .info)

            // Always reload unread status from UserDefaults to pick up changes made while view was not visible
            loadUnreadStatus()

            if conversations.isEmpty {
                Task {
                    await loadConversations()
                }
            }

            // Listen for mark-as-read notifications
            if let existingObserver = notificationObserver {
                NotificationCenter.default.removeObserver(existingObserver)
                os_log("[AllMessagesView] Removed existing notification observer",
                       log: .default, type: .info)
            }

            os_log("[AllMessagesView] Setting up notification observer for mark-as-read",
                   log: .default, type: .info)

            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("MarkMessageConversationAsRead"),
                object: nil,
                queue: .main
            ) { notification in
                if let conversationId = notification.userInfo?["conversationId"] as? String {
                    os_log("[AllMessagesView] Received mark-as-read notification for: %{public}s",
                           log: .default, type: .info, String(conversationId.prefix(8)))

                    // Reload from UserDefaults to get the updated state from Store
                    loadUnreadStatus()

                    // Toggle trigger to force UI to re-render with new count
                    unreadRefreshTrigger.toggle()

                    os_log("[AllMessagesView] Reloaded unread status, new count: %d",
                           log: .default, type: .info, unreadConversationIds.count)
                }
            }

            // Listen for provider notes changes
            if let existingNotesObserver = notesChangedObserver {
                NotificationCenter.default.removeObserver(existingNotesObserver)
            }

            notesChangedObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ProviderNotesChanged"),
                object: nil,
                queue: .main
            ) { notification in
                os_log("[AllMessagesView] Received provider notes changed notification",
                       log: .default, type: .info)
                // Toggle trigger to force UI to re-render notes icons
                notesRefreshTrigger.toggle()
            }
        }
        .onDisappear {
            // Don't remove notification observer - we need to keep listening for read status updates
            // even when this view is not visible (e.g., when user navigates to read a message)
            // The observer will be cleaned up when the view is deallocated
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

    private func hasNotes(for conversationId: String) -> Bool {
        // Access the trigger to make this reactive
        _ = notesRefreshTrigger
        let notes = store.loadProviderNotes(conversationId: conversationId)
        return notes != nil && !notes!.isEmpty
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
                    let normalizedId = conversation.conversationId.lowercased()
                    if !hasBeenTracked(conversationId: normalizedId) {
                        unreadConversationIds.insert(normalizedId)
                        markAsTracked(conversationId: normalizedId)
                    }
                }

                // Save updated unread status
                saveUnreadStatus()

                isLoading = false
                os_log("[AllMessagesView] Loaded %d conversations, %d unread", log: .default, type: .info, results.count, unreadConversationIds.count)
            }

            // Prefetch provider notes for all loaded conversations to warm the cache
            let conversationIds = results.map { $0.conversationId }
            await store.prefetchProviderNotes(conversationIds: conversationIds)
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
            os_log("[AllMessagesView] Loading unread status from UserDefaults: %d unread conversations",
                   log: .default, type: .info, decoded.count)
            unreadConversationIds = decoded
            os_log("[AllMessagesView] Unread IDs: %{public}s",
                   log: .default, type: .debug, decoded.map { String($0.prefix(8)) }.joined(separator: ", "))
        } else {
            os_log("[AllMessagesView] No unread status found in UserDefaults",
                   log: .default, type: .info)
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
        let normalizedId = conversationId.lowercased()
        unreadConversationIds.remove(normalizedId)
        unreadRefreshTrigger.toggle()  // Force UI to re-render the count
        saveUnreadStatus()
        os_log("[AllMessagesView] Marked conversation as read: %{public}s", log: .default, type: .info, String(normalizedId.prefix(8)))
    }
}

struct MessageConversationRow: View {
    let conversation: MessageConversationSummary
    let isUnread: Bool
    let hasNotes: Bool
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

                // Notes indicator
                if hasNotes {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundColor(.primaryCoral)
                }

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

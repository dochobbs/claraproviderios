import SwiftUI
import os.log

struct AllMessagesView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    @State private var conversations: [MessageConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    @State private var selectedFilter: MessageFilter = .all
    @State private var notesRefreshTrigger = false  // Toggle this to force notes icons to refresh
    @State private var notesChangedObserver: NSObjectProtocol?
    @State private var listRefreshObserver: NSObjectProtocol?

    enum MessageFilter {
        case unread, notes, flags, all
    }

    @State private var dataRefreshTrigger = 0  // Increment to force complete UI refresh

    var filteredConversations: [MessageConversationSummary] {
        var filtered = conversations

        // Apply filter
        switch selectedFilter {
        case .unread:
            // Unread = admin_viewed_at is null (never viewed by provider)
            filtered = filtered.filter { $0.adminViewedAt == nil }
        case .notes:
            filtered = filtered.filter { hasNotes(for: $0.conversationId) }
        case .flags:
            filtered = filtered.filter { $0.isFlagged == true }
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
        // Access triggers to make this reactive
        _ = dataRefreshTrigger
        let count = conversations.filter { $0.adminViewedAt == nil }.count
        os_log("[AllMessagesView] Computing unreadCount: %d", log: .default, type: .debug, count)
        return count
    }

    var notesCount: Int {
        // Access triggers to make this reactive
        _ = notesRefreshTrigger
        _ = dataRefreshTrigger
        let count = conversations.filter { hasNotes(for: $0.conversationId) }.count
        os_log("[AllMessagesView] Computing notesCount: %d", log: .default, type: .debug, count)
        return count
    }

    var flagsCount: Int {
        // Access triggers to make this reactive
        _ = dataRefreshTrigger
        let count = conversations.filter { $0.isFlagged == true }.count
        os_log("[AllMessagesView] Computing flagsCount: %d", log: .default, type: .debug, count)
        return count
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
                    os_log("[AllMessagesView] Switched to Unread filter", log: .default, type: .info)
                }
                .frame(maxWidth: .infinity)

                SubFilterButton(
                    title: "Notes",
                    count: notesCount,
                    isSelected: selectedFilter == .notes
                ) {
                    selectedFilter = .notes
                    os_log("[AllMessagesView] Switched to Notes filter", log: .default, type: .info)
                }
                .frame(maxWidth: .infinity)

                SubFilterButton(
                    title: "Flags",
                    count: flagsCount,
                    isSelected: selectedFilter == .flags
                ) {
                    selectedFilter = .flags
                    os_log("[AllMessagesView] Switched to Flags filter", log: .default, type: .info)
                }
                .frame(maxWidth: .infinity)

                SubFilterButton(
                    title: "All",
                    count: conversations.count,
                    isSelected: selectedFilter == .all
                ) {
                    selectedFilter = .all
                    os_log("[AllMessagesView] Switched to All filter", log: .default, type: .info)
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
                                    isUnread: conversation.adminViewedAt == nil,
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
            // Always reload to pick up changes (notes, flags, read status)
            Task {
                await loadConversations()
            }

            // Listen for provider notes changes to update indicators
            if let existingNotesObserver = notesChangedObserver {
                NotificationCenter.default.removeObserver(existingNotesObserver)
            }

            notesChangedObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ProviderNotesChanged"),
                object: nil,
                queue: .main
            ) { [self] _ in
                os_log("[AllMessagesView] Received provider notes changed notification - refreshing UI",
                       log: .default, type: .info)
                notesRefreshTrigger.toggle()
                dataRefreshTrigger += 1
            }

            // Listen for conversation list refresh requests (from MessageDetailView)
            if let existingListObserver = listRefreshObserver {
                NotificationCenter.default.removeObserver(existingListObserver)
            }

            listRefreshObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ConversationListNeedsRefresh"),
                object: nil,
                queue: .main
            ) { [self] _ in
                os_log("[AllMessagesView] Received list refresh notification - reloading conversations",
                       log: .default, type: .info)
                Task {
                    await loadConversations()
                }
            }
        }
        .onDisappear {
            if let observer = notesChangedObserver {
                NotificationCenter.default.removeObserver(observer)
                notesChangedObserver = nil
            }
            if let observer = listRefreshObserver {
                NotificationCenter.default.removeObserver(observer)
                listRefreshObserver = nil
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

    private func hasNotes(for conversationId: String) -> Bool {
        // Access the trigger to make this reactive
        _ = notesRefreshTrigger
        // Use cache-only check to avoid triggering API calls on every row render
        return store.hasProviderNotesInCache(conversationId: conversationId)
    }

    private func loadConversations() async {
        await MainActor.run { isLoading = true }

        do {
            os_log("[AllMessagesView] Fetching conversations from messages table", log: .default, type: .info)
            let results = try await ProviderSupabaseService.shared.fetchAllConversationsFromMessages()

            await MainActor.run {
                conversations = results
                isLoading = false

                // Log counts BEFORE prefetch
                let unreadCountBefore = results.filter { $0.adminViewedAt == nil }.count
                let flaggedCountBefore = results.filter { $0.isFlagged == true }.count
                let withNotesCountBefore = results.filter { hasNotes(for: $0.conversationId) }.count

                os_log("[AllMessagesView] BEFORE prefetch - %d conversations: %d unread, %d flagged, %d with notes",
                       log: .default, type: .info, results.count, unreadCountBefore, flaggedCountBefore, withNotesCountBefore)

                // Log sample conversations for debugging
                let flaggedSamples = results.filter { $0.isFlagged == true }.prefix(3)
                for sample in flaggedSamples {
                    os_log("[AllMessagesView] Flagged conversation: %{public}s, flagReason: %{public}s",
                           log: .default, type: .info,
                           String(sample.conversationId.prefix(8)),
                           sample.flagReason ?? "none")
                }
            }

            // Prefetch notes for all conversations to show indicators in list
            let conversationIds = results.map { $0.conversationId }
            os_log("[AllMessagesView] Starting prefetch for %d conversation IDs", log: .default, type: .info, conversationIds.count)
            await store.prefetchProviderNotes(conversationIds: conversationIds)

            // Trigger complete UI refresh after prefetch completes
            await MainActor.run {
                // Log counts AFTER prefetch
                let unreadCountAfter = conversations.filter { $0.adminViewedAt == nil }.count
                let flaggedCountAfter = conversations.filter { $0.isFlagged == true }.count
                let withNotesCountAfter = conversations.filter { hasNotes(for: $0.conversationId) }.count

                os_log("[AllMessagesView] AFTER prefetch - %d conversations: %d unread, %d flagged, %d with notes",
                       log: .default, type: .info, conversations.count, unreadCountAfter, flaggedCountAfter, withNotesCountAfter)

                // Force UI refresh by incrementing both triggers
                notesRefreshTrigger.toggle()
                dataRefreshTrigger += 1
                os_log("[AllMessagesView] Triggered complete UI refresh (dataRefreshTrigger=%d)",
                       log: .default, type: .info, dataRefreshTrigger)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                isLoading = false
                os_log("[AllMessagesView] Error loading conversations: %{public}s", log: .default, type: .error, String(describing: error))
            }
        }
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

                // Flag indicator
                if conversation.isFlagged == true {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.flaggedTeal)
                }

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

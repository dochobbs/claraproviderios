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
        // Count conversations where admin_viewed_at is null (from conversations table)
        return conversations.filter { $0.adminViewedAt == nil }.count
    }

    var notesCount: Int {
        // Access the trigger to make this reactive
        _ = notesRefreshTrigger
        return conversations.filter { hasNotes(for: $0.conversationId) }.count
    }

    var flagsCount: Int {
        // Count conversations with is_flagged=true from conversations table
        return conversations.filter { $0.isFlagged == true }.count
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

                // Notes/Flags toggle button - tap to cycle through notes → flags → all
                let notesButtonTitle = selectedFilter == .notes ? "Notes" : (selectedFilter == .flags ? "Flags" : "Notes/Flags")
                let notesButtonCount = selectedFilter == .notes ? notesCount : (selectedFilter == .flags ? flagsCount : (notesCount + flagsCount))
                let notesIsSelected = selectedFilter == .notes || selectedFilter == .flags

                SubFilterButton(
                    title: notesButtonTitle,
                    count: notesButtonCount,
                    isSelected: notesIsSelected
                ) {
                    HapticFeedback.light()
                    // Cycle through: notes → flags → all
                    switch selectedFilter {
                    case .notes:
                        selectedFilter = .flags
                        os_log("[AllMessagesView] Switched to Flags filter", log: .default, type: .info)
                    case .flags:
                        selectedFilter = .all
                        os_log("[AllMessagesView] Switched to All filter", log: .default, type: .info)
                    case .all, .unread:
                        selectedFilter = .notes
                        os_log("[AllMessagesView] Switched to Notes filter", log: .default, type: .info)
                    }
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

                let unreadCount = results.filter { $0.adminViewedAt == nil }.count
                let flaggedCount = results.filter { $0.isFlagged == true }.count
                let withNotesCount = results.filter { hasNotes(for: $0.conversationId) }.count

                os_log("[AllMessagesView] Loaded %d conversations: %d unread, %d flagged, %d with notes (from cache)",
                       log: .default, type: .info, results.count, unreadCount, flaggedCount, withNotesCount)

                // Log first conversation's data for debugging
                if let first = results.first {
                    os_log("[AllMessagesView] First conversation - ID: %{public}s, isFlagged: %{public}s, adminViewedAt: %{public}s",
                           log: .default, type: .info,
                           String(first.conversationId.prefix(8)),
                           String(describing: first.isFlagged),
                           first.adminViewedAt ?? "nil")
                }
            }

            // Prefetch notes for all conversations to show indicators in list
            let conversationIds = results.map { $0.conversationId }
            await store.prefetchProviderNotes(conversationIds: conversationIds)

            // Trigger UI refresh after prefetch completes
            await MainActor.run {
                notesRefreshTrigger.toggle()
                os_log("[AllMessagesView] Triggered notes UI refresh after prefetch, cache size: %d",
                       log: .default, type: .info, conversationIds.count)
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

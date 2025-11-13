import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @State private var selectedTab: MainTab = .reviews  // New: main tab selection
    @State private var selectedReviewFilter: ReviewFilter = .pending  // New: sub-filter for reviews
    @State private var selectedMessageFilter: MessageFilter = .unread  // New: sub-filter for messages
    @State private var searchText: String = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var notificationObserver: NSObjectProtocol?
    @State private var showScheduleFollowUp: Bool = false
    @State private var selectedRequestForFollowUp: ProviderReviewRequestDetail?

    enum MainTab {
        case reviews, messages
    }

    enum ReviewFilter {
        case pending, flagged, all
    }

    enum MessageFilter {
        case unread, all
    }

    var filteredRequests: [ProviderReviewRequestDetail] {
        var requests = store.reviewRequests

        // Filter by main tab and sub-filter
        if selectedTab == .reviews {
            switch selectedReviewFilter {
            case .pending:
                requests = requests.filter { $0.status == "pending" }
            case .flagged:
                requests = requests.filter { $0.isFlagged == true }
            case .all:
                // Show all review requests (no filtering)
                break
            }
        } else {
            // Messages tab: show conversations with active messaging (responded status)
            requests = requests.filter { $0.status?.lowercased() == "responded" }

            // Apply message sub-filter
            switch selectedMessageFilter {
            case .unread:
                // Demo: Filter to only show conversations with unread messages (hash-based)
                requests = requests.filter { request in
                    let hash = abs(request.conversationId.hashValue)
                    return (hash % 3) == 0  // ~33% have unread messages
                }
            case .all:
                // Show all conversations with messaging enabled
                break
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            requests = requests.filter { request in
                (request.conversationTitle?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (request.childName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return requests
    }

    var hasPendingReviews: Bool {
        store.pendingCount > 0 || store.flaggedCount > 0
    }

    var hasUnreadMessages: Bool {
        store.messagesUnreadCount > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main tab buttons: Reviews and Messages
            HStack(spacing: 12) {
                MainTabButton(
                    title: "Reviews",
                    count: store.pendingCount,
                    isSelected: selectedTab == .reviews,
                    hasAlert: hasPendingReviews,
                    colorScheme: colorScheme
                ) {
                    selectedTab = .reviews
                }

                MainTabButton(
                    title: "Messages",
                    count: store.messagesUnreadCount,
                    isSelected: selectedTab == .messages,
                    hasAlert: hasUnreadMessages,
                    colorScheme: colorScheme
                ) {
                    selectedTab = .messages
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.adaptiveBackground(for: colorScheme))

            // Sub-filter buttons for Reviews (when Reviews tab is selected)
            if selectedTab == .reviews {
                HStack(spacing: 8) {
                    SubFilterButton(
                        title: "Pending",
                        count: store.pendingCount,
                        isSelected: selectedReviewFilter == .pending
                    ) {
                        selectedReviewFilter = .pending
                    }
                    .frame(maxWidth: .infinity)

                    SubFilterButton(
                        title: "Flagged",
                        count: store.flaggedCount,
                        isSelected: selectedReviewFilter == .flagged
                    ) {
                        selectedReviewFilter = .flagged
                    }
                    .frame(maxWidth: .infinity)

                    SubFilterButton(
                        title: "All",
                        count: store.reviewRequests.count,
                        isSelected: selectedReviewFilter == .all
                    ) {
                        selectedReviewFilter = .all
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)  // Align with main buttons
                .padding(.vertical, 6)
                .background(Color.adaptiveBackground(for: colorScheme))
            }

            // Sub-filter buttons for Messages (when Messages tab is selected)
            if selectedTab == .messages {
                HStack(spacing: 8) {
                    SubFilterButton(
                        title: "Unread",
                        count: store.messagesUnreadCount,
                        isSelected: selectedMessageFilter == .unread
                    ) {
                        selectedMessageFilter = .unread
                    }
                    .frame(maxWidth: .infinity)

                    SubFilterButton(
                        title: "All",
                        count: store.reviewRequests.filter { $0.status?.lowercased() == "responded" }.count,
                        isSelected: selectedMessageFilter == .all
                    ) {
                        selectedMessageFilter = .all
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)  // Align with main buttons
                .padding(.vertical, 6)
                .background(Color.adaptiveBackground(for: colorScheme))
            }

            Divider()
            
            // List of conversations
            if store.isLoading && store.reviewRequests.isEmpty {
                ProgressView("Loading reviews...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.adaptiveBackground(for: colorScheme))
            } else if filteredRequests.isEmpty {
                EmptyStateView(
                    title: searchText.isEmpty ? "No Reviews" : "No Results",
                    message: searchText.isEmpty ? "No review requests match your filters." : "Try adjusting your search."
                )
                .background(Color.adaptiveBackground(for: colorScheme))
            } else {
                List {
                    ForEach(filteredRequests, id: \.id) { request in
                        // CRITICAL FIX: Validate UUID format before navigation
                        // Creating a random UUID if parsing fails leads to opening wrong conversation
                        // This was a HIPAA violation risk - provider could see wrong patient's data
                        if let validUUID = UUID(uuidString: request.conversationId) {
                            NavigationLink(value: validUUID) {
                                ConversationRowView(request: request)
                            }
                            .listRowBackground(Color.adaptiveBackground(for: colorScheme))
                            .contextMenu {
                                Button(action: {
                                    selectedRequestForFollowUp = request
                                    showScheduleFollowUp = true
                                }) {
                                    Label("Schedule Follow-up", systemImage: "calendar.badge.plus")
                                }
                            }
                        } else {
                            // Data integrity issue - show error instead of silently opening wrong conversation
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text("Invalid Conversation")
                                        .font(.rethinkSansBold(16, relativeTo: .body))
                                    Text("Conversation ID format is invalid")
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
                    await store.refresh()
                }
            }
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScheduleFollowUp) {
            if let request = selectedRequestForFollowUp {
                ScheduleFollowUpView(request: request)
                    .environmentObject(store)
            }
        }
        .searchable(text: $searchText, prompt: "Search conversations...")
        .background(SearchBarCustomizer())
        .onAppear {
            // Ensure search bar appearance is set with multiple approaches
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Method 1: UISearchBar appearance
                UISearchBar.appearance().searchTextField.backgroundColor = .white
                UISearchBar.appearance().searchTextField.textColor = .black
                
                // Method 2: UITextField appearance in search bars
                UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = .white
                UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).textColor = .black
                
                // Method 3: Layer background
                if #available(iOS 13.0, *) {
                    UISearchBar.appearance().searchTextField.layer.backgroundColor = UIColor.white.cgColor
                    UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).layer.backgroundColor = UIColor.white.cgColor
                }
            }
        }
        .toolbarBackground(
            colorScheme == .dark ? Color(.systemBackground) : Color.paperBackground,
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Error", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") {
                store.errorMessage = nil
            }
            Button("Retry") {
                store.errorMessage = nil
                Task {
                    await store.refresh()
                }
            }
        } message: {
            if let error = store.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            if store.reviewRequests.isEmpty {
                Task {
                    await store.loadReviewRequests()
                }
            }

            // CRITICAL FIX: Properly manage NotificationCenter observer lifecycle
            // Bug: Observer was added in onAppear but never removed
            // Result: Multiple observers accumulated after each navigation cycle, causing
            // push notifications to fire multiple times and draining battery/memory
            // Fix: Store observer reference and remove it in onDisappear

            // Remove any existing observer first to prevent duplicates
            if let existingObserver = notificationObserver {
                NotificationCenter.default.removeObserver(existingObserver)
            }

            // Add observer and store reference for cleanup
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("OpenConversationFromPush"),
                object: nil,
                queue: .main
            ) { notification in
                if let conversationId = notification.userInfo?["conversationId"] as? UUID {
                    store.selectedConversationId = conversationId
                }
            }
        }
        .onDisappear {
            // Remove observer when view disappears to prevent memory leak
            if let observer = notificationObserver {
                NotificationCenter.default.removeObserver(observer)
                notificationObserver = nil
            }
        }
    }
}

// Main tab button: Reviews or Messages
struct MainTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let hasAlert: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.rethinkSansBold(17, relativeTo: .headline))

                Text("(\(count))")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(isSelected ? .white : Color.adaptiveLabel(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.primaryCoral : Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        hasAlert && !isSelected ? Color.primaryCoral : Color.clear,
                        lineWidth: 2
                    )
                    .padding(1)  // Small space between outline and fill
            )
        }
    }
}

// Sub-filter button for Reviews: Pending, Flagged, All
struct SubFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(isSelected ? .rethinkSansBold(13, relativeTo: .subheadline) : .rethinkSans(13, relativeTo: .subheadline))
                Text("(\(count))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(isSelected ? .white : Color.adaptiveLabel(for: colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primaryCoral : Color.adaptiveSecondaryBackground(for: colorScheme))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.clear : Color.adaptiveSecondaryLabel(for: colorScheme).opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
    }
}

struct StatusFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(isSelected ? .rethinkSansBold(13, relativeTo: .subheadline) : .rethinkSans(13, relativeTo: .subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(count)")
                    .font(.system(size: 12, design: .monospaced))
            }
            .foregroundColor(isSelected ? .white : Color.adaptiveLabel(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primaryCoral : Color.adaptiveSecondaryBackground(for: colorScheme))
            .cornerRadius(8)
        }
    }
}

struct ConversationRowView: View {
    let request: ProviderReviewRequestDetail
    @EnvironmentObject var store: ProviderConversationStore
    @State private var isCancelling: Bool = false

    // Demo: Generate deterministic unread count based on conversation ID
    var demoUnreadCount: Int {
        // Use hash of conversation ID to determine unread count (0-5)
        // This makes some conversations have unread messages in a consistent way
        let hash = abs(request.conversationId.hashValue)
        let hasUnread = (hash % 3) == 0  // ~33% of conversations have unread
        if hasUnread {
            return (hash % 5) + 1  // 1-5 unread messages
        }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.conversationTitle ?? (request.childName ?? "Conversation"))
                    .font(.rethinkSansBold(17, relativeTo: .headline))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 6) {
                    // Order: Flag → Follow-up → Messages → Status

                    // 1. Show flag badge if flagged (separate from status)
                    if request.isFlagged == true {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.flaggedTeal)
                            .cornerRadius(6)
                    }

                    // 2. Show clock badge if follow-up scheduled - tappable to cancel
                    if request.scheduleFollowup == true {
                        Button(action: {
                            guard let conversationId = UUID(uuidString: request.conversationId) else { return }
                            isCancelling = true
                            Task {
                                do {
                                    try await store.cancelFollowUp(conversationId: conversationId)
                                } catch {
                                    // Error handling - could show alert
                                    print("Failed to cancel follow-up: \(error)")
                                }
                                isCancelling = false
                            }
                        }) {
                            if isCancelling {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 12, height: 12)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            } else {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // 3. Show message badge with unread count (demo - needs backend)
                    // For demo: Show messaging is available if provider has responded
                    // This allows us to distinguish which conversations have active messaging
                    // TODO: Backend should provide actual message counts and messaging status
                    let hasMessagingEnabled = request.status?.lowercased() == "responded"
                    let unreadCount = demoUnreadCount  // Demo: use hash-based count

                    if hasMessagingEnabled {
                        HStack(spacing: 2) {
                            Image(systemName: unreadCount > 0 ? "message.fill" : "message")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            if unreadCount > 0 {
                                Text("\(unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(unreadCount > 0 ? Color.orange : Color.gray.opacity(0.6))
                        .cornerRadius(6)
                    }

                    // 4. Show status badge - uniform width/height
                    StatusBadge(status: request.status ?? "pending")
                }
            }
            
            if let childName = request.childName {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                    Text(childName)
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                    
                    if let age = request.childAge {
                        Text("• \(age)")
                            .font(.rethinkSans(15, relativeTo: .subheadline))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Show user ID if child name is not available
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                    Text("User: \(request.userId)")
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                }
            }
            
            // Show conversation preview if title is missing
            if request.conversationTitle == nil || request.conversationTitle?.isEmpty == true {
                if let firstMessage = request.conversationMessages?.first {
                    Text(firstMessage.content.prefix(50) + (firstMessage.content.count > 50 ? "..." : ""))
                        .font(.rethinkSans(12, relativeTo: .caption))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            if let triageOutcome = request.triageOutcome {
                TriageBadge(outcome: triageOutcome)
            }
            
            if let createdAt = request.createdAt {
                Text(formatDate(createdAt))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
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

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "pending":
            return .primaryCoral
        case "escalated":
            return .red
        case "responded":
            return .flaggedTeal
        case "dismissed":
            return .gray
        default:
            return .gray
        }
    }

    var displayText: String {
        switch status {
        case "pending":
            return "P"
        case "escalated":
            return "E"
        case "responded":
            return "R"
        case "dismissed":
            return "D"
        default:
            return "?"
        }
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 12, weight: .bold, design: .default))
            .foregroundColor(.white)
            .frame(width: 22, height: 22)  // Fixed size for uniform appearance
            .background(color)
            .cornerRadius(6)
    }
}

struct TriageBadge: View {
    let outcome: String
    
    var color: Color {
        switch outcome {
        case "er_911", "er_drive":
            return .red
        case "urgent_visit":
            return .orange
        case "routine_visit":
            return .primaryCoral
        case "home_care":
            return .green
        default:
            return .gray
        }
    }
    
    var displayText: String {
        switch outcome {
        case "er_911":
            return "ER - Call 911"
        case "er_drive":
            return "ER - Drive"
        case "urgent_visit":
            return "Urgent Visit"
        case "routine_visit":
            return "Routine Visit"
        case "home_care":
            return "Home Care"
        default:
            return outcome
        }
    }
    
    var body: some View {
        Text(displayText)
            .font(.rethinkSans(12, relativeTo: .caption))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(6)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.rethinkSansBold(22, relativeTo: .title2))
                .foregroundColor(Color.adaptiveLabel(for: colorScheme))
            Text(message)
                .font(.rethinkSans(15, relativeTo: .subheadline))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.adaptiveBackground(for: colorScheme))
    }
}

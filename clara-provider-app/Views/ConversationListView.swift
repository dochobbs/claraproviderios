import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @State private var selectedStatus: String? = "pending"
    @State private var searchText: String = ""
    @Environment(\.colorScheme) var colorScheme
    @State private var notificationObserver: NSObjectProtocol?
    @State private var showScheduleFollowUp: Bool = false
    @State private var selectedRequestForFollowUp: ProviderReviewRequestDetail?
    
    var filteredRequests: [ProviderReviewRequestDetail] {
        var requests = store.reviewRequests

        // Filter by status or flagged/follow-up state
        if let status = selectedStatus {
            if status == "flagged" {
                // Special case: filter by is_flagged boolean, not status
                requests = requests.filter { $0.isFlagged == true }
            } else if status == "follow-ups" {
                // Special case: filter by schedule_followup boolean, not status
                requests = requests.filter { $0.scheduleFollowup == true }
            } else {
                // Filter by status for other values
                requests = requests.filter { $0.status == status }
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Status filter bar
            HStack(spacing: 8) {
                StatusFilterButton(
                    title: "Pending",
                    count: store.pendingCount,
                    isSelected: selectedStatus == "pending"
                ) {
                    selectedStatus = "pending"
                }
                .frame(maxWidth: .infinity)

                StatusFilterButton(
                    title: "All",
                    count: store.reviewRequests.count,
                    isSelected: selectedStatus == nil
                ) {
                    selectedStatus = nil
                }
                .frame(maxWidth: .infinity)

                StatusFilterButton(
                    title: "Follow-ups",
                    count: store.followUpCount,
                    isSelected: selectedStatus == "follow-ups"
                ) {
                    selectedStatus = "follow-ups"
                }
                .frame(maxWidth: .infinity)

                StatusFilterButton(
                    title: "Flagged",
                    count: store.flaggedCount,
                    isSelected: selectedStatus == "flagged"
                ) {
                    selectedStatus = "flagged"
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.adaptiveBackground(for: colorScheme))
            
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
        .navigationTitle("Provider Reviews")
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
                    .font(.rethinkSans(12, relativeTo: .caption))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.conversationTitle ?? (request.childName ?? "Conversation"))
                    .font(.rethinkSansBold(17, relativeTo: .headline))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 6) {
                    // Show message badge with unread count (demo - needs backend)
                    // TODO: Replace with actual message count from backend
                    let hasMessages = true  // Demo: assume all conversations have messages
                    let unreadCount = 0     // Demo: will be populated by backend

                    if hasMessages {
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
                        .background(unreadCount > 0 ? Color.flaggedTeal : Color.gray.opacity(0.6))
                        .cornerRadius(6)
                    }

                    // Show clock badge if follow-up scheduled - tappable to cancel
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

                    // Show flag badge if flagged (separate from status)
                    if request.isFlagged == true {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(6)
                    }

                    // Show status badge
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
            return .orange
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

    var body: some View {
        Text(status.capitalized)
            .font(.rethinkSansBold(12, relativeTo: .caption))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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

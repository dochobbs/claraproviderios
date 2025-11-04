# Clara Provider iOS - Implementation Examples

Complete code examples for implementing the Priority 1 features from the roadmap.

---

## Feature 1: Display Conversation Summaries in List View

### Step 1: Update ConversationListView.swift

Replace the current list item view with this enhanced version:

```swift
// In ConversationListView.swift, in the List { ForEach } block

List {
    ForEach(filteredRequests) { request in
        NavigationLink(destination: ConversationDetailView(request: request)) {
            VStack(alignment: .leading, spacing: 12) {
                // Title and status row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.conversationTitle ?? "Untitled")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)

                        // Patient info with triage badge
                        HStack(spacing: 8) {
                            if let childName = request.childName {
                                Text("\(childName), \(request.childAge ?? "unknown")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Triage outcome badge
                            if let outcome = request.triageOutcome {
                                TriageBadgeSmall(outcome: outcome)
                            }
                        }
                    }

                    Spacer()

                    // Status badge
                    StatusBadge(status: request.status ?? "pending")
                }

                // Conversation summary (NEW)
                if let summary = request.conversationSummary {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .padding(.vertical, 8)

                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .truncationMode(.tail)
                    }
                }

                // Footer: timestamp and message count
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .font(.caption)
                        Text("\(request.conversationMessages?.count ?? 0) messages")
                            .font(.caption)
                    }
                    .foregroundColor(.tertiary)

                    Spacer()

                    if let createdAt = request.createdAt {
                        Text(formatTimeAgo(createdAt))
                            .font(.caption)
                            .foregroundColor(.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// Helper function to format timestamps
private func formatTimeAgo(_ dateString: String) -> String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: dateString) else { return "Unknown" }

    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

    if let days = components.day, days > 0 {
        return "\(days)d ago"
    } else if let hours = components.hour, hours > 0 {
        return "\(hours)h ago"
    } else if let minutes = components.minute, minutes > 0 {
        return "\(minutes)m ago"
    } else {
        return "Just now"
    }
}
```

### Step 2: Add Helper Badge Component

Create a new file: `Views/TriageBadgeSmall.swift`

```swift
import SwiftUI

struct TriageBadgeSmall: View {
    let outcome: String

    var badgeColor: Color {
        switch outcome {
        case "er_911":
            return .red
        case "er_drive":
            return .orange
        case "urgent_visit":
            return .yellow
        case "routine_visit", "routine_same_day":
            return .blue
        case "home_care":
            return .green
        default:
            return .gray
        }
    }

    var badgeLabel: String {
        switch outcome {
        case "er_911":
            return "🚨 911"
        case "er_drive":
            return "🚗 ER Drive"
        case "urgent_visit":
            return "⚡ Urgent"
        case "routine_visit", "routine_same_day":
            return "📅 Routine"
        case "home_care":
            return "🏠 Home Care"
        default:
            return outcome
        }
    }

    var body: some View {
        Text(badgeLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor)
            .cornerRadius(4)
    }
}

#Preview {
    VStack(spacing: 8) {
        TriageBadgeSmall(outcome: "home_care")
        TriageBadgeSmall(outcome: "urgent_visit")
        TriageBadgeSmall(outcome: "er_911")
    }
}
```

---

## Feature 2: Provider Dashboard with Stats

### Create New File: Views/ProviderDashboardView.swift

```swift
import SwiftUI
import Combine

struct ProviderDashboardView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @State private var stats: ProviderDashboardStats?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)

                        Text("Unable to Load Stats")
                            .font(.headline)

                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: loadStats) {
                            Text("Try Again")
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(32)
                } else if let stats = stats {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Summary Cards
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Pending",
                                    value: "\(stats.pendingReviews)",
                                    icon: "hourglass.end",
                                    color: .orange
                                )

                                StatCard(
                                    title: "Reviewed Today",
                                    value: "\(stats.respondedToday)",
                                    icon: "checkmark.circle",
                                    color: .green
                                )
                            }

                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Escalated",
                                    value: "\(stats.escalatedConversations)",
                                    icon: "arrow.up.circle",
                                    color: .red
                                )

                                StatCard(
                                    title: "Avg Response",
                                    value: stats.averageResponseTimeFormatted,
                                    icon: "timer",
                                    color: .blue
                                )
                            }

                            // Case Distribution
                            CaseDistributionSection(reviews: store.reviewRequests)

                            // Triage Agreement
                            TriageAgreementSection(reviews: store.reviewRequests)

                            // Quick Stats
                            QuickStatsSection(reviews: store.reviewRequests)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadStatsAsync()
            }
        }
        .onAppear {
            loadStats()
        }
    }

    private func loadStats() {
        isLoading = true
        errorMessage = nil

        Task {
            await loadStatsAsync()
        }
    }

    private func loadStatsAsync() async {
        do {
            let dashStats = try await store.service.fetchDashboardStats()
            await MainActor.run {
                self.stats = dashStats
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(value)
                        .font(.system(.title2, design: .default))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .opacity(0.3)
            }

            Divider()
                .opacity(0.2)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Case Distribution Section
struct CaseDistributionSection: View {
    let reviews: [ProviderReviewRequestDetail]

    var caseTypes: [(String, Int, Color)] {
        var types: [String: Int] = [:]
        for review in reviews {
            let outcome = review.triageOutcome ?? "unknown"
            types[outcome, default: 0] += 1
        }

        return types.map { outcome, count in
            let color: Color = {
                switch outcome {
                case "home_care": return .green
                case "routine_visit", "routine_same_day": return .blue
                case "urgent_visit": return .yellow
                case "er_drive": return .orange
                case "er_911": return .red
                default: return .gray
                }
            }()

            return (outcome, count, color)
        }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Case Distribution")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ForEach(caseTypes, id: \.0) { outcome, count, color in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(outcome)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Color(.systemGray5)

                                    Color(color)
                                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(reviews.count))
                                }
                            }
                            .frame(height: 8)
                            .cornerRadius(4)
                        }

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("\(Int(Double(count) / Double(reviews.count) * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Triage Agreement Section
struct TriageAgreementSection: View {
    let reviews: [ProviderReviewRequestDetail]

    var agreementRate: Int {
        let responded = reviews.filter { $0.status == "responded" }
        guard !responded.isEmpty else { return 0 }

        let agreed = responded.filter {
            // Provider agreed if they responded (didn't escalate)
            $0.status != "escalated"
        }

        return Int(Double(agreed.count) / Double(responded.count) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Metrics")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Triage Agreement Rate")
                            .font(.subheadline)

                        Text("\(agreementRate)%")
                            .font(.title3)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 8)

                        Circle()
                            .trim(from: 0, to: CGFloat(agreementRate) / 100)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))

                        Text("\(agreementRate)%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .frame(width: 80, height: 80)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Stats Section
struct QuickStatsSection: View {
    let reviews: [ProviderReviewRequestDetail]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Facts")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                StatRow(
                    label: "Total Reviews",
                    value: "\(reviews.count)",
                    icon: "list.number"
                )

                StatRow(
                    label: "Unique Patients",
                    value: "\(Set(reviews.compactMap { $0.userId }).count)",
                    icon: "person.2"
                )

                StatRow(
                    label: "Escalations",
                    value: "\(reviews.filter { $0.status == "escalated" }.count)",
                    icon: "arrow.up"
                )

                StatRow(
                    label: "Dismissed",
                    value: "\(reviews.filter { $0.status == "dismissed" }.count)",
                    icon: "xmark.circle"
                )
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    ProviderDashboardView()
        .environmentObject(ProviderConversationStore())
}
```

### Step 3: Add Dashboard Tab to ContentView

Update `ContentView.swift` to include the new dashboard:

```swift
// In ContentView, replace or update the TabView section

TabView(selection: $selectedTab) {
    // Existing Conversation List Tab
    ConversationListView()
        .tabItem {
            Label("Reviews", systemImage: "list.bullet")
        }
        .tag(0)

    // NEW: Dashboard Tab
    ProviderDashboardView()
        .tabItem {
            Label("Dashboard", systemImage: "chart.bar")
        }
        .tag(1)

    // Existing Patient Side Menu or other tabs
    // ...
}
```

---

## Feature 3: Show Related Patient Cases

### Update: ConversationDetailView.swift

Add this section to show related cases:

```swift
import SwiftUI

struct ConversationDetailView: View {
    let request: ProviderReviewRequestDetail

    @EnvironmentObject var store: ProviderConversationStore
    @State private var relatedCases: [ConversationSummary] = []
    @State private var isLoadingRelated = false

    // ... existing properties ...

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Existing scroll view content
                ScrollView {
                    VStack(spacing: 16) {
                        // Patient Info Card (existing)
                        PatientInfoCard(request: request)

                        // NEW: Related Cases Section
                        RelatedCasesSection(
                            cases: relatedCases,
                            isLoading: isLoadingRelated,
                            currentConversationId: request.conversationId
                        )

                        // Messages (existing)
                        ConversationMessagesView(
                            messages: conversationMessages,
                            triageOutcome: request.triageOutcome
                        )

                        // Provider reply box (existing)
                        ProviderReplyBox(
                            conversationId: request.conversationId ?? "",
                            request: request
                        )
                    }
                    .padding(16)
                }

                Spacer()
            }
        }
        .onAppear {
            loadRelatedCases()
        }
    }

    private func loadRelatedCases() {
        guard let userId = request.userId else { return }

        isLoadingRelated = true

        Task {
            do {
                let cases = try await store.service.fetchConversations(for: userId)
                await MainActor.run {
                    // Filter out current case and sort by date
                    self.relatedCases = cases
                        .filter { $0.id.uuidString != request.conversationId }
                        .sorted {
                            let date1 = ISO8601DateFormatter().date(from: $0.createdAt ?? "") ?? Date()
                            let date2 = ISO8601DateFormatter().date(from: $1.createdAt ?? "") ?? Date()
                            return date1 > date2
                        }
                        .prefix(5) // Show last 5 cases
                        .map { $0 }

                    isLoadingRelated = false
                }
            } catch {
                await MainActor.run {
                    isLoadingRelated = false
                    print("Error loading related cases: \(error)")
                }
            }
        }
    }
}

// MARK: - Related Cases Section
struct RelatedCasesSection: View {
    let cases: [ConversationSummary]
    let isLoading: Bool
    let currentConversationId: String?

    var body: some View {
        if !cases.isEmpty || isLoading {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Patient History")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(cases.count) previous cases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        ForEach(cases) { caseItem in
                            RelatedCaseRow(caseItem: caseItem)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .border(Color(.systemGray4), width: 1)
        }
    }
}

struct RelatedCaseRow: View {
    let caseItem: ConversationSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caseItem.title ?? "Untitled")
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 12) {
                if let createdAt = caseItem.createdAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(formatDate(createdAt))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                if let updatedAt = caseItem.updatedAt {
                    Text(formatTimeAgo(updatedAt))
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "Unknown" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return dateFormatter.string(from: date)
    }

    private func formatTimeAgo(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "Unknown" }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour], from: date, to: now)

        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else {
            return "Today"
        }
    }
}
```

---

## Summary: What to Implement First

**Week 1 Implementation Priority**:

1. **Summary Display** (30 min)
   - Update `ConversationListView` with summary text
   - Add `TriageBadgeSmall` component
   - Test with real data

2. **Dashboard View** (2-3 hours)
   - Create `ProviderDashboardView.swift`
   - Add tab to `ContentView`
   - Test stats display

3. **Related Cases** (1 hour)
   - Update `ConversationDetailView`
   - Add `RelatedCasesSection` component
   - Test with patient having multiple cases

**Estimated Total Time**: 3.5-4 hours of development

**Impact**: Transforms app from basic review list to clinical decision support tool

---

**Code Examples Version**: 1.0
**Last Updated**: November 2, 2025

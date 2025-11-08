import SwiftUI

struct ProviderDashboardView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    @State private var stats: ProviderDashboardStats? = nil
    @State private var isLoadingStats = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats cards
                if isLoadingStats {
                    ProgressView("Loading statistics...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let stats = stats {
                    StatsGrid(stats: stats)
                }
                
                // Quick actions
                QuickActionsSection(store: store)
                
                // Recent activity
                RecentActivitySection(store: store)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle("Dashboard")
        .refreshable {
            await refreshDashboard()
        }
        .onAppear {
            loadDashboard()
        }
    }
    
    private func loadDashboard() {
        Task {
            await refreshDashboard()
        }
    }
    
    private func refreshDashboard() async {
        isLoadingStats = true
        
        // Refresh review requests first
        await store.loadReviewRequests()
        
        // Then fetch stats
        do {
            let dashboardStats = try await ProviderSupabaseService.shared.fetchDashboardStats()
            await MainActor.run {
                stats = dashboardStats
                isLoadingStats = false
            }
        } catch {
            await MainActor.run {
                isLoadingStats = false
                print("Error loading dashboard stats: \(error)")
            }
        }
    }
}

struct StatsGrid: View {
    let stats: ProviderDashboardStats
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Pending",
                value: "\(stats.pendingReviews)",
                color: .orange,
                icon: "hourglass"
            )
            
            StatCard(
                title: "Responded Today",
                value: "\(stats.respondedToday)",
                color: .primaryCoral,
                icon: "checkmark.message"
            )
            
            StatCard(
                title: "Escalated",
                value: "\(stats.escalatedConversations)",
                color: .red,
                icon: "exclamationmark.triangle"
            )
            
            StatCard(
                title: "Avg Response Time",
                value: stats.averageResponseTimeFormatted,
                color: .primaryCoral,
                icon: "clock"
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.rethinkSansBold(28, relativeTo: .title))
            
            Text(title)
                .font(.rethinkSans(12, relativeTo: .caption))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct QuickActionsSection: View {
    @ObservedObject var store: ProviderConversationStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.rethinkSansBold(17, relativeTo: .headline))
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Pending Reviews",
                    icon: "hourglass",
                    color: .orange,
                    count: store.pendingCount
                ) {
                    // Navigate to pending reviews
                }
                
                QuickActionButton(
                    title: "Escalated",
                    icon: "exclamationmark.triangle",
                    color: .red,
                    count: store.escalatedCount
                ) {
                    // Navigate to escalated reviews
                }
                
                QuickActionButton(
                    title: "Flagged",
                    icon: "flag",
                    color: .flaggedTeal,
                    count: store.flaggedCount
                ) {
                    // Navigate to flagged reviews
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text("\(count)")
                    .font(.rethinkSansBold(20, relativeTo: .title3))
                
                Text(title)
                    .font(.rethinkSans(12, relativeTo: .caption))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.adaptiveSecondaryBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }
}

struct RecentActivitySection: View {
    @ObservedObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    
    var recentReviews: [ProviderReviewRequestDetail] {
        Array(store.reviewRequests.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.rethinkSansBold(17, relativeTo: .headline))
            
            if recentReviews.isEmpty {
                Text("No recent activity")
                    .font(.rethinkSans(15, relativeTo: .subheadline))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(recentReviews, id: \.id) { request in
                    // Validate UUID before navigation - never fallback to random UUID (HIPAA compliance)
                    // If UUID parsing fails, skip this conversation rather than open wrong patient's data
                    if let conversationUUID = UUID(uuidString: request.conversationId) {
                        NavigationLink(
                            destination: ConversationDetailView(conversationId: conversationUUID)
                                .environmentObject(store)
                        ) {
                            RecentActivityRow(request: request)
                        }
                    } else {
                        // Log error and show disabled state instead of creating random UUID
                        RecentActivityRow(request: request)
                            .opacity(0.5)
                            .disabled(true)
                            .help("Invalid conversation ID")
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.adaptiveSecondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}

struct RecentActivityRow: View {
    let request: ProviderReviewRequestDetail
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                    Text(request.conversationTitle ?? "Untitled Conversation")
                    .font(.rethinkSansBold(15, relativeTo: .subheadline))
                    .lineLimit(1)
                
                if let childName = request.childName {
                    Text(childName)
                        .font(.rethinkSans(12, relativeTo: .caption))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                    if let createdAt = request.createdAt {
                        Text(formatDate(createdAt))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                
                StatusBadge(status: request.status ?? "pending")
            }
        }
        .padding(.vertical, 8)
    }
    
    var statusColor: Color {
        switch request.status {
        case "pending":
            return .orange
        case "escalated":
            return .red
        case "flagged":
            return .flaggedTeal
        case "responded":
            return .green
        default:
            return .gray
        }
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

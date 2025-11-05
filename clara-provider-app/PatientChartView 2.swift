import SwiftUI

struct PatientChartView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    let userId: String
    let name: String
    @State private var conversations: [ConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""

    var filteredConversations: [ConversationSummary] {
        guard !searchText.isEmpty else { return conversations }
        return conversations.filter { summary in
            (summary.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            summary.id.uuidString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if isLoading && conversations.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading conversations…")
                            .font(.rethinkSans(15, relativeTo: .subheadline))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else if filteredConversations.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No Conversations" : "No Results")
                            .font(.rethinkSansBold(17, relativeTo: .headline))
                        Text(searchText.isEmpty ? "This patient has no conversations." : "Try a different search.")
                            .font(.rethinkSans(15, relativeTo: .subheadline))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(filteredConversations) { convo in
                    NavigationLink(value: convo.id) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.primaryCoral)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(convo.title?.isEmpty == false ? (convo.title ?? "Conversation") : "Conversation")
                                    .font(.rethinkSansBold(17, relativeTo: .headline))
                                    .lineLimit(1)
                                if let updated = convo.updatedAt ?? convo.createdAt {
                                    Text(relative(updated))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                        .listRowBackground(Color.adaptiveBackground(for: colorScheme))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle(name)
        .searchable(text: $searchText, prompt: "Search conversations…")
        .onAppear { Task { await loadConversations() } }
        .refreshable { await loadConversations() }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
            Button("Retry") { Task { await loadConversations() } }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }

    private func loadConversations() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let result = try await ProviderSupabaseService.shared.fetchConversations(for: userId)
            await MainActor.run {
                conversations = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func relative(_ iso8601: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso8601) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            return rel.localizedString(for: date, relativeTo: Date())
        }
        return iso8601
    }
}

#Preview {
    NavigationStack {
        PatientChartView(userId: "demo_user", name: "Alex Johnson")
            .environmentObject(ProviderConversationStore())
    }
}

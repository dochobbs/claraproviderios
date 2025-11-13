import SwiftUI
import os.log

struct AllMessagesView: View {
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    @State private var conversations: [MessageConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""

    var filteredConversations: [MessageConversationSummary] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.conversationId.localizedCaseInsensitiveContains(searchText) ||
                (conversation.latestMessagePreview?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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
                                MessageConversationRow(conversation: conversation)
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
                isLoading = false
                os_log("[AllMessagesView] Loaded %d conversations", log: .default, type: .info, results.count)
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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

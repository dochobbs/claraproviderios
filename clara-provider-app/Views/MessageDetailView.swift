import SwiftUI
import os.log

struct MessageDetailView: View {
    let conversationId: UUID
    @EnvironmentObject var store: ProviderConversationStore
    @Environment(\.colorScheme) var colorScheme
    @State private var messages: [MessageDetail] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var shareItem: ShareItem? = nil
    @State private var showingFlagModal = false
    @State private var flagReason = ""
    @State private var isFlagging = false
    @State private var isFlagged = false
    @State private var showingNotesModal = false
    @State private var providerNotes = ""
    @State private var providerTags: [String] = []
    @State private var newTagText = ""
    @State private var notesRefreshTrigger = false  // Toggle this to force view refresh
    @State private var notesChangedObserver: NSObjectProtocol?

    // Load notes and tags from cache only (no API fetch)
    private var savedProviderNotes: String? {
        // Access notesRefreshTrigger to make this computed property reactive to state changes
        _ = notesRefreshTrigger
        // Use cache-only check to avoid triggering API calls on every render
        return store.getProviderNotesFromCache(conversationId: conversationId.uuidString)
    }

    private var savedProviderTags: [String] {
        _ = notesRefreshTrigger
        // Use cache-only check to avoid triggering API calls on every render
        return store.getProviderTagsFromCache(conversationId: conversationId.uuidString)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.adaptiveBackground(for: colorScheme))
            } else if messages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Messages")
                        .font(.rethinkSansBold(22, relativeTo: .title2))
                    Text("No messages found in this conversation.")
                        .font(.rethinkSans(15, relativeTo: .subheadline))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveBackground(for: colorScheme))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Display provider notes/tags inline (tappable to edit)
                        if (savedProviderNotes != nil && !savedProviderNotes!.isEmpty) || (!savedProviderTags.isEmpty) {
                            Button(action: {
                                Task {
                                    await loadNotesForModal()
                                }
                                showingNotesModal = true
                                HapticFeedback.light()
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "note.text")
                                            .foregroundColor(.primaryCoral)
                                            .font(.caption)

                                        Text("Provider Notes (Internal)")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.primaryCoral)
                                            .fontWeight(.semibold)

                                        Spacer()

                                        Text("Not shown to patient")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .italic()

                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.primaryCoral)
                                    }

                                    if let notes = savedProviderNotes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                    }

                                    // Display tags as chips
                                    if !savedProviderTags.isEmpty {
                                        FlowLayout(spacing: 6) {
                                            ForEach(savedProviderTags, id: \.self) { tag in
                                                Text(tag)
                                                    .font(.system(.caption, design: .rounded))
                                                    .fontWeight(.medium)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.primaryCoral.opacity(0.2))
                                                    .foregroundColor(.primaryCoral)
                                                    .cornerRadius(6)
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.primaryCoral.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primaryCoral.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical)
                }
                .scrollContentBackground(.hidden)
                .background(Color.adaptiveBackground(for: colorScheme))
            }
        }
        .background(Color.adaptiveBackground(for: colorScheme))
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Share menu with options
                    Menu {
                        Button(action: { shareAllContent() }) {
                            Label("Full Output", systemImage: "doc.text.fill")
                        }
                        Button(action: { shareConversationOnly() }) {
                            Label("Conversation Only", systemImage: "bubble.left.and.bubble.right")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primaryCoral)
                    }
                    .accessibilityLabel("Share conversation")

                    // Provider notes button
                    Button(action: {
                        // Load notes asynchronously to ensure we have latest from database
                        Task {
                            await loadNotesForModal()
                        }
                        showingNotesModal = true
                    }) {
                        let hasNotes = savedProviderNotes != nil && !savedProviderNotes!.isEmpty
                        Image(systemName: "note.text")
                            .foregroundColor(hasNotes ? .primaryCoral : .gray)
                    }
                    .accessibilityLabel("Provider notes")

                    Button(action: {
                        if isFlagged {
                            // Unflag
                            Task {
                                await unflagConversation()
                            }
                        } else {
                            // Flag
                            showingFlagModal = true
                        }
                    }) {
                        Image(systemName: isFlagged ? "flag.fill" : "flag")
                            .foregroundColor(.flaggedTeal)
                    }
                    .accessibilityLabel(isFlagged ? "Unflag conversation" : "Flag conversation")
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.content])
        }
        .sheet(isPresented: $showingFlagModal) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Flag Conversation")
                        .font(.rethinkSansBold(22, relativeTo: .title2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason (optional)")
                            .font(.rethinkSansBold(15, relativeTo: .subheadline))

                        TextEditor(text: $flagReason)
                            .font(.rethinkSans(15, relativeTo: .body))
                            .frame(minHeight: 80, maxHeight: 150)
                            .padding(8)
                            .border(Color.adaptiveSecondaryBackground(for: colorScheme))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)

                    Text("Character limit: \(flagReason.count)/500")
                        .font(.rethinkSans(12, relativeTo: .caption))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)

                    Spacer()

                    Button(action: flagConversation) {
                        if isFlagging {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Flag Conversation")
                                .font(.rethinkSansBold(17, relativeTo: .body))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Color.primaryCoral)
                    .cornerRadius(12)
                    .disabled(isFlagging || flagReason.count > 500)
                    .padding()
                }
                .background(Color.adaptiveBackground(for: colorScheme))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingFlagModal = false
                            flagReason = ""
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNotesModal) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Provider Notes")
                            .font(.rethinkSansBold(22, relativeTo: .title2))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()

                        Text("Internal notes (not shown to patient)")
                            .font(.rethinkSans(14, relativeTo: .caption))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, -15)

                        // Notes text editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.rethinkSansBold(15, relativeTo: .subheadline))
                            TextEditor(text: $providerNotes)
                                .font(.rethinkSans(15, relativeTo: .body))
                                .frame(minHeight: 120, maxHeight: 200)
                                .padding(8)
                                .border(Color.adaptiveSecondaryBackground(for: colorScheme))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)

                        // Tags section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tags")
                                .font(.rethinkSansBold(15, relativeTo: .subheadline))

                            // Display existing tags
                            if !providerTags.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(providerTags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text(tag)
                                                .font(.rethinkSans(14, relativeTo: .caption))
                                            Button(action: {
                                                providerTags.removeAll { $0 == tag }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.primaryCoral.opacity(0.2))
                                        .cornerRadius(16)
                                    }
                                }
                            }

                            // Add new tag
                            HStack(spacing: 8) {
                                TextField("Add tag...", text: $newTagText)
                                    .font(.rethinkSans(15, relativeTo: .body))
                                    .padding(8)
                                    .background(Color.adaptiveSecondaryBackground(for: colorScheme))
                                    .cornerRadius(8)
                                    .onSubmit {
                                        addTag()
                                    }

                                Button(action: addTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.primaryCoral)
                                }
                                .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 20)

                        Button(action: saveProviderNotes) {
                            Text("Save Notes & Tags")
                                .font(.rethinkSansBold(17, relativeTo: .body))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.primaryCoral)
                        .cornerRadius(12)
                        .padding()
                    }
                }
                .background(Color.adaptiveBackground(for: colorScheme))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingNotesModal = false
                            providerNotes = ""
                            providerTags = []
                            newTagText = ""
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            providerNotes = ""
                            providerTags = []
                            saveProviderNotes()
                        }) {
                            Text("Clear")
                                .foregroundColor(.red)
                        }
                        .disabled((savedProviderNotes == nil || savedProviderNotes!.isEmpty) && savedProviderTags.isEmpty)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadMessages()
                checkFlagStatus()
            }

            // Mark this conversation as read in conversations table (admin_viewed_at)
            Task {
                await markConversationAsRead()
            }

            // Fetch notes from database (triggers async load and cache update)
            _ = store.loadProviderNotes(conversationId: conversationId.uuidString)

            // Listen for provider notes changes to refresh UI
            if let existingObserver = notesChangedObserver {
                NotificationCenter.default.removeObserver(existingObserver)
            }

            notesChangedObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ProviderNotesChanged"),
                object: nil,
                queue: .main
            ) { notification in
                // Toggle trigger to force UI to re-render notes display
                notesRefreshTrigger.toggle()
                os_log("[MessageDetailView] Received notes changed notification - refreshing UI",
                       log: .default, type: .info)
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
                    await loadMessages()
                }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func loadMessages() async {
        await MainActor.run { isLoading = true }

        do {
            os_log("[MessageDetailView] Fetching messages for conversation_id: %{public}s", log: .default, type: .info, conversationId.uuidString)

            let fetchedMessages = try await ProviderSupabaseService.shared.fetchMessagesForConversation(conversationId: conversationId)

            await MainActor.run {
                messages = fetchedMessages
                isLoading = false
                os_log("[MessageDetailView] Loaded %d messages", log: .default, type: .info, fetchedMessages.count)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load messages: \(error.localizedDescription)"
                isLoading = false
                os_log("[MessageDetailView] Error loading messages: %{public}s", log: .default, type: .error, String(describing: error))
            }
        }
    }

    private func shareAllContent() {
        var content = ""

        // Section 1: Summary
        content += "═══════════════════════════════\n"
        content += "CONVERSATION EXPORT\n"
        content += "═══════════════════════════════\n\n"
        content += "Conversation ID: \(conversationId.uuidString)\n"
        content += "Total Messages: \(messages.count)\n"
        if let firstMessage = messages.first {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            content += "Started: \(formatter.string(from: firstMessage.timestamp))\n"
        }
        content += "\n"

        // Section 2: Provider Notes (if any) - use cache-only to avoid triggering fetches
        if let notes = store.getProviderNotesFromCache(conversationId: conversationId.uuidString), !notes.isEmpty {
            content += "═══════════════════════════════\n"
            content += "PROVIDER NOTES (INTERNAL)\n"
            content += "═══════════════════════════════\n\n"
            content += notes
            content += "\n\n"
        }

        // Section 3: Full Conversation
        content += "═══════════════════════════════\n"
        content += "FULL CONVERSATION\n"
        content += "═══════════════════════════════\n\n"

        if messages.isEmpty {
            content += "(No messages in conversation)\n\n"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short

            for message in messages {
                let sender = message.isFromUser ? "User" : "AI"
                let timestamp = formatter.string(from: message.timestamp)
                content += "[\(timestamp)] \(sender): \(message.content)\n\n"
            }
        }

        // Create share item
        shareItem = ShareItem(content: content)
    }

    private func shareConversationOnly() {
        var content = ""

        // Conversation only - no metadata
        content += "═══════════════════════════════\n"
        content += "CONVERSATION\n"
        content += "═══════════════════════════════\n\n"

        if messages.isEmpty {
            content += "(No messages in conversation)\n\n"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short

            for message in messages {
                let sender = message.isFromUser ? "User" : "AI"
                let timestamp = formatter.string(from: message.timestamp)
                content += "[\(timestamp)] \(sender): \(message.content)\n\n"
            }
        }

        // Create share item
        shareItem = ShareItem(content: content)
    }

    private func markConversationAsRead() async {
        do {
            // Write admin_viewed_at to conversations table
            let urlString = "\(ProviderSupabaseService.shared.projectURL)/rest/v1/conversations?id=eq.\(conversationId.uuidString.lowercased())"
            guard let url = URL(string: urlString) else { return }

            var request = ProviderSupabaseService.shared.createPatchRequest(url: url)

            let formatter = ISO8601DateFormatter()
            let payload: [String: Any] = [
                "admin_viewed_at": formatter.string(from: Date())
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, _) = try await URLSession.shared.data(for: request)

            os_log("[MessageDetailView] Marked conversation as read (admin_viewed_at) in conversations table",
                   log: .default, type: .info)
        } catch {
            os_log("[MessageDetailView] Error marking conversation as read: %{public}s",
                   log: .default, type: .error, String(describing: error))
        }
    }

    private func checkFlagStatus() {
        // For Threads view, check flag status from conversations table
        // NOT from provider_review_requests (that's for Reviews view only)
        Task {
            do {
                let urlString = "\(ProviderSupabaseService.shared.projectURL)/rest/v1/conversations?id=eq.\(conversationId.uuidString.lowercased())&select=is_flagged,flag_reason"
                guard let url = URL(string: urlString) else { return }

                let request = ProviderSupabaseService.shared.createRequest(url: url, method: "GET")
                let (data, _) = try await URLSession.shared.data(for: request)

                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let conversation = jsonArray.first {
                    await MainActor.run {
                        isFlagged = conversation["is_flagged"] as? Bool ?? false
                        if let reason = conversation["flag_reason"] as? String, !reason.isEmpty {
                            flagReason = reason
                        }
                        os_log("[MessageDetailView] Loaded flag status from conversations table: isFlagged=%{public}@",
                               log: .default, type: .info, isFlagged ? "true" : "false")
                    }
                }
            } catch {
                os_log("[MessageDetailView] Error loading flag status: %{public}s",
                       log: .default, type: .error, String(describing: error))
            }
        }
    }

    private func flagConversation() {
        guard !isFlagging else { return }
        isFlagging = true

        Task {
            do {
                // For Threads, write flag to conversations table (NOT provider_review_requests)
                let urlString = "\(ProviderSupabaseService.shared.projectURL)/rest/v1/conversations?id=eq.\(conversationId.uuidString.lowercased())"
                guard let url = URL(string: urlString) else {
                    throw NSError(domain: "MessageDetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }

                var request = ProviderSupabaseService.shared.createPatchRequest(url: url)

                let formatter = ISO8601DateFormatter()
                var payload: [String: Any] = [
                    "is_flagged": true,
                    "flagged_at": formatter.string(from: Date()),
                    "flagged_by": "Dr. Hobbs"  // TODO: Get from authenticated user
                ]

                if !flagReason.isEmpty {
                    payload["flag_reason"] = flagReason
                }

                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (_, _) = try await URLSession.shared.data(for: request)

                await MainActor.run {
                    isFlagged = true
                    isFlagging = false
                    showingFlagModal = false
                    os_log("[MessageDetailView] Successfully flagged conversation in conversations table", log: .default, type: .info)
                }
            } catch {
                await MainActor.run {
                    isFlagging = false
                    errorMessage = "Failed to flag conversation: \(error.localizedDescription)"
                    os_log("[MessageDetailView] Error flagging conversation: %{public}s", log: .default, type: .error, String(describing: error))
                }
            }
        }
    }

    private func unflagConversation() async {
        do {
            // For Threads, write flag to conversations table (NOT provider_review_requests)
            let urlString = "\(ProviderSupabaseService.shared.projectURL)/rest/v1/conversations?id=eq.\(conversationId.uuidString.lowercased())"
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "MessageDetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }

            var request = ProviderSupabaseService.shared.createPatchRequest(url: url)

            let formatter = ISO8601DateFormatter()
            let payload: [String: Any] = [
                "is_flagged": false,
                "unflagged_at": formatter.string(from: Date()),
                "flag_reason": NSNull()
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, _) = try await URLSession.shared.data(for: request)

            await MainActor.run {
                isFlagged = false
                flagReason = ""
                os_log("[MessageDetailView] Successfully unflagged conversation in conversations table", log: .default, type: .info)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to unflag conversation: \(error.localizedDescription)"
                os_log("[MessageDetailView] Error unflagging conversation: %{public}s", log: .default, type: .error, String(describing: error))
            }
        }
    }

    private func loadNotesForModal() async {
        // Fetch notes and tags from database asynchronously
        do {
            if let feedback = try await ProviderSupabaseService.shared.fetchConversationFeedback(conversationId: conversationId.uuidString.lowercased()) {
                await MainActor.run {
                    providerNotes = feedback.feedback ?? ""
                    providerTags = feedback.tags ?? []
                    os_log("[MessageDetailView] Loaded notes and tags from database: notes=%d chars, tags=%d",
                           log: .default, type: .info, providerNotes.count, providerTags.count)
                }
            } else {
                // No existing feedback
                await MainActor.run {
                    providerNotes = ""
                    providerTags = []
                    os_log("[MessageDetailView] No existing notes/tags found",
                           log: .default, type: .info)
                }
            }
        } catch {
            os_log("[MessageDetailView] Error loading notes/tags: %{public}s",
                   log: .default, type: .error, String(describing: error))
            // Keep existing values or empty
            await MainActor.run {
                providerNotes = savedProviderNotes ?? ""
                providerTags = savedProviderTags
            }
        }
    }

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Avoid duplicates
        guard !providerTags.contains(trimmed) else {
            newTagText = ""
            return
        }

        providerTags.append(trimmed)
        newTagText = ""
    }

    private func saveProviderNotes() {
        let notesToSave = providerNotes.isEmpty ? nil : providerNotes
        let tagsToSave = providerTags.isEmpty ? nil : providerTags
        store.saveProviderNotes(conversationId: conversationId.uuidString, notes: notesToSave, tags: tagsToSave)
        showingNotesModal = false
        notesRefreshTrigger.toggle()  // Force view to refresh and update note icon color
        HapticFeedback.success()
        os_log("[MessageDetailView] Provider notes and tags saved successfully", log: .default, type: .info)
    }
}

struct MessageBubble: View {
    let message: MessageDetail
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
            if message.isFromUser {
                // User message - beige bubble on the right
                HStack(alignment: .top, spacing: 8) {
                    Text(message.content)
                        .font(.rethinkSans(17, relativeTo: .body))
                        .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                        .textSelection(.enabled)

                    // User initial circle
                    ZStack {
                        Circle()
                            .fill(Color.adaptiveTertiaryBackground(for: colorScheme))
                            .frame(width: 28, height: 28)
                        Text("U")
                            .font(.rethinkSansBold(12, relativeTo: .caption2))
                            .foregroundColor(Color.adaptiveSecondaryLabel(for: colorScheme))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.userBubbleBackground)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // AI/System message - plain text on left
                Text(message.content)
                    .font(.rethinkSans(17, relativeTo: .body))
                    .foregroundColor(Color.adaptiveLabel(for: colorScheme))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(formatTime(message.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: message.isFromUser ? .trailing : .leading)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout for Tags (wrapping horizontal layout)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

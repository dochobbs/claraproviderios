import Foundation
import Combine
import os.log

// MARK: - Provider Conversation Store
// Manages state for provider review requests and conversations
class ProviderConversationStore: ObservableObject {
    @Published var reviewRequests: [ProviderReviewRequestDetail] = []
    @Published var selectedConversationId: UUID? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Cache for full conversation details
    private var conversationDetailsCache: [UUID: ProviderReviewRequestDetail] = [:]
    
    // Auto-refresh timer
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 60 // 60 seconds

    // CRITICAL FIX: Track active refresh task to prevent accumulation
    // Bug: Auto-refresh timer created new Tasks without cancelling previous ones
    // Result: Multiple fetch operations running simultaneously, draining battery and network resources
    // Solution: Store task reference and cancel before starting new refresh
    private var activeRefreshTask: Task<Void, Never>?

    // PERFORMANCE FIX: Debounce auto-refresh to prevent excessive view updates
    // Bug: 60-second timer publishes to @Published property, triggering cascading re-renders
    // Solution: Track last successful refresh time and skip updates if data hasn't actually changed
    private var lastRefreshTime: Date = Date.distantPast
    private let refreshDebounceInterval: TimeInterval = 30 // Only refresh if 30s have passed AND data changed

    private let supabaseService = ProviderSupabaseService.shared
    
    init() {
        startAutoRefresh()
        
        // Update badge count when review requests change
        $reviewRequests
            .map { $0.filter { $0.status == "pending" }.count }
            .removeDuplicates()
            .sink { count in
                ProviderPushNotificationManager.shared.updateBadgeCount(pendingCount: count)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()

    deinit {
        stopAutoRefresh()
    }

    // MARK: - UUID Validation Logging

    /// Safely parse UUID string with validation logging for data integrity monitoring
    /// Logs failures to help detect corrupted data in database
    private func parseUUID(_ uuidString: String, context: String) -> UUID? {
        guard let uuid = UUID(uuidString: uuidString) else {
            os_log("[UUID Validation] Failed to parse UUID: %{public}s in context: %{public}s",
                   log: .default, type: .error, uuidString, context)
            return nil
        }
        return uuid
    }

    // MARK: - Error Filtering

    /// Check if an error is a cancellation error that should not be shown to users
    /// Cancellation errors are benign and occur during normal app lifecycle (backgrounding, view dismissal, etc.)
    private func isCancellationError(_ error: Error) -> Bool {
        // Check for URLError cancellation
        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }

        // Check for NSError cancellation (code -999)
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        // Check for Task cancellation
        if error is CancellationError {
            return true
        }

        return false
    }
    
    // MARK: - Load Review Requests

    /// Load all review requests from Supabase
    /// - Parameter bypassDebounce: If true, ignore the 30-second debounce. Used for forced refresh on unlock.
    func loadReviewRequests(bypassDebounce: Bool = false) async {
        // PERFORMANCE FIX: Skip if we just refreshed recently (debounce auto-refresh)
        // Exception: bypassDebounce=true allows forced refreshes (e.g., on app unlock)
        let now = Date()
        let timeSinceLastRefresh = now.timeIntervalSince(lastRefreshTime)

        // Only proceed with refresh if enough time has passed since last successful refresh
        // This prevents excessive view updates from the 60-second timer
        // BUT: If bypassDebounce is true, skip this check (used for forced unlock refresh)
        if !bypassDebounce && timeSinceLastRefresh < refreshDebounceInterval {
            os_log("[ProviderConversationStore] Skipping refresh - last refresh was %.1f seconds ago (debounce: %.0f seconds)",
                   log: .default, type: .debug, timeSinceLastRefresh, refreshDebounceInterval)
            return
        }

        if bypassDebounce {
            os_log("[ProviderConversationStore] Forcing refresh (bypassDebounce=true) - ignoring debounce interval",
                   log: .default, type: .info)
        }

        await MainActor.run {
            isLoading = true
            // FIX: Don't auto-clear errorMessage on auto-refresh
            // Only clear if user explicitly taps retry (not on background refresh)
            // This prevents error notifications from disappearing unexpectedly
        }

        do {
            let requests = try await supabaseService.fetchProviderReviewRequests()

            await MainActor.run {
                os_log("[ProviderConversationStore] Loaded %d review requests", log: .default, type: .info, requests.count)

                // Debug: Log sample data to see what we're getting
                if let first = requests.first {
                    os_log("[ProviderConversationStore] Sample request - ID: %{public}s, Conversation: %{public}s, Title: %{public}s",
                           log: .default, type: .debug, first.id, first.conversationId, first.conversationTitle ?? "nil")
                    os_log("[ProviderConversationStore] Patient - Name: %{public}s, Age: %{public}s, Messages: %d",
                           log: .default, type: .debug, first.childName ?? "nil", first.childAge ?? "nil", first.conversationMessages?.count ?? 0)
                }

                // Only publish if data actually changed (prevents unnecessary view updates)
                if requests != reviewRequests {
                    reviewRequests = requests
                    lastRefreshTime = Date()
                    os_log("[ProviderConversationStore] Data changed, updating reviewRequests and lastRefreshTime",
                           log: .default, type: .debug)
                } else {
                    os_log("[ProviderConversationStore] Data unchanged, skipping publish to prevent view updates",
                           log: .default, type: .debug)
                }

                isLoading = false
            }
        } catch {
            await MainActor.run {
                let errorDesc = error.localizedDescription

                // Filter out cancellation errors - they're benign and shouldn't be shown to users
                if !isCancellationError(error) {
                    errorMessage = errorDesc
                    os_log("[ProviderConversationStore] Error loading review requests: %{public}s",
                           log: .default, type: .error, errorDesc)
                    if let supabaseError = error as? SupabaseError {
                        os_log("[ProviderConversationStore] Supabase error: %{public}s",
                               log: .default, type: .error, supabaseError.localizedDescription)
                    }
                } else {
                    os_log("[ProviderConversationStore] Request cancelled (benign) - not showing to user",
                           log: .default, type: .debug)
                }

                isLoading = false
            }
        }
    }
    
    /// Load review requests filtered by status
    func loadReviewRequests(status: String) async {
        await MainActor.run {
            isLoading = true
            // Don't clear error on filtered load - this may be background operation
            // User can dismiss error explicitly via alert
        }
        
        do {
            let requests: [ProviderReviewRequestDetail]
            
            switch status {
            case "pending":
                requests = try await supabaseService.fetchPendingReviews()
            case "escalated":
                requests = try await supabaseService.fetchEscalatedReviews()
            case "flagged":
                requests = try await supabaseService.fetchFlaggedReviews()
            default:
                requests = try await supabaseService.fetchProviderReviewRequests(status: status)
            }
            
            await MainActor.run {
                reviewRequests = requests
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // Filter out cancellation errors
                if !isCancellationError(error) {
                    errorMessage = error.localizedDescription
                    os_log("[ProviderConversationStore] Error loading filtered review requests: %{public}s",
                           log: .default, type: .error, error.localizedDescription)
                } else {
                    os_log("[ProviderConversationStore] Filtered request cancelled (benign)",
                           log: .default, type: .debug)
                }
                isLoading = false
            }
        }
    }
    
    // MARK: - Reviews
    func fetchReviewForConversation(id: UUID) async -> ProviderReviewRequestDetail? {
        do {
            return try await supabaseService.fetchReviewForConversation(conversationId: id)
        } catch {
            os_log("[ProviderConversationStore] Error fetching review for conversation %{public}s: %{public}s",
                   log: .default, type: .error, id.uuidString, error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Load Conversation Details
    
    /// Load full conversation details for a specific conversation
    func loadConversationDetails(id: UUID, forceFresh: Bool = false) async {
        // CRITICAL FIX: Don't clear cache if conversation is already cached
        // This prevents losing flagged status when navigating back into a conversation
        // Only clear cache if conversation is not in memory (first load)
        // Exception: forceFresh=true forces a server fetch even if cached (for post-submission refresh)

        // Clear cache if we need fresh data
        if forceFresh {
            conversationDetailsCache.removeValue(forKey: id)
        }

        let shouldLoadFromServer = conversationDetailsCache[id] == nil && !reviewRequests.contains { req in
            if let storedId = parseUUID(req.conversationId, context: "loadConversationDetails") {
                return storedId == id
            }
            return req.conversationId.lowercased() == id.uuidString.lowercased()
        }

        await MainActor.run {
            isLoading = !shouldLoadFromServer // Only set loading if we're actually fetching
        }

        // If already cached and not forcing fresh, use it; otherwise fetch from server
        if conversationDetailsCache[id] != nil && !forceFresh {
            await MainActor.run {
                isLoading = false
            }
            return
        }

        do {
            if let details = try await supabaseService.fetchConversationDetails(conversationId: id) {
                await MainActor.run {
                    conversationDetailsCache[id] = details

                    // Update in reviewRequests if present
                    if let index = reviewRequests.firstIndex(where: {
                        if let storedId = parseUUID($0.conversationId, context: "updateReviewRequestsAfterDetailsFetch") {
                            return storedId == id
                        }
                        return $0.conversationId.lowercased() == id.uuidString.lowercased()
                    }) {
                        reviewRequests[index] = details
                    }

                    isLoading = false
                }
            } else {
                await MainActor.run {
                    // Only show error if we don't have it cached or in list
                    if getConversationDetails(for: id) == nil {
                        errorMessage = "Conversation not found"
                    }
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                // Only show error if we don't have it cached or in list, and it's not a cancellation
                if getConversationDetails(for: id) == nil && !isCancellationError(error) {
                    errorMessage = error.localizedDescription
                } else if isCancellationError(error) {
                    os_log("[ProviderConversationStore] Conversation details request cancelled (benign)",
                           log: .default, type: .debug)
                }
                isLoading = false
            }
            if !isCancellationError(error) {
                os_log("[ProviderConversationStore] Error loading conversation details for %{public}s: %{public}s",
                       log: .default, type: .error, id.uuidString, error.localizedDescription)
            }
        }
    }
    
    /// Get conversation details (from cache or reviewRequests)
    func getConversationDetails(for conversationId: UUID) -> ProviderReviewRequestDetail? {
        // First check cache
        if let cached = conversationDetailsCache[conversationId] {
            return cached
        }
        
        // Then check reviewRequests list with flexible matching
        if let found = reviewRequests.first(where: {
            if let storedId = parseUUID($0.conversationId, context: "getConversationDetails") {
                return storedId == conversationId
            }
            // Fallback: compare as strings (case-insensitive)
            return $0.conversationId.lowercased() == conversationId.uuidString.lowercased()
        }) {
            return found
        }
        
        return nil
    }
    
    // MARK: - Send Message
    
    /// Send a message from provider to patient
    func sendMessage(
        conversationId: UUID,
        content: String,
        urgency: String = "routine"
    ) async throws {
        // CRITICAL FIX: Input validation for messages
        // Prevent empty, whitespace-only, or excessively long messages
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate message is not empty
        guard !trimmedContent.isEmpty else {
            throw NSError(domain: "ProviderConversationStore", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Message cannot be empty"])
        }

        // Validate message length (prevent DoS and database issues)
        guard trimmedContent.count <= 5000 else {
            throw NSError(domain: "ProviderConversationStore", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Message is too long (max 5000 characters)"])
        }

        // Validate urgency is one of allowed values
        let validUrgencies = ["routine", "urgent", "escalated"]
        guard validUrgencies.contains(urgency.lowercased()) else {
            throw NSError(domain: "ProviderConversationStore", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid urgency level"])
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil  // Clear errors for user-initiated send action
        }

        do {
            _ = try await supabaseService.sendProviderMessage(
                conversationId: conversationId,
                message: trimmedContent,
                urgency: urgency.lowercased()
            )

            // Refresh conversation details after sending message
            await loadConversationDetails(id: conversationId)

            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // Filter out cancellation errors
                if !isCancellationError(error) {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            throw error
        }
    }

    // MARK: - Update Status
    
    /// Update the status of a review request (public method)
    func updateReviewStatus(id: String, status: String) async throws {
        try await updateStatus(id: id, status: status)
    }
    
    /// Update the status of a review request (internal method)
    private func updateStatus(id: String, status: String) async throws {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await supabaseService.updateReviewStatus(id: id, status: status)

            // Clear cache for this conversation to force refresh
            if let request = reviewRequests.first(where: { $0.id == id }),
               let conversationId = parseUUID(request.conversationId, context: "updateStatusClearCache") {
                conversationDetailsCache.removeValue(forKey: conversationId)
            }

            // Refresh review requests to get updated status
            await loadReviewRequests()

            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // Filter out cancellation errors
                if !isCancellationError(error) {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            throw error
        }
    }

    /// Flag a conversation for review
    func flagConversation(id: String) async throws {
        try await updateStatus(id: id, status: "flagged")
    }
    
    /// Escalate a conversation
    func escalateConversation(id: String) async throws {
        try await updateStatus(id: id, status: "escalated")
    }
    
    /// Mark a conversation as resolved
    func markAsResolved(id: String) async throws {
        try await updateStatus(id: id, status: "responded")
    }
    
    /// Add provider response to a review request
    func addProviderResponse(
        id: String,
        response: String,
        name: String?,
        urgency: String?
    ) async throws {
        // CRITICAL FIX: Input validation for provider response
        // Prevent empty responses and validate input lengths

        // Validate response is not empty
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResponse.isEmpty else {
            throw NSError(domain: "ProviderConversationStore", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Response cannot be empty"])
        }

        // Validate response length
        guard trimmedResponse.count <= 5000 else {
            throw NSError(domain: "ProviderConversationStore", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Response is too long (max 5000 characters)"])
        }

        // Validate provider name if provided
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let providerName = trimmedName, !providerName.isEmpty {
            guard providerName.count <= 255 else {
                throw NSError(domain: "ProviderConversationStore", code: -4,
                             userInfo: [NSLocalizedDescriptionKey: "Provider name is too long"])
            }
        }

        // Validate urgency if provided
        if let urg = urgency {
            let validUrgencies = ["routine", "urgent", "escalated"]
            guard validUrgencies.contains(urg.lowercased()) else {
                throw NSError(domain: "ProviderConversationStore", code: -3,
                             userInfo: [NSLocalizedDescriptionKey: "Invalid urgency level"])
            }
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            try await supabaseService.addProviderResponse(
                id: id,
                response: trimmedResponse,
                name: trimmedName,
                urgency: urgency?.lowercased()
            )
            
            // Clear cache for this conversation to force refresh
            if let request = reviewRequests.first(where: { $0.id == id }),
               let conversationId = parseUUID(request.conversationId, context: "addProviderResponseClearCache") {
                conversationDetailsCache.removeValue(forKey: conversationId)
            }

            // Refresh review requests
            await loadReviewRequests()

            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                // Filter out cancellation errors
                if !isCancellationError(error) {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            throw error
        }
    }

    // MARK: - Flag Conversation

    /// Flag a conversation for review with optional reason
    func flagConversation(id: UUID, reason: String? = nil) async throws {
        // FEATURE: Flag conversation for provider attention with optional reason
        // Store status and reason locally, then sync to backend

        let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Validate reason length if provided
        if !trimmedReason.isEmpty && trimmedReason.count > 500 {
            throw NSError(domain: "ProviderConversationStore", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Reason is too long (max 500 characters)"])
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // NEW: Use is_flagged column instead of status
            // No need to preserve original status - status field stays unchanged!
            let providerName = "Dr. Hobbs"  // TODO: Get from actual provider profile

            try await supabaseService.flagReview(
                id: id.uuidString,
                reason: trimmedReason.isEmpty ? nil : trimmedReason,
                flaggedBy: providerName
            )

            // Update local cache
            await MainActor.run {
                // Update in reviewRequests list
                if let index = reviewRequests.firstIndex(where: {
                    if let storedId = parseUUID($0.conversationId, context: "flagConversationUpdateList") {
                        return storedId == id
                    }
                    return $0.conversationId.lowercased() == id.uuidString.lowercased()
                }) {
                    reviewRequests[index].isFlagged = true
                    reviewRequests[index].flaggedAt = ISO8601DateFormatter().string(from: Date())
                    reviewRequests[index].flaggedBy = providerName
                    if !trimmedReason.isEmpty {
                        reviewRequests[index].flagReason = trimmedReason
                    }
                    // NOTE: status field stays unchanged!
                }

                // Update in cache
                if var cached = conversationDetailsCache[id] {
                    cached.isFlagged = true
                    cached.flaggedAt = ISO8601DateFormatter().string(from: Date())
                    cached.flaggedBy = providerName
                    if !trimmedReason.isEmpty {
                        cached.flagReason = trimmedReason
                    }
                    conversationDetailsCache[id] = cached
                }

                // NO MORE UserDefaults - not needed!
                os_log("[ProviderConversationStore] Flagged conversation %{public}s with is_flagged=true",
                       log: .default, type: .info, id.uuidString)

                isLoading = false
                os_log("[ProviderConversationStore] Conversation flagged: %{public}s, reason: %{public}s",
                       log: .default, type: .info, id.uuidString, trimmedReason.isEmpty ? "(none)" : trimmedReason)
            }
        } catch {
            await MainActor.run {
                // Filter out cancellation errors
                if !isCancellationError(error) {
                    errorMessage = "Failed to flag conversation: \(error.localizedDescription)"
                    os_log("[ProviderConversationStore] Error flagging conversation: %{public}s",
                           log: .default, type: .error, error.localizedDescription)
                } else {
                    os_log("[ProviderConversationStore] Flag request cancelled (benign)",
                           log: .default, type: .debug)
                }
                isLoading = false
            }
            throw error
        }
    }

    /// Unflag a conversation and remove its flag reason
    /// Note: Preserves any existing review status and provider response (review reason)
    func unflagConversation(id: UUID) async throws {
        // NEW: Use is_flagged column instead of status
        // No need to restore status - it was never changed!

        os_log("[ProviderConversationStore] Unflagging conversation %{public}s - setting is_flagged=false",
               log: .default, type: .info, id.uuidString)

        // Update via Supabase - sets is_flagged=false, adds unflagged_at
        try await supabaseService.unflagReview(id: id.uuidString)

        // Update local cache
        await MainActor.run {
            // Update in reviewRequests list
            if let index = reviewRequests.firstIndex(where: {
                if let storedId = UUID(uuidString: $0.conversationId) {
                    return storedId == id
                }
                return $0.conversationId.lowercased() == id.uuidString.lowercased()
            }) {
                reviewRequests[index].isFlagged = false
                reviewRequests[index].unflaggedAt = ISO8601DateFormatter().string(from: Date())
                reviewRequests[index].flagReason = nil  // Clear reason text from UI
                // NOTE: status field stays unchanged!
                // NOTE: Keep flagged_at, flagged_by in DB for audit trail
            }

            // Update in cache
            if var cached = conversationDetailsCache[id] {
                cached.isFlagged = false
                cached.unflaggedAt = ISO8601DateFormatter().string(from: Date())
                cached.flagReason = nil  // Clear reason text from UI
                conversationDetailsCache[id] = cached
            }

            // NO MORE UserDefaults - not needed!

            os_log("[ProviderConversationStore] Conversation unflagged: %{public}s, is_flagged=false",
                   log: .default, type: .info, id.uuidString)
        }
    }

    // MARK: - Provider Notes (Synced with Supabase)

    // Cache for conversation feedback to avoid repeated API calls
    private var feedbackCache: [String: ConversationFeedback] = [:]

    /// Save provider notes for a conversation to Supabase conversation_feedback table
    /// These notes are synced with the web dashboard and visible to the team
    func saveProviderNotes(conversationId: String, notes: String?, tags: [String]? = nil) {
        // Normalize to lowercase for consistent keys
        let normalizedId = conversationId.lowercased()

        Task {
            do {
                // TODO: Get actual provider ID from authenticated user
                // For now, using hardcoded provider name
                let providerId = "Dr. Hobbs"

                if let notes = notes, !notes.isEmpty {
                    // Upsert to database
                    let feedback = try await supabaseService.upsertConversationFeedback(
                        conversationId: normalizedId,
                        createdBy: providerId,
                        feedback: notes,
                        tags: tags
                    )

                    // Update cache
                    await MainActor.run {
                        feedbackCache[normalizedId] = feedback
                        os_log("[ProviderConversationStore] Saved provider notes to database for conversation %{public}s",
                               log: .default, type: .info, String(normalizedId.prefix(8)))
                    }
                } else {
                    // Delete from database if notes are empty
                    try await supabaseService.deleteConversationFeedback(conversationId: normalizedId)

                    // Remove from cache
                    await MainActor.run {
                        feedbackCache.removeValue(forKey: normalizedId)
                        os_log("[ProviderConversationStore] Deleted provider notes from database for conversation %{public}s",
                               log: .default, type: .info, String(normalizedId.prefix(8)))
                    }
                }

                // Notify views to refresh notes indicators
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ProviderNotesChanged"),
                        object: nil,
                        userInfo: ["conversationId": normalizedId]
                    )
                }
            } catch {
                os_log("[ProviderConversationStore] Error saving provider notes: %{public}s",
                       log: .default, type: .error, String(describing: error))

                await MainActor.run {
                    // Show error to user if it's not a cancellation
                    if !isCancellationError(error) {
                        errorMessage = "Failed to save notes: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    /// Load provider notes for a conversation from Supabase conversation_feedback table
    /// Returns the feedback text, or nil if no feedback exists
    func loadProviderNotes(conversationId: String) -> String? {
        // Normalize to lowercase for consistent keys
        let normalizedId = conversationId.lowercased()

        // Check cache first
        if let cached = feedbackCache[normalizedId] {
            return cached.feedback
        }

        // If not in cache, we need to fetch from database
        // This is synchronous, so we'll need to handle this differently
        // For now, return nil and trigger async load in background
        Task {
            await loadProviderNotesAsync(conversationId: normalizedId)
        }

        return nil
    }

    /// Load provider tags for a conversation from Supabase conversation_feedback table
    /// Returns array of tags, or empty array if no tags exist
    func loadProviderTags(conversationId: String) -> [String] {
        // Normalize to lowercase for consistent keys
        let normalizedId = conversationId.lowercased()

        // Check cache first
        if let cached = feedbackCache[normalizedId] {
            return cached.tags ?? []
        }

        // If not in cache, trigger async load in background
        Task {
            await loadProviderNotesAsync(conversationId: normalizedId)
        }

        return []
    }

    /// Check if provider notes exist in cache (cache-only, no fetch)
    /// Use this for UI display to avoid triggering API calls on every row render
    func hasProviderNotesInCache(conversationId: String) -> Bool {
        let normalizedId = conversationId.lowercased()
        if let cached = feedbackCache[normalizedId] {
            return cached.feedback != nil && !cached.feedback!.isEmpty
        }
        return false
    }

    /// Async version of loadProviderNotes - fetches from database and updates cache
    private func loadProviderNotesAsync(conversationId: String) async {
        let normalizedId = conversationId.lowercased()

        do {
            if let feedback = try await supabaseService.fetchConversationFeedback(conversationId: normalizedId) {
                await MainActor.run {
                    feedbackCache[normalizedId] = feedback
                    os_log("[ProviderConversationStore] Loaded notes from database for %{public}s: %d characters",
                           log: .default, type: .debug, String(normalizedId.prefix(8)), feedback.feedback?.count ?? 0)

                    // Notify views to refresh
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ProviderNotesChanged"),
                        object: nil,
                        userInfo: ["conversationId": normalizedId]
                    )
                }
            }
        } catch {
            os_log("[ProviderConversationStore] Error loading provider notes: %{public}s",
                   log: .default, type: .error, String(describing: error))
        }
    }

    /// Prefetch provider notes for multiple conversations to warm the cache
    /// Call this when loading conversation lists to ensure notes are available
    func prefetchProviderNotes(conversationIds: [String]) async {
        for conversationId in conversationIds {
            let normalizedId = conversationId.lowercased()

            // Skip if already in cache
            if feedbackCache[normalizedId] != nil {
                continue
            }

            do {
                if let feedback = try await supabaseService.fetchConversationFeedback(conversationId: normalizedId) {
                    await MainActor.run {
                        feedbackCache[normalizedId] = feedback
                    }
                }
            } catch {
                // Silently fail - notes are optional
                os_log("[ProviderConversationStore] Could not prefetch notes for %{public}s: %{public}s",
                       log: .default, type: .debug, String(normalizedId.prefix(8)), String(describing: error))
            }
        }

        os_log("[ProviderConversationStore] Prefetched notes for %d conversations, cache size: %d",
               log: .default, type: .info, conversationIds.count, feedbackCache.count)
    }

    /// Schedule a follow-up for a conversation
    func scheduleFollowUp(
        conversationId: UUID,
        userId: String,
        childName: String?,
        childAge: String?,
        scheduledFor: Date,
        urgency: String,
        message: String,
        followUpDays: Int?,
        followUpHours: Int?,
        followUpMinutes: Int?
    ) async throws {
        os_log("[ProviderConversationStore] Scheduling follow-up for conversation %{public}s",
               log: .default, type: .info, conversationId.uuidString)

        // Create follow-up request via Supabase
        let followUpId = try await supabaseService.scheduleFollowUp(
            conversationId: conversationId,
            userId: userId,
            childName: childName,
            childAge: childAge,
            scheduledFor: scheduledFor,
            urgency: urgency,
            message: message,
            followUpDays: followUpDays,
            followUpHours: followUpHours,
            followUpMinutes: followUpMinutes
        )

        // Update local cache to reflect schedule_followup = true
        await MainActor.run {
            // Update in reviewRequests list
            if let index = reviewRequests.firstIndex(where: {
                if let storedId = UUID(uuidString: $0.conversationId) {
                    return storedId == conversationId
                }
                return $0.conversationId.lowercased() == conversationId.uuidString.lowercased()
            }) {
                reviewRequests[index].scheduleFollowup = true
            }

            // Update in cache
            if var cached = conversationDetailsCache[conversationId] {
                cached.scheduleFollowup = true
                conversationDetailsCache[conversationId] = cached
            }

            os_log("[ProviderConversationStore] Follow-up scheduled: %{public}s",
                   log: .default, type: .info, followUpId)
        }
    }

    /// Cancel a scheduled follow-up for a conversation
    func cancelFollowUp(conversationId: UUID) async throws {
        os_log("[ProviderConversationStore] Cancelling follow-up for conversation %{public}s",
               log: .default, type: .info, conversationId.uuidString)

        // Cancel follow-up via Supabase
        try await supabaseService.cancelFollowUp(conversationId: conversationId)

        // Update local cache to reflect schedule_followup = false
        await MainActor.run {
            // Update in reviewRequests list
            if let index = reviewRequests.firstIndex(where: {
                if let storedId = UUID(uuidString: $0.conversationId) {
                    return storedId == conversationId
                }
                return $0.conversationId.lowercased() == conversationId.uuidString.lowercased()
            }) {
                reviewRequests[index].scheduleFollowup = false
            }

            // Update in cache
            if var cached = conversationDetailsCache[conversationId] {
                cached.scheduleFollowup = false
                conversationDetailsCache[conversationId] = cached
            }

            os_log("[ProviderConversationStore] Follow-up cancelled locally",
                   log: .default, type: .info)
        }
    }

    // MARK: - Refresh Conversation

    /// Refresh a specific conversation
    func refreshConversation(id: UUID) async {
        // Clear cache
        conversationDetailsCache.removeValue(forKey: id)

        // Reload
        await loadConversationDetails(id: id)
    }

    /// Force refresh review requests regardless of debounce timer
    /// Used when app unlocks or when we need fresh data immediately
    func forceRefreshReviewRequests() async {
        // FIX: Force refresh on unlock by bypassing the 30-second debounce
        // This is called when the app unlocks so the user sees fresh data immediately
        // We pass bypassDebounce=true to skip the debounce check in loadReviewRequests()
        os_log("[ProviderConversationStore] forceRefreshReviewRequests() - bypassing debounce for unlock", log: .default, type: .info)
        await loadReviewRequests(bypassDebounce: true)
    }
    
    // MARK: - Auto Refresh

    /// Start automatic refresh timer
    func startAutoRefresh() {
        stopAutoRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            // Cancel any existing refresh task before starting new one
            // This prevents task accumulation when refresh timer fires faster than
            // the previous refresh completes
            self?.activeRefreshTask?.cancel()

            // Create new refresh task and store reference for lifecycle management
            self?.activeRefreshTask = Task {
                await self?.loadReviewRequests()
            }
        }
    }

    /// Stop automatic refresh timer
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        // CRITICAL FIX: Cancel active refresh task to prevent orphaned tasks
        // Bug: Task continued running even after timer was stopped
        // Result: Background refresh tasks persisted after app backgrounded/closed
        // Solution: Explicitly cancel task when stopping auto-refresh
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
    }
    
    /// Manually refresh review requests (user-initiated pull-to-refresh)
    /// Bypass debounce since user explicitly requested the refresh
    func refresh() async {
        os_log("[ProviderConversationStore] User initiated pull-to-refresh", log: .default, type: .info)
        await loadReviewRequests(bypassDebounce: true)
    }
    
    // MARK: - Computed Properties
    
    /// Get pending reviews count
    var pendingCount: Int {
        reviewRequests.filter { $0.status == "pending" }.count
    }
    
    /// Get escalated reviews count
    var escalatedCount: Int {
        reviewRequests.filter { $0.status == "escalated" }.count
    }
    
    /// Get flagged reviews count
    var flaggedCount: Int {
        reviewRequests.filter { $0.isFlagged == true }.count
    }

    /// Get follow-up scheduled count
    var followUpCount: Int {
        reviewRequests.filter { $0.scheduleFollowup == true }.count
    }

    /// Get conversations with unread messages (demo)
    var messagesUnreadCount: Int {
        // TODO: Replace with actual unread message count from backend
        // Demo: Count conversations with responded status that have simulated unread messages
        reviewRequests.filter { request in
            guard request.status?.lowercased() == "responded" else { return false }
            // Use same hash logic as ConversationRowView to determine unread
            let hash = abs(request.conversationId.hashValue)
            return (hash % 3) == 0  // ~33% of responded conversations have unread
        }.count
    }

    /// Get reviews responded today
    var respondedTodayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return reviewRequests.filter { review in
            guard let respondedAt = review.respondedAt,
                  let respondedDate = ISO8601DateFormatter().date(from: respondedAt) else {
                return false
            }
            return Calendar.current.isDate(respondedDate, inSameDayAs: today)
        }.count
    }

    // MARK: - Message Read Status (for AllMessagesView)

    /// Get unread message conversations count (from UserDefaults)
    var unreadMessageConversationsCount: Int {
        if let data = UserDefaults.standard.data(forKey: "unreadMessageConversations"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return decoded.count
        }
        return 0
    }

    /// Mark a message conversation as read (updates both client-side and database)
    /// This directly updates UserDefaults AND posts a notification for real-time UI updates
    func markMessageConversationAsRead(conversationId: String) {
        // Normalize to lowercase to match database format
        let normalizedId = conversationId.lowercased()

        os_log("[ProviderConversationStore] markMessageConversationAsRead called for: %{public}s",
               log: .default, type: .info, String(normalizedId.prefix(8)))

        // Update UserDefaults directly (so it persists even if notification is missed)
        if let data = UserDefaults.standard.data(forKey: "unreadMessageConversations"),
           var unreadSet = try? JSONDecoder().decode(Set<String>.self, from: data) {
            let sizeBefore = unreadSet.count
            let wasPresent = unreadSet.contains(normalizedId)
            unreadSet.remove(normalizedId)
            let sizeAfter = unreadSet.count

            os_log("[ProviderConversationStore] Unread set before: %d, was present: %d, after: %d",
                   log: .default, type: .info, sizeBefore, wasPresent ? 1 : 0, sizeAfter)

            if let encoded = try? JSONEncoder().encode(unreadSet) {
                UserDefaults.standard.set(encoded, forKey: "unreadMessageConversations")
                os_log("[ProviderConversationStore] Updated UserDefaults with new unread set",
                       log: .default, type: .info)
            }
        } else {
            os_log("[ProviderConversationStore] WARNING: No unread set found in UserDefaults or decode failed",
                   log: .default, type: .error)
        }

        // Post notification for real-time UI updates (if AllMessagesView is visible)
        os_log("[ProviderConversationStore] Posting notification for UI update",
               log: .default, type: .info)
        NotificationCenter.default.post(
            name: NSNotification.Name("MarkMessageConversationAsRead"),
            object: nil,
            userInfo: ["conversationId": normalizedId]
        )

        // Update database in background (non-blocking)
        guard let uuid = UUID(uuidString: conversationId) else {
            os_log("[ProviderConversationStore] Invalid conversation ID format: %{public}s",
                   log: .default, type: .error, conversationId)
            return
        }

        Task {
            do {
                try await supabaseService.markMessagesAsRead(conversationId: uuid)
                os_log("[ProviderConversationStore] Successfully marked messages as read in database: %{public}s",
                       log: .default, type: .info, conversationId)
            } catch {
                os_log("[ProviderConversationStore] Failed to mark messages as read in database: %{public}s - %{public}s",
                       log: .default, type: .error, conversationId, String(describing: error))
                // Don't throw - client-side tracking already updated, database is best-effort
            }
        }
    }
}

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
                errorMessage = errorDesc
                isLoading = false
                os_log("[ProviderConversationStore] Error loading review requests: %{public}s",
                       log: .default, type: .error, errorDesc)
                if let supabaseError = error as? SupabaseError {
                    os_log("[ProviderConversationStore] Supabase error: %{public}s",
                           log: .default, type: .error, supabaseError.localizedDescription)
                }
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
                errorMessage = error.localizedDescription
                isLoading = false
                os_log("[ProviderConversationStore] Error loading filtered review requests: %{public}s",
                       log: .default, type: .error, error.localizedDescription)
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
    func loadConversationDetails(id: UUID) async {
        // Always fetch fresh data from server (don't use cache)
        // This ensures we get the latest status after updates
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            // Clear cache to force refresh
            conversationDetailsCache.removeValue(forKey: id)
        }
        
        do {
            if let details = try await supabaseService.fetchConversationDetails(conversationId: id) {
                await MainActor.run {
                    conversationDetailsCache[id] = details
                    
                    // Update in reviewRequests if present
                    if let index = reviewRequests.firstIndex(where: { 
                        if let storedId = UUID(uuidString: $0.conversationId) {
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
                // Only show error if we don't have it cached or in list
                if getConversationDetails(for: id) == nil {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            os_log("[ProviderConversationStore] Error loading conversation details for %{public}s: %{public}s",
                   log: .default, type: .error, id.uuidString, error.localizedDescription)
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
            if let storedId = UUID(uuidString: $0.conversationId) {
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
                errorMessage = error.localizedDescription
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
               let conversationId = UUID(uuidString: request.conversationId) {
                conversationDetailsCache.removeValue(forKey: conversationId)
            }
            
            // Refresh review requests to get updated status
            await loadReviewRequests()
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
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
               let conversationId = UUID(uuidString: request.conversationId) {
                conversationDetailsCache.removeValue(forKey: conversationId)
            }
            
            // Refresh review requests
            await loadReviewRequests()
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Flag Conversation

    /// Flag a conversation for review with optional reason
    func flagConversation(id: UUID, reason: String? = nil) async throws {
        // FEATURE: Flag conversation for provider attention
        // Store status change locally first, then sync to backend

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
            // Update conversation status to "flagged" via Supabase
            try await supabaseService.updateReviewStatus(id: id.uuidString, status: "flagged")

            // Update local cache
            await MainActor.run {
                // Update in reviewRequests list
                if let index = reviewRequests.firstIndex(where: {
                    if let storedId = UUID(uuidString: $0.conversationId) {
                        return storedId == id
                    }
                    return $0.conversationId.lowercased() == id.uuidString.lowercased()
                }) {
                    reviewRequests[index].status = "flagged"
                }

                // Update in cache
                if var cached = conversationDetailsCache[id] {
                    cached.status = "flagged"
                    conversationDetailsCache[id] = cached
                }

                isLoading = false
                os_log("[ProviderConversationStore] Conversation flagged: %{public}s",
                       log: .default, type: .info, id.uuidString)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to flag conversation: \(error.localizedDescription)"
                isLoading = false
                os_log("[ProviderConversationStore] Error flagging conversation: %{public}s",
                       log: .default, type: .error, error.localizedDescription)
            }
            throw error
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
        reviewRequests.filter { $0.status == "flagged" }.count
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
}

# Clara Provider iOS - Architecture Documentation

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Data Flow](#data-flow)
3. [Module Breakdown](#module-breakdown)
4. [API Integration](#api-integration)
5. [State Management](#state-management)
6. [View Hierarchy](#view-hierarchy)

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SwiftUI Views Layer                          │
├─────────────────────────────────────────────────────────────────┤
│  ConversationListView │ ConversationDetailView │ PatientProfile  │
└─────────────────┬─────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│            State Management (Combine & MVVM)                     │
├─────────────────────────────────────────────────────────────────┤
│          ProviderConversationStore (@StateObject)                │
│  - reviewRequests: [ProviderReviewRequestDetail]                 │
│  - conversationDetailsCache: [UUID: Detail]                      │
│  - Auto-refresh via Timer (60s)                                  │
└─────────────────┬─────────────────────────────────────────────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
    ┌─────────────┐  ┌────────────────────────┐
    │  Services   │  │  Notifications Manager │
    ├─────────────┤  ├────────────────────────┤
    │ Supabase    │  │ Push Notifications     │
    │ REST API    │  │ Badge Updates          │
    │ HTTP Client │  │ Local Notifications    │
    └────────────┬┘  └────────┬───────────────┘
                 │             │
                 └─────┬───────┘
                       ▼
        ┌──────────────────────────────┐
        │   Supabase PostgreSQL API    │
        │  - provider_review_requests  │
        │  - follow_up_messages        │
        │  - patients                  │
        │  - conversations             │
        └──────────────────────────────┘
```

### Architectural Patterns

**MVVM (Model-View-ViewModel)**
- **Models**: Data structures (ProviderReviewRequestDetail, Message, ChildProfile)
- **Views**: SwiftUI components that observe state changes
- **ViewModel**: ProviderConversationStore manages state and business logic

**Reactive Programming**
- Uses Combine framework for reactive state updates
- @Published properties trigger view updates automatically
- Eliminates need for delegates or manual refresh logic

**Dependency Injection**
- Global state injected via @EnvironmentObject
- Services passed through view initializers
- Enables testing and code reusability

## Data Flow

### 1. App Initialization Flow

```
AppDelegate
├─> Application lifecycle setup
├─> NotificationCenter delegate configuration
├─> Request push notification permissions
├─> Register for remote notifications
└─> Register device token to UserDefaults

Clara_ProviderApp
├─> Create @StateObject ProviderConversationStore
├─> Inject into environment via @EnvironmentObject
├─> Customize UI (search bar appearance)
└─> Show ContentView

ContentView
├─> Initialize navigation stack
├─> Show ConversationListView (primary)
├─> Set up side menu
└─> onAppear: Load initial review requests
```

### 2. Loading Review Requests

```
User Opens App
└─> ContentView.onAppear()
    └─> Store.loadReviewRequests()
        └─> ProviderSupabaseService.fetchProviderReviewRequests()
            ├─> Build URL: /provider_review_requests?select=*
            ├─> Add auth headers (API key + Bearer token)
            ├─> URLSession.data() with retry logic (3 attempts)
            ├─> JSONDecoder parses response
            └─> Parse to [ProviderReviewRequestDetail]
        └─> @Published reviewRequests updated
        └─> SwiftUI automatically re-renders ConversationListView

ConversationListView
└─> Observes @EnvironmentObject store
    └─> Auto-updates when reviewRequests changes
    └─> Applies current filters (status, search)
    └─> Displays updated list immediately
```

### 3. Viewing Conversation Details

```
User Taps Conversation Row
└─> ConversationListView taps conversationId
    └─> Navigate to ConversationDetailView(conversationId)

ConversationDetailView.onAppear()
└─> Store.loadConversationDetails(conversationId)

Store.loadConversationDetails()
├─> Check conversationDetailsCache first
│   └─> Return cached data if available (fast path)
└─> If not cached:
    ├─> ProviderSupabaseService.fetchConversationDetails(conversationId)
    │   └─> Fetch from provider_review_requests by conversationId
    │       └─> With retry for UUID format variations
    │
    ├─> ProviderSupabaseService.fetchFollowUpMessages(conversationId)
    │   └─> Fetch from follow_up_messages where conversationId = ?
    │
    └─> Merge conversation.conversationMessages + followUpMessages
        ├─> Sort by timestamp
        ├─> Map to Message UI model
        ├─> Cache in conversationDetailsCache
        └─> Update @Published property

ConversationDetailView
└─> Receives merged message array
    └─> Render each Message as MessageBubbleView
    └─> Display sender (Patient, Clara, Provider) with colors
    └─> Show triage outcome badge
```

### 4. Submitting a Provider Review

```
User Fills Review Form in ConversationDetailView
├─> Selects ProviderResponseType (Agree, Disagree, etc.)
├─> Types optional response text
└─> Taps Submit

ProviderReplyBox.submitReview()
├─> Determine new status based on type
├─> Create payload:
│   ├─ id: reviewRequestId
│   ├─ response: responseText
│   ├─ providerName: "Current Provider" (TODO: implement user system)
│   ├─ urgency: urgencyLevel
│   └─ status: newStatus
│
├─> If has response text:
│   ├─> Store.addProviderResponse(...) [PATCH operation]
│   └─> Service.createPatientNotificationMessage()
│       └─> Send follow-up message to patient
│
└─> Else if only status change:
    └─> Store.updateReviewStatus(id, status) [PATCH operation]

Service Operation (PATCH to provider_review_requests)
├─> Build request body with new status/response
├─> Send PATCH with retry logic
├─> Update Supabase record
└─> Return success/error

Store Updates
└─> Auto-refresh view via Store.loadReviewRequests()
    └─> Reload all reviews to reflect status changes
    └─> Update badge count
    └─> UI updates automatically
```

### 5. Push Notification Flow

```
Supabase sends Remote Notification (APNs)
└─> Device receives notification
    └─> App is running:
        └─> didReceive(_ request:withContentHandler:)
    └─> App is backgrounded:
        └─> OS handles notification delivery
        └─> Badge count updates

ProviderPushNotificationManager.handleNotification()
├─> Extract conversationId from payload
├─> Post "OpenConversationFromPush" notification
├─> Increment badge count
│   ├─> If iOS 17+: setBadgeCount() (new API)
│   └─> Else: applicationIconBadgeNumber
│
└─> ConversationListView observes notification
    └─> Updates selectedConversationId
    └─> Triggers navigation to ConversationDetailView
    └─> User sees the specific conversation

Auto-Badge Update
├─> Store.pendingCount changes
├─> @Published triggers update
├─> ProviderPushNotificationManager.updateBadgeCount()
└─> App badge reflects pending review count
```

### 6. Auto-Refresh Cycle

```
Store.startAutoRefresh() (called from ContentView.onAppear)
└─> Timer fires every 60 seconds
    └─> Store.refresh()
        └─> Store.loadReviewRequests()
            └─> Fetch latest data from Supabase
            └─> Update @Published if changed
            └─> Automatically triggers view update

This ensures:
- New requests appear without manual refresh
- Status changes sync across views
- Badge count stays current
- User sees real-time updates
```

## Module Breakdown

### Models (`/Models`)

#### ProviderReviewRequestDetail
Core data model representing a provider review request:

```swift
struct ProviderReviewRequestDetail: Codable {
    let id: String                              // UUID
    let userId: String?                         // Patient ID
    let conversationId: String?                 // Conversation UUID
    let conversationTitle: String?              // Request title
    let childName: String?                      // Patient name
    let childAge: String?                       // Age (formatted)
    let childDOB: String?                       // Date of birth
    let triageOutcome: String?                  // Triage classification
    let conversationMessages: [ConversationMessage]?  // Initial messages
    let conversationSummary: String?            // AI-generated summary
    let status: String?                         // pending/responded/flagged/escalated
    let providerName: String?                   // Responding provider
    let providerResponse: String?               // Clinical feedback
    let providerUrgency: String?                // Urgency classification
    let respondedAt: String?                    // ISO8601 timestamp
    let createdAt: String?                      // ISO8601 timestamp
}
```

**Triage Outcomes:**
- `er_911`: Emergency room, call 911
- `er_drive`: Emergency room, drive now
- `urgent_visit`: Urgent clinic visit needed
- `routine_visit`: Schedule routine visit
- `home_care`: Can be managed at home

**Review Statuses:**
- `pending`: Awaiting provider review
- `responded`: Provider has reviewed and responded
- `flagged`: Marked for special attention
- `escalated`: Requires higher-level review

#### ConversationMessage
Individual message from the initial triage conversation:

```swift
struct ConversationMessage: Codable {
    let content: String                 // Message text
    let isFromUser: Bool                // Patient (true) vs AI Clara (false)
    let timestamp: String               // ISO8601
    let imageURL: String?               // Optional attached image
}
```

#### FollowUpMessage
Messages sent after initial triage:

```swift
struct FollowUpMessage: Codable {
    let id: String
    let conversationId: String
    let userId: String
    let messageContent: String
    let isFromUser: Bool                // Patient vs Provider
    let timestamp: String               // ISO8601
    let isRead: Bool
    let followUpId: String?
    let createdAt: String               // ISO8601
}
```

#### Message
SwiftUI-friendly message for UI display:

```swift
struct Message: Identifiable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let triageOutcome: String?
    let followUpDays: Int?
    let followUpHours: Int?
    let followUpMinutes: Int?
    let imageURL: String?
    let providerName: String?           // nil=patient, "Clara"=AI, else=provider
    let isRead: Bool
}
```

#### ChildProfile
Complete patient medical profile:

```swift
struct ChildProfile: Identifiable, Codable {
    let id: String
    let parentName: String
    let childName: String
    let dateOfBirth: String
    let gender: String
    let challenges: [Challenge]
    let allergies: [String]
    let medications: [String]
    let pastConditions: [String]
    let notes: String
    let nicknames: [String]

    var age: String { /* calculated from DOB */ }
}
```

### Services (`/Services`)

#### ProviderSupabaseService
Main API client extending SupabaseServiceBase:

**Review Request Operations:**
```swift
func fetchProviderReviewRequests(status: String? = nil) async throws -> [ProviderReviewRequestDetail]
func fetchPendingReviews() async throws -> [ProviderReviewRequestDetail]
func fetchEscalatedReviews() async throws -> [ProviderReviewRequestDetail]
func fetchFlaggedReviews() async throws -> [ProviderReviewRequestDetail]
func fetchReviewForConversation(_ conversationId: UUID) async throws -> ProviderReviewRequestDetail
func fetchConversationDetails(_ conversationId: String) async throws -> ProviderReviewRequestDetail
```

**Messaging Operations:**
```swift
func sendProviderMessage(conversationId: String, message: String, urgency: String) async throws
func fetchFollowUpMessages(for conversationId: String) async throws -> [FollowUpMessage]
func createPatientNotificationMessage() async throws
```

**Status Management:**
```swift
func updateReviewStatus(id: String, status: String) async throws
func addProviderResponse(id: String, response: String, name: String, urgency: String, status: String) async throws
```

**Supabase Tables:**
| Table | Purpose | Key Columns |
|-------|---------|------------|
| `provider_review_requests` | Review requests | id, conversationId, status, providerId |
| `follow_up_messages` | Follow-up conversation | id, conversationId, messageContent, isFromUser |
| `patients` | Patient list | id, childName, gender, dateOfBirth |
| `conversations` | Conversation history | id, userId, title |

#### SupabaseServiceBase
Base class providing HTTP foundation:

**Features:**
- URL construction with query parameters
- Authentication header management (API key + Bearer token)
- JSON serialization/deserialization using Codable
- Automatic retry logic (3 attempts with exponential backoff)
- Comprehensive error handling and logging
- Support for GET, POST, PATCH operations
- Response debugging for troubleshooting

**Authentication:**
```
Headers:
- apikey: {supabase-anon-key}
- Authorization: Bearer {user-token}
- Content-Type: application/json
```

**Retry Strategy:**
```
Initial request
└─> Failure (network/timeout)
    └─> Wait 1 second
    └─> Retry (attempt 2)
        └─> Failure
            └─> Wait 2 seconds
            └─> Retry (attempt 3)
                └─> Failure → throw error
                └─> Success → return data
        └─> Success → return data
    └─> Success → return data
```

#### ProviderPushNotificationManager
Manages local and remote push notifications:

**Key Methods:**
```swift
func requestUserNotificationPermissions() async throws
func registerForRemoteNotifications()
func handleNotification(userInfo: [AnyHashable: Any])
func scheduleLocalTestNotification()
func updateBadgeCount(count: Int)
```

**Badge Count Update:**
```swift
if #available(iOS 17, *) {
    try? await UNUserNotificationCenter.current().setBadgeCount(count)
} else {
    UIApplication.shared.applicationIconBadgeNumber = count
}
```

**Notification Payload Handling:**
```json
{
  "aps": {
    "alert": {
      "title": "New Review Request",
      "body": "Patient needs clinical review"
    },
    "badge": 1,
    "sound": "default"
  },
  "conversationId": "uuid-here"
}
```

### Store (`/Store`)

#### ProviderConversationStore
Central ObservableObject managing app state using Combine:

**Published State:**
```swift
@Published var reviewRequests: [ProviderReviewRequestDetail] = []
@Published var selectedConversationId: UUID?
@Published var isLoading: Bool = false
@Published var errorMessage: String?
```

**Internal State:**
```swift
private var conversationDetailsCache: [UUID: ProviderReviewRequestDetail] = [:]
private var refreshTimer: Timer?
private let service: ProviderSupabaseService
private let notificationManager: ProviderPushNotificationManager
```

**Key Methods:**

1. **Data Loading:**
   ```swift
   func loadReviewRequests(status: String? = nil) async
   func loadConversationDetails(id: UUID) async
   func refresh() async
   func refreshConversation(id: UUID) async
   ```

2. **Queries:**
   ```swift
   func getConversationDetails(for id: UUID) -> ProviderReviewRequestDetail?
   func fetchReviewForConversation(id: String) async throws
   ```

3. **Updates:**
   ```swift
   func updateReviewStatus(id: String, status: String) async
   func addProviderResponse(id: String, response: String, name: String, urgency: String) async
   func flagConversation(id: String) async
   func escalateConversation(id: String) async
   func markAsResolved(id: String) async
   ```

4. **Messaging:**
   ```swift
   func sendMessage(conversationId: String, content: String, urgency: String) async
   ```

5. **Auto-refresh:**
   ```swift
   func startAutoRefresh(interval: TimeInterval = 60)
   func stopAutoRefresh()
   ```

6. **Computed Properties:**
   ```swift
   var pendingCount: Int { reviewRequests.filter { $0.status == "pending" }.count }
   var escalatedCount: Int { reviewRequests.filter { $0.status == "escalated" }.count }
   var flaggedCount: Int { reviewRequests.filter { $0.status == "flagged" }.count }
   var respondedTodayCount: Int { /* calculated from respondedAt */ }
   ```

## API Integration

### REST Endpoints

**Base URL:** `{supabase-project}.supabase.co/rest/v1/`

#### GET /provider_review_requests
Fetch review requests with optional filtering:

```
Query Parameters:
- select=* (select all columns)
- status=eq.pending (filter by status)
- status=in.("pending","flagged") (multiple values)

Response:
[
  {
    "id": "uuid",
    "conversationId": "uuid",
    "status": "pending",
    "childName": "John",
    "triageOutcome": "urgent_visit",
    ...
  }
]
```

#### GET /provider_review_requests?conversationId=eq.{uuid}
Fetch single review by conversation ID:

```
Response: Single ProviderReviewRequestDetail object
Note: Includes retry logic for UUID format variations
```

#### GET /follow_up_messages?conversationId=eq.{uuid}
Fetch follow-up messages for a conversation:

```
Response:
[
  {
    "id": "uuid",
    "messageContent": "Patient's follow-up message",
    "isFromUser": true,
    "timestamp": "2024-01-15T10:30:00Z"
  }
]
```

#### PATCH /provider_review_requests
Update review status or add response:

```json
Request Body:
{
  "status": "responded",
  "providerName": "Dr. Smith",
  "providerResponse": "Clinical assessment...",
  "providerUrgency": "urgent",
  "respondedAt": "2024-01-15T10:35:00Z"
}
```

#### POST /follow_up_messages
Create a follow-up message (notification to patient):

```json
Request Body:
{
  "conversationId": "uuid",
  "userId": "patient-uuid",
  "messageContent": "Provider's response",
  "isFromUser": false,
  "timestamp": "2024-01-15T10:35:00Z"
}
```

### Error Handling Strategy

**Network Errors:**
- Automatic retry with exponential backoff (up to 3 attempts)
- User-friendly error messages
- Graceful degradation (cached data when available)

**Parsing Errors:**
- Detailed logging for debugging
- Fallback to empty models when optional fields fail
- Multiple UUID format support for compatibility

**API Errors:**
- Extract HTTP status codes
- Map to user-friendly error messages
- Log full response for debugging

## View Hierarchy

```
Clara_ProviderApp
└─ ContentView
   ├─ ConversationListView (main)
   │  ├─ StatusFilterButton (x3: Pending, All, Flagged)
   │  ├─ SearchBar
   │  ├─ List
   │  │  └─ ConversationRowView (repeating)
   │  │     ├─ StatusBadge
   │  │     ├─ TriageBadge
   │  │     └─ Timestamp
   │  └─ EmptyStateView (fallback)
   │
   ├─ ConversationDetailView (detail)
   │  ├─ PatientInfoCard
   │  ├─ ScrollView
   │  │  ├─ MessageBubbleView (x many)
   │  │  └─ ProviderReplyBox
   │  │     ├─ Response type selector
   │  │     ├─ Text input
   │  │     └─ Submit button
   │  └─ Optional: MessageInputSheet
   │
   ├─ PatientProfileView (detail)
   │  ├─ PatientHeaderView
   │  ├─ Section: Allergies
   │  ├─ Section: Medications
   │  ├─ Section: Past Conditions
   │  ├─ Section: Notes
   │  └─ Section: Recent Conversations
   │
   └─ SideMenuView (overlay)
      ├─ Patient list
      └─ Search functionality
```

## State Flow Diagram

```
User Action
    ↓
    └─→ View calls Store method
        ↓
        └─→ Store.@Published property changes
            ↓
            ├─→ Triggers Service call (async)
            │   ↓
            │   └─→ HTTP request to Supabase
            │       ↓
            │       └─→ Parse response
            │           ↓
            │           └─→ Update @Published property
            │
            └─→ SwiftUI re-renders affected views
                ↓
                └─→ User sees update
```

## Caching Strategy

**Conversation Details Cache:**
- In-memory dictionary: `[UUID: ProviderReviewRequestDetail]`
- Populated on first load of a conversation
- Provides instant display when returning to a conversation
- Cleared via `refreshConversation(id:)` to reload from server

**TTL (Time-to-Live):**
- No automatic expiration
- Manual refresh via pull-to-refresh or 60-second auto-refresh cycle
- Ensures data freshness without excessive API calls

## Performance Considerations

1. **Auto-refresh Interval**: 60 seconds balances freshness with battery/network usage
2. **Caching**: Reduces API calls when switching between conversations
3. **Message Merging**: Done in-memory only when conversation opened
4. **Async/Await**: All network operations non-blocking
5. **Badge Updates**: Batched in auto-refresh cycle

## Security

- API key stored in code (consider environment variables for production)
- Bearer token for user authentication
- All endpoints use HTTPS
- Request/response logging includes sensitive data (implement sanitization for production)
- Push notification payloads contain only conversationId (not patient data)

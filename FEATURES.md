# clara-provider-app iOS - Features Documentation

## Feature Overview

clara-provider-app is organized around six core feature areas that enable healthcare providers to effectively manage patient triage requests and clinical reviews.

## 1. Review Request Management

### Overview
The core feature enabling providers to view, filter, and manage incoming triage requests from patients.

### Components
- **ConversationListView** - Primary UI for browsing requests
- **ProviderConversationStore** - State management for review requests
- **ProviderSupabaseService** - API backend integration

### Feature Details

#### 1.1 View All Requests
Display all available review requests in a unified list with essential information.

**UI Components:**
- Scrollable list of ConversationRowView items
- Each row displays:
  - Conversation title
  - Patient name and age
  - Current status (badge with color coding)
  - Triage outcome classification
  - Creation timestamp
  - Unread indicator (optional)

**Data Loaded:**
```swift
ConversationListView.onAppear()
  └─> Store.loadReviewRequests()
      └─> Service.fetchProviderReviewRequests()
          └─> GET /provider_review_requests
```

**Performance:**
- First load: ~500ms (network + parsing)
- Cached list: <50ms (in-memory)
- Auto-refresh: Every 60 seconds (if enabled)

#### 1.2 Filter by Status
Quickly find requests by their current review status.

**Available Filters:**
1. **Pending** - Awaiting provider review (orange badge)
2. **All** - Show all requests regardless of status
3. **Flagged** - Marked for special attention (yellow badge)

**Additional Statuses (in data):**
- **Responded** - Provider has already reviewed (green badge)
- **Escalated** - Referred for higher-level review (red badge)

**Implementation:**
```swift
@State var selectedStatus: String = "Pending"

// When status button tapped:
Store.loadReviewRequests(status: "pending")
  └─> Service adds query parameter: ?status=eq.pending
      └─> Supabase filters before returning results
```

**Filter Logic:**
```
Pending Filter: Shows status == "pending"
All Filter: Shows status in any state
Flagged Filter: Shows status == "flagged"
```

#### 1.3 Search Functionality
Full-text search across conversation titles and patient names.

**Search Fields:**
- Conversation title
- Patient name (childName)
- Partial matches supported

**Implementation:**
```swift
@State var searchText: String = ""

filteredRequests = reviewRequests.filter { request in
    if searchText.isEmpty { return true }

    let searchLower = searchText.lowercased()
    return (request.conversationTitle?.lowercased().contains(searchLower) ?? false) ||
           (request.childName?.lowercased().contains(searchLower) ?? false)
}
```

**Search Features:**
- Real-time filtering as user types
- Case-insensitive matching
- Works across current filter (status doesn't reset)
- Clear button to reset search

#### 1.4 Pull-to-Refresh
Manually refresh the request list to check for new items.

**Trigger:**
```swift
List { ... }
    .refreshable {
        await Store.loadReviewRequests()
    }
```

**Behavior:**
- Displays standard iOS refresh spinner
- Reloads from Supabase
- Updates counts and badges
- Maintains current filter and search

#### 1.5 Request Counts
Display running count of requests by status.

**Displayed Counts:**
```
Pending: [Number] badge
Flagged: [Number] badge
All: Shows total count
```

**Updates:**
- Automatically recalculated when list changes
- Updates via @Published property
- Real-time badge count integration with notifications

---

## 2. Conversation Review and Response

### Overview
Detailed interface for providers to review full conversation history and submit clinical responses.

### Components
- **ConversationDetailView** - Conversation display interface
- **ProviderReplyBox** - Response submission form
- **MessageBubbleView** - Individual message display
- **PatientInfoCard** - Patient summary card

### Feature Details

#### 2.1 View Conversation History
Display full conversation thread including patient messages, Clara AI responses, and any follow-ups.

**Message Sources:**
1. **Conversation Messages** - Initial triage conversation
   - Stored in `ProviderReviewRequestDetail.conversationMessages`
   - Contains patient messages and Clara AI responses
   - Tagged with `isFromUser` boolean

2. **Follow-up Messages** - Post-triage messages
   - Fetched from `follow_up_messages` table
   - Patient and provider messages
   - Timestamps for tracking response times

**Message Display:**
```
Patient Message (Left)
├─ Light background color
├─ Name: "Patient" or patient name
└─ Timestamp

Clara AI Response (Right)
├─ Different background color
├─ Name: "Clara"
└─ Timestamp

Provider Response (Right)
├─ Provider-specific styling
├─ Name: Provider name
└─ Timestamp
```

**Data Loading:**
```swift
ConversationDetailView.onAppear()
  ├─> Store.loadConversationDetails(conversationId)
  │   ├─> Check conversationDetailsCache first
  │   ├─> If not cached:
  │   │   ├─> Service.fetchConversationDetails(conversationId)
  │   │   └─> Service.fetchFollowUpMessages(conversationId)
  │   └─> Merge and sort by timestamp
  └─> Display merged messages
```

**Message Ordering:**
- Chronological: Earliest to latest
- Triage outcome shown with relevant message
- Response time calculated from timestamps

#### 2.2 Display Triage Outcome
Show the AI-determined triage classification prominently.

**Triage Classifications:**
| Outcome | Display | Color | Meaning |
|---------|---------|-------|---------|
| er_911 | "911 Emergency" | Red | Call emergency services immediately |
| er_drive | "ER - Drive Now" | Orange | Drive to ER immediately |
| urgent_visit | "Urgent Visit Needed" | Yellow | Schedule urgent appointment |
| routine_visit | "Routine Visit" | Blue | Schedule regular appointment |
| home_care | "Home Care" | Green | Can manage at home |

**Displayed As:**
- Badge in patient info card
- Highlighted in conversation header
- Visual indicator in list view

#### 2.3 Patient Information Card
Quick reference to patient demographics and medical history.

**Information Displayed:**
- **Name**: Patient name
- **Age**: Calculated from DOB (formatted: "4 years old")
- **Gender**: Patient gender
- **Triage Outcome**: Current classification with badge
- **Quick Actions**:
  - Tap to expand full profile
  - View medical history button

**Compact Display:**
```
┌─────────────────────────────┐
│ John (4 years old)          │
│ Gender: Male                │
│ Triage: Urgent Visit        │
│ [View Full Profile]         │
└─────────────────────────────┘
```

#### 2.4 Message Composition
Compose and submit clinical responses to patients.

**ProviderReplyBox Components:**
1. **Response Type Selector**
   - Dropdown or segmented control
   - Options:
     - "Agree" - Concur with triage outcome
     - "Agree with Thoughts" - Agree with clinical notes
     - "Disagree with Thoughts" - Different assessment
     - "Escalation Needed" - Refer for specialist review

2. **Text Input Area**
   - Multiline text field
   - Placeholder: "Enter your clinical assessment..."
   - Optional: Character count

3. **Urgency Selection**
   - Urgency level for response
   - Options: Normal, Urgent, Critical
   - Affects notification priority to patient

4. **Submit Button**
   - Enabled when response type selected
   - Shows loading state during submission
   - Disabled until action completes

**Submission Flow:**
```swift
User selects response type: "Agree with Thoughts"
User types clinical assessment: "Assessment details..."
User selects urgency: "Urgent"
User taps "Submit Review"

ProviderReplyBox.submitReview()
  ├─> Validate input
  ├─> Determine new status (e.g., "responded")
  ├─> If has response text:
  │   ├─> Store.addProviderResponse(
  │   │       id, response, providerName, urgency, status
  │   │   )
  │   │   └─> Service.addProviderResponse()
  │   │       └─> PATCH /provider_review_requests
  │   │
  │   └─> Service.createPatientNotificationMessage()
  │       └─> Send follow-up message to patient
  │
  └─> Refresh conversation to show new response
      └─> Store.loadConversationDetails(id, forceRefresh: true)
          └─> Clear cache and reload
          └─> Display updated conversation
```

**Status Mapping:**
- Response Type → Review Status:
  - All response types → "responded"
  - Escalation Needed → Can also set to "escalated"

---

## 3. Patient Information Management

### Overview
Comprehensive access to patient medical histories and profiles.

### Components
- **PatientProfileView** - Full patient information display
- **PatientInfoCard** - Compact patient summary
- **Models**: ChildProfile, Message

### Feature Details

#### 3.1 Patient Profile View
Full-screen detailed patient information.

**Profile Sections:**

1. **Demographics**
   - Full name
   - Date of birth (with age calculation)
   - Gender
   - Contact information (if available)

2. **Allergies**
   - List of known allergies
   - Severity indicators (if available)
   - Empty state: "No known allergies"

3. **Current Medications**
   - Medication name
   - Dosage
   - Frequency
   - Empty state: "No current medications"

4. **Past Medical Conditions**
   - Historical conditions
   - Relevant past surgeries
   - Chronic conditions
   - Empty state: "No past medical conditions"

5. **Clinical Notes**
   - Provider-added notes
   - Medical history summary
   - Special considerations
   - Empty state: "No notes"

6. **Recent Conversations**
   - List of last 5 conversations
   - Links to view full conversation
   - Dates and outcomes
   - Searchable list

**Data Loaded From:**
```
Patient Profile = ChildProfile model
  ├─ From patient's own profile record
  ├─ From ProviderReviewRequestDetail (current conversation context)
  └─ From follow_up_messages (historical context)
```

#### 3.2 Medical History Context
Access patient's past conversations and clinical outcomes.

**Conversation History Display:**
- Recent conversation list (most recent first)
- Date/time of conversation
- Triage outcome summary
- Provider response status

**Linked Actions:**
- Tap conversation to view full details
- See related messages
- Compare with current issue

---

## 4. Push Notification System

### Overview
Real-time notifications for new review requests and message updates.

### Components
- **ProviderPushNotificationManager** - Notification handling
- **AppDelegate** - Lifecycle integration
- **UserNotifications** framework

### Feature Details

#### 4.1 Remote Push Notifications
Receive notifications from Supabase when new requests arrive.

**Trigger Events:**
- New review request created
- Patient sends follow-up message
- Review request status changes
- Provider needs urgent attention

**Notification Payload:**
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
  "conversationId": "uuid-12345-67890"
}
```

**Notification Handling:**
```
Remote notification received
├─> App in foreground:
│   └─> didReceive(_ request:withContentHandler:)
│       └─> ProviderPushNotificationManager.handleNotification()
│
└─> App backgrounded:
    └─> OS displays notification
    └─> User taps notification
    └─> App launched with notification userInfo
        └─> AppDelegate parses and extracts conversationId
            └─> Navigate to that conversation automatically
```

#### 4.2 Badge Count Management
Keep app icon badge synchronized with pending review count.

**Badge Update Logic:**
```
Store.pendingCount changes
  ├─> @Published property updates
  └─> ProviderPushNotificationManager.updateBadgeCount()
      ├─> If iOS 17+:
      │   └─> UNUserNotificationCenter.setBadgeCount(count)
      └─> Else:
          └─> UIApplication.applicationIconBadgeNumber = count
```

**Badge Display:**
- Small red badge on app icon
- Number = count of pending reviews
- Updates in real-time
- Clears when all reviews resolved

**Example:**
- 3 pending reviews → Badge shows "3"
- User marks one as responded → Badge shows "2"
- All reviewed → Badge clears

#### 4.3 Local Notifications
Test notifications and local alerts within the app.

**Use Cases:**
- Testing notification system
- Local reminders for pending actions
- In-app alerts for status changes

**Scheduling:**
```swift
ProviderPushNotificationManager.scheduleLocalTestNotification()
  ├─> Creates test notification
  ├─> Schedules for 5 seconds from now
  ├─> Displays alert on device
  └─> Useful for testing APNs setup
```

#### 4.4 Permission Management
Request user consent for push notifications.

**Permission Request:**
```swift
ProviderPushNotificationManager.requestUserNotificationPermissions()
  ├─> Requests .alert, .sound, .badge permissions
  ├─> Shows system dialog to user
  ├─> Records permission status
  └─> Enables/disables notification features accordingly
```

**Permission Statuses:**
- **Authorized**: Full notification support
- **Denied**: No notifications (user can enable in Settings)
- **Provisional**: Silent notifications only (iOS 12+)
- **Ephemeral**: Temporary for app testing

---

## 5. Real-time Synchronization

### Overview
Keep app data current with automatic and manual refresh mechanisms.

### Components
- **ProviderConversationStore** - State management
- **Timer** - Periodic refresh
- **Refresh operations** - Manual and automatic

### Feature Details

#### 5.1 Auto-Refresh
Automatic periodic refresh of review requests.

**Schedule:**
```
Every 60 seconds:
  ├─> Store.refresh()
  │   └─> Store.loadReviewRequests()
  │       └─> Service.fetchProviderReviewRequests()
  │           └─> Compare with current data
  │           └─> Update if changed
  │
  └─> Update badge count based on new pending count
```

**Features:**
- Non-blocking (runs on background queue)
- No UI blocking
- Only updates if data changed
- Respectful of battery/network

**Control:**
```swift
ContentView.onAppear()
  └─> Store.startAutoRefresh(interval: 60)

ContentView.onDisappear()
  └─> Store.stopAutoRefresh()
```

**Benefits:**
- New requests appear without manual action
- Status changes sync across views
- User sees real-time updates
- Battery efficient (60-second interval)

#### 5.2 Manual Refresh
User-initiated refresh via pull-to-refresh.

**Gesture:**
```
User drags list down
  ├─> System shows refresh spinner
  └─> List.refreshable { } block executes
      └─> Store.loadReviewRequests()
          ├─> Fetches latest data
          ├─> Updates local state
          └─> Dismisses spinner
```

**Timing:**
- Completes in ~500ms on average
- Shows network activity indicator
- Handles errors gracefully

#### 5.3 Conversation Detail Refresh
Refresh specific conversation when detail changes.

**Triggers:**
- User returns to conversation after response
- Manual refresh requested
- Status changed by another provider
- New follow-up messages received

**Implementation:**
```swift
Store.refreshConversation(conversationId)
  ├─> Clear cache entry: conversationDetailsCache.removeValue(forKey: id)
  └─> Reload: loadConversationDetails(id)
      ├─> Force fetch from server (not cache)
      ├─> Merge latest messages
      └─> Display updated view
```

---

## 6. Status Tracking and Updates

### Overview
Track review request lifecycle and status changes.

### Components
- **ProviderConversationStore** - Status management
- **ProviderSupabaseService** - API operations
- **Models** - Status tracking data

### Feature Details

#### 6.1 Review Status Lifecycle

**Status Flow Diagram:**
```
pending (initial state)
  ├─ Provider reviews and responds
  └─> responded

pending
  ├─ Request needs escalation
  └─> escalated → responded

pending
  ├─ Request flagged for review
  └─> flagged → responded

responded (final state)
  └─ Review complete
```

**Status Descriptions:**

| Status | Color | Meaning | Can Change To |
|--------|-------|---------|---------------|
| pending | Orange | Awaiting provider review | responded, flagged, escalated |
| responded | Green | Provider has reviewed | Can't change (final) |
| flagged | Yellow | Marked for special attention | responded |
| escalated | Red | Referred for specialist review | responded |

#### 6.2 Update Status
Change review status programmatically.

**Methods:**
```swift
Store.updateReviewStatus(id: String, status: String)
Store.flagConversation(id: String)        // → status = "flagged"
Store.escalateConversation(id: String)    // → status = "escalated"
Store.markAsResolved(id: String)          // → status = "responded"
```

**API Operation:**
```
PATCH /provider_review_requests
Body: { "status": "responded", "respondedAt": "2024-01-15T10:35:00Z" }
```

#### 6.3 Add Provider Response
Submit clinical assessment with status update.

**Response Information:**
```swift
addProviderResponse(
    id: String,                    // Review ID
    response: String,              // Clinical text
    name: String,                  // Provider name
    urgency: String,               // Response urgency
    status: String                 // New status (usually "responded")
)
```

**Additional Operations:**
- Timestamp set to current time
- Create follow-up message for patient
- Update badge count
- Refresh conversation list

**Submitted Data:**
```json
{
  "status": "responded",
  "providerName": "Dr. Smith",
  "providerResponse": "Based on the conversation, I agree...",
  "providerUrgency": "urgent",
  "respondedAt": "2024-01-15T10:35:00Z"
}
```

---

## 7. UI/UX Features

### Overview
Polished user interface and experience enhancements.

### Color Scheme
- **Primary**: Coral (`#FF6B6B` equivalent)
- **Background**: Paper white (`#F5F5F5` equivalent)
- **Text**: Dark gray for light mode, white for dark mode
- **Accents**: Status-specific colors (green/orange/yellow/red)

### Dark Mode Support
- Full support for iOS dark mode
- Automatic color adaptation
- `Color.adaptiveBackground()` for theme-aware colors
- System respects user's preference

### Status Badges
Visual indicators for review status:
- Pending: Orange badge
- Flagged: Yellow badge
- Escalated: Red badge
- Responded: Green badge

### Triage Badges
Color-coded triage outcome display:
- Emergency (911): Red
- ER Drive: Orange
- Urgent: Yellow
- Routine: Blue
- Home Care: Green

---

## Summary Table

| Feature | Status | UI Component | Backend |
|---------|--------|--------------|---------|
| View requests | ✅ Active | ConversationListView | provider_review_requests |
| Filter by status | ✅ Active | StatusFilterButton | Query params |
| Search requests | ✅ Active | SearchBar | Client-side filter |
| Pull-to-refresh | ✅ Active | List.refreshable | fetchProviderReviewRequests |
| View conversation | ✅ Active | ConversationDetailView | Multiple tables |
| Review & respond | ✅ Active | ProviderReplyBox | addProviderResponse |
| Patient profiles | ✅ Active | PatientProfileView | patients table |
| Push notifications | ✅ Active | AppDelegate | Remote APNs |
| Badge count | ✅ Active | Notification Manager | pending count |
| Auto-refresh | ✅ Active | Timer loop | Periodic fetch |
| Status tracking | ✅ Active | Store state | updateReviewStatus |
| Message history | ✅ Active | MessageBubbleView | follow_up_messages |
| Dashboard stats | 🚧 Planned | ProviderDashboardView | Aggregate data |


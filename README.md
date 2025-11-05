# clara-provider-app iOS

A modern SwiftUI-based iOS application for healthcare providers to review and respond to patient triage requests and consultation outcomes in real-time.

## Overview

**clara-provider-app** enables healthcare providers to:
- Review incoming patient triage and consultation requests
- Access comprehensive patient medical histories
- Provide clinical feedback and medical responses
- Track review request statuses (pending, responded, flagged, escalated)
- Receive real-time push notifications for new requests
- Manage conversations with patients through the Clara platform

## Key Features

✅ **Review Management**
- Real-time list of patient review requests
- Status-based filtering (Pending, All, Flagged)
- Full-text search by conversation title or patient name
- Pull-to-refresh functionality

✅ **Detailed Review Interface**
- Complete conversation history with triage outcomes
- Patient information cards with medical background
- Support for multiple provider response types (Agree, Agree with Thoughts, Disagree with Thoughts, Escalation)
- Message composition and submission

✅ **Patient Information**
- Comprehensive patient profiles
- Medical history including:
  - Current medications
  - Known allergies
  - Past medical conditions
  - Clinical notes

✅ **Smart Notifications**
- Remote push notifications for new requests
- Real-time badge count updates
- Background notification handling
- Local test notification support

✅ **Real-time Sync**
- Automatic 60-second auto-refresh of review list
- Conversation caching for optimal performance
- Seamless status updates across views

## Architecture

The app follows **MVVM (Model-View-ViewModel)** architecture with Combine for state management:

```
clara-provider-app/
├── Clara_ProviderApp.swift          # App entry point
├── ContentView.swift                # Navigation container
│
├── Store/
│   └── ProviderConversationStore    # Central state management
│
├── Services/
│   ├── ProviderSupabaseService      # API client
│   ├── SupabaseServiceBase          # HTTP foundation
│   └── ProviderPushNotificationManager
│
├── Models/
│   ├── ProviderReviewRequestDetail  # Core data model
│   ├── SupabaseModels               # Message structures
│   ├── Message                      # UI message model
│   └── ChildProfile                 # Patient profile
│
└── Views/
    ├── ConversationListView         # Main provider dashboard
    ├── ConversationDetailView       # Review detail interface
    ├── PatientProfileView           # Patient information
    ├── ProviderDashboardView        # Analytics (planned)
    └── Supporting views & utilities
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for comprehensive technical details.

## Quick Start

### Prerequisites
- Xcode 15 or later
- iOS 15.0 or later
- Swift 5.9 or later

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/dochobbs/claraproviderios.git
   cd "clara-provider-app"
   ```

2. **Configure Supabase credentials**
   - Update API endpoint and authentication tokens in `Services/SupabaseServiceBase.swift`
   - Add your Supabase project configuration

3. **Open in Xcode**
   ```bash
   open "clara-provider-app.xcodeproj"
   ```

4. **Build and Run**
   - Select target device/simulator
   - Press `Cmd + R` to build and run

### Push Notifications Setup

To enable push notifications:

1. Configure Apple Push Notification (APNs) in your Apple Developer account
2. Add the certificate/key pair to your Supabase project
3. Device tokens are automatically registered on app launch
4. Badge counts automatically update with pending review count

See [SETUP.md](SETUP.md) for detailed configuration instructions.

## Core Data Models

### ProviderReviewRequestDetail
Primary model for review requests:
- `id`: Unique identifier
- `conversationId`: Related conversation UUID
- `conversationTitle`: Triage request title
- `childName`, `childAge`, `childDOB`: Patient demographics
- `triageOutcome`: Classification (er_911, er_drive, urgent_visit, routine_visit, home_care)
- `status`: Current status (pending, responded, flagged, escalated)
- `conversationMessages`: Full conversation history
- `providerResponse`: Provider's clinical feedback
- `respondedAt`: Response timestamp

### Message
UI-friendly message representation for conversations:
- `content`: Message text
- `isFromUser`: Sender type (patient/Clara/provider)
- `timestamp`: Message creation time
- `triageOutcome`: Optional triage classification
- `providerName`: Sender identifier

See [ARCHITECTURE.md](ARCHITECTURE.md) for complete model documentation.

## API Integration

The app integrates with **Supabase REST API** for:

**Review Request Operations:**
- Fetch review requests with optional status filtering
- Get pending/escalated/flagged reviews
- Fetch detailed conversation with retry logic

**Messaging:**
- Send provider responses to patients
- Fetch follow-up messages
- Create patient notifications

**Status Management:**
- Update review statuses
- Add provider responses with urgency levels
- Track response timestamps

**Utility Operations:**
- Patient list retrieval
- Conversation history
- Dashboard statistics

See [ARCHITECTURE.md](ARCHITECTURE.md) for complete API documentation.

## Features Documentation

For detailed feature documentation, implementation details, and usage examples, see [FEATURES.md](FEATURES.md).

## Development

### Project Structure
- **Models**: Data structures for Supabase integration
- **Services**: Backend communication and push notification handling
- **Store**: Centralized state management with Combine
- **Views**: SwiftUI components and screens

### Key Technologies
- **Language**: Swift
- **Framework**: SwiftUI
- **State Management**: Combine (@Published, @StateObject)
- **Backend**: Supabase (PostgreSQL + REST API)
- **Networking**: URLSession
- **Notifications**: UserNotifications framework

### Development Guidelines
- Uses MVVM architecture with clear separation of concerns
- Comprehensive error handling with detailed logging
- Graceful fallbacks for API changes
- Support for multiple UUID formats
- Memory-efficient caching for conversation details

## Known Issues and TODOs

- **User Authentication**: Currently uses "default_user" placeholder - replace with actual user ID system
- **Child Profiles**: May require separate API endpoint if stored differently
- **Follow-up Messages Schema**: Graceful fallback if schema differs
- **Dashboard Stats**: UI ready but statistics calculation pending

## Contributing

When contributing to this project:

1. Follow the existing MVVM architecture
2. Add comprehensive error handling
3. Include SwiftUI view previews
4. Test on both light and dark modes
5. Update documentation for new features

## License

[Add your license here]

## Support

For issues, questions, or contributions, please create a GitHub issue or contact the development team.

---

**Status**: Active Development
**Last Updated**: November 2024
**Version**: 1.0.0

For more details, see:
- [ARCHITECTURE.md](ARCHITECTURE.md) - Complete system design
- [FEATURES.md](FEATURES.md) - Feature documentation
- [SETUP.md](SETUP.md) - Development setup guide

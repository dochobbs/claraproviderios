# clara-provider-app iOS - Setup & Development Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Xcode Configuration](#xcode-configuration)
4. [Supabase Integration](#supabase-integration)
5. [Push Notification Setup](#push-notification-setup)
6. [Development Workflow](#development-workflow)
7. [Troubleshooting](#troubleshooting)
8. [Deployment](#deployment)

## Prerequisites

### System Requirements
- **macOS**: 12.0 or later
- **Xcode**: 15.0 or later
- **iOS**: 15.0 or later (deployment target)
- **Swift**: 5.9 or later (included with Xcode)

### Development Tools
- **Git**: For version control
- **Terminal/Shell**: For command-line operations
- **Apple Developer Account**: For certificates and signing
- **Supabase Account**: For backend services

### Hardware
- **Mac**: Any Mac that runs Xcode 15
- **iPhone/iPad** (optional): iOS 15.0+ for real device testing
  - Simulator is sufficient for development

## Initial Setup

### 1. Clone the Repository

```bash
# Clone the repository
git clone https://github.com/dochobbs/claraproviderios.git

# Navigate to project directory
cd "clara-provider-app"

# Verify directory structure
ls -la
```

**Expected Structure:**
```
clara-provider-app/
├── Clara_ProviderApp.swift
├── ContentView.swift
├── PatientChartView.swift
├── PatientChartView 2.swift
├── Models/
│   ├── ChildProfile.swift
│   ├── Message.swift
│   ├── ProviderReviewRequestDetail.swift
│   └── SupabaseModels.swift
├── Services/
│   ├── ProviderPushNotificationManager.swift
│   ├── ProviderSupabaseService.swift
│   └── SupabaseServiceBase.swift
├── Store/
│   └── ProviderConversationStore.swift
└── Views/
    ├── ColorExtensions.swift
    ├── ConversationDetailView.swift
    ├── ConversationListView.swift
    ├── ErrorHandling.swift
    ├── PatientProfileView.swift
    ├── ProviderDashboardView.swift
    ├── ProviderMessageInput.swift
    ├── ReviewActionsView.swift
    └── SearchBarCustomizer.swift
```

### 2. Open in Xcode

```bash
# Open the project in Xcode
# Note: If this is a Swift Package or has a .xcodeproj, adjust accordingly
open -a Xcode .
```

**Alternative:**
- Open Xcode manually
- File → Open → Navigate to project folder
- Select the project folder

### 3. Select Build Target

Once in Xcode:
1. Click on the Project in the left sidebar
2. Select "clara-provider-app" target
3. Verify build settings:
   - **Minimum Deployment**: iOS 15.0
   - **Swift Language**: 5.9 or later

## Xcode Configuration

### 1. Project Settings

**Team Selection:**
1. Select Project → clara-provider-app target
2. Go to "Signing & Capabilities" tab
3. Select your Apple Developer Team from dropdown
   - If you don't see your team, sign in to Xcode with your Apple ID

**Bundle Identifier:**
- Should be: `com.dochobbs.claraproviderios`
- Or your team's convention: `com.yourteam.claraproviderios`

### 2. Build Settings

**Key Build Settings:**
```
IPHONEOS_DEPLOYMENT_TARGET = 15.0
SWIFT_VERSION = 5.9
CODE_SIGN_IDENTITY = Apple Development
PROVISIONING_PROFILE_SPECIFIER = [Auto-generated]
```

**Verify Settings:**
1. Select Project → Build Settings
2. Search for "deployment"
3. Verify IPHONEOS_DEPLOYMENT_TARGET = 15.0

### 3. Build Phases

No custom build phases required. The project uses standard SwiftUI.

### 4. Linked Frameworks

The project relies on built-in frameworks:
- Foundation
- SwiftUI
- Combine
- UserNotifications
- URLSession (Foundation)

No external CocoaPods or SPM packages configured by default.

## Supabase Integration

### 1. Create Supabase Project

1. Visit [supabase.com](https://supabase.com)
2. Sign in or create account
3. Click "New Project"
4. Configure:
   - **Organization**: Your organization
   - **Project Name**: `clara-provider` (or your choice)
   - **Database Password**: Generate strong password (save securely)
   - **Region**: Select closest to your users
   - **Pricing Plan**: Start with Free tier
5. Wait for project initialization (~5 minutes)

### 2. Get Credentials

Once project is ready:

1. **Go to Project Settings**
   - Click Settings icon (gear) in bottom left
   - Click "API" in left sidebar

2. **Copy API Credentials**
   ```
   API URL: https://[project-id].supabase.co
   Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   Service Role Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... (keep secret)
   ```

3. **Save credentials securely**
   - Never commit credentials to Git
   - Use environment variables for production

### 3. Configure in App

**File:** `clara-provider-app/Services/SupabaseServiceBase.swift`

Locate the base class and update:

```swift
class SupabaseServiceBase {
    let baseURL = "https://YOUR_PROJECT_ID.supabase.co/rest/v1"
    let apiKey = "YOUR_ANON_KEY"
    let authToken = "YOUR_USER_TOKEN" // Or from login
}
```

**Secure Configuration (Recommended):**

Create `Config.swift` (add to `.gitignore`):
```swift
struct SupabaseConfig {
    static let baseURL = "https://[project-id].supabase.co/rest/v1"
    static let apiKey = "[anon-key]"
    static let projectID = "[project-id]"
}
```

Then in SupabaseServiceBase:
```swift
let baseURL = SupabaseConfig.baseURL
let apiKey = SupabaseConfig.apiKey
```

### 4. Create Required Tables

The app expects these Supabase tables:

**provider_review_requests**
```sql
CREATE TABLE public.provider_review_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users,
  conversation_id UUID NOT NULL,
  conversation_title VARCHAR,
  child_name VARCHAR,
  child_age VARCHAR,
  child_dob DATE,
  triage_outcome VARCHAR,
  conversation_messages JSONB,
  conversation_summary TEXT,
  status VARCHAR DEFAULT 'pending',
  provider_name VARCHAR,
  provider_response TEXT,
  provider_urgency VARCHAR,
  responded_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_provider_review_requests_conversation_id
ON public.provider_review_requests(conversation_id);

CREATE INDEX idx_provider_review_requests_status
ON public.provider_review_requests(status);

CREATE INDEX idx_provider_review_requests_user_id
ON public.provider_review_requests(user_id);
```

**follow_up_messages**
```sql
CREATE TABLE public.follow_up_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.provider_review_requests(conversation_id),
  user_id UUID REFERENCES auth.users,
  message_content TEXT NOT NULL,
  is_from_user BOOLEAN DEFAULT true,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_read BOOLEAN DEFAULT false,
  follow_up_id UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_follow_up_messages_conversation_id
ON public.follow_up_messages(conversation_id);

CREATE INDEX idx_follow_up_messages_user_id
ON public.follow_up_messages(user_id);
```

**patients**
```sql
CREATE TABLE public.patients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_name VARCHAR,
  child_name VARCHAR,
  date_of_birth DATE,
  gender VARCHAR,
  challenges JSONB,
  allergies TEXT[],
  medications TEXT[],
  past_conditions TEXT[],
  notes TEXT,
  nicknames TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_patients_child_name
ON public.patients(child_name);
```

### 5. Enable RLS (Row Level Security)

**Important:** Secure your tables with RLS policies.

```sql
-- Enable RLS on tables
ALTER TABLE public.provider_review_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follow_up_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;

-- Provider can see their own review requests
CREATE POLICY "Providers see own requests"
ON public.provider_review_requests
FOR SELECT
USING (auth.uid() = user_id);

-- Providers can update their own requests
CREATE POLICY "Providers update own requests"
ON public.provider_review_requests
FOR UPDATE
USING (auth.uid() = user_id);
```

See `provider_review_requests_rls_policy.sql` in the repo for complete RLS setup.

## Push Notification Setup

### 1. Apple Push Notification (APNs) Certificate

**Requirements:**
- Apple Developer Program account
- Access to Apple Developer portal

**Steps:**

1. **Generate Certificate Request**
   - Open Keychain Access (Applications → Utilities)
   - Keychain Access → Certificate Assistant → Request Certificate from CA
   - Email address: Your apple ID email
   - Save to disk
   - Name: `CertificateSigningRequest.certSigningRequest`

2. **Create APNs Certificate**
   - Visit [developer.apple.com](https://developer.apple.com)
   - Sign in with Apple ID
   - Certificates, IDs & Profiles
   - Certificates → Click "+"
   - Select "Apple Push Notification service SSL (Sandbox)"
   - Select Bundle ID: `com.dochobbs.claraproviderios`
   - Upload certificate request
   - Download certificate: `aps_development.cer`

3. **Install Certificate**
   - Double-click `aps_development.cer` to add to Keychain
   - Verify in Keychain Access → My Certificates

4. **Export Private Key**
   - In Keychain Access, right-click the certificate
   - Export "Apple Push Notification service SSL (Sandbox) ID: ..."
   - Format: `.p12`
   - Set password (or leave empty)
   - Save as `APNs_Development.p12`

### 2. Configure Supabase with APNs

1. **In Supabase Dashboard**
   - Project Settings → Apple
   - Upload `APNs_Development.p12`
   - Enter password (if set)
   - Select certificate type: Development

2. **Enable Push Notifications**
   - Project Settings → Auth Providers
   - Ensure OAuth/Auth is configured

### 3. Request Push Permission in App

The app automatically requests push permissions on launch via:

```swift
ProviderPushNotificationManager.requestUserNotificationPermissions()
```

When user runs app:
1. System shows permission dialog
2. User taps "Allow" to enable notifications
3. App is registered with APNs
4. Device token saved for push delivery

**Testing Permissions:**
```swift
// In ProviderPushNotificationManager
UNUserNotificationCenter.current().getNotificationSettings { settings in
    switch settings.authorizationStatus {
    case .authorized:
        print("✅ Notifications authorized")
    case .denied:
        print("❌ Notifications denied - user can enable in Settings")
    case .notDetermined:
        print("⏳ Awaiting user permission")
    case .provisional:
        print("📢 Provisional notifications enabled")
    case .ephemeral:
        print("📱 Ephemeral notifications (testing)")
    @unknown default:
        break
    }
}
```

### 4. Test Notifications

**Local Test Notification:**
```swift
ProviderPushNotificationManager.scheduleLocalTestNotification()
// Will show notification in 5 seconds
```

**Remote Notification via Supabase:**

Use Supabase Edge Functions or HTTP endpoint to send notifications:

```bash
curl -X POST \
  https://[project-id].supabase.co/functions/v1/send-notification \
  -H "Authorization: Bearer [service-role-key]" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "uuid-here",
    "title": "New Review Request",
    "body": "Patient John Smith needs review",
    "conversation_id": "uuid-here"
  }'
```

## Development Workflow

### 1. Building the Project

**Clean Build:**
```bash
# From Xcode menu: Product → Clean Build Folder
# Or use keyboard shortcut: Shift + Cmd + K
```

**Build for Simulator:**
```
Product → Build (Cmd + B)
```

**Build for Device:**
```
Product → Build (Cmd + B)
# Then: Product → Run (Cmd + R)
```

### 2. Running on Simulator

1. **Select Simulator**
   - Top of Xcode window: clara-provider-app → iPhone 15 (or your choice)
   - Or: Product → Destination → Select device

2. **Run App**
   - Product → Run (Cmd + R)
   - Or click play button in toolbar

3. **View Console Output**
   - View → Debug Area → Show Console (Cmd + Shift + C)
   - Watch for API calls, errors, and logs

### 3. Running on Device

1. **Connect iPhone**
   - USB cable to Mac
   - iPhone: Trust This Computer

2. **Select Device**
   - Xcode: clara-provider-app → Your iPhone
   - Or: Product → Destination → Your iPhone

3. **Run App**
   - Product → Run (Cmd + R)
   - App installs and launches on device

4. **Debugging**
   - View → Debug Area shows output
   - Use lldb debugger for step-through debugging
   - Set breakpoints by clicking line numbers

### 4. Code Style Guidelines

**Swift Style:**
```swift
// Use 4-space indentation
// Follow Apple's Swift API Design Guidelines

// Naming: camelCase for properties/methods
var reviewRequests: [ProviderReviewRequestDetail]

// Class/Struct names: PascalCase
struct ProviderReviewRequestDetail { }

// Constants: camelCase or UPPER_SNAKE_CASE
let maxRetries = 3
let API_KEY = "..."

// Access Control: Internal is default
public class Store { }
private var cache: [String: Data] = [:]
```

**Comments:**
```swift
/// Documentation comments for public APIs
/// - Parameter id: The review request ID
/// - Returns: The detailed review request
func loadConversationDetails(id: UUID) async { }

// Implementation comments for complex logic
// Retry up to 3 times with exponential backoff
```

### 5. Testing

**Manual Testing Checklist:**

- [ ] Load review requests on app launch
- [ ] Filter by status (Pending, All, Flagged)
- [ ] Search by patient name
- [ ] Pull-to-refresh list
- [ ] Tap conversation to view details
- [ ] View conversation messages
- [ ] Submit provider response
- [ ] Verify status updates
- [ ] Check push notification handling
- [ ] Verify badge count updates
- [ ] Test dark mode (Settings → Display & Brightness)
- [ ] Test on different device sizes

### 6. Debugging Tips

**Enable Verbose Logging:**

In `SupabaseServiceBase.swift`:
```swift
func makeRequest<T: Decodable>(...) async throws -> T {
    // Add verbose logging
    print("🔵 API Request: \(method) \(url)")
    print("📋 Headers: \(headers)")
    if let body = body {
        print("📦 Body: \(String(data: body, encoding: .utf8) ?? "N/A")")
    }

    // ... network call ...

    print("🟢 API Response: \(response.statusCode)")
    print("📄 Data: \(String(data: data, encoding: .utf8) ?? "N/A")")
}
```

**Xcode Debugger:**
```
Set breakpoint: Click line number (red dot appears)
Step over: F6 (or Debug → Step Over)
Step into: F7 (or Debug → Step Into)
Step out: F8 (or Debug → Step Out)
Continue: Ctrl + Cmd + Y (or click play in debug area)
```

**View Hierarchy:**
```
Debug menu → View UI Hierarchy
Shows all SwiftUI views and their properties
Great for finding layout issues
```

### 7. Performance Profiling

**Using Instruments:**
1. Product → Profile (Cmd + I)
2. Select profiling template:
   - Time Profiler: CPU usage
   - Core Data: Database queries
   - Network: HTTP calls
   - Memory Leaks: Memory issues
3. Run for 30 seconds
4. Analyze hotspots

## Troubleshooting

### Common Issues

#### "Cannot find API endpoint"
**Cause**: Supabase configuration not set correctly
**Solution:**
1. Verify `baseURL` in `SupabaseServiceBase.swift`
2. Check API key is correct
3. Ensure Supabase project is running
4. Test endpoint with curl:
```bash
curl -X GET "https://[project-id].supabase.co/rest/v1/provider_review_requests?select=*" \
  -H "apikey: [anon-key]"
```

#### "Build failed - Swift compiler error"
**Cause**: Swift version mismatch or syntax error
**Solution:**
1. Product → Clean Build Folder (Cmd + Shift + K)
2. File → Packages → Reset Package Caches
3. Close Xcode and reopen
4. Check error details in Issues panel

#### "Simulator build succeeds but device fails"
**Cause**: Team/Signing configuration
**Solution:**
1. Select Project → clara-provider-app target
2. Signing & Capabilities → Team
3. Select your Apple Developer Team
4. Wait for auto code signing to complete
5. Rebuild

#### "Push notifications not working"
**Cause**: APNs not configured or permissions denied
**Solution:**
1. Check APNs certificate in Supabase
2. Verify app has notification permission:
   - Settings → clara-provider-app → Notifications → On
3. Check device token is registered:
   - Check UserDefaults for device token
   - Log output should show registration
4. Test with local notification first

#### "App crashes on startup"
**Cause**: Unhandled exception or missing configuration
**Solution:**
1. Check console output for error message
2. Set breakpoint in `Clara_ProviderApp.swift`
3. Step through app initialization
4. Check all service initializations
5. Verify all @State/@Published properties initialized

### Getting Help

1. **Check Xcode Console**: View → Debug Area → Show Console
2. **Add Logging**: Insert print() statements to trace execution
3. **Use Breakpoints**: Set breakpoints to pause execution
4. **Test API Endpoints**: Use curl or Postman to test Supabase
5. **Search Issues**: GitHub Issues may have solutions
6. **Community Support**: Swift forums, Stack Overflow

## Deployment

### Preparing for App Store

#### 1. App Privacy Policy
Create privacy policy covering:
- Data collected (patient info)
- Data usage (triage review)
- Third-party services (Supabase)
- User rights

#### 2. App Store Review Guidelines
- Follow [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Healthcare apps require special review
- Ensure HIPAA compliance if handling sensitive data
- No hardcoded credentials

#### 3. Code Signing for Distribution
1. Project Settings → Signing & Capabilities
2. Change to "Apple Distribution" certificate
3. Create App Store provisioning profile
4. Update Bundle ID and Team ID

#### 4. Create App Store Listing
1. App Store Connect → Apps → My Apps
2. Create new app
3. Fill out metadata (screenshots, description, keywords)
4. Set pricing and availability
5. Add release notes

#### 5. Archive and Submit
```
Product → Archive (Cmd + Shift + C)
→ Validate App
→ Distribute App
→ Submission
```

### Release Checklist

- [ ] Update version number in Info.plist
- [ ] Update build number (increment)
- [ ] Test on real device (not just simulator)
- [ ] Verify all API endpoints work
- [ ] Test push notifications
- [ ] Check dark mode support
- [ ] Test on iOS 15.0 (minimum supported)
- [ ] Review console logs for warnings
- [ ] Update documentation
- [ ] Create git tag: `v1.0.0`
- [ ] Create release notes

---

**For additional help**, refer to:
- [Apple SwiftUI Documentation](https://developer.apple.com/xcode/swiftui/)
- [Supabase iOS Guide](https://supabase.com/docs/guides/realtime)
- [README.md](README.md) - Project overview
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
- [FEATURES.md](FEATURES.md) - Feature documentation

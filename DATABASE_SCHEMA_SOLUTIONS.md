# Database Schema Solutions - Flag/Unflag Impact on Patient App

**Document Created:** November 8, 2025
**Problem:** Single `status` field serves two incompatible purposes
**Goal:** Allow provider workflow management without breaking patient app

---

## Problem Statement

The `provider_review_requests` table has a single `status` field that tries to serve two incompatible purposes:

1. **Provider Workflow Management** (flagged, escalated, dismissed)
2. **Patient Response Visibility** (has provider responded?)

**Result:** Provider flag operations break patient app's ability to display responses.

---

## Current Table Structure

### provider_review_requests Table (Inferred)
```sql
CREATE TABLE provider_review_requests (
    id UUID PRIMARY KEY,
    user_id TEXT,  -- Patient's user ID
    conversation_id UUID,  -- Links to conversations table
    conversation_title TEXT,
    child_name TEXT,
    child_age TEXT,
    child_dob TEXT,
    triage_outcome TEXT,
    conversation_summary TEXT,
    conversation_messages JSONB,

    -- Provider response fields
    provider_name TEXT,
    provider_response TEXT,  -- The actual response text
    provider_urgency TEXT,
    responded_at TIMESTAMP,

    -- Status tracking (THE PROBLEM FIELD)
    status TEXT,  -- "pending", "responded", "flagged", "escalated", "dismissed"

    -- Flag tracking
    flag_reason TEXT,

    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    provider_push_sent BOOLEAN
);
```

### Current Status Values
- `"pending"` - Awaiting provider review
- `"responded"` - Provider has responded (PATIENT QUERY DEPENDS ON THIS)
- `"flagged"` - Flagged for provider follow-up
- `"escalated"` - Escalated for urgent attention
- `"dismissed"` - Provider dismissed (no action needed)

---

## The Core Conflict

### Patient App Query (SupabaseService.swift:158)
```swift
WHERE status = 'responded'
```

**Expectation:** Returns all provider responses
**Reality:** Only returns responses where status is currently "responded"
**Problem:** Flagging changes status from "responded" to "flagged", breaking query

### Provider App Workflow
```swift
// When provider flags a responded conversation:
status: "responded" → "flagged"  // Response becomes invisible to patient

// When provider unflags:
status: "flagged" → "responded"  // Response becomes visible again
```

---

## Solution 1: Separate Status Fields (RECOMMENDED)

### Approach
Split the single `status` field into two independent fields:
- `response_status` - Patient-facing (has provider responded?)
- `provider_workflow_status` - Provider-facing (workflow management)

### Schema Changes
```sql
ALTER TABLE provider_review_requests
ADD COLUMN response_status TEXT,
ADD COLUMN provider_workflow_status TEXT;

-- Migrate existing data
UPDATE provider_review_requests
SET
    response_status = CASE
        WHEN provider_response IS NOT NULL AND provider_response != '' THEN 'responded'
        ELSE 'pending'
    END,
    provider_workflow_status = status;

-- Add constraints
ALTER TABLE provider_review_requests
ALTER COLUMN response_status SET NOT NULL,
ALTER COLUMN response_status SET DEFAULT 'pending';

-- Create index for patient queries
CREATE INDEX idx_provider_review_response_status
ON provider_review_requests(conversation_id, response_status);

-- Optional: Drop old status column after migration verified
-- ALTER TABLE provider_review_requests DROP COLUMN status;
```

### New Table Structure
```sql
CREATE TABLE provider_review_requests (
    -- ... existing fields ...

    -- Patient-facing response status (never changes after response)
    response_status TEXT NOT NULL DEFAULT 'pending',
        -- Values: 'pending', 'responded'
        -- Set to 'responded' when provider_response is added
        -- NEVER changes back to 'pending'

    -- Provider-facing workflow status (changes frequently)
    provider_workflow_status TEXT DEFAULT 'pending',
        -- Values: 'pending', 'active', 'flagged', 'escalated', 'dismissed', 'closed'
        -- Can change independently of response_status
        -- Used for provider workflow management only

    -- ... existing fields ...
);
```

### Updated Provider App Code

**ProviderSupabaseService.swift - Update Status:**
```swift
// BEFORE (breaks patient app):
func updateReviewStatus(id: String, status: String) async throws {
    var updatePayload: [String: Any] = [
        "status": status  // ❌ Changes both provider AND patient status
    ]
    // ...
}

// AFTER (doesn't affect patient app):
func updateReviewStatus(id: String, workflowStatus: String) async throws {
    var updatePayload: [String: Any] = [
        "provider_workflow_status": workflowStatus  // ✅ Only changes provider workflow
    ]
    // response_status stays unchanged
    // ...
}
```

**ProviderSupabaseService.swift - Submit Response:**
```swift
func submitProviderResponse(...) async throws {
    var updatePayload: [String: Any] = [
        "provider_response": response,
        "provider_name": providerName,
        "response_status": "responded",  // ✅ Set patient-facing status
        "provider_workflow_status": "responded",  // ✅ Set provider workflow status
        "responded_at": ISO8601DateFormatter().string(from: Date())
    ]
    // ...
}
```

**ProviderConversationStore.swift - Flag Conversation:**
```swift
// BEFORE (changes status, breaks patient query):
func flagConversation(_ id: UUID, reason: String?) async throws {
    try await supabaseService.updateReviewStatus(id: id.uuidString, status: "flagged")
    // ❌ Patient query breaks
}

// AFTER (only changes workflow status):
func flagConversation(_ id: UUID, reason: String?) async throws {
    try await supabaseService.updateReviewWorkflowStatus(id: id.uuidString, status: "flagged")
    // ✅ response_status stays "responded", patient query still works
}
```

### Updated Patient App Code

**SupabaseService.swift - Fetch Provider Response:**
```swift
// BEFORE (breaks when flagged):
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&status=eq.responded&select=...")

// AFTER (always works):
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&response_status=eq.responded&select=...")
```

### Benefits
✅ **Patient app always works** - `response_status` never changes after response is submitted
✅ **Provider workflow flexible** - Can flag/unflag without affecting patient visibility
✅ **Clear separation of concerns** - Two statuses for two purposes
✅ **No UserDefaults hacks** - Database structure enforces correct behavior
✅ **Backward compatible** - Can keep old `status` column during migration

### Drawbacks
❌ **Schema migration required** - Need to update database and both apps
❌ **Two status fields** - More complex data model (but clearer semantics)

---

## Solution 2: Add `has_provider_response` Boolean (SIMPLE)

### Approach
Add a dedicated boolean field to indicate if provider has responded, independent of workflow status.

### Schema Changes
```sql
ALTER TABLE provider_review_requests
ADD COLUMN has_provider_response BOOLEAN DEFAULT FALSE;

-- Backfill existing data
UPDATE provider_review_requests
SET has_provider_response = TRUE
WHERE provider_response IS NOT NULL AND provider_response != '';

-- Create index
CREATE INDEX idx_provider_review_has_response
ON provider_review_requests(conversation_id, has_provider_response)
WHERE has_provider_response = TRUE;
```

### New Table Structure
```sql
CREATE TABLE provider_review_requests (
    -- ... existing fields ...

    has_provider_response BOOLEAN NOT NULL DEFAULT FALSE,
        -- Set to TRUE when provider submits response
        -- NEVER set back to FALSE
        -- Independent of status field

    status TEXT,  -- Still used for provider workflow
        -- Values: 'pending', 'flagged', 'escalated', 'dismissed'
        -- Can change freely without affecting patient queries

    -- ... existing fields ...
);
```

### Updated Patient App Code

**SupabaseService.swift:**
```swift
// BEFORE:
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&status=eq.responded&select=...")

// AFTER:
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&has_provider_response=eq.true&select=...")
```

### Updated Provider App Code

**ProviderSupabaseService.swift - Submit Response:**
```swift
func submitProviderResponse(...) async throws {
    var updatePayload: [String: Any] = [
        "provider_response": response,
        "provider_name": providerName,
        "has_provider_response": true,  // ✅ Set boolean flag
        "status": "responded",  // Set initial status
        "responded_at": ISO8601DateFormatter().string(from: Date())
    ]
    // ...
}
```

**ProviderConversationStore.swift - Flag Conversation:**
```swift
// Flagging now only changes status, not has_provider_response
func flagConversation(_ id: UUID, reason: String?) async throws {
    try await supabaseService.updateReviewStatus(id: id.uuidString, status: "flagged")
    // has_provider_response stays TRUE, patient query still works ✅
}
```

### Benefits
✅ **Simplest solution** - Just one boolean field
✅ **Clear semantics** - "Has provider responded?" is obvious
✅ **Easy migration** - Simple backfill from existing data
✅ **Patient app works** - Boolean never changes after TRUE
✅ **Provider workflow flexible** - Status can change freely

### Drawbacks
❌ **Redundant with provider_response** - Boolean duplicates info (provider_response != null)
❌ **Still have confusing status field** - Status still mixes workflow and response state

---

## Solution 3: Computed Column / Database View (NO CODE CHANGES)

### Approach
Add a generated column that automatically determines response status based on `provider_response` field.

### Schema Changes
```sql
-- Add generated column
ALTER TABLE provider_review_requests
ADD COLUMN has_response BOOLEAN GENERATED ALWAYS AS (
    provider_response IS NOT NULL AND provider_response != ''
) STORED;

-- Create index
CREATE INDEX idx_provider_review_has_response
ON provider_review_requests(conversation_id, has_response)
WHERE has_response = TRUE;
```

### Updated Patient App Code

**SupabaseService.swift:**
```swift
// BEFORE:
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&status=eq.responded&select=...")

// AFTER:
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&has_response=eq.true&select=...")
```

### Benefits
✅ **No provider app changes** - Generated column auto-updates
✅ **Always correct** - Can't get out of sync with provider_response
✅ **Simple patient app change** - Just change query filter
✅ **No data migration** - Computed on the fly

### Drawbacks
❌ **PostgreSQL specific** - Generated columns not in all databases
❌ **Slight performance cost** - Computed on every query (but indexed)
❌ **Less explicit** - Implicit behavior vs. explicit status

---

## Solution 4: Update Patient App Query (QUICK FIX)

### Approach
Change patient app to check for response existence, not status value.

### Patient App Code Changes

**SupabaseService.swift:**
```swift
// BEFORE (breaks when flagged):
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&status=eq.responded&select=...")

// AFTER (always works):
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&provider_response=not.is.null&select=...")
```

### Alternative - Fetch All and Filter Client-Side:
```swift
// Fetch without status filter
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&select=...")

// Filter in Swift
let reviews = try await fetchReviews(conversationId)
let respondedReview = reviews.first {
    $0.providerResponse != nil && !$0.providerResponse!.isEmpty
}
```

### Benefits
✅ **No database changes** - Works with existing schema
✅ **Quick to implement** - Only patient app code changes
✅ **Immediately effective** - Fixes issue in next patient app release

### Drawbacks
❌ **Doesn't fix root cause** - Status field still confusing
❌ **May fetch too much data** - Gets all reviews including flagged/dismissed
❌ **Client-side filtering** - Less efficient than database query
❌ **Fragile** - Assumes provider_response presence = valid response

---

## Comparison Matrix

| Solution | DB Changes | Provider App Changes | Patient App Changes | Complexity | Effectiveness |
|----------|------------|---------------------|---------------------|------------|---------------|
| **Solution 1: Separate Status Fields** | ✅ Required | ✅ Required | ✅ Required | High | ✅✅✅ Best |
| **Solution 2: Boolean Flag** | ✅ Required | ✅ Required | ✅ Required | Medium | ✅✅ Good |
| **Solution 3: Generated Column** | ✅ Required | ❌ None | ✅ Required | Low | ✅✅ Good |
| **Solution 4: Query Update** | ❌ None | ❌ None | ✅ Required | Low | ✅ Okay |

---

## Recommended Implementation Plan

### Phase 1: Immediate Fix (Solution 4)
**Timeline:** 1-2 hours
**Changes:** Patient app only

```swift
// Update patient app query to check for response existence
&provider_response=not.is.null
```

**Result:**
- ✅ Patient app shows responses even when flagged
- ✅ No database migration required
- ✅ Provider app continues working unchanged
- ⚠️ Doesn't fix root architectural issue

### Phase 2: Long-term Solution (Solution 2)
**Timeline:** 1-2 days
**Changes:** Database + both apps

**Step 1: Database Migration**
```sql
ALTER TABLE provider_review_requests
ADD COLUMN has_provider_response BOOLEAN DEFAULT FALSE;

UPDATE provider_review_requests
SET has_provider_response = TRUE
WHERE provider_response IS NOT NULL AND provider_response != '';

CREATE INDEX idx_provider_review_has_response
ON provider_review_requests(conversation_id, has_provider_response)
WHERE has_provider_response = TRUE;
```

**Step 2: Provider App Updates**
```swift
// When submitting response:
updatePayload["has_provider_response"] = true

// Flag/unflag operations:
// No changes needed - don't touch has_provider_response
```

**Step 3: Patient App Updates**
```swift
// Update query filter:
&has_provider_response=eq.true
```

**Result:**
- ✅ Clean separation of concerns
- ✅ Provider workflow doesn't affect patient visibility
- ✅ Explicit, clear field name
- ✅ Future-proof architecture

---

## Alternative: Solution 1 (Maximum Clarity)

For maximum clarity and long-term maintainability, implement Solution 1 (Separate Status Fields).

### Migration Script
```sql
-- Step 1: Add new columns
ALTER TABLE provider_review_requests
ADD COLUMN response_status TEXT DEFAULT 'pending',
ADD COLUMN provider_workflow_status TEXT;

-- Step 2: Migrate existing data
UPDATE provider_review_requests
SET
    response_status = CASE
        WHEN provider_response IS NOT NULL AND provider_response != '' THEN 'responded'
        ELSE 'pending'
    END,
    provider_workflow_status = status;

-- Step 3: Set constraints
ALTER TABLE provider_review_requests
ALTER COLUMN response_status SET NOT NULL;

-- Step 4: Create indexes
CREATE INDEX idx_provider_review_response_status
ON provider_review_requests(conversation_id, response_status);

CREATE INDEX idx_provider_workflow_status
ON provider_review_requests(provider_workflow_status);

-- Step 5 (Optional): Rename old status column for safety
ALTER TABLE provider_review_requests
RENAME COLUMN status TO status_deprecated;

-- Step 6 (After verification): Drop old column
-- ALTER TABLE provider_review_requests DROP COLUMN status_deprecated;
```

---

## Testing Strategy

### Test Case 1: Response Visibility During Flag
```
1. Provider responds to conversation
2. Verify patient app shows response ✅
3. Provider flags conversation
4. Verify patient app STILL shows response ✅
5. Provider unflags conversation
6. Verify patient app STILL shows response ✅
```

### Test Case 2: Multiple Flag/Unflag Cycles
```
1. Provider responds
2. Patient sees response ✅
3. Provider flags
4. Patient sees response ✅
5. Provider unflags
6. Patient sees response ✅
7. Provider flags again
8. Patient sees response ✅
```

### Test Case 3: Flag Before Response
```
1. Conversation is pending
2. Provider flags
3. Provider adds response
4. Patient sees response ✅
```

---

## Migration Risks

### Low Risk
- **Solution 4:** Query change only, no data migration
- **Solution 3:** Generated column, automatic

### Medium Risk
- **Solution 2:** Single boolean column, simple backfill

### High Risk
- **Solution 1:** Two new columns, complex migration

### Mitigation Strategies
1. **Test in staging first** - Don't apply to production immediately
2. **Backup database** - Full backup before migration
3. **Rollback plan** - Keep old columns until verified
4. **Gradual rollout** - Deploy patient app first, then provider app
5. **Monitor queries** - Watch for performance issues after index creation

---

## Rollback Plans

### Solution 1 or 2 Rollback
```sql
-- If migration fails, rollback:
ALTER TABLE provider_review_requests
DROP COLUMN IF EXISTS response_status,
DROP COLUMN IF EXISTS provider_workflow_status,
DROP COLUMN IF EXISTS has_provider_response;

-- Restore original app versions from git
```

### Solution 3 Rollback
```sql
-- Remove generated column
ALTER TABLE provider_review_requests
DROP COLUMN has_response;
```

### Solution 4 Rollback
```swift
// Revert patient app query to original:
&status=eq.responded
```

---

## Recommended Action

**Immediate:** Implement Solution 4 (query update) for quick fix
**Next Sprint:** Implement Solution 2 (boolean flag) for long-term solution

**Reasoning:**
1. Solution 4 fixes patient-facing issue immediately with minimal risk
2. Solution 2 provides clean architecture without over-engineering
3. Two-phase approach reduces migration risk
4. Allows time to test and validate before full migration

---

**Document Version:** 1.0
**Last Updated:** November 8, 2025
**Author:** Claude Code
**Related Docs:**
- FLAG_UNFLAG_ISSUE_HISTORY.md
- PATIENT_APP_FLAG_IMPACT_ANALYSIS.md

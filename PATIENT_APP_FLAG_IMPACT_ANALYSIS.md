# Patient App - Flag/Unflag Impact Analysis

**Document Created:** November 8, 2025
**Issue:** Provider flag/unflag operations affecting patient app conversation display
**Severity:** HIGH - Affects patient-facing functionality

---

## Executive Summary

The Clara patient app does NOT have flagging functionality - flagging is purely a provider-side workflow management tool. However, when providers flag/unflag conversations in the provider app, it changes the `status` field in the `provider_review_requests` table, which **breaks the patient app's ability to display provider responses**.

**Root Cause:** Patient app queries for `status=eq.responded` but flagging changes status to `"flagged"`, making the provider response invisible to patients even though it exists in the database.

---

## The Problem

### Patient App Query (SupabaseService.swift:158)
```swift
let url = URL(string: "\(projectURL)/rest/v1/provider_review_requests?conversation_id=eq.\(conversationId.uuidString.lowercased())&status=eq.responded&select=provider_name,provider_response,provider_urgency,responded_at")!
```

**Critical Filter:** `status=eq.responded`

**What This Means:**
- Patient app ONLY fetches provider responses where `status = "responded"`
- If status is anything else (`"flagged"`, `"pending"`, `"escalated"`, `"dismissed"`), response is invisible to patient
- Provider response data (`provider_response`, `provider_name`, etc.) exists but cannot be queried

### Provider App Status Changes

When provider flags a conversation (ProviderSupabaseService.swift:196):
```swift
func updateReviewStatus(id: String, status: String) async throws {
    var updatePayload: [String: Any] = [
        "status": status  // Changes from "responded" to "flagged"
    ]
    // ... PATCH to provider_review_requests table
}
```

**What Happens:**
1. Provider responds to conversation → `status = "responded"` → Patient sees response ✅
2. Provider flags conversation → `status = "flagged"` → Patient response disappears ❌
3. Provider unflags conversation → `status = "responded"` (restored) → Patient sees response again ✅

---

## Impact on Patient Experience

### Scenario 1: Provider Flags After Responding
```
Timeline:
1. Parent submits Clara conversation for provider review
2. Provider reviews and responds → status="responded"
3. Patient app shows provider response ✅
4. Provider flags for follow-up → status="flagged"
5. Patient app NO LONGER shows provider response ❌ (response disappears from UI)
6. Parent thinks provider hasn't responded yet
7. Parent may re-contact provider or feel ignored
```

### Scenario 2: Provider Unflags
```
Timeline:
1. Conversation is flagged (status="flagged")
2. Provider response exists but invisible to patient ❌
3. Provider unflags → status="responded"
4. Provider response suddenly appears to patient ✅
5. Patient confused why response appeared "late"
```

### Scenario 3: Provider Flags Before Responding
```
Timeline:
1. Conversation pending (status="pending")
2. Provider flags it → status="flagged"
3. Provider later responds with provider_response text
4. But status STAYS "flagged" (because flag was set first)
5. Patient NEVER sees the response ❌
```

---

## Database State vs. UI State

### What's IN the Database (Always Present)
```json
{
  "conversation_id": "uuid",
  "provider_response": "Your child should be seen today...",
  "provider_name": "Dr. Hobbs",
  "provider_urgency": "urgent",
  "responded_at": "2025-11-08T10:30:00Z",
  "status": "flagged"  // ⚠️ Prevents patient query
}
```

### What Patient App Sees (Only if status="responded")
```
If status="responded":  ✅ Shows response
If status="flagged":    ❌ Shows nothing (response invisible)
If status="pending":    ❌ Shows nothing
If status="escalated":  ❌ Shows nothing
If status="dismissed":  ❌ Shows nothing
```

---

## Why This Design Exists

### Provider App Perspective
- `status` field is used for **workflow management**
- Statuses track provider's internal workflow:
  - `"pending"` = Needs provider review
  - `"responded"` = Provider has responded
  - `"flagged"` = Flagged for provider follow-up/attention
  - `"escalated"` = Escalated for urgent attention
  - `"dismissed"` = Provider dismissed (no action needed)

### Patient App Perspective
- `status` field is used as a **filter** to determine if response exists
- Patient app assumes: `status="responded"` means "provider has responded"
- Patient app doesn't care about provider workflow states (shouldn't see "flagged", "escalated", etc.)

### The Mismatch
- **Provider app:** `status` = workflow state (flag for follow-up, even if already responded)
- **Patient app:** `status` = "has provider responded?" (binary: yes/no)
- **Result:** Provider workflow states hide patient-facing data

---

## Current Workarounds (Provider App)

### UserDefaults-Based Status Preservation
The provider app attempts to preserve original status when flagging:

```swift
// ProviderConversationStore.swift:507
let statusToStore = originalStatus ?? "responded"
UserDefaults.standard.set(statusToStore, forKey: "original_status_\(id.uuidString)")

// When unflagging (line 576):
let originalStatus = storedStatus ?? "responded"
try await supabaseService.updateReviewStatus(id: id.uuidString, status: originalStatus)
```

### Why This Doesn't Fully Work
1. **Only works in provider app** - Patient app doesn't know about UserDefaults
2. **Temporary solution** - Status still changes to "flagged" during flag period
3. **Doesn't prevent patient impact** - Response is hidden from patient while flagged
4. **Client-side only** - Database status changes regardless
5. **No guarantee** - If original status is nil, defaults to "responded" (good), but doesn't prevent initial flag from hiding response

---

## The Core Architecture Problem

### Single Field, Multiple Purposes
The `status` field is trying to serve two incompatible purposes:

**Purpose 1 (Provider):** Workflow management
- Track internal provider actions
- Flag items for follow-up
- Escalate urgent items
- Dismiss non-actionable items

**Purpose 2 (Patient):** Response existence check
- Has provider responded or not?
- Binary state needed
- Doesn't care about provider internal workflow

**Result:** These two purposes conflict
- Provider flags a responded conversation → Status changes from "responded" to "flagged"
- Patient query breaks → `status=eq.responded` no longer matches
- Response disappears from patient view

---

## Files Affected

### Patient App
1. **SupabaseService.swift (ClaraApp)**
   - Line 158: Provider response query with `status=eq.responded` filter

2. **SupabaseService.swift (ClaraSharedKit)**
   - Line 205: Duplicate provider response query with same filter
   - Line 255: Full provider review request query (includes status)

### Provider App
1. **ProviderSupabaseService.swift**
   - Lines 196-220: `updateReviewStatus()` - Changes status field
   - Lines 223-243: `updateFlagReason()` - Updates flag_reason but doesn't change status back

2. **ProviderConversationStore.swift**
   - Lines 485-509: `flagConversation()` - Changes status to "flagged"
   - Lines 574-582: `unflagConversation()` - Restores status (attempts to restore to "responded")

---

## Timeline of Patient App Impact

### Normal Flow (No Flagging)
```
1. Provider responds to conversation
   ├─ provider_response: "Take Tylenol and call if fever persists"
   ├─ provider_name: "Dr. Hobbs"
   ├─ status: "responded"
   └─ responded_at: "2025-11-08T10:00:00Z"

2. Patient app queries:
   └─ SELECT * FROM provider_review_requests
      WHERE conversation_id='...' AND status='responded'

3. Patient sees:
   ✅ "Dr. Hobbs responded: Take Tylenol and call if fever persists"
```

### Broken Flow (With Flagging)
```
1. Provider responds to conversation
   ├─ provider_response: "Take Tylenol and call if fever persists"
   ├─ provider_name: "Dr. Hobbs"
   ├─ status: "responded"  ← Initially correct
   └─ responded_at: "2025-11-08T10:00:00Z"

2. Provider flags conversation for follow-up
   ├─ provider_response: "Take Tylenol and call if fever persists" (unchanged)
   ├─ provider_name: "Dr. Hobbs" (unchanged)
   ├─ status: "flagged"  ← Changed! Breaks patient query
   ├─ flag_reason: "Need to check back on fever tomorrow"
   └─ responded_at: "2025-11-08T10:00:00Z" (unchanged)

3. Patient app queries:
   └─ SELECT * FROM provider_review_requests
      WHERE conversation_id='...' AND status='responded'

4. Patient sees:
   ❌ Nothing - query returns empty result
   ❌ Response exists in DB but is invisible
   ❌ Parent thinks provider hasn't responded

5. Provider unflags conversation
   ├─ provider_response: "Take Tylenol and call if fever persists" (unchanged)
   ├─ provider_name: "Dr. Hobbs" (unchanged)
   ├─ status: "responded"  ← Restored
   └─ responded_at: "2025-11-08T10:00:00Z" (unchanged)

6. Patient app queries again:
   └─ SELECT * FROM provider_review_requests
      WHERE conversation_id='...' AND status='responded'

7. Patient sees:
   ✅ "Dr. Hobbs responded: Take Tylenol and call if fever persists"
   ⚠️  But response "appeared late" from patient perspective
```

---

## Why Provider UserDefaults Doesn't Help Patient App

### Provider App Solution (Current)
```swift
// When flagging:
let originalStatus = conversation.status  // "responded"
UserDefaults.standard.set(originalStatus, ...)  // Save locally
updateStatus(to: "flagged")  // Change in DB

// When unflagging:
let savedStatus = UserDefaults.standard.string(...)  // "responded"
updateStatus(to: savedStatus)  // Restore in DB
```

### Why Patient App Still Breaks
1. **Database changes immediately** - Patient app queries DB, not provider's UserDefaults
2. **During flag period** - Status is "flagged" in DB, patient query fails
3. **Patient app is separate** - Has no access to provider's UserDefaults
4. **No coordination** - Patient app doesn't know provider flagged temporarily

### The Gap
```
Provider App State:
├─ UserDefaults: originalStatus = "responded" ← Saved locally
├─ Database: status = "flagged" ← What patient app sees
└─ Intent: "I want to follow up but patient should still see response"

Patient App State:
├─ No UserDefaults access
├─ Database query: status = "responded" ← Looking for this
├─ Query result: Empty ← Doesn't match "flagged"
└─ UI: "No provider response" ← Wrong!
```

---

## Edge Cases

### Edge Case 1: Multiple Flag/Unflag Cycles
```
1. Provider responds → status="responded" (patient sees ✅)
2. Provider flags → status="flagged" (patient doesn't see ❌)
3. Provider unflags → status="responded" (patient sees ✅)
4. Provider flags again → status="flagged" (patient doesn't see ❌)
5. Provider unflags again → status="responded" (patient sees ✅)

Result: Response visibility toggles on/off from patient perspective
```

### Edge Case 2: Flag Before Responding
```
1. Conversation is pending → status="pending"
2. Provider flags → status="flagged"
3. Provider adds provider_response text
4. Status stays "flagged" (flag happened first)
5. Patient NEVER sees response until unflagged ❌
```

### Edge Case 3: Provider App Reinstall/Data Loss
```
1. Provider responds → status="responded"
2. Provider flags → status="flagged", UserDefaults saves "responded"
3. Provider app deleted or UserDefaults cleared
4. Provider unflags → no saved status, defaults to "responded" ✅
5. Works by accident (default is correct), but fragile
```

---

## Current Status

**Issue Status:** ACTIVE - Patient app affected by provider flagging operations
**Workaround:** Provider app attempts to restore status, but doesn't prevent temporary invisibility
**Patient Impact:** Provider responses disappear when flagged, reappear when unflagged

---

## Related Documents

- `FLAG_UNFLAG_ISSUE_HISTORY.md` - Provider app bug fixes
- `DATABASE_SCHEMA_SOLUTIONS.md` - Proposed database solutions
- Patient app: `SupabaseService.swift:158` - Problematic query
- Provider app: `ProviderSupabaseService.swift:196` - Status update function

---

**Document Version:** 1.0
**Last Updated:** November 8, 2025
**Author:** Claude Code

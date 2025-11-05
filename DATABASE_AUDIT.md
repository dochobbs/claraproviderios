# clara-provider-app iOS - Database Audit Report

**Date**: November 2, 2025
**Database**: Supabase (dmfsaoawhomuxabhdubw)
**Records Analyzed**: 27 provider review requests

---

## Executive Summary

Your Supabase database contains **rich clinical data** in a single table (`provider_review_requests`), but many of your code's supporting tables are empty. The good news: you already have everything needed for your MVP. The opportunity: extracting more value from what's already there.

---

## Database Structure

### ✅ Tables With Data

#### 1. `provider_review_requests` (27 records)
**This is your core table**. It contains:

| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `id` | UUID | ✅ | Unique identifier |
| `user_id` | UUID | ✅ | Patient identifier |
| `conversation_id` | UUID | ✅ | Links to conversation |
| `conversation_title` | String | ✅ | Review request title |
| `child_name` | String | ✅ (sometimes null) | Patient name |
| `child_age` | String | ✅ | Formatted age (e.g., "8 years, 7 months") |
| `child_dob` | String | ✅ (sometimes null) | Date of birth |
| `triage_outcome` | String | ✅ | Classification (see breakdown below) |
| `conversation_messages` | JSON Array | ✅ | Full message history |
| `conversation_summary` | String | ✅ | AI-generated clinical summary |
| `status` | String | ✅ | pending, responded, dismissed, escalated |
| `provider_name` | String | ✅ (sometimes null) | Provider's name |
| `provider_response` | String | ✅ | Clinical feedback text |
| `provider_urgency` | String | ✅ (sometimes null) | Urgency level assigned |
| `responded_at` | Timestamp | ✅ | When provider responded |
| `created_at` | Timestamp | ✅ | When review was created |
| `device_token` | String | ✅ | APNs device token |
| `schedule_followup` | Boolean | ✅ | Follow-up needed? |
| `provider_push_sent` | Boolean | ✅ | Push notification sent? |
| `push_sent_at` | Timestamp | ✅ (sometimes null) | When notification sent |

### ❌ Tables That Are Empty

These tables exist in your code but have no data:

- **`patients`** - Expected to store full medical profiles (allergies, medications, conditions)
- **`follow_up_messages`** - Expected to store messages after initial review
- **`conversations`** - Expected to store conversation metadata separately

**Impact**: These aren't blocking MVP functionality, but they would enhance future features.

---

## Data Content Analysis

### Status Distribution
```
responded: 26 (96%)
dismissed:  1 (4%)
pending:    0 (0%)
escalated:  0 (0%)
flagged:    0 (0%)
```

**Insight**: Your review pipeline is working well - nearly all reviews get responses.

### Triage Outcome Distribution
```
home_care:        25 (93%)
routine_same_day:  2 (7%)
er_911:            0 (0%)
er_drive:          0 (0%)
urgent_visit:      0 (0%)
```

**Insight**: Most cases are low-risk. This is normal for a telemedicine triage system, but means your escalation workflows aren't heavily tested yet.

### Conversation Message Depth
- **Min messages per conversation**: 2
- **Max messages per conversation**: 8
- **Average messages per conversation**: 4.8

**Data Structure of Each Message**:
```json
{
  "content": "string",
  "is_from_user": boolean,
  "timestamp": "ISO8601",
  "image_url": "string (optional)"
}
```

### Provider Response Quality
All provider responses include signature format:
```
Clinical assessment text

— Dr [Name]
```

---

## What You Can Do RIGHT NOW

### 1. Extract Triage-to-Response Patterns
**Currently Unused**: You calculate `fetchDashboardStats()` but never use it.

```swift
// You already calculate this - just need to display it
pendingReviews: 0
respondedToday: 26
escalatedConversations: 0
averageResponseTime: ~10 minutes
```

**Action**: Add a dashboard view showing:
- Response times by provider
- Triage outcome agreement rates
- Time of day patterns

### 2. Implement Provider Performance Tracking
You have the data to answer:
- How often does Dr. Hobbs agree with triage outcome?
- Average response time per provider?
- Which case types get escalated most?

**Action**: Add analytics view with:
- Response time trends
- Case type distribution
- Triage agreement score

### 3. Create Patient Encounter History
You can fetch all reviews for a user_id.

**Action**: In `ConversationDetailView`, show:
- "This patient has 3 previous reviews"
- Last visit: "Head Injury Check - 2 days ago"
- Pattern: "Typically home care cases"

### 4. Add Conversation Summaries to List View
You're fetching `conversation_summary` but not displaying it.

**Action**: Show AI summary as preview in conversation list:
```
Title: Head Injury Check
Summary: 8yo fell and hit forehead. No LOC, mild sleepiness. Low risk.
Status: Responded by Dr Hobbs
```

---

## Data Quality Observations

### ✅ Strong Points
1. **Consistent timestamps** - All records have ISO8601 timestamps
2. **Message continuity** - Full conversation history preserved
3. **Provider attribution** - All responses attributed to provider
4. **Clinical summaries** - AI-generated summaries included
5. **Device tokens** - Push notification data captured

### ⚠️ Gaps & Inconsistencies
1. **Null child demographics** - Some records missing `child_name` or `child_dob`
   - Record 2 has no child info (generic acetaminophen question)
   - 85% have complete child info

2. **No follow-up outcome data** - Can't track what actually happened after provider response

3. **No medical history** - The `patients` table is empty, so no pre-populated allergies/medications

4. **No multi-provider tracking** - All responses are from same provider (Dr Michael Hobbs)
   - Would need provider authentication system to scale

---

## Recommendations

### Short Term (1-2 weeks)
1. **Display conversation summaries** in list view - you have this data
2. **Show provider stats dashboard** - calculate and display existing metrics
3. **Add related patient history** - show previous conversations for same user

### Medium Term (1 month)
1. **Implement actual follow-up tracking** - add outcome field to reviews
2. **Build provider authentication** - currently hardcoded to one provider
3. **Create patient medical history import** - populate `patients` table

### Long Term (3+ months)
1. **Add outcome analytics** - track what happened after provider response
2. **Implement peer comparison** - show how your provider compares to others
3. **Build clinical decision support** - recommend responses based on similar cases

---

## API Query Examples

All working queries you can use:

```swift
// Get all reviews (you do this)
GET /provider_review_requests?select=*&order=created_at.desc

// Get specific conversation
GET /provider_review_requests?conversation_id=eq.{uuid}

// Get reviews by status
GET /provider_review_requests?status=eq.pending

// Get reviews for specific user
GET /provider_review_requests?user_id=eq.{uuid}

// Update review status
PATCH /provider_review_requests?id=eq.{uuid}
{ "status": "responded", "provider_response": "..." }
```

---

## Technical Notes

### Why Other Tables Are Empty
These were probably scaffolded for future features but not yet populated:
- **patients table**: Would duplicate data already in provider_review_requests
- **follow_up_messages**: Not needed while all communication goes through web
- **conversations table**: Redundant - one review = one conversation

### Current Data Model is Actually Good
Your current approach of embedding `conversation_messages` in the review request is efficient because:
1. No extra queries needed
2. Message history won't change once review is created
3. One source of truth

---

## Summary Table: What's Available to Use

| Feature | Available? | Location | Status |
|---------|-----------|----------|--------|
| Review requests | ✅ Yes | `provider_review_requests` | Fully used |
| Conversation history | ✅ Yes | `provider_review_requests.conversation_messages` | Partially used |
| Triage outcomes | ✅ Yes | `provider_review_requests.triage_outcome` | Not analyzed |
| Provider responses | ✅ Yes | `provider_review_requests.provider_response` | Basic display only |
| Timestamps | ✅ Yes | `provider_review_requests.created_at`, `responded_at` | Not analyzed |
| Patient demographics | ✅ Partial | `provider_review_requests` | Name/age only, no medical history |
| Performance stats | ✅ Yes (calculated) | Service layer | Not displayed |
| Related cases | ✅ Yes (via user_id) | `provider_review_requests` | Not used |
| Conversation summaries | ✅ Yes | `provider_review_requests.conversation_summary` | Not displayed |
| Follow-up messages | ❌ No | `follow_up_messages` (empty) | Not applicable |
| Medical history | ❌ No | `patients` (empty) | Future feature |

---

**Report Generated**: November 2, 2025
**Tool**: Claude Code Database Audit

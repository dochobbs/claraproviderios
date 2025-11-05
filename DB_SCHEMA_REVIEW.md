# Database Schema Review - Issues and Recommendations

## Critical Issues

### 1. `provider_review_requests` - Missing FK constraint on conversation_id
- **Problem:** `conversation_id uuid NOT NULL` has no FOREIGN KEY to `conversations(id)`
- **Impact:** Allows orphaned records if a conversation is deleted
- **Fix:** Add constraint:
  ```sql
  CONSTRAINT provider_review_requests_conversation_id_fkey
    FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
  ```

### 2. `children` - Duplicate and conflicting columns
- **Problem:**
  - `child_name` duplicates functionality of `name`
  - `patient_id` references `patients(id)` suggesting children are patients
  - Unclear data model relationship
- **Impact:** Data inconsistency, confusion about source of truth
- **Fix:** Clarify the relationship or consolidate columns

### 3. `messages` and `follow_up_messages` - Inconsistent timestamp handling
- **Problem:** Both tables have redundant timestamp columns:
  - `messages`: has both `created_at` and `timestamp` (both with time zone)
  - `follow_up_messages`: has both `created_at` and `timestamp` (both with time zone)
- **Impact:** Confusing which column to use, potential data inconsistency
- **Fix:** Use one consistent timestamp column per table, standardize naming

### 4. `conversations` - Duplicate follow-up columns
- **Problem:**
  - Both `followup_date` and `follow_up_date` exist
  - Both `has_scheduled_followup` and `has_scheduled_follow_up` exist
- **Impact:** Data redundancy, confusion about source of truth
- **Fix:** Remove duplicates (prefer snake_case for consistency)

### 5. `follow_up_requests` - Missing FK on conversation_id
- **Problem:** `conversation_id uuid NOT NULL` but no FOREIGN KEY constraint
- **Impact:** Orphaned records possible, referential integrity not enforced
- **Fix:** Add constraint:
  ```sql
  CONSTRAINT follow_up_requests_conversation_id_fkey
    FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
  ```

### 6. `follow_up_messages` - Missing FK on conversation_id
- **Problem:** `conversation_id uuid NOT NULL` but no FOREIGN KEY constraint
- **Impact:** Orphaned records possible, referential integrity not enforced
- **Fix:** Add constraint:
  ```sql
  CONSTRAINT follow_up_messages_conversation_id_fkey
    FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
  ```

---

## Data Model Issues

### 7. `escalations` - Invalid severity type value
- **Problem:** `severity USER-DEFINED DEFAULT 'moderate'::urgency_level`
- **Issue:** The value 'moderate' may not exist in the `urgency_level` enum
- **Likely values:** 'routine', 'urgent', 'high', etc. (depends on enum definition)
- **Fix:** Check enum definition and update to valid value

### 8. `children` vs `patients` - Unclear relationship
- **Problem:**
  - `children` table has `patient_id FK` pointing to `patients(id)`
  - `patients` table has adult-oriented fields (name, email, phone)
  - Suggests patients might be parents, not children
- **Impact:** Confusing data model, potential for incorrect queries
- **Questions to clarify:**
  - Are patients the parents of children?
  - Or should patients reference children?
  - Can a patient have multiple children?
- **Recommendation:** Rename tables or add clarifying comments, consider `parent_patients` if patients are parents

### 9. `follow_up_requests` and `follow_up_messages` - user_id type mismatch
- **Problem:**
  - `follow_up_requests.user_id` is `text NOT NULL`
  - `follow_up_messages.user_id` is `text NOT NULL`
  - `user_profiles.id` is `uuid`
- **Impact:** Cannot properly join/reference users, type inconsistency
- **Fix:** Change both to `uuid` and add FK constraints:
  ```sql
  CONSTRAINT follow_up_requests_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.user_profiles(id),

  CONSTRAINT follow_up_messages_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.user_profiles(id)
  ```

---

## Redundancy Issues

### 10. `children` - JSONB duplication with dedicated tables
- **Problem:**
  - JSONB columns: `challenges`, `allergies`, `medications`, `past_conditions`
  - Dedicated tables exist: `allergies`, `medications`, `problem_list`
  - Data is stored in two places
- **Impact:** Hard to maintain, inconsistent updates, query complexity
- **Options:**
  1. Remove JSONB columns and query from dedicated tables
  2. Remove dedicated tables and use JSONB only (not recommended for relational queries)
  3. Document which is source of truth and deprecate the other
- **Recommendation:** Use dedicated tables for relational integrity and querying

### 11. `user_profiles` - Duplicate phone columns
- **Problem:** Both `phone` and `phone_number` exist
- **Impact:** Unclear which is authoritative, potential data inconsistency
- **Fix:** Keep one consistent column name (prefer `phone_number` for clarity)

---

## Missing Constraints

### 12. `messages` - No FK to user or sender
- **Problem:**
  - Has `is_from_user` boolean but no way to know which user sent it
  - `provider_name` is stored as text instead of FK
- **Recommendation:** Consider adding:
  ```sql
  user_id uuid,
  CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(id)
  ```

---

## Summary of Priority Fixes

### 🔴 High Priority (Referential Integrity)
1. Add missing FKs:
   - `provider_review_requests.conversation_id` → `conversations(id)`
   - `follow_up_requests.conversation_id` → `conversations(id)`
   - `follow_up_messages.conversation_id` → `conversations(id)`
   - `follow_up_requests.user_id` (change type to uuid)
   - `follow_up_messages.user_id` (change type to uuid)

2. Fix user_id type consistency across all tables (text → uuid)

### 🟡 Medium Priority (Data Consistency)
1. Resolve `children` vs `patients` relationship confusion
2. Remove duplicate columns:
   - `conversations`: keep only `follow_up_date` and `has_scheduled_follow_up`
   - `messages` & `follow_up_messages`: keep only `created_at` or `timestamp` (standardize)
   - `user_profiles`: keep only `phone_number`

3. Clarify JSONB fields in `children` - consolidate with or remove from dedicated tables

### 🟢 Low Priority (Code Quality)
1. Update enum values to match actual type definitions
2. Add clarifying comments for complex relationships
3. Standardize naming conventions (snake_case preferred)
4. Add missing FKs for `messages.provider_name` if tracking provider who sent message

---

## Recommended Next Steps

1. **Run a constraint verification query** to identify all orphaned records
2. **Map out the actual business relationships** (especially children ↔ patients ↔ users)
3. **Create a migration script** to:
   - Add missing FKs
   - Fix type mismatches
   - Consolidate duplicate columns
   - Consolidate JSONB redundancy
4. **Add data validation** before and after migration
5. **Update application code** to use correct column names after cleanup

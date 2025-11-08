-- Database Cleanup Script for Flag/Unflag Migration
-- Run this in Supabase SQL Editor to fix any legacy status='flagged' records
-- Date: November 8, 2025

-- ============================================================================
-- STEP 1: INSPECTION - Check for problematic records
-- ============================================================================

-- Find conversations with status='flagged' (should not exist after migration)
SELECT
    conversation_id,
    status,
    is_flagged,
    provider_response IS NOT NULL as has_response,
    provider_response,
    flagged_at,
    unflagged_at,
    created_at
FROM provider_review_requests
WHERE status = 'flagged'
ORDER BY created_at DESC;

-- Count by status to see distribution
SELECT
    status,
    COUNT(*) as count,
    COUNT(CASE WHEN is_flagged = true THEN 1 END) as flagged_count,
    COUNT(CASE WHEN provider_response IS NOT NULL THEN 1 END) as response_count
FROM provider_review_requests
GROUP BY status
ORDER BY count DESC;

-- Find mismatches where response exists but status != 'responded'
SELECT
    conversation_id,
    status,
    is_flagged,
    provider_response,
    created_at
FROM provider_review_requests
WHERE provider_response IS NOT NULL
  AND provider_response != ''
  AND status != 'responded'
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 2: BACKUP - Create backup before cleanup
-- ============================================================================

-- Create a backup table (optional but recommended)
CREATE TABLE IF NOT EXISTS provider_review_requests_backup_20251108 AS
SELECT * FROM provider_review_requests
WHERE status = 'flagged';

-- Verify backup
SELECT COUNT(*) as backed_up_count
FROM provider_review_requests_backup_20251108;

-- ============================================================================
-- STEP 3: CLEANUP - Fix legacy 'flagged' status records
-- ============================================================================

-- Update records with status='flagged' and provider_response to 'responded'
UPDATE provider_review_requests
SET status = 'responded'
WHERE status = 'flagged'
  AND provider_response IS NOT NULL
  AND provider_response != '';

-- Update records with status='flagged' and no provider_response to 'pending'
UPDATE provider_review_requests
SET status = 'pending'
WHERE status = 'flagged'
  AND (provider_response IS NULL OR provider_response = '');

-- ============================================================================
-- STEP 4: VERIFICATION - Confirm cleanup worked
-- ============================================================================

-- Should return 0 rows
SELECT COUNT(*) as remaining_flagged_count
FROM provider_review_requests
WHERE status = 'flagged';

-- Verify all flagged conversations now have proper status
SELECT
    status,
    is_flagged,
    COUNT(*) as count
FROM provider_review_requests
WHERE is_flagged = true
GROUP BY status, is_flagged
ORDER BY count DESC;

-- Check for any remaining inconsistencies
SELECT
    conversation_id,
    status,
    is_flagged,
    provider_response IS NOT NULL as has_response
FROM provider_review_requests
WHERE (provider_response IS NOT NULL AND status NOT IN ('responded', 'escalated'))
   OR (provider_response IS NULL AND status = 'responded')
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 5: ANALYTICS - Post-cleanup summary
-- ============================================================================

-- Summary of all records
SELECT
    status,
    is_flagged,
    COUNT(*) as count
FROM provider_review_requests
GROUP BY status, is_flagged
ORDER BY status, is_flagged;

-- Expected output:
-- status     | is_flagged | count
-- -----------|------------|-------
-- pending    | false      | X
-- pending    | true       | X
-- responded  | false      | X
-- responded  | true       | X  (flagged responses)
-- escalated  | false      | X
-- escalated  | true       | X
-- dismissed  | false      | X
-- dismissed  | true       | X

-- ============================================================================
-- ROLLBACK (if something goes wrong)
-- ============================================================================

-- Restore from backup (only if cleanup went wrong)
-- UPDATE provider_review_requests prr
-- SET status = 'flagged'
-- FROM provider_review_requests_backup_20251108 bak
-- WHERE prr.conversation_id = bak.conversation_id;

-- ============================================================================
-- CLEANUP BACKUP TABLE (after verifying everything works)
-- ============================================================================

-- After 1-2 weeks of successful operation, remove backup:
-- DROP TABLE provider_review_requests_backup_20251108;

-- RLS Policy for provider_review_requests table
-- This allows the 'anon' role (used by your iOS app) to read all provider review requests

-- First, enable RLS on the table if not already enabled
ALTER TABLE provider_review_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists (to avoid conflicts)
DROP POLICY IF EXISTS "Allow anon read access to provider_review_requests" ON provider_review_requests;

-- Create a new policy that allows anonymous users to read all provider review requests
CREATE POLICY "Allow anon read access to provider_review_requests"
ON provider_review_requests
FOR SELECT
TO anon
USING (true);

-- Optional: Also allow authenticated users to read (if you add auth later)
DROP POLICY IF EXISTS "Allow authenticated read access to provider_review_requests" ON provider_review_requests;

CREATE POLICY "Allow authenticated read access to provider_review_requests"
ON provider_review_requests
FOR SELECT
TO authenticated
USING (true);

-- Optional: Allow service role full access (for backend operations)
DROP POLICY IF EXISTS "Allow service role full access to provider_review_requests" ON provider_review_requests;

CREATE POLICY "Allow service role full access to provider_review_requests"
ON provider_review_requests
FOR ALL
TO service_role
USING (true);


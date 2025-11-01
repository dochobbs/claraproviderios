# How to Change RLS Policies for provider_review_requests

## Option 1: Using Supabase Dashboard (Recommended)

1. **Go to Supabase Dashboard**
   - Navigate to: https://app.supabase.com/
   - Log in to your account
   - Select your project: `dmfsaoawhomuxabhdubw`

2. **Navigate to Table Editor**
   - Click "Table Editor" in the left sidebar
   - Or go to: Database → Tables

3. **Select the `provider_review_requests` table**
   - Click on `provider_review_requests` in the table list

4. **Open the Policies Tab**
   - Click the "Policies" tab (next to "Table", "Columns", etc.)

5. **Review Existing Policies**
   - Check if there are any existing policies
   - If a policy blocks `anon` from reading, you need to modify or create a new one

6. **Create a New Policy**
   - Click "New Policy" button
   - Choose "Create a policy from scratch"
   - **Policy Name**: `Allow anon read access to provider_review_requests`
   - **Allowed operation**: Select `SELECT` (for reading)
   - **Target roles**: Select `anon` (and optionally `authenticated`)
   - **USING expression**: Enter `true` (this allows reading all rows)
   - Click "Review" then "Save Policy"

7. **Verify the Policy**
   - The policy should now appear in the list
   - Make sure it shows: `anon` role with `SELECT` operation

## Option 2: Using SQL Editor (Faster)

1. **Go to Supabase Dashboard**
   - Navigate to: https://app.supabase.com/
   - Select your project

2. **Open SQL Editor**
   - Click "SQL Editor" in the left sidebar
   - Or go to: Database → SQL Editor

3. **Run the SQL Script**
   - Copy and paste the contents of `provider_review_requests_rls_policy.sql`
   - Click "Run" or press Cmd/Ctrl + Enter

4. **Verify**
   - Check that the query executed successfully
   - Go back to Table Editor → Policies tab to confirm the policy exists

## Troubleshooting

**If you still get "data couldn't be read" error:**

1. **Check RLS is enabled**: The table must have RLS enabled for policies to work
2. **Check policy target**: Make sure the policy targets `anon` role (not just `authenticated`)
3. **Check USING expression**: Should be `true` for allowing all reads, or a specific condition
4. **Try refreshing**: After creating/modifying policies, wait a few seconds and refresh your app

**For testing purposes only:**
- You can temporarily disable RLS: `ALTER TABLE provider_review_requests DISABLE ROW LEVEL SECURITY;`
- ⚠️ **WARNING**: Only do this for testing! Never disable RLS in production.

## What the Policy Does

The policy allows:
- ✅ `anon` role: Can read (`SELECT`) all provider review requests
- ✅ `authenticated` role: Can read all provider review requests (if you add auth later)
- ✅ `service_role`: Has full access (for backend operations)

This means your iOS app using the `anon` API key can now fetch all 23 provider review requests.


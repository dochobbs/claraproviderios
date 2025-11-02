# Push Notification Setup Guide

## Overview
This guide explains how to set up push notifications for the Clara Provider app using Supabase webhooks. When a new review request is created, a webhook will trigger a push notification to be sent to the provider's device.

## Architecture

```
Patient App → Creates Review Request → Supabase Database
                                              ↓
                                    Database Trigger/Webhook
                                              ↓
                                    Supabase Edge Function
                                              ↓
                                    APNs → Provider Device
```

## Step 1: Store Device Token in Supabase

First, we need to store provider device tokens in Supabase so the webhook knows where to send notifications.

### Option A: Create a `providers` table (Recommended)

```sql
-- Create providers table
CREATE TABLE IF NOT EXISTS public.providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT UNIQUE NOT NULL, -- Provider's user identifier
    device_token TEXT, -- APNs device token
    device_type TEXT DEFAULT 'ios',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.providers ENABLE ROW LEVEL SECURITY;

-- Policy: Providers can read/update their own record
CREATE POLICY "Providers manage own tokens"
ON public.providers
FOR ALL
USING (auth.uid()::text = user_id);

-- Create index for faster lookups
CREATE INDEX idx_providers_user_id ON public.providers(user_id);
CREATE INDEX idx_providers_device_token ON public.providers(device_token);
```

### Option B: Add to existing table (if you have a providers/users table)

Just add these columns:
```sql
ALTER TABLE public.providers 
ADD COLUMN IF NOT EXISTS device_token TEXT,
ADD COLUMN IF NOT EXISTS device_type TEXT DEFAULT 'ios';
```

## Step 2: Update App to Register Device Token

The app will automatically send the device token to Supabase when it's received. See `ProviderSupabaseService.swift` for the implementation.

## Step 3: Set Up Supabase Webhook

### 3.1 Create Supabase Edge Function

Create a new Edge Function in your Supabase project:

**Function name:** `send-provider-notification`

**Code:** `supabase/functions/send-provider-notification/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get the review request data from webhook payload
    const { record } = await req.json()
    
    if (!record) {
      throw new Error('No record in webhook payload')
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all provider device tokens
    // Note: In production, you might want to filter by specific provider IDs
    const { data: providers, error: providerError } = await supabase
      .from('providers')
      .select('device_token')
      .not('device_token', 'is', null)

    if (providerError) {
      throw providerError
    }

    if (!providers || providers.length === 0) {
      console.log('No provider device tokens found')
      return new Response(
        JSON.stringify({ message: 'No providers registered' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Prepare notification payload
    const conversationTitle = record.conversation_title || record.child_name || 'New Review Request'
    const childName = record.child_name || 'Patient'
    
    const notificationPayload = {
      title: 'New Review Request',
      body: `${childName}: ${conversationTitle}`,
      data: {
        conversationId: record.conversation_id,
        type: 'review_request'
      },
      sound: 'default',
      badge: 1
    }

    // Send push notification to all registered providers
    // Note: Supabase has built-in push notification support
    // You can use Supabase's push notification API or send directly to APNs
    
    // Option 1: Use Supabase Push Notifications (if configured)
    const { data: pushResult, error: pushError } = await supabase.functions.invoke('send-push', {
      body: {
        tokens: providers.map(p => p.device_token),
        payload: notificationPayload
      }
    })

    // Option 2: Send directly to APNs (requires APNs certificate configuration)
    // See Step 4 for APNs direct integration

    if (pushError) {
      console.error('Push notification error:', pushError)
      throw pushError
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        sentTo: providers.length,
        message: 'Notifications sent' 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
```

### 3.2 Deploy Edge Function

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Deploy the function
supabase functions deploy send-provider-notification
```

### 3.3 Configure Database Webhook

In Supabase Dashboard:

1. Go to **Database** → **Webhooks**
2. Click **Create a new webhook**
3. Configure:
   - **Name**: `new-review-request-notification`
   - **Table**: `provider_review_requests`
   - **Events**: `INSERT`
   - **Type**: `HTTP Request`
   - **URL**: `https://[your-project-ref].supabase.co/functions/v1/send-provider-notification`
   - **HTTP Method**: `POST`
   - **HTTP Headers**: 
     ```
     Authorization: Bearer [your-service-role-key]
     Content-Type: application/json
     ```
   - **HTTP Request Body**:
     ```json
     {
       "record": {
         "id": "{{ $new.id }}",
         "conversation_id": "{{ $new.conversation_id }}",
         "conversation_title": "{{ $new.conversation_title }}",
         "child_name": "{{ $new.child_name }}",
         "user_id": "{{ $new.user_id }}"
       }
     }
     ```

## Step 4: Configure APNs in Supabase

### 4.1 Generate APNs Certificate

1. **Generate Certificate Request**
   - Open Keychain Access (Applications → Utilities)
   - Keychain Access → Certificate Assistant → Request Certificate from CA
   - Email: Your Apple ID email
   - Save as `CertificateSigningRequest.certSigningRequest`

2. **Create APNs Certificate in Apple Developer Portal**
   - Visit [developer.apple.com](https://developer.apple.com)
   - Certificates, IDs & Profiles → Certificates → "+"
   - Select "Apple Push Notification service SSL (Sandbox & Production)"
   - Select your App ID: `vital.Clara-Provider`
   - Upload certificate request
   - Download: `aps_development.cer`

3. **Export Certificate**
   - Double-click `aps_development.cer` to add to Keychain
   - In Keychain Access, find the certificate
   - Right-click → Export "Apple Push Notification service SSL..."
   - Format: `.p12`
   - Set password (remember this!)
   - Save as `APNs_Certificate.p12`

### 4.2 Upload to Supabase

1. Go to **Project Settings** → **Apple**
2. Upload `APNs_Certificate.p12`
3. Enter the password you set
4. Select certificate type: **Development** (or **Production** for App Store builds)

## Step 5: Test the Setup

### 5.1 Test Device Token Registration

1. Run the app on a physical device
2. Grant notification permissions
3. Check Xcode console for: `📱 Provider device token: [token]`
4. Verify token is stored in Supabase:
   ```sql
   SELECT * FROM public.providers WHERE device_token IS NOT NULL;
   ```

### 5.2 Test Webhook

1. Create a test review request in Supabase:
   ```sql
   INSERT INTO public.provider_review_requests (
     user_id, 
     conversation_id, 
     conversation_title,
     child_name,
     status
   ) VALUES (
     'test-user-id',
     gen_random_uuid()::text,
     'Test Review Request',
     'Test Patient',
     'pending'
   );
   ```

2. Check Supabase Edge Function logs:
   - Go to **Edge Functions** → `send-provider-notification` → **Logs**
   - Should see the function being called

3. Check device for notification:
   - Should receive push notification within seconds
   - Tapping notification should open the conversation

## Troubleshooting

### Notifications not arriving

1. **Check device token registration:**
   ```sql
   SELECT user_id, device_token, updated_at 
   FROM public.providers 
   ORDER BY updated_at DESC;
   ```

2. **Check webhook logs:**
   - Database → Webhooks → Click webhook → View logs

3. **Check Edge Function logs:**
   - Edge Functions → Function → Logs

4. **Verify APNs certificate:**
   - Project Settings → Apple → Should show certificate status

5. **Check notification permissions:**
   - Device Settings → Clara Provider → Notifications → Should be ON

### Webhook not triggering

1. Verify webhook is enabled (toggle ON in dashboard)
2. Check webhook event type matches (`INSERT`)
3. Verify table name is correct (`provider_review_requests`)
4. Test webhook manually in dashboard

### Edge Function errors

1. Check function logs for error messages
2. Verify service role key is correct
3. Check Supabase URL is correct
4. Verify `providers` table exists and has data

## Alternative: Direct APNs Integration

If you prefer not to use Supabase's push notification service, you can send directly to APNs from the Edge Function. This requires:

1. Converting `.p12` certificate to `.p8` key (for token-based auth) or using `.p12` directly
2. Implementing APNs HTTP/2 API calls in the Edge Function
3. Handling APNs response codes and errors

See Apple's documentation: https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server

## Next Steps

1. ✅ Set up `providers` table in Supabase
2. ✅ Update app to register device tokens
3. ✅ Create Edge Function
4. ✅ Configure database webhook
5. ✅ Upload APNs certificate
6. ✅ Test end-to-end

Once complete, you'll receive push notifications whenever a new review request is created!


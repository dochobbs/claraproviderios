# Follow-up System Backend Requirements

## Overview
The Clara Provider app now includes a complete follow-up scheduling system that allows providers to schedule check-in messages for parents at specific times. The iOS app handles the scheduling interface, but **the backend must handle the actual message delivery**.

## Database Tables

### `follow_up_requests`
Stores scheduled follow-up requests created by providers.

**Key Columns:**
- `id` (uuid): Unique identifier
- `conversation_id` (uuid): Links to the conversation
- `user_id` (text): Parent/patient user ID
- `scheduled_for` (timestamp with time zone): When to send the message
- `urgency` (text): "routine" or "urgent"
- `display_text` (text): The message to send to the parent
- `original_message` (text): Copy of the message
- `status` (text): "scheduled", "sent", or "cancelled"
- `child_name` (text): Optional child name
- `child_age` (text): Optional child age
- `device_token` (text): Optional device token for push notifications
- `follow_up_days`, `follow_up_hours`, `follow_up_minutes` (integer): Time breakdown
- `created_at`, `sent_at` (timestamp): Tracking timestamps

### `provider_review_requests`
Updated with a boolean flag to indicate follow-ups are scheduled.

**Key Column:**
- `schedule_followup` (boolean): True when a follow-up is scheduled

## Backend Requirements

### 1. **Polling Service** (Required)
The backend must implement a polling service that:

1. **Queries for pending follow-ups:**
   ```sql
   SELECT * FROM follow_up_requests
   WHERE status = 'scheduled'
   AND scheduled_for <= NOW()
   ORDER BY scheduled_for ASC;
   ```

2. **For each pending follow-up:**
   - Send the message to the parent (via push notification, SMS, or in-app message)
   - Create an entry in `follow_up_messages` table
   - Update `follow_up_requests.status` to "sent"
   - Set `follow_up_requests.sent_at` to current timestamp

3. **Recommended polling interval:** Every 1-5 minutes

### 2. **Message Delivery** (Required)
When sending a follow-up message:

**Option A: Push Notification**
```json
{
  "to": "<device_token from follow_up_requests>",
  "notification": {
    "title": "Follow-up from Dr. <provider_name>",
    "body": "<display_text from follow_up_requests>",
    "sound": "default"
  },
  "data": {
    "conversation_id": "<conversation_id>",
    "type": "follow_up",
    "follow_up_id": "<id>"
  }
}
```

**Option B: Create follow_up_messages entry**
```sql
INSERT INTO follow_up_messages (
  conversation_id,
  user_id,
  message_content,
  is_from_user,
  follow_up_id,
  timestamp
) VALUES (
  '<conversation_id>',
  '<user_id>',
  '<display_text>',
  false,  -- message from provider
  '<follow_up_request_id>',
  NOW()
);
```

### 3. **Error Handling** (Required)
- **Failed delivery**: Update status to "failed", log error
- **Retries**: Implement retry logic (3 attempts with exponential backoff)
- **Invalid device token**: Mark as "failed", notify admin
- **Cancelled follow-ups**: Skip, already marked as "cancelled" by iOS app

### 4. **Cleanup** (Recommended)
- Archive or delete sent/cancelled follow-ups older than 90 days
- Keep failed follow-ups for debugging

## iOS App Behavior

### Scheduling a Follow-up
1. Provider long-presses conversation row
2. Selects "Schedule Follow-up" from context menu
3. Fills in message, selects time, chooses urgency
4. Taps "Schedule" button

**What happens:**
- Creates entry in `follow_up_requests` with status="scheduled"
- Sets `provider_review_requests.schedule_followup = true`
- Blue clock badge appears on conversation row
- Conversation appears in "Follow-ups" filter tab

### Cancelling a Follow-up
1. Provider taps the blue clock badge

**What happens:**
- Updates `follow_up_requests.status` to "cancelled"
- Sets `provider_review_requests.schedule_followup = false`
- Clock badge disappears immediately
- Conversation removed from "Follow-ups" filter tab

## Implementation Example (Python/FastAPI)

```python
import asyncio
from datetime import datetime
from typing import List

async def poll_and_send_follow_ups():
    """Poll for pending follow-ups and send them"""
    while True:
        try:
            # Query pending follow-ups
            pending = await db.fetch_all("""
                SELECT * FROM follow_up_requests
                WHERE status = 'scheduled'
                AND scheduled_for <= NOW()
                ORDER BY scheduled_for ASC
                LIMIT 100
            """)

            for follow_up in pending:
                try:
                    # Send the message
                    await send_follow_up_message(
                        user_id=follow_up['user_id'],
                        message=follow_up['display_text'],
                        conversation_id=follow_up['conversation_id'],
                        device_token=follow_up['device_token']
                    )

                    # Mark as sent
                    await db.execute("""
                        UPDATE follow_up_requests
                        SET status = 'sent', sent_at = NOW()
                        WHERE id = $1
                    """, follow_up['id'])

                    # Create follow_up_messages entry
                    await db.execute("""
                        INSERT INTO follow_up_messages (
                            conversation_id, user_id, message_content,
                            is_from_user, follow_up_id, timestamp
                        ) VALUES ($1, $2, $3, false, $4, NOW())
                    """,
                        follow_up['conversation_id'],
                        follow_up['user_id'],
                        follow_up['display_text'],
                        follow_up['id']
                    )

                except Exception as e:
                    # Mark as failed
                    await db.execute("""
                        UPDATE follow_up_requests
                        SET status = 'failed'
                        WHERE id = $1
                    """, follow_up['id'])
                    print(f"Failed to send follow-up {follow_up['id']}: {e}")

        except Exception as e:
            print(f"Polling error: {e}")

        # Wait before next poll
        await asyncio.sleep(60)  # Poll every minute

async def send_follow_up_message(user_id: str, message: str, conversation_id: str, device_token: str = None):
    """Send follow-up message via push notification or other channel"""
    if device_token:
        # Send push notification
        await push_notification_service.send(
            token=device_token,
            title="Follow-up from your provider",
            body=message,
            data={"conversation_id": conversation_id, "type": "follow_up"}
        )
    else:
        # Fallback: Store in follow_up_messages for in-app retrieval
        pass
```

## Testing

### Manual Test Flow
1. Schedule a follow-up for "In 1 hour"
2. Backend should detect it after 1 hour
3. Message should be sent to parent
4. Status should update to "sent"
5. Clock badge should remain visible (follow-up still in history)

### Edge Cases to Handle
- **Cancelled before sending**: Status="cancelled", skip sending
- **No device token**: Use fallback delivery method
- **Past scheduled time**: Send immediately when detected
- **Multiple pending for same conversation**: Send all in order

## Monitoring & Alerts
- Track follow-up send success rate
- Alert if success rate drops below 95%
- Alert if polling service stops
- Log all failed deliveries for debugging

---

**Last Updated:** November 9, 2025
**iOS App Version:** Includes complete scheduling & cancellation UI
**Backend Status:** ⚠️ Requires implementation

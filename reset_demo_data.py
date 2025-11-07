#!/usr/bin/env python3
"""
Reset demo/test data in Supabase for Clara Provider App

This script:
1. Deletes all existing test conversations (identified by user_id = 'test_provider_001')
2. Recreates the 6 standard demo patients

Run this whenever you want to reset to a clean demo state.
"""

import os
import sys

# Check for supabase module
try:
    from supabase import create_client, Client
except ImportError:
    print("ERROR: supabase module not found")
    print("Run: source .venv/bin/activate && pip install supabase")
    sys.exit(1)

# Import the demo data creator
try:
    from create_test_conversations import TEST_CONVERSATIONS, create_conversation_messages, SUPABASE_URL
except ImportError:
    print("ERROR: create_test_conversations.py not found")
    sys.exit(1)

from datetime import datetime, timedelta
import uuid

SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_KEY:
    print("ERROR: Please set SUPABASE_KEY environment variable")
    print("export SUPABASE_KEY='your-supabase-anon-key'")
    sys.exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)


def delete_test_conversations():
    """Delete all test conversations from the database"""
    print("🗑️  Deleting existing test conversations...")

    try:
        # Delete all conversations with test_provider_001 user_id
        result = supabase.table("provider_review_requests").delete().eq("user_id", "test_provider_001").execute()
        print(f"✅ Deleted {len(result.data) if result.data else 0} test conversations")
    except Exception as e:
        print(f"⚠️  Warning during deletion: {e}")
        print("   (This is normal if no test data exists yet)")


def create_demo_conversations():
    """Create the 10 standard demo patient conversations"""
    print("\n📝 Creating 10 demo patient conversations...")

    for idx, conv in enumerate(TEST_CONVERSATIONS, 1):
        try:
            conversation_id = str(uuid.uuid4())

            # Prepare the data
            data = {
                "conversation_id": conversation_id,
                "user_id": "test_provider_001",
                "conversation_title": conv["conversation_title"],
                "child_name": conv["child_name"],
                "child_age": conv["child_age"],
                "child_dob": conv["child_dob"],
                "triage_outcome": conv["triage_outcome"],
                "conversation_summary": conv["conversation_summary"],
                "conversation_messages": create_conversation_messages(conv["messages"]),
                "status": conv["status"],
                "created_at": datetime.now().astimezone().isoformat()
            }

            # Add optional fields if present
            if "provider_response" in conv:
                data["provider_response"] = conv["provider_response"]
            if "provider_name" in conv:
                data["provider_name"] = conv["provider_name"]
            if "responded_at" in conv:
                # Convert relative time to absolute
                hours_ago = 2 if idx <= 3 else 5
                data["responded_at"] = (datetime.now().astimezone() - timedelta(hours=hours_ago)).isoformat()
            if "flag_reason" in conv:
                data["flag_reason"] = conv["flag_reason"]

            # Insert into Supabase
            result = supabase.table("provider_review_requests").insert(data).execute()

            status_icon = "⏳" if conv['status'] == 'pending' else "✅" if conv['status'] == 'responded' else "🚩"
            print(f"  {status_icon} {conv['child_name']} - {conv['conversation_title']} ({conv['status']})")

        except Exception as e:
            print(f"  ❌ Error creating {conv['child_name']}: {e}")

    print("\n✅ Demo data reset complete!")
    print("\n📊 Demo Patients:")
    print("   7 Pending: Emma, Noah, Ethan, Olivia, Mason, Isabella, Jackson Nonesuch")
    print("   2 Responded: Sophia, Liam Nonesuch")
    print("   1 Flagged: Ava Nonesuch")


def main():
    print("=" * 60)
    print("CLARA PROVIDER APP - DEMO DATA RESET")
    print("=" * 60)

    delete_test_conversations()
    create_demo_conversations()

    print("\n" + "=" * 60)
    print("🎉 Ready to test! Open Clara Provider App to see demo data.")
    print("=" * 60)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Create synthetic test conversations in Supabase for Clara Provider App testing

This script creates 6 realistic test conversations with varying:
- Triage outcomes (routine, urgent, emergency)
- Child ages and conditions
- Conversation lengths
- Statuses (pending, responded, flagged)
"""

import os
import uuid
from datetime import datetime, timedelta
import json

# You'll need to install: pip install supabase-py
from supabase import create_client, Client

# Supabase configuration
SUPABASE_URL = "https://dmfsaoawhomuxabhdubw.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_KEY")  # Set this in your environment

if not SUPABASE_KEY:
    print("ERROR: Please set SUPABASE_KEY environment variable")
    print("export SUPABASE_KEY='your-supabase-anon-key'")
    exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Test conversation templates
TEST_CONVERSATIONS = [
    {
        "child_name": "Emma Nonesuch",
        "child_age": "2 years, 3 months old",
        "child_dob": "2022-08-15",
        "conversation_title": "Fever and rash",
        "triage_outcome": "routine",
        "conversation_summary": "Parent concerned about fever (101°F) and red rash on torso. Child eating and playing normally. Rash appeared 2 days ago after fever started.",
        "status": "pending",
        "messages": [
            {"role": "parent", "content": "Hi, my daughter Emma Nonesuch has had a fever for 2 days and now has a red rash on her stomach."},
            {"role": "clara", "content": "I understand Emma has a fever and rash. Let me ask some questions. What's her current temperature?"},
            {"role": "parent", "content": "It's 101 degrees. The rash just started this morning."},
            {"role": "clara", "content": "Is the rash flat or raised? Does it blanch when you press on it?"},
            {"role": "parent", "content": "It's mostly flat and small red dots. They do go away when I press them."},
            {"role": "clara", "content": "That's helpful. Is Emma eating and drinking normally?"},
            {"role": "parent", "content": "Yes, she's been drinking well and ate breakfast."},
        ]
    },
    {
        "child_name": "Noah Nonesuch",
        "child_age": "5 years, 7 months old",
        "child_dob": "2019-04-10",
        "conversation_title": "Cough and difficulty breathing",
        "triage_outcome": "urgent",
        "conversation_summary": "Child with worsening cough, wheezing, and labored breathing. History of asthma. Using rescue inhaler every 3 hours with minimal relief.",
        "status": "pending",
        "messages": [
            {"role": "parent", "content": "My son Noah Nonesuch has been coughing a lot and seems to be breathing hard."},
            {"role": "clara", "content": "I'm concerned about Noah's breathing. Does he have a history of asthma?"},
            {"role": "parent", "content": "Yes, he does. He's been using his inhaler but it's not helping much."},
            {"role": "clara", "content": "How often is he using the rescue inhaler?"},
            {"role": "parent", "content": "Every 3 hours or so. He's wheezing pretty bad."},
            {"role": "clara", "content": "Is he able to speak in full sentences or is he breathing too hard?"},
            {"role": "parent", "content": "He can only say a few words before needing to catch his breath."},
            {"role": "clara", "content": "I'm concerned about Noah. Can you count how many breaths he takes in one minute?"},
            {"role": "parent", "content": "I counted 45 breaths in a minute."},
        ]
    },
    {
        "child_name": "Sophia Nonesuch",
        "child_age": "6 months old",
        "child_dob": "2024-05-07",
        "conversation_title": "Vomiting and refusing feeds",
        "triage_outcome": "urgent",
        "conversation_summary": "6-month-old with vomiting x6 times in past 12 hours. Refusing bottle feeds. Last wet diaper 8 hours ago. Lethargic but arousable.",
        "status": "responded",
        "provider_response": "I agree with Clara's recommendation. Please take Sophia Nonesuch to urgent care today. With decreased wet diapers and refusing feeds, she needs evaluation for dehydration. Call if she becomes difficult to wake or has no urine for 12+ hours.",
        "provider_name": "Dr Michael Hobbs",
        "responded_at": (datetime.utcnow() - timedelta(hours=2)).isoformat() + "Z",
        "messages": [
            {"role": "parent", "content": "Sophia Nonesuch has been throwing up since last night. She's thrown up 6 times."},
            {"role": "clara", "content": "That must be worrying. Is she keeping any fluids down?"},
            {"role": "parent", "content": "No, she throws up the bottle every time I try to feed her."},
            {"role": "clara", "content": "When was her last wet diaper?"},
            {"role": "parent", "content": "It's been about 8 hours. Should I be worried?"},
            {"role": "clara", "content": "Yes, I'm concerned about dehydration. Is she acting normally otherwise?"},
            {"role": "parent", "content": "She seems really tired and sleepy, more than usual."},
        ]
    },
    {
        "child_name": "Liam Nonesuch",
        "child_age": "3 years, 1 month old",
        "child_dob": "2021-10-12",
        "conversation_title": "Ear pain after swimming",
        "triage_outcome": "routine",
        "conversation_summary": "Child with ear pain after swimming yesterday. No fever. Pain is moderate, interfering with sleep. Drainage from right ear noted.",
        "status": "responded",
        "provider_response": "Sounds like swimmer's ear. You can use over-the-counter pain relief and keep the ear dry. If pain worsens or fever develops, see your pediatrician within 24-48 hours for prescription ear drops.",
        "provider_name": "Dr Michael Hobbs",
        "responded_at": (datetime.utcnow() - timedelta(hours=5)).isoformat() + "Z",
        "messages": [
            {"role": "parent", "content": "Liam Nonesuch went swimming yesterday and now his ear hurts."},
            {"role": "clara", "content": "Does he have a fever?"},
            {"role": "parent", "content": "No fever, just complaining about his right ear."},
            {"role": "clara", "content": "Is there any drainage from the ear?"},
            {"role": "parent", "content": "Yes, a little clear fluid came out this morning."},
        ]
    },
    {
        "child_name": "Ava Nonesuch",
        "child_age": "4 years, 5 months old",
        "child_dob": "2020-06-20",
        "conversation_title": "Possible allergic reaction to food",
        "triage_outcome": "urgent",
        "conversation_summary": "Child developed hives and facial swelling 15 minutes after eating peanut butter for first time. No difficulty breathing. Parent has Benadryl at home.",
        "status": "flagged",
        "flag_reason": "Need to verify if breathing is truly normal - facial swelling can progress",
        "provider_response": "Watch closely for any breathing difficulty. Give Benadryl as directed. If any lip swelling, tongue swelling, or trouble breathing develops, use EpiPen if available and call 911 immediately.",
        "responded_at": (datetime.utcnow() - timedelta(minutes=30)).isoformat() + "Z",
        "messages": [
            {"role": "parent", "content": "Help! Ava Nonesuch ate peanut butter and now has hives all over!"},
            {"role": "clara", "content": "Is she having any trouble breathing or swallowing?"},
            {"role": "parent", "content": "No, but her face looks a little puffy around her eyes."},
            {"role": "clara", "content": "Do you have Benadryl or an EpiPen at home?"},
            {"role": "parent", "content": "I have Benadryl. Should I give it to her?"},
            {"role": "clara", "content": "Yes, give her the appropriate dose for her weight. Is she breathing normally?"},
            {"role": "parent", "content": "Yes, breathing is fine. Just the hives and puffy eyes."},
        ]
    },
    {
        "child_name": "Ethan Nonesuch",
        "child_age": "7 years, 2 months old",
        "child_dob": "2017-09-03",
        "conversation_title": "Head injury from fall",
        "triage_outcome": "urgent",
        "conversation_summary": "Child fell from playground equipment (~6 feet), hit head on mulch. Brief loss of consciousness (~10 seconds). Currently awake but confused and has vomited once.",
        "status": "pending",
        "messages": [
            {"role": "parent", "content": "Ethan Nonesuch fell off the monkey bars at the playground and hit his head!"},
            {"role": "clara", "content": "That's scary. Did he lose consciousness at all?"},
            {"role": "parent", "content": "Yes, for maybe 10 seconds. He's awake now but seems confused."},
            {"role": "clara", "content": "Has he vomited?"},
            {"role": "parent", "content": "Yes, once right after he woke up."},
            {"role": "clara", "content": "Is he complaining of a headache? Can you see his pupils?"},
            {"role": "parent", "content": "He says his head hurts a lot. His pupils look the same size to me."},
            {"role": "clara", "content": "How high was the fall?"},
            {"role": "parent", "content": "About 6 feet onto wood chips."},
        ]
    }
]


def create_conversation_messages(messages):
    """Format messages into the JSON structure expected by Supabase"""
    formatted = []
    for idx, msg in enumerate(messages):
        formatted.append({
            "id": str(uuid.uuid4()),
            "content": msg["content"],
            "isFromUser": msg["role"] == "parent",
            "timestamp": (datetime.utcnow() - timedelta(hours=2, minutes=len(messages)-idx*2)).isoformat() + "Z"
        })
    return formatted


def create_test_conversations():
    """Insert test conversations into Supabase"""
    print("Creating 6 synthetic test conversations...")

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
                "created_at": (datetime.utcnow() - timedelta(hours=idx*2)).isoformat() + "Z"
            }

            # Add optional fields if present
            if "provider_response" in conv:
                data["provider_response"] = conv["provider_response"]
            if "provider_name" in conv:
                data["provider_name"] = conv["provider_name"]
            if "responded_at" in conv:
                data["responded_at"] = conv["responded_at"]
            if "flag_reason" in conv:
                data["flag_reason"] = conv["flag_reason"]

            # Insert into Supabase
            result = supabase.table("provider_review_requests").insert(data).execute()

            print(f"✅ Created: {conv['child_name']} - {conv['conversation_title']} (Status: {conv['status']})")

        except Exception as e:
            print(f"❌ Error creating conversation {idx}: {e}")

    print("\n✅ Done! Created 6 test conversations")
    print("\nStatus breakdown:")
    print("- 3 pending (Emma Nonesuch, Noah Nonesuch, Ethan Nonesuch)")
    print("- 2 responded (Sophia Nonesuch, Liam Nonesuch)")
    print("- 1 flagged (Ava Nonesuch)")


if __name__ == "__main__":
    create_test_conversations()

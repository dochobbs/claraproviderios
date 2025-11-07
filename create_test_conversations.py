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
    },
    {
        "child_name": "Olivia Nonesuch",
        "child_age": "18 months old",
        "child_dob": "2023-05-20",
        "conversation_title": "Persistent diarrhea and diaper rash",
        "triage_outcome": "routine",
        "conversation_summary": "18-month-old with watery diarrhea for 3 days, 5-6 episodes per day. Drinking well. Severe diaper rash developed. No fever. Still playful and active.",
        "status": "pending",
        "messages": [
            {"role": "parent", "content": "Hi, Olivia Nonesuch has had diarrhea for 3 days now and her diaper area is really red."},
            {"role": "clara", "content": "I understand that's uncomfortable for her. How many episodes of diarrhea is she having per day?"},
            {"role": "parent", "content": "About 5 or 6 times. It's really watery."},
            {"role": "clara", "content": "Is she keeping fluids down? How is she drinking?"},
            {"role": "parent", "content": "She's drinking fine. Maybe even more than usual because she seems thirsty."},
            {"role": "clara", "content": "That's good. Does she have a fever?"},
            {"role": "parent", "content": "No fever. She's actually still playing and seems pretty happy between diaper changes."},
            {"role": "clara", "content": "How bad is the diaper rash? Is the skin broken or bleeding?"},
            {"role": "parent", "content": "It's very red and she cries when I wipe her, but I don't see any bleeding."},
            {"role": "clara", "content": "Has she been around anyone else who's been sick?"},
            {"role": "parent", "content": "Yes, her older brother had a stomach bug last week."},
        ]
    },
    {
        "child_name": "Mason Nonesuch",
        "child_age": "4 years, 8 months old",
        "child_dob": "2020-03-12",
        "conversation_title": "Sore throat and refusing to eat",
        "triage_outcome": "routine",
        "conversation_summary": "4-year-old with sore throat for 2 days, refusing solid foods. Low-grade fever (100.4°F). Drinking liquids okay. No difficulty breathing or drooling.",
        "status": "pending",
        "messages": [
            {"role": "parent", "content": "Mason Nonesuch has a sore throat and won't eat anything. Should I be worried?"},
            {"role": "clara", "content": "Sore throats can make eating difficult. Does he have a fever?"},
            {"role": "parent", "content": "Yes, it's been around 100.4 degrees for the past day."},
            {"role": "clara", "content": "Is he able to drink liquids?"},
            {"role": "parent", "content": "Yes, he's drinking juice and water. Just won't eat solid food because he says it hurts."},
            {"role": "clara", "content": "Can you look at his throat? Do you see any white patches or redness?"},
            {"role": "parent", "content": "It's hard to get him to open wide, but I can see it's pretty red in the back."},
            {"role": "clara", "content": "Is he drooling or having any trouble breathing?"},
            {"role": "parent", "content": "No drooling and breathing seems normal."},
            {"role": "clara", "content": "Has he been around other kids with strep throat recently?"},
            {"role": "parent", "content": "Actually yes, there's been strep going around his preschool."},
        ]
    },
    {
        "child_name": "Isabella Nonesuch",
        "child_age": "8 years, 5 months old",
        "child_dob": "2016-06-18",
        "conversation_title": "Ankle injury from soccer",
        "triage_outcome": "routine",
        "conversation_summary": "8-year-old twisted ankle during soccer practice 2 hours ago. Can bear some weight but limping. Mild swelling on outside of ankle. No deformity visible.",
        "status": "pending",
        "messages": [
            {"role": "parent", "content": "Isabella Nonesuch hurt her ankle at soccer practice. She's limping but can walk on it."},
            {"role": "clara", "content": "When did this happen?"},
            {"role": "parent", "content": "About 2 hours ago. She was running and twisted it."},
            {"role": "clara", "content": "Can she put any weight on it at all?"},
            {"role": "parent", "content": "Yes, she can stand on it but she's limping. She says it hurts when she walks."},
            {"role": "clara", "content": "Is there any swelling or bruising?"},
            {"role": "parent", "content": "There's some swelling on the outside of her ankle. No bruising yet."},
            {"role": "clara", "content": "Does the ankle look deformed or out of place compared to the other ankle?"},
            {"role": "parent", "content": "No, it looks normal, just a bit puffy."},
            {"role": "clara", "content": "Have you tried ice or elevation?"},
            {"role": "parent", "content": "Yes, we've had ice on it for about 20 minutes and she's been sitting with it up."},
        ]
    },
    {
        "child_name": "Jackson Nonesuch",
        "child_age": "10 months old",
        "child_dob": "2024-01-15",
        "conversation_title": "Possible ear infection - fussy and pulling ear",
        "triage_outcome": "routine",
        "conversation_summary": "10-month-old increasingly fussy for 2 days, pulling at right ear. Low fever (100.8°F). Decreased appetite but still taking some bottle. No drainage from ear visible.",
        "status": "pending",
        "messages": [
            {"role": "parent", "content": "Jackson Nonesuch has been really fussy and keeps pulling at his right ear."},
            {"role": "clara", "content": "Ear pulling can be a sign of discomfort. How long has this been going on?"},
            {"role": "parent", "content": "About 2 days. He's been more cranky than usual, especially at night."},
            {"role": "clara", "content": "Does he have a fever?"},
            {"role": "parent", "content": "Yes, 100.8 this morning. Nothing too high."},
            {"role": "clara", "content": "Is he eating and drinking normally?"},
            {"role": "parent", "content": "Not as much as usual. He's taking his bottle but not finishing it like he normally does."},
            {"role": "clara", "content": "Have you noticed any drainage or fluid coming from his ear?"},
            {"role": "parent", "content": "No, I don't see anything coming out. Just keeps tugging at it."},
            {"role": "clara", "content": "Has he had a cold or congestion recently?"},
            {"role": "parent", "content": "Yes! He had a runny nose last week. It's mostly cleared up now."},
            {"role": "clara", "content": "Is he sleeping okay or waking up more than usual?"},
            {"role": "parent", "content": "He's been waking up crying a lot more at night. Last night was rough."},
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

    print("\n✅ Done! Created 10 test conversations")
    print("\nStatus breakdown:")
    print("- 7 pending (Emma, Noah, Ethan, Olivia, Mason, Isabella, Jackson Nonesuch)")
    print("- 2 responded (Sophia, Liam Nonesuch)")
    print("- 1 flagged (Ava Nonesuch)")


if __name__ == "__main__":
    create_test_conversations()

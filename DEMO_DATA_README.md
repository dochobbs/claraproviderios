# Demo Data Scripts for Clara Provider App

These scripts create and manage demo/test patient conversations in Supabase for testing the Clara Provider iOS app.

## Setup (One Time)

1. **Activate virtual environment and install dependencies:**
   ```bash
   cd /Users/dochobbs/Downloads/Consult/GIT/vhs/clara-provider-app
   source .venv/bin/activate
   pip install supabase
   ```

2. **Set your Supabase key:**
   ```bash
   export SUPABASE_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRtZnNhb2F3aG9tdXhhYmhkdWJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAzNTI3MjksImV4cCI6MjA3NTkyODcyOX0.X8zyqgFWNQ8Rk_UB096gaVTv709SAKI7iJc61UJn-L8'
   ```

   Or add to your `~/.zshrc` for persistence:
   ```bash
   echo "export SUPABASE_KEY='your-key-here'" >> ~/.zshrc
   source ~/.zshrc
   ```

## Usage

### Reset Demo Data (Recommended)
Deletes all test conversations and recreates the 10 standard demo patients:

```bash
source .venv/bin/activate
python3 reset_demo_data.py
```

### Create Demo Data (First Time Only)
Only creates demo data without deleting:

```bash
source .venv/bin/activate
python3 create_test_conversations.py
```

## The 10 Demo Patients

These are the standard demo patients that will be created. All patients have the last name **Nonesuch** for easy identification.

### 1. Emma Nonesuch (2 years old) - PENDING
- **Chief Complaint:** Fever and rash
- **Triage:** Routine
- **Summary:** 101°F fever with flat, blanching red rash on torso. Eating and drinking normally.
- **Use For:** Testing response submission, different response types

### 2. Noah Nonesuch (5 years old) - PENDING
- **Chief Complaint:** Cough and difficulty breathing
- **Triage:** Urgent
- **Summary:** History of asthma, using rescue inhaler every 3 hours with minimal relief. Wheezing, speaking in short phrases, 45 breaths/min.
- **Use For:** Testing urgent case response, escalation

### 3. Sophia Nonesuch (6 months old) - RESPONDED
- **Chief Complaint:** Vomiting and refusing feeds
- **Triage:** Urgent
- **Summary:** 6 episodes of vomiting in 12 hours, no wet diaper in 8 hours, lethargic.
- **Provider Response:** Already responded by Dr. Hobbs recommending urgent care
- **Use For:** Testing flag/unflag, reopen response

### 4. Liam Nonesuch (3 years old) - RESPONDED
- **Chief Complaint:** Ear pain after swimming
- **Triage:** Routine
- **Summary:** Right ear pain with clear drainage. No fever. Likely swimmer's ear.
- **Provider Response:** Already responded with OTC recommendations
- **Use For:** Testing flag/unflag on routine cases

### 5. Ava Nonesuch (4 years old) - FLAGGED
- **Chief Complaint:** Possible allergic reaction to food
- **Triage:** Urgent
- **Summary:** Hives and facial swelling after first exposure to peanut butter. No breathing difficulty currently.
- **Provider Response:** Already responded with monitoring instructions
- **Flag Reason:** "Need to verify if breathing is truly normal - facial swelling can progress"
- **Use For:** Testing unflag workflow, ensuring response persists

### 6. Ethan Nonesuch (7 years old) - PENDING
- **Chief Complaint:** Head injury from fall
- **Triage:** Urgent
- **Summary:** Fell 6 feet from monkey bars, brief loss of consciousness (~10 sec), confused, vomited once, complaining of headache.
- **Use For:** Testing urgent case handling, emergency escalation

### 7. Olivia Nonesuch (18 months old) - PENDING
- **Chief Complaint:** Persistent diarrhea and diaper rash
- **Triage:** Routine
- **Summary:** Watery diarrhea for 3 days, 5-6 episodes per day. Drinking well. Severe diaper rash. No fever. Still playful.
- **Use For:** Testing routine case handling, basic triage

### 8. Mason Nonesuch (4 years old) - PENDING
- **Chief Complaint:** Sore throat and refusing to eat
- **Triage:** Routine
- **Summary:** Sore throat for 2 days, refusing solids. Low-grade fever (100.4°F). Drinking okay. Possible strep exposure.
- **Use For:** Testing routine infectious disease cases

### 9. Isabella Nonesuch (8 years old) - PENDING
- **Chief Complaint:** Ankle injury from soccer
- **Triage:** Routine
- **Summary:** Twisted ankle 2 hours ago. Can bear weight but limping. Mild swelling, no deformity.
- **Use For:** Testing musculoskeletal injury cases

### 10. Jackson Nonesuch (10 months old) - PENDING
- **Chief Complaint:** Possible ear infection - fussy and pulling ear
- **Triage:** Routine
- **Summary:** Fussy for 2 days, pulling right ear. Low fever (100.8°F). Decreased appetite. Recent cold.
- **Use For:** Testing infant cases, ear infection presentation

## Workflow Testing Scenarios

### Test Response Persistence (Bug Fix Verification)
1. Open Emma or Noah (pending)
2. Submit a response
3. ✅ Response should appear immediately (not need to leave/return)

### Test Unflag Workflow (Bug Fix Verification)
1. Open Sophia or Liam (responded)
2. Flag it
3. Unflag it
4. ✅ Response should stay visible, reply box should NOT reappear

### Test Dismiss Button (Bug Fix Verification)
1. Open any pending conversation
2. Submit response
3. Dismiss it
4. ✅ Status should change to "dismissed"

### Test Flagging with Reason
1. Open Sophia or Liam
2. Flag with a custom reason
3. ✅ Flag reason should appear in the UI
4. Unflag
5. ✅ Flag reason should disappear, response stays

### Test Response Types Don't Auto-Flag
1. Open Emma or Noah
2. Select "Disagree with Thoughts" response type
3. Submit
4. ✅ Should save as "responded" NOT "flagged"

## Database Details

- **Table:** `provider_review_requests`
- **Test User ID:** `test_provider_001`
- **Supabase Project:** dmfsaoawhomuxabhdubw

All demo conversations are tagged with `user_id = 'test_provider_001'` so they can be easily identified and deleted.

## Maintenance

To reset demo data to pristine state:
```bash
source .venv/bin/activate
python3 reset_demo_data.py
```

This is useful:
- After heavy testing that modified statuses
- Before demos or screenshots
- When you want a fresh slate

## Files

- `create_test_conversations.py` - Creates demo data (doesn't delete)
- `reset_demo_data.py` - Deletes and recreates demo data (clean slate)
- `DEMO_DATA_README.md` - This file

---

**Last Updated:** November 7, 2025
**Demo Patient Count:** 10 standard patients (all with last name "Nonesuch")
**Purpose:** Testing Clara Provider App bug fixes and workflows

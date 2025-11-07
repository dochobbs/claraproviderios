# /done Command

Ends the current Claude Code session and generates comprehensive session artifacts.

## How It Works

This is a custom slash command that triggers `.claude/commands/done.sh`, which executes the session exit handler and generates all session artifacts automatically.

## What It Does

When you run `/done`, this command:

1. **Gathers Session Data**
   - Calculates session duration
   - Checks git status and logs
   - Analyzes file changes
   - Reviews current todo list

2. **Generates Session Summary**
   - Creates `.claude/sessions/YYYY-MM-DD/SESSION_SUMMARY.md`
   - Lists completed/in-progress tasks
   - Documents code changes with metrics
   - Includes all commits made

3. **Updates Project Worklist**
   - Creates/updates `.claude/PROJECT_WORKLIST.md`
   - Marks tasks as completed
   - Prioritizes remaining work
   - Suggests next steps

4. **Creates Changelog**
   - Generates `.claude/sessions/YYYY-MM-DD/CHANGELOG.md`
   - Includes commit hashes and messages
   - Categorizes by type (FEATURE, FIX, SECURITY, DOCS, etc.)
   - Links to related todos

5. **Records Metrics**
   - Saves `.claude/sessions/YYYY-MM-DD/METRICS.txt`
   - Session duration (auto-calculated)
   - File and code statistics
   - Task progress tracking
   - Next session recommendations

6. **Archives Everything**
   - All files stored in `.claude/sessions/YYYY-MM-DD/`
   - Current worklist always available in `.claude/PROJECT_WORKLIST.md`
   - Combined changelog in `.claude/CHANGELOG_ARCHIVE.md`

## Output Example

Running `/done` at end of session creates:

```
.claude/sessions/2025-11-06/
├── SESSION_SUMMARY.md (3-4 KB)
├── WORKLIST.md (2 KB)
├── CHANGELOG.md (2 KB)
└── METRICS.txt (1 KB)
```

Plus updates:
- `.claude/PROJECT_WORKLIST.md` (current state)
- `.claude/CHANGELOG_ARCHIVE.md` (historical reference)

## Usage

Simply type at any time:
```
/done
```

Then you'll get:
1. A summary displayed in terminal showing what was recorded
2. Notification when complete
3. File paths where everything was saved
4. Any warnings (uncommitted changes, etc.)
5. Next session recommendations

## Files Generated

### SESSION_SUMMARY.md
```markdown
# Session Summary - November 6, 2025

**Duration:** 2h 15m | **Time:** 2:30 PM - 4:45 PM

## Completed Tasks ✅
[List of finished work]

## In Progress 🔄
[Work started but not completed]

## Files Modified
[With line counts and changes]

## Commits Made
[With hashes and messages]

## Metrics & Statistics
[Code changes, new files, etc.]

## Next Session Recommendations
[Prioritized next steps]
```

### WORKLIST.md
```markdown
# Project Worklist - Clara Provider App
**Updated:** November 6, 2025

## 🔴 CRITICAL (2 items)
## 🟠 HIGH (5 items)
## 🟡 MEDIUM (3 items)
## 🟢 LOW (7 items)

[All items with checkboxes and status]
```

### CHANGELOG.md
```markdown
# Changelog - November 6, 2025

## SECURITY (1)
- a1b2c3d - Description with files

## DOCS (1)
- d4e5f6g - Description with files

## FEATURE (1)
- h7i8j9k - Description with files

[Statistics by type]
```

### METRICS.txt
```
SESSION METRICS - November 6, 2025
===================================

Duration: 2h 15m
Files Changed: 7
Lines Added: +181
Commits: 3

[Detailed breakdown]
```

## Notes

- **No manual tracking needed** - Duration is calculated automatically
- **Git-aware** - Only includes commits from this session
- **Todo-integrated** - Uses your current TodoWrite list
- **Safe to run multiple times** - Re-running updates files, doesn't duplicate
- **Uncommitted changes warning** - Alerts if you have pending changes
- **Automatically commits archives** - (Optional) Can auto-commit session files

## Workflow

Typical end-of-session:
```
# Finish your work
[do stuff]

# Run the command
/done

# Review the output
[see summary, metrics, next steps]

# Done! Files are archived
```

## What If...

**...I want to redo a session summary?**
Just run `/done` again - it overwrites the files for that date.

**...I have uncommitted changes?**
The command will warn you and skip that commit from the changelog.

**...I want to exclude certain files?**
The command ignores `.git/`, `node_modules/`, `.build/`, etc. by default.

**...I ran it at the wrong time?**
Delete the folder in `.claude/sessions/YYYY-MM-DD/` and rerun.

---

See `.claude/skills/exit.md` for implementation details.

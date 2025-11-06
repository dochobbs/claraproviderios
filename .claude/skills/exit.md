# Exit Session Skill

Triggered when user runs `/exit` to end their Claude Code session.

## Purpose

Automatically:
1. Create session summary with work completed
2. Update project worklist/todos
3. Generate changelog entries with commit references
4. Track session metrics (time, files, changes)
5. Prepare next session recommendations

## Execution Flow

### Phase 1: Gather Session Data
- Get current time and calculate session duration
- Check git status for uncommitted changes
- Review git log for commits made this session
- Analyze file modifications
- Extract current todo list state

### Phase 2: Generate Summary
- Create timestamped session summary in Markdown
- List all tasks completed/in-progress
- Document code changes with file paths
- Include commits made with messages
- Add metrics and statistics

### Phase 3: Update Project Worklist
- Export current todo list to project file
- Mark completed items
- Prioritize remaining items
- Add recommendations for next session

### Phase 4: Generate Changelog
- Create or append to dated changelog
- Include commits with hashes
- Categorize by type (FEATURE, FIX, REFACTOR, DOCS)
- Link to relevant todo items
- Add session date and time

### Phase 5: Archive & Report
- Save all files to `.claude/sessions/YYYY-MM-DD/` structure
- Generate final summary report
- Warn about uncommitted changes
- Provide next session checklist

## Output Structure

```
.claude/
├── sessions/
│   ├── 2025-11-06/
│   │   ├── SESSION_SUMMARY.md          # What was done
│   │   ├── WORKLIST.md                 # Updated todos
│   │   ├── CHANGELOG.md                # Commits & changes
│   │   └── METRICS.txt                 # Session stats
│   └── 2025-11-05/
│       ├── SESSION_SUMMARY.md
│       ├── WORKLIST.md
│       ├── CHANGELOG.md
│       └── METRICS.txt
├── PROJECT_WORKLIST.md                 # Current active worklist
├── CHANGELOG_ARCHIVE.md                # All changelogs combined
└── NOTIFICATIONS.md
```

## Session Summary Format

```markdown
# Session Summary - November 6, 2025

**Duration:** 2 hours 15 minutes
**Time:** 2:30 PM - 4:45 PM
**Focus Area:** Security & State Management Fixes

## Tasks Completed ✅
- [ ] Task 1 with details
- [ ] Task 2 with details

## Tasks In Progress 🔄
- [ ] Task 3 (70% complete)
- [ ] Task 4 (30% complete)

## Files Modified (7 files)
- `Services/ClaudeChatService.swift` (+25 lines, -8 lines)
- `Services/SecureConfig.swift` (+0 lines, -0 lines)
- `.claude/CLAUDE.md` (+156 lines, -0 lines)

## Commits Made (3 total)
- `a1b2c3d` - SECURITY: Move Claude API key to Keychain
- `d4e5f6g` - DOCS: Add CLAUDE.md project instructions
- `h7i8j9k` - FEATURE: Add notification system documentation

## Code Metrics
- Total lines changed: +181 lines
- Files touched: 7
- Commits: 3
- Tests added: 0
- Tests modified: 0

## Key Accomplishments
- Identified 18 priority fixes needed for Clara Provider App
- Created comprehensive code review (6,644 LOC analyzed)
- Set up notification system for task alerts
- Established project documentation standards

## Next Session Recommendations
1. Continue with critical security fixes (2 items)
2. Implement error handling improvements
3. Test changes in simulator before committing

## Issues/Blockers
- None at end of session
```

## Worklist Format

```markdown
# Project Worklist - Clara Provider App
**Last Updated:** November 6, 2025
**Total Items:** 18
**Completed:** 0
**In Progress:** 1
**Pending:** 17

## 🔴 CRITICAL (Do First)
- [ ] Move Claude API key to Keychain (SecureConfig) - IN PROGRESS
- [ ] Replace hardcoded 'default_user' with authenticated provider ID

## 🟠 HIGH (Do This Sprint)
- [ ] Implement dashboard quick action button navigation
- [ ] Add error alerts to ClaudeChatService
- [ ] Add error alerts to ReviewActionsView
- [ ] Add error alerts to ProviderDashboardView
- [ ] Implement logout functionality

## 🟡 MEDIUM (Next Sprint)
- [ ] Server-side access control verification
- [ ] Implement token refresh mechanism
- [ ] Move device token to Keychain

## 🟢 LOW & MISCELLANEOUS
- [ ] Add retry UI for network errors
- [ ] Implement message image caching
- [ ] Implement message pagination
- [ ] Fix flag/unflag UX
- [ ] Add message content validation
- [ ] Commit CLAUDE.md to git
- [ ] Add UUID validation logging
- [ ] Review Claude API model version
```

## Changelog Format

```markdown
# Changelog - November 6, 2025

**Session Duration:** 2h 15m
**Total Commits:** 3
**Files Changed:** 7
**Lines Added:** +181

## SECURITY
- **a1b2c3d** - Move Claude API key from UserDefaults to Keychain
  - Related todo: #1 CRITICAL
  - Files: `Services/ClaudeChatService.swift`, `Services/SecureConfig.swift`

## DOCS
- **d4e5f6g** - Add CLAUDE.md project instructions
  - Created comprehensive project documentation
  - Files: `.claude/CLAUDE.md`

## FEATURE
- **h7i8j9k** - Add notification system for task alerts
  - Implemented macOS notifications via osascript
  - Files: `.claude/NOTIFICATIONS.md`

## Summary by Type
- SECURITY: 1 commit
- DOCS: 1 commit
- FEATURE: 1 commit

## Files Modified by Category

### Core Services
- `Services/ClaudeChatService.swift` (+25, -8)
- `Services/SecureConfig.swift` (no changes)

### Documentation
- `.claude/CLAUDE.md` (+156, -0)
- `.claude/NOTIFICATIONS.md` (+47, -0)

### Configuration
- `.claude/settings.local.json` (no changes)
```

## Metrics Format

```
SESSION METRICS - November 6, 2025
=====================================

Duration: 2 hours 15 minutes
Start Time: 2:30 PM
End Time: 4:45 PM

FILES CHANGED:
  Total: 7
  Modified: 5
  Created: 2
  Deleted: 0

CODE STATISTICS:
  Lines Added: +181
  Lines Removed: -8
  Net Change: +173

GIT ACTIVITY:
  Commits: 3
  Files in commits: 7
  Commit types:
    - SECURITY: 1
    - DOCS: 1
    - FEATURE: 1

UNCOMMITTED CHANGES:
  Status: Clean (all changes committed)

TASK METRICS:
  Completed: 0
  In Progress: 1
  Pending: 17
  Completed Rate: 0%

ESTIMATED REMAINING:
  Critical Items: 2 (est. 50 min)
  High Items: 5 (est. 3.5 hours)
  Medium Items: 3 (est. 2 hours)
  Low Items: 7 (est. 4 hours)
  TOTAL ESTIMATED: 10 hours
```

## Implementation Notes

### Git Integration
- Query `git log` for commits since session start
- Use `git diff` to count lines changed
- Check `git status` for uncommitted work
- Extract commit hashes and messages

### Todo Integration
- Read current TodoWrite list
- Track which items moved to completed
- Estimate remaining work
- Suggest priority adjustments

### File Tracking
- Use `git diff --stat` to get file changes
- Calculate +/- lines per file
- Categorize by file type

### Time Tracking
- Use start time from session initialization
- Calculate duration at exit
- Format as "Xh Ym" or "Xm"

### Next Session Prep
- Identify blocked items needing decisions
- Flag items ready to start
- Suggest optimal order based on dependencies

## Error Handling
- If git not initialized: Skip commit tracking
- If no todos exist: Create from scratch
- If changelog doesn't exist: Create new
- If files can't write: Log warning and continue

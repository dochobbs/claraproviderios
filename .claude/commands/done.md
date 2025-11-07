---
description: End session and generate comprehensive session artifacts
---

# Session Exit Handler

Archive the current session's work with comprehensive summaries, metrics, and changelogs.

This command:
1. Gathers session data (duration, git commits, file changes)
2. Generates SESSION_SUMMARY.md with completed/in-progress tasks
3. Updates PROJECT_WORKLIST.md with current status
4. Creates CHANGELOG.md with commit history
5. Records METRICS.txt with detailed statistics
6. Archives everything in `.claude/sessions/YYYY-MM-DD/`

Run this at the end of your session to automatically organize and document your work.

!bash .claude/commands/done.sh

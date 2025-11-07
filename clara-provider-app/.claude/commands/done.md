---
description: End session and generate comprehensive session artifacts
---

End the current Claude Code session and automatically generate comprehensive session documentation including summary, worklist updates, changelog, and metrics.

This command archives all session work by:
- Gathering session duration and file changes
- Listing completed and in-progress tasks
- Creating SESSION_SUMMARY.md with detailed progress
- Updating PROJECT_WORKLIST.md with current status
- Generating CHANGELOG.md from git commits
- Recording METRICS.txt with session statistics

All artifacts are saved to `.claude/sessions/YYYY-MM-DD/` for historical reference.

!bash ./.claude/commands/done.sh

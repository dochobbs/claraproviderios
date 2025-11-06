# Claude Code Notifications System

This file documents the notification strategy used to alert you when tasks are complete or attention is needed.

## Notification Method

**System:** macOS Notifications via `osascript`
**Trigger:** Used when:
- ✅ A task is completed
- 🎯 Your input/decision is needed
- ⚠️ An issue is discovered
- 📍 Major progress milestone reached

## Format

Notifications use this structure:
```bash
osascript -e 'display notification "[brief status]" with title "[task name]"'
```

## Examples

**Task Complete:**
```bash
osascript -e 'display notification "Moved API key to Keychain. Ready to test." with title "✅ Task Complete"'
```

**Need Your Input:**
```bash
osascript -e 'display notification "3 options ready. See terminal for details." with title "🎯 Need Your Attention"'
```

**Issue Found:**
```bash
osascript -e 'display notification "Build failed on line 156. Check terminal." with title "⚠️ Issue Found"'
```

**Progress Update:**
```bash
osascript -e 'display notification "Moving to ReviewActionsView (2/3)" with title "📍 In Progress"'
```

## When You'll See Them

- **Bottom-right corner** of your screen (macOS Notification Center)
- **Also in Notification Center history** (swipe down from top-right)
- **Persistent** - stays visible until you dismiss it
- **No sound** - just visual notification (can adjust if you want audio)

---

**Last Updated:** November 6, 2025

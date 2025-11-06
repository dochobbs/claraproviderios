#!/bin/bash

# Session Initialization Hook - SessionStart
# Loads project context and prepares workspace

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

echo "═══════════════════════════════════════════════════════"
echo "📚 Session Context Loaded"
echo "═══════════════════════════════════════════════════════"

# Load project worklist if it exists
if [ -f "$PROJECT_DIR/.claude/PROJECT_WORKLIST.md" ]; then
  echo ""
  echo "📋 Current Project Worklist:"
  echo "───────────────────────────────────────────────────────"
  # Show summary stats from worklist
  grep -E "^(\*\*|##)" "$PROJECT_DIR/.claude/PROJECT_WORKLIST.md" | head -10
  echo "📄 View full worklist: .claude/PROJECT_WORKLIST.md"
fi

# Show git status
echo ""
echo "📊 Git Status:"
echo "───────────────────────────────────────────────────────"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Show branch and status
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "Branch: $BRANCH"

# Show uncommitted changes
CHANGES=$(git status --short 2>/dev/null | wc -l)
if [ "$CHANGES" -gt 0 ]; then
  echo "Uncommitted changes: $CHANGES files"
  git status --short | head -5
  if [ "$CHANGES" -gt 5 ]; then
    echo "... and $((CHANGES - 5)) more"
  fi
else
  echo "Status: Clean ✓"
fi

# Show recent commits
echo ""
echo "📅 Recent Commits:"
echo "───────────────────────────────────────────────────────"
git log --oneline -3 2>/dev/null || echo "No commits yet"

# Load last session if available
if [ -d "$PROJECT_DIR/.claude/sessions" ]; then
  LAST_SESSION=$(ls -t "$PROJECT_DIR/.claude/sessions/" 2>/dev/null | head -1)
  if [ -n "$LAST_SESSION" ]; then
    echo ""
    echo "🔄 Last Session Summary:"
    echo "───────────────────────────────────────────────────────"
    # Extract key info from last session
    if [ -f "$PROJECT_DIR/.claude/sessions/$LAST_SESSION/METRICS.txt" ]; then
      echo "See: .claude/sessions/$LAST_SESSION/METRICS.txt"
      head -5 "$PROJECT_DIR/.claude/sessions/$LAST_SESSION/METRICS.txt"
    fi
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ Ready to start work!"
echo "═══════════════════════════════════════════════════════"

exit 0

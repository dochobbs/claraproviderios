#!/bin/bash

# /done Command - Session Exit Handler
# Runs the exit_handler.py script to archive session work

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# Try parent directory first (where main .claude directory is)
HANDLER_SCRIPT="$PROJECT_DIR/../.claude/exit_handler.py"

if [ ! -f "$HANDLER_SCRIPT" ]; then
  # Fallback to current directory
  HANDLER_SCRIPT="$PROJECT_DIR/.claude/exit_handler.py"
fi

if [ ! -f "$HANDLER_SCRIPT" ]; then
  echo "❌ Error: exit_handler.py not found at $HANDLER_SCRIPT"
  exit 1
fi

echo "🔄 Running session exit handler..."
python3 "$HANDLER_SCRIPT"

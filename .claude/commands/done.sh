#!/bin/bash

# /done Command - Session Exit Handler
# Runs the exit_handler.py script to archive session work

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
HANDLER_SCRIPT="$PROJECT_DIR/.claude/exit_handler.py"

if [ ! -f "$HANDLER_SCRIPT" ]; then
  echo "❌ Error: exit_handler.py not found at $HANDLER_SCRIPT"
  exit 1
fi

echo "🔄 Running session exit handler..."
python3 "$HANDLER_SCRIPT"

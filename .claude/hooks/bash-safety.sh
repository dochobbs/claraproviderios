#!/bin/bash

# Bash Safety Hook - PreToolUse
# Prevents destructive bash commands

set -u

TOOL_NAME="${1:-}"
TOOL_INPUT="${2:-}"

# Extract command from tool input
COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null || echo "")

# If no command, allow
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Log for debugging
echo "[bash-safety] Checking command: ${COMMAND:0:100}..." >&2

# Patterns that are too dangerous
DANGEROUS_PATTERNS=(
  "rm -rf /"           # Recursive delete from root
  "rm -rf ~"           # Recursive delete home directory
  "git reset --hard"   # Permanent history loss
  "git push --force"   # Force push (usually bad)
  "dd if="             # Direct disk writes
  "mkfs"               # Format filesystems
  "shred"              # Permanent file deletion
  ": \(\( .* \)\) rm"  # Bash fork bomb with rm
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if [[ "$COMMAND" =~ $pattern ]]; then
    echo "⚠️ DANGEROUS: Command blocked for safety: $COMMAND" >&2
    echo "This type of command could cause unrecoverable damage."
    exit 1
  fi
done

# Commands that need extra caution
CAUTION_PATTERNS=(
  "^rm "      # Any rm command
  "git reset" # Git resets
  "git clean" # Git clean
)

for pattern in "${CAUTION_PATTERNS[@]}"; do
  if [[ "$COMMAND" =~ $pattern ]]; then
    echo "⚠️ CAUTION: Potentially risky command: $COMMAND" >&2
    # Log for user review but allow
    # In production, you might want to block these too
  fi
done

exit 0

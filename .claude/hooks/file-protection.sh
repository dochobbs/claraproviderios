#!/bin/bash

# File Protection Hook - PreToolUse
# Prevents writes to critical files and outside project directory
# This protects you from accidental deletion like the git incident

# Ensure bash strict mode
set -u

# Input parameters from Claude Code
TOOL_NAME="${1:-}"
TOOL_INPUT="${2:-}"

# Parse file path from tool input JSON
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null || echo "")

# If no file path, allow operation
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Log for debugging
echo "[file-protection] Checking: $FILE_PATH" >&2

# Critical protected patterns (modify for your needs)
PROTECTED_PATTERNS=(
  "\.env"
  "\.env\.local"
  "\.env\.production"
  "package-lock\.json"
  "yarn\.lock"
  "Gemfile\.lock"
  "Podfile\.lock"
  "\.google"
  "\.ssh"
  "\.aws"
  "credentials"
  "secret"
  "private_key"
  "config/secrets"
  "\.gnupg"
  "\.kube"
  "docker-compose\.prod"
)

# Check if file matches protected pattern
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" =~ $pattern ]]; then
    echo "🛡️ BLOCKED: Cannot modify protected file: $FILE_PATH" >&2
    echo "This file is protected to prevent accidental changes."
    exit 1
  fi
done

# Prevent writing to parent directories (above project)
# This is the critical guard against home directory deletion
if [[ "$FILE_PATH" == /* ]]; then
  # Absolute path - check if it starts with project directory
  CANONICAL_PROJECT=$(cd "$PROJECT_DIR" 2>/dev/null && pwd || echo "$PROJECT_DIR")
  CANONICAL_FILE=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && pwd || echo "$(dirname "$FILE_PATH")")

  if [[ ! "$CANONICAL_FILE" = "$CANONICAL_PROJECT"* ]]; then
    # Check if it's a system-critical directory
    if [[ "$FILE_PATH" =~ ^(/etc|/usr|/bin|/sbin|/System|/Applications|$HOME) ]]; then
      echo "🛡️ BLOCKED: Cannot write to system directory: $FILE_PATH" >&2
      exit 1
    fi
  fi
fi

# Allow the operation
exit 0

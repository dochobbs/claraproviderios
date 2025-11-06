# AI Team Guide: Building Your AI Safety & Project Management System

As a "vibe coding physician," you need guardrails that let you move fast but safely. This guide shows how to build a distributed AI team using Claude Code's hooks, skills, and commands to prevent costly mistakes.

## The Problem You're Solving

- ❌ Cursor accidentally deleted your home directory via git
- ❌ Manual tracking of project state wastes energy
- ❌ Risky file operations need automatic guards
- ❌ Session context gets lost between work sessions
- ❌ No audit trail of decisions made during sessions

## Your AI Team Architecture

Think of Claude Code as a team of specialized agents, each with specific responsibilities:

```
Your AI Team
├── 🛡️ Safety Officer (PreToolUse hooks)
│   └── Protects critical files, validates risky operations
├── 📋 Project Manager (/done command + Skills)
│   └── Tracks work, archives sessions, manages worklist
├── 🔍 Code Reviewer (PostToolUse hooks)
│   └── Lints code, validates changes before committing
├── 🎯 Context Manager (SessionStart/SessionEnd hooks)
│   └── Loads project state, saves progress
├── 🤔 Decision Maker (Stop/SubagentStop hooks - Prompt-based)
│   └── Evaluates if work is complete before declaring done
└── 📝 Custom Skills
    └── Domain-specific automations (/review-pr, /audit, etc.)
```

---

## 1. Safety Officer: PreToolUse Hooks 🛡️

### Purpose
Intercept and validate dangerous operations BEFORE they execute.

### What It Can Do
- Block writes to critical files (.env, package-lock.json, sensitive configs)
- Require confirmation for destructive bash commands (rm -rf, git force-push)
- Validate file paths to prevent writing outside project directory
- Prevent commits without proper messages
- Reject operations on protected directories (home dir, /etc, etc.)

### Implementation

Create `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/file-protection.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/bash-safety.sh"
          }
        ]
      }
    ]
  }
}
```

### Example: file-protection.sh

```bash
#!/bin/bash

# File Protection Hook - Prevents writes to critical files
# Input: $1 = tool name, $2 = tool input JSON

TOOL_INPUT="$2"

# Extract file path from JSON
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')

# Protected patterns
PROTECTED_PATTERNS=(
  "\.env"
  "package-lock\.json"
  "yarn\.lock"
  "Gemfile\.lock"
  "config/secrets"
  "\.aws/credentials"
  "\.ssh"
  "private_key"
)

# Check if file matches protected pattern
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" =~ $pattern ]]; then
    echo "BLOCKED: Cannot modify protected file: $FILE_PATH"
    exit 1
  fi
done

# Check if write is outside project directory
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
if [[ ! "$FILE_PATH" = "$CLAUDE_PROJECT_DIR"* ]]; then
  echo "BLOCKED: Write outside project directory: $FILE_PATH"
  exit 1
fi

exit 0
```

### Example: bash-safety.sh

```bash
#!/bin/bash

# Bash Safety Hook - Prevents destructive commands
# Input: $1 = tool name, $2 = tool input JSON

COMMAND=$(echo "$2" | jq -r '.command // empty')

# Dangerous patterns that require extra confirmation
DANGEROUS_PATTERNS=(
  "rm -rf"
  "git reset --hard"
  "git push --force"
  ":\(\(.*\)\)rm"
  "dd if="
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if [[ "$COMMAND" =~ $pattern ]]; then
    echo "WARNING: Potentially destructive command detected"
    echo "Command: $COMMAND"
    exit 1
  fi
done

exit 0
```

---

## 2. Project Manager: Custom Commands & Skills 📋

Already implemented: `/done` command for session archival.

### Additional Commands to Create

#### `/audit` - Code audit report
```bash
# Quickly scan for security issues, TODOs, FIXMEs
```

#### `/status` - Current project status
```bash
# Shows: open PRs, pending tests, uncommitted changes, todo progress
```

#### `/impact` - Change impact analysis
```bash
# Analyzes what files changed and what tests to run
```

#### `/next` - Next recommended task
```bash
# Looks at worklist and suggests what to work on based on dependencies
```

---

## 3. Code Reviewer: PostToolUse Hooks 📊

### Purpose
Validate code quality after writes automatically.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/code-quality.sh"
          }
        ]
      }
    ]
  }
}
```

### Example: code-quality.sh

```bash
#!/bin/bash

# Code Quality Hook - Runs linters after code changes
# Input: $1 = tool name, $2 = tool output JSON

FILE_PATH=$(echo "$2" | jq -r '.file_path // empty')

# Skip non-code files
if [[ ! "$FILE_PATH" =~ \.(swift|py|js|ts|go|rs)$ ]]; then
  exit 0
fi

# Run appropriate linter based on language
if [[ "$FILE_PATH" =~ \.swift$ ]]; then
  swiftlint "$FILE_PATH" --fix 2>/dev/null || true
fi

if [[ "$FILE_PATH" =~ \.py$ ]]; then
  black "$FILE_PATH" 2>/dev/null || true
  pylint "$FILE_PATH" 2>/dev/null || true
fi

if [[ "$FILE_PATH" =~ \.(js|ts)$ ]]; then
  prettier --write "$FILE_PATH" 2>/dev/null || true
  eslint "$FILE_PATH" --fix 2>/dev/null || true
fi

exit 0
```

---

## 4. Context Manager: SessionStart/SessionEnd Hooks 🎯

### SessionStart - Load project context

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-init.sh"
          }
        ]
      }
    ]
  }
}
```

### Example: session-init.sh

```bash
#!/bin/bash

# Session Initialization - Load context at startup
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Load recent todos
if [ -f "$PROJECT_DIR/.claude/PROJECT_WORKLIST.md" ]; then
  echo "📋 Loading project worklist..."
  head -20 "$PROJECT_DIR/.claude/PROJECT_WORKLIST.md"
fi

# Check git status
echo ""
echo "📊 Current git status:"
cd "$PROJECT_DIR"
git status --short | head -10 || true

# Load last session summary
LAST_SESSION=$(ls -t "$PROJECT_DIR/.claude/sessions/" 2>/dev/null | head -1)
if [ -n "$LAST_SESSION" ]; then
  echo ""
  echo "📅 Last session summary:"
  head -15 "$PROJECT_DIR/.claude/sessions/$LAST_SESSION/SESSION_SUMMARY.md" 2>/dev/null || true
fi

exit 0
```

### SessionEnd - Auto-archive

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PROJECT_DIR}/.claude/exit_handler.py"
          }
        ]
      }
    ]
  }
}
```

---

## 5. Decision Maker: Stop/SubagentStop Hooks 🤔

Use prompt-based hooks to evaluate context-aware decisions.

### Example: Should we mark task as complete?

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "prompt",
        "prompt": "The assistant just finished work. Evaluate: Has the original user request been fully addressed? Consider if all subtasks are done, tests pass, documentation updated. Respond with JSON: {\"complete\": true/false, \"reason\": \"string\"}",
        "timeout": 30
      }
    ]
  }
}
```

Claude Haiku evaluates the context and responds with JSON that can guide decisions.

---

## 6. Custom Skills: Domain-Specific Automations 🛠️

Create reusable skills for frequent tasks:

### `/review-pr` - Auto-review code changes
### `/test-local` - Run tests locally with safety checks
### `/backup` - Create backup before risky operations
### `/git-safe` - Safe git operations with validations
### `/deploy-check` - Pre-deployment checklist

---

## Complete Setup: Putting It All Together

### 1. Create hooks directory

```bash
mkdir -p ~/.claude/hooks
chmod +x ~/.claude/hooks/*.sh
```

### 2. Create settings.json

```bash
cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/file-protection.sh",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/bash-safety.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/code-quality.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-init.sh"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PROJECT_DIR}/.claude/exit_handler.py"
          }
        ]
      }
    ]
  }
}
EOF
```

### 3. Create hook scripts in project

```bash
# In your project
mkdir -p .claude/hooks
cp ~/.claude/hooks/file-protection.sh .claude/hooks/
cp ~/.claude/hooks/bash-safety.sh .claude/hooks/
```

### 4. Test hooks

Run `/help` in Claude Code to verify hooks are loaded.

---

## Safety Guidelines

⚠️ **Critical Rules for Your AI Team**:

1. **Always use absolute paths** in hooks - relative paths can be exploited
2. **Quote all variables** - `"$FILE_PATH"` not `$FILE_PATH`
3. **Validate inputs** - Never trust tool parameters directly
4. **Use `jq` for JSON parsing** - Don't regex JSON
5. **Test hooks locally** before adding to settings
6. **Log everything** for audit trails
7. **Set timeouts** - Prevent hanging hooks
8. **Use matchers** to limit hook scope - don't process everything

---

## MCP Integrations (Advanced)

Once you master hooks, integrate external tools:

- **GitHub MCP** - Get PR info, manage issues
- **Linear MCP** - Sync with project management tool
- **Slack MCP** - Send notifications to team
- **Memory MCP** - Persistent cross-session context

---

## Your Workflow With AI Team

### Typical Day
```
Session Start
  ↓ SessionStart hook loads project context
  ↓ You start coding
  ↓ PreToolUse validates all file writes (safety officer)
  ↓ PostToolUse lints/formats code automatically (code reviewer)
  ↓ You run /next to see recommended task
  ↓ You code and ask Claude to help
  ↓ Stop hook evaluates if work is complete
  ↓ You run /done to archive session
  ↓ SessionEnd hook auto-runs exit_handler.py
Session End
  ↓ Next session starts fresh with context loaded
```

---

## Your Cost: Avoiding Disasters

**The git rm -rf incident cost you:**
- Time to recover
- Anxiety
- Lost work context

**Prevention cost:**
- 30 minutes to set up hooks
- Negligible performance overhead
- Peace of mind forever

---

## Next: Build Your Team

Ready to implement? Here's the order:

1. **CRITICAL FIRST:** Safety Officer (PreToolUse hooks)
2. **NEXT:** Context Manager (SessionStart/End)
3. **THEN:** Code Reviewer (PostToolUse)
4. **AFTER:** Custom Commands (/audit, /status, /impact, /next)
5. **ADVANCED:** Prompt-based hooks and MCP integrations

---

## Resources

- Claude Code Docs: https://code.claude.com/docs/en/
- Hooks Reference: https://code.claude.com/docs/en/hooks
- Claude-Code-Guardrails: https://github.com/wangbooth/Claude-Code-Guardrails
- ClaudeKit: https://github.com/carlrannaberg/claudekit

---

**Remember:** Your AI team works 24/7 to keep you safe. Use them wisely.

---

*Last Updated: November 6, 2025*

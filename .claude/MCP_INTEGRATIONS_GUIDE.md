# MCP Integrations & Memory Guide for Claude Code

As a vibe coding physician building multiple projects, you need MCPs and memory to maintain context across sessions without losing momentum.

## The Problem

- 🧠 Context resets between sessions (especially with long conversations)
- 🔗 No direct integration with GitHub to create issues from code
- 📊 Manual tracking of project state across multiple repos
- 🔄 Can't persist notes/decisions between session threads

## The Solution: MCP + Memory

**Memory** = Persistent knowledge stored in files
**MCP** = Real-time integrations with external tools

Together they create a context-aware AI coding partner.

---

## Part 1: Claude Code Memory System 🧠

### What It Is

Memory is a four-tier system that automatically loads project context when you start coding:

```
4. Project Memory (Local) - Deprecated
    ↓
3. User Memory (~/.claude/CLAUDE.md) - Personal, all projects
    ↓
2. Project Memory (./.claude/CLAUDE.md) - Team, this project
    ↓
1. Enterprise Policy - Organization-wide rules
```

**Key fact:** All memory files are automatically loaded into your context when Claude Code launches.

### Tier 3: User Memory (~/.claude/CLAUDE.md)

Shared across ALL your projects. Use for:
- Personal coding style preferences
- Recurring instructions
- Your development environment setup
- General tools and conventions

Example:
```markdown
# My Coding Preferences

## Swift Development
- Use 4-space indentation
- Prefer guards over if-lets
- Document all public APIs
- Run swiftlint before commits

## Git Workflow
- Commit frequently
- Write detailed commit messages
- Create feature branches
- Never force-push to main

## Tools I Use
- Xcode 15.0+
- SwiftLint for code quality
- Git for version control
- Claude Code for AI assistance

## Projects
- Clara Provider App (iOS)
- Digital Doctor Graph (Python)
```

### Tier 2: Project Memory (./.claude/CLAUDE.md)

**Already created for you!** This is what's in your clara-provider-app project.

Use for:
- Project-specific architecture
- Development setup steps
- Code conventions for this project
- Known issues and workarounds
- API documentation

### Adding Quick Memories

During work, start any input with `#` to create a new memory:

```
# This project uses SwiftUI, not UIKit
# The API is Supabase-based, not Firebase
# We deploy to TestFlight every Friday
```

Claude Code will:
1. Extract the memory
2. Ask where to store it (user or project)
3. Add it to the appropriate CLAUDE.md file
4. Make it available for all future sessions

### Using Memory in Conversations

Reference memory in your prompts:
```
Based on my project setup, help me...
Given my coding preferences, implement...
Considering the architecture documented, fix...
```

Claude automatically loads and considers all memory when responding.

---

## Part 2: MCP Integrations 🔗

Model Context Protocol enables real-time connections to external systems.

### Why Use MCPs?

Memory is **persistent knowledge** (your notes, architecture docs).
MCPs are **real-time data** (GitHub issues, Linear tickets, Git history).

Together:
- Memory gives context about the project
- MCPs give data about the current state
- You get a fully aware AI coding partner

### Most Useful MCPs for Your Workflow

#### 1. **Git MCP** (High Priority)
**What it does:** Real-time access to your repository

```bash
# Install
pip install mcp-git
# Or use: https://github.com/evalstate/mcp-git
```

**Capabilities:**
- Read git log and commits (find what changed when)
- Get file history (understand code evolution)
- Show current diffs (see what's staged)
- Get branch information (understand git state)
- List contributors (team knowledge)

**Example usage:**
```
What changes did I make in the last 3 commits?
Show me the history of this specific file
What's the diff for the files I changed?
Who implemented this feature originally?
```

#### 2. **GitHub MCP** (High Priority)
**What it does:** Direct GitHub integration

```bash
# Install from: https://github.com/modelcontextprotocol/servers/tree/main/src/github
pip install mcp-github
```

**Capabilities:**
- List and search issues/PRs
- Create issues from code problems
- Comment on existing issues
- Get PR diffs
- Check CI/CD status
- Manage projects

**Example usage:**
```
Create a GitHub issue for this bug: [description]
What's the status of PR #123?
List all open issues labeled "bug"
Add this task as a GitHub issue with this description
```

#### 3. **Memory MCP** (Optional but Useful)
Adds SQLite-backed persistent memory across conversations

```bash
# Install from: https://github.com/mkreyman/mcp-memory-keeper
pip install mcp-memory-keeper
```

**Use case:** Storing conversation notes, decisions, learnings that survive token limit resets

#### 4. **Code Search MCP** (Optional)
Deep semantic search across entire codebase

```bash
# Install from: https://github.com/zilliztech/claude-context
pip install mcp-code-search
```

**Use case:** Finding patterns, understanding how features are implemented elsewhere

---

## Setup Instructions

### Step 1: Create User Memory File

```bash
# Create personal memory for all projects
mkdir -p ~/.claude
cat > ~/.claude/CLAUDE.md << 'EOF'
# Claude Code Personal Setup

## Vibe Coding Physician
Developer focused on healthcare AI, rapid iteration, and automated safeguards.

## My Development Style
- Fast iteration with safety guardrails
- Document as I go
- Test frequently
- Git commit regularly

## Tools & Environment
- macOS with Xcode
- Python 3.9+
- Git with conventional commits
- Claude Code with hooks and MCPs

## Key Projects
- Clara Provider App (iOS, SwiftUI)
- Digital Doctor Graph (Python, LangGraph)

## Coding Standards
- Use provided hooks to prevent disasters
- Commit meaningful changes with good messages
- Use /done at end of session for archival
- Reference memory for context across sessions

EOF
```

### Step 2: Install Git MCP

```bash
# Using pip
pip install mcp-git

# Or clone and set up
git clone https://github.com/evalstate/mcp-git.git
cd mcp-git
pip install -e .
```

### Step 3: Install GitHub MCP (Optional)

```bash
# From Anthropic's official repo
pip install mcp-github

# Set up authentication
export GITHUB_TOKEN=<your-github-token>
```

### Step 4: Add MCPs to Claude Code Settings

Edit `~/.claude/settings.json`:

```json
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
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/session-init.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PROJECT_DIR}/.claude/exit_handler.py",
            "timeout": 30
          }
        ]
      }
    ]
  },
  "mcpServers": {
    "git": {
      "command": "python",
      "args": ["-m", "mcp_git"],
      "env": {
        "MCP_GIT_ROOT": "${CLAUDE_PROJECT_DIR}"
      }
    },
    "github": {
      "command": "python",
      "args": ["-m", "mcp_github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

### Step 5: Test MCPs Work

In Claude Code:

```
/mcp

(You should see: git, github, and other MCPs listed)
```

Then try:

```
What were my last 3 commits?
(Git MCP should show recent commits)

List open issues in this repo
(GitHub MCP should show GitHub issues)
```

---

## Workflow: Memory + MCPs Together

### Session Start
```
Session begins
  ↓ SessionStart hook runs
  ↓ session-init.sh loads project context
  ↓ Memory files load (./.claude/CLAUDE.md + ~/.claude/CLAUDE.md)
  ↓ MCPs become available
  ↓ You ask: "What's the current state?"
  ↓ Claude combines:
    - Memory: "This project uses SwiftUI + Supabase"
    - Git MCP: "Last commit was X"
    - GitHub MCP: "3 open issues, 1 PR in review"
  ↓ Full context ready to work
```

### During Work
```
You: "Create a GitHub issue for this bug"
  ↓ Claude writes code to fix it
  ↓ Claude uses GitHub MCP to create the issue
  ↓ Issue appears in GitHub automatically

You: "What changed recently?"
  ↓ Git MCP shows recent commits
  ↓ Memory provides context about those changes
```

### Session End
```
You: /done
  ↓ SessionEnd hook runs
  ↓ exit_handler.py creates session summary
  ↓ Next session has full context
  ↓ MCPs + Memory ready immediately
```

---

## Your AI Team Now Has:

| Component | Function | Scope |
|-----------|----------|-------|
| **Hooks** | Prevent disasters | Local |
| **Memory** | Persistent knowledge | Cross-session |
| **Git MCP** | Repository context | Real-time git data |
| **GitHub MCP** | Issue/PR management | Real-time GitHub data |
| **/done command** | Session archival | Automatic |
| **SessionStart** | Load context | Automatic |

---

## Advanced: Multi-Project Memory

For managing multiple projects:

```
~/.claude/CLAUDE.md
  └─ Personal preferences (all projects)

GIT/vhs/clara-provider-app/.claude/CLAUDE.md
  └─ Clara Provider App specifics

GIT/digital-doctor-graph/.claude/CLAUDE.md
  └─ Digital Doctor Graph specifics
```

Each project's memory is automatically loaded when you're in that directory.

---

## Quick Reference

### Memory Commands
```
/memory          # Open memory editor
# new memory     # Create quick memory (start input with #)
/init            # Initialize project CLAUDE.md
```

### MCP Commands
```
/mcp             # List available MCPs
```

### Git MCP Example Prompts
```
"Show my last 5 commits"
"What files did I change in commit abc123?"
"Show me the diff for current changes"
"Who originally wrote this function?"
"Get the blame history for this file"
```

### GitHub MCP Example Prompts
```
"Create an issue titled 'Add error handling to X' with this description"
"List all open bugs in this repo"
"Show me the diff for PR #123"
"What's the status of my open PRs?"
"Add a comment to issue #456 saying..."
```

---

## Safety Notes

⚠️ **With MCPs, Claude can:**
- Read your git history
- Access GitHub issues/PRs
- Create issues automatically

✅ **Safe because:**
- Hooks still validate file writes
- GitHub requires authentication
- Git operations are read-mostly
- You can review before executing

🛡️ **Best practices:**
- Review generated GitHub issues before creation
- Keep GITHUB_TOKEN secure (don't commit it)
- Use memory files for sensitive info sparingly
- Review MCPs in settings.json regularly

---

## Resource List

### Official Docs
- Claude Code Memory: https://code.claude.com/docs/en/memory
- Claude Code MCP: https://code.claude.com/docs/en/mcp

### MCP Servers
- Git MCP: https://github.com/evalstate/mcp-git
- GitHub MCP: https://github.com/modelcontextprotocol/servers
- Memory MCP: https://github.com/mkreyman/mcp-memory-keeper
- Code Search: https://github.com/zilliztech/claude-context

### Learning
- MCPcat: https://mcpcat.io/ (MCP directory)
- Composio Blog: Excellent MCP integration guides

---

## Next Steps

1. **This session:** Create your user memory file
2. **Next session:** Install Git MCP and test
3. **Future:** Add GitHub MCP for issue management
4. **Advanced:** Explore other MCPs as needed

---

**Remember:** Memory gives context, MCPs give data. Together they make an AI coding partner that remembers where you left off and knows what's happening in your repos.

---

*Last Updated: November 6, 2025*

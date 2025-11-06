# Install Git MCP

This guide sets up the Git MCP server so Claude Code can access your git history automatically.

## What It Does

Git MCP gives Claude Code real-time access to:
- Recent commits and history
- File change patterns
- Git status and diffs
- Blame/authorship information

## Installation (2 minutes)

### Option 1: Using pip (Easiest)

```bash
# Install Git MCP server
pip install mcp-git

# Verify it works
python -m mcp_git --help
```

### Option 2: From Source

```bash
# Clone the repo
git clone https://github.com/evalstate/mcp-git.git
cd mcp-git

# Install in development mode
pip install -e .

# Verify
python -m mcp_git --help
```

## Configure Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "git": {
      "command": "python",
      "args": ["-m", "mcp_git"],
      "env": {
        "MCP_GIT_ROOT": "${CLAUDE_PROJECT_DIR}"
      }
    }
  }
}
```

## Test It Works

In Claude Code, type:

```
/mcp
```

You should see `git` listed as an available server.

Then try:

```
Show me my last 5 commits
```

Git MCP should return the commit information automatically.

## Troubleshooting

**"mcp_git command not found"**
- Reinstall: `pip install --upgrade mcp-git`
- Check Python path: `which python`

**"MCP_GIT_ROOT not set"**
- Make sure you're in a git repository
- Check `${CLAUDE_PROJECT_DIR}` is correctly set

**No commits returned**
- Verify git is initialized: `git log --oneline`
- Check MCP is listed: `/mcp`

---

See enhanced `/done` command that uses Git MCP: `/done`

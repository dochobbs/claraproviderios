# Install Git MCP

This guide sets up the Git MCP server so Claude Code can access your git history automatically.

## What It Does

Git MCP gives Claude Code real-time access to:
- Recent commits and history
- File change patterns
- Git status and diffs
- Blame/authorship information

## Installation Status

**Note:** Git MCP requires Python 3.10+. The official Anthropic MCP Git server is still being packaged and may not be available on PyPI yet.

## Installation Options

### Option 1: From Anthropic's Official MCP Servers (Recommended when available)

```bash
# Once available on PyPI:
pip install mcp-server-git

# Or from source:
git clone https://github.com/modelcontextprotocol/servers.git
cd servers/src/git
pip install -e .
```

**Requirements:** Python 3.10+

### Option 2: Alternative Community Git MCP Implementations

Several community implementations are available:

```bash
# Example from GitHub
git clone https://github.com/modelcontextprotocol/servers.git
cd servers/src/git
pip install -e .
```

### Option 3: Use Enhanced exit_handler.py (No Installation Needed)

Your `/done` command already includes git analysis without requiring Git MCP:
- Gathers commit data automatically
- Categorizes commits by type
- Analyzes file changes
- Creates comprehensive summaries

No additional installation needed - runs every time you use `/done`

## Configure Claude Code (When Available)

Once Git MCP is installed, add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "git": {
      "command": "python",
      "args": ["-m", "mcp_server_git"],
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

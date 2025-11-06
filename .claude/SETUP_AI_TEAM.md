# Quick Setup: Your AI Safety Team

This guide gets you protected in 5 minutes.

## Problem You're Solving ⚠️

Cursor deleted your home directory via git. We're preventing that.

## What You're Building

A 24/7 AI safety team with:
- ✅ File protection (blocks writes to sensitive files & home dir)
- ✅ Bash safety (blocks dangerous commands)
- ✅ Session context (loads project state automatically)
- ✅ Session archival (captures work daily)

## Installation: 5 Minutes

### Step 1: Copy settings to Claude Code

```bash
# Copy the template settings
cp ~/.claude/settings-template.json ~/.claude/settings.json

# Verify the path to project in the settings
# (Settings are now active)
```

### Step 2: Test it works

In Claude Code, type:
```
/help
```

You should see hooks are loaded. If you don't see "Hooks" in the output, check that `~/.claude/settings.json` exists.

### Step 3: Verify protection

In Claude Code, try:

```
Write a file to /tmp/test.txt
```

Should work ✓

Then try:

```
Write a file to ~/.ssh/id_rsa
```

Should be blocked ✓

```
Run: rm -rf /
```

Should be blocked ✓

### Step 4: Test session tracking

Do some work, then type:

```
/done
```

You should see artifacts created in `.claude/sessions/YYYY-MM-DD/`

### Step 5: Customize for your needs

Edit the protected patterns in `.claude/hooks/file-protection.sh`:

```bash
PROTECTED_PATTERNS=(
  "\.env"
  "YOUR_SENSITIVE_FILE_HERE"
  "another_protected_pattern"
)
```

## How It Works

### When you write/edit a file
```
You: "Create new config.js"
  ↓ PreToolUse hook runs
  ↓ file-protection.sh checks filename
  ↓ Is it protected? Block it
  ↓ Is it outside project? Block it
  ↓ Otherwise, allow it
  ↓ File gets written
```

### When you run bash
```
You: "Run npm install"
  ↓ PreToolUse hook runs
  ↓ bash-safety.sh checks command
  ↓ Is it dangerous (rm -rf, force push)? Block it
  ↓ Otherwise, allow it
  ↓ Command executes
```

### When session starts
```
Claude Code starts
  ↓ SessionStart hook runs
  ↓ session-init.sh shows:
    - Current worklist
    - Git status
    - Recent commits
    - Last session summary
  ↓ You see context loaded
  ↓ Ready to work
```

### When session ends (you run /done)
```
You: /done
  ↓ SessionEnd hook runs
  ↓ exit_handler.py creates:
    - SESSION_SUMMARY.md
    - WORKLIST.md
    - CHANGELOG.md
    - METRICS.txt
  ↓ Notification sent
  ↓ Next session has full context
```

## Protected Files (Default)

Your team blocks writes to:
- `.env`, `.env.local`, `.env.production` - Environment variables
- `*-lock.json`, `Podfile.lock` - Dependency locks
- `.ssh`, `.aws`, `.gnupg` - Credentials
- `*secret*`, `*private*` - Sensitive configs
- `docker-compose.prod` - Production configs

## Dangerous Commands Blocked

Your team blocks:
- `rm -rf /` - Delete everything
- `rm -rf ~` - Delete home directory
- `git reset --hard` - Lose commit history
- `git push --force` - Overwrite remote
- `dd if=` - Direct disk writes
- `mkfs` - Format filesystem

## Customization

### Add more protected files

Edit `.claude/hooks/file-protection.sh`:

```bash
PROTECTED_PATTERNS=(
  "\.env"
  "YOUR_PATTERN_HERE"  # Add your own
)
```

### Add more dangerous commands

Edit `.claude/hooks/bash-safety.sh`:

```bash
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "YOUR_DANGEROUS_PATTERN"  # Add your own
)
```

### Add custom hooks

Create new files in `.claude/hooks/` and add to settings.json

## Troubleshooting

### Hooks aren't running

Check:
1. `~/.claude/settings.json` exists
2. Settings are valid JSON: `jq . ~/.claude/settings.json`
3. Project directory is set: `echo $CLAUDE_PROJECT_DIR`
4. Reload Claude Code

### Getting blocked when you shouldn't

The `file-protection.sh` script is conservative. If you need to edit a protected file:

1. **Temporarily disable:** Comment out the pattern in the hook
2. **Make your edit**
3. **Re-enable:** Uncomment the pattern

### Hooks running too slowly

Adjust timeouts in settings:
```json
"timeout": 3  # Reduce from 5
```

### Need to understand what blocked you?

Check the error message - it tells you exactly what was blocked and why.

## Next Steps (Optional)

After this works, you can add:

### Code quality checks (PostToolUse)
Automatically lint/format code after writes

### Custom commands (/audit, /status, /impact)
Analyze code, show status, assess changes

### Prompt-based hooks
AI-powered decisions (should we mark as done?)

### MCP integrations
Connect to GitHub, Linear, Slack, etc.

See `AI_TEAM_GUIDE.md` for details.

## The Safety Guarantee

With these hooks enabled:

❌ **Cannot happen:**
- Accidental writes outside project directory
- Deletion of home directory via git commands
- Force pushes that lose work
- Writes to `.env` or credential files
- Direct filesystem operations

✅ **Still possible:**
- All normal development work
- Protected edits (with conscious effort)
- Safe git operations
- Everything useful, nothing destructive

## Emergency: Disable All Hooks

If something is broken, you can disable all hooks:

```bash
# Backup current settings
cp ~/.claude/settings.json ~/.claude/settings.json.bak

# Create empty settings
echo '{}' > ~/.claude/settings.json

# Reload Claude Code
```

Then fix and re-enable.

## Support

- Detailed guide: `AI_TEAM_GUIDE.md`
- Hook scripts: `.claude/hooks/`
- Settings template: `.claude/settings-template.json`

---

**You're now protected. Happy coding!** 🛡️

*P.S. - This took 30 minutes to set up. The git incident cost you days. Worth it.*

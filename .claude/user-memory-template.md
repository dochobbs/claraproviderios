# Claude Code User Memory - Vibe Coding Physician

This file should be copied to `~/.claude/CLAUDE.md` to persist across ALL your projects.

## Developer Profile

**Role:** Vibe Coding Physician
**Focus:** Healthcare AI, rapid iteration, automated safety
**Philosophy:** Move fast with guardrails, document continuously, test frequently

---

## Swift/iOS Development Standards

### Code Style
- **Indentation:** 4 spaces (standard Swift convention)
- **Architecture:** SwiftUI only (no UIKit)
- **Type System:** Leverage Swift's strong typing
- **Access Control:** Default to `private`, make `public` consciously
- **Documentation:** All public APIs must have doc comments

### SwiftUI Patterns
- Use `@Published` in ViewModels for reactive updates
- Prefer `@StateObject` over `@ObservedObject` for parent-owned objects
- Use `@EnvironmentObject` for shared state
- Avoid deeply nested View hierarchies (extract subviews at 3+ levels)
- Use `.eraseToAnyPublisher()` to hide implementation details

### Error Handling
- Use custom `Error` enums, not generic exceptions
- Include localized error descriptions
- Show user-facing error alerts, not debug logs
- Log errors with `os_log` for debugging

### Testing
- Write unit tests for business logic
- Test ViewModels separately from Views
- Use mocks for network calls
- Aim for 80%+ coverage on critical paths

### Xcode & Build
- Minimum iOS: 15.0
- Target: Latest 2 iOS versions
- SwiftLint enabled (enforce code style)
- Build configuration: Debug & Release

---

## Python Development Standards

### Code Style
- **Indentation:** 2 spaces (project standard)
- **Formatter:** Black for automatic formatting
- **Linter:** Pylint or Flake8
- **Type Hints:** Required for all functions
- **Docstrings:** Google-style for all public functions

### Project Structure
```
project/
├── src/           # Source code
├── tests/         # Test suite
├── docs/          # Documentation
├── requirements.txt
├── pyproject.toml
└── README.md
```

### Virtual Environments
- Always use `python -m venv .venv`
- Activate before any work: `source .venv/bin/activate`
- Freeze dependencies: `pip freeze > requirements.txt`
- Document setup in README

### Testing
- Use `pytest` with parallel execution (`pytest-xdist`)
- Run before commits: `pytest --cov`
- Aim for 80%+ coverage
- Test edge cases and error conditions

---

## Git Workflow & Commit Practices

### Commit Discipline
- **Frequency:** Commit when feature/fix is complete and tested
- **Messages:** Use conventional commits (FEATURE:, FIX:, DOCS:, REFACTOR:, SECURITY:, CHORE:)
- **Format:**
  ```
  TYPE: Brief one-line summary

  Detailed explanation of WHY and WHAT
  - Bullet point 1
  - Bullet point 2

  Related: Issue #123 or PR link
  ```

### Branch Strategy
- **Main:** Always production-ready, all tests passing
- **Features:** `feature/description` - merged via PR
- **Fixes:** `fix/description` - merged via PR
- **Never:** Force-push to main, commit directly to main

### Push Strategy
- **Local:** Commit when feature/fix is complete
- **Remote:** Push only when ready to ship (end of session or milestone)
- **Benefits:** Clean history, CI/CD friendly, flexibility to amend before pushing
- **Don't:** Push incomplete or broken work

### Before Any Push
```bash
git status              # Check what's staged
git diff HEAD~1         # Review changes
pytest                  # Run all tests
swiftlint (if iOS)      # Check code style
```

---

## Development Tools & Environment

### Required
- **macOS** (latest or latest-1)
- **Xcode 15.0+** for iOS development
- **Python 3.9+** for backend work
- **Git** with `git config` for commits

### Recommended
- **Claude Code** with hooks enabled
- **SSH keys** for GitHub access (no passwords)
- **Homebrew** for package management
- **iTerm2** or native Terminal

### Configuration Files
- `~/.zshrc` - Shell environment (PATH, aliases, API keys)
- `~/.ssh/config` - SSH shortcuts for repos
- `~/.gitconfig` - Git user, aliases, pull strategy
- `~/.claude/CLAUDE.md` - This file (user memory)

### API Keys & Secrets
- **NEVER** commit to git
- Store in `~/.zshrc` for local development
- Use Keychain for sensitive credentials in apps
- Use environment variables for CI/CD

---

## Projects Under Management

### 1. Clara Provider App
**Type:** iOS App (SwiftUI)
**Purpose:** Provider review and triage management
**Location:** `/Users/dochobbs/Downloads/Consult/GIT/vhs/clara-provider-app/`
**Status:** Production with active fixes
**Key Tech:** SwiftUI, Supabase, Face ID, Push Notifications

### 2. Digital Doctor Graph
**Type:** Python Backend (LangGraph)
**Purpose:** Healthcare agent with MCP servers
**Location:** `/Users/dochobbs/Downloads/Consult/GIT/digital-doctor-graph/`
**Status:** Production evaluation
**Key Tech:** FastAPI, LangGraph, PostgreSQL, MCP

### 3. VHS Evals
**Type:** Python Evaluation System
**Purpose:** Clara AI system evaluation framework
**Location:** `/Users/dochobbs/Downloads/Consult/VHS/evals/`
**Status:** Production ready
**Key Tech:** Anthropic SDK, Claude 3.5 Sonnet, Pytest

---

## Coding Preferences & Patterns

### Code Organization
- One main concept per file
- Extract to separate files at ~200 lines
- Keep functions under 30 lines (general rule)
- Group related functionality into classes/modules

### Naming Conventions
- **Classes:** PascalCase (e.g., `ProviderConversationStore`)
- **Functions:** camelCase (e.g., `fetchProviderRequests`)
- **Constants:** UPPER_SNAKE_CASE (e.g., `API_TIMEOUT`)
- **Private:** prefix with `_` (e.g., `_internalHelper`)
- **Booleans:** prefix with `is`, `has`, `can` (e.g., `isLoading`, `hasError`)

### Code Review Checklist
Before committing, ensure:
- [ ] Code runs without errors
- [ ] Tests pass locally
- [ ] No debug print statements
- [ ] No hardcoded values (use config)
- [ ] Follows project conventions
- [ ] Commit message is clear and detailed
- [ ] No unrelated changes mixed in

---

## Safety & Guardrails

### My Safety Setup
- **Claude Code hooks enabled** - File protection, bash safety
- **PreToolUse hooks** - Block writes to .env, ~/.ssh, system directories
- **Bash safety hooks** - Block rm -rf, force push, etc.
- **SessionStart hooks** - Load project context automatically
- **/done command** - Archive each session with metrics

### Before Any Risky Operation
- Review the command: What exactly will it do?
- Check the affected files: Is this the right scope?
- Consider the impact: Can this be undone?
- If uncertain: Ask Claude Code, don't guess

### Never Allow
- ❌ Writes outside project directory
- ❌ Deletes of home directory or system files
- ❌ Force pushes to main
- ❌ Commits without review
- ❌ Hardcoded credentials in code

---

## Session Workflow

### Starting a Session
1. Open Claude Code in project directory
2. SessionStart hook loads context automatically
3. Review project worklist: `.claude/PROJECT_WORKLIST.md`
4. Check last session summary: `.claude/sessions/YYYY-MM-DD/`
5. Start work with full context

### During a Session
- Create memories with `#` prefix if discovering patterns
- Use `/memory` to review or update context
- Reference project architecture from CLAUDE.md
- Commit frequently with good messages
- Test changes before moving on

### Ending a Session
1. Run `/done` command
2. Review generated artifacts:
   - SESSION_SUMMARY.md - What was done
   - WORKLIST.md - Updated todo list
   - CHANGELOG.md - Commits made
   - METRICS.txt - Session statistics
3. All files automatically archived and committed
4. Next session has full context ready

---

## Collaboration & Communication

### With Claude Code
- Be specific about what you want
- Reference architecture docs (CLAUDE.md)
- Ask for explanations, not just solutions
- Review generated code carefully
- Commit frequently for safety

### With Team (Future)
- Document decisions in commit messages
- Keep CLAUDE.md files updated
- Use conventional commits for clarity
- Reference issues in commits
- Comment on PRs constructively

---

## Learning & Continuous Improvement

### Code Quality Resources
- **Swift:** Apple's Swift Design Guidelines
- **Python:** PEP 8, Google Python Style Guide
- **Git:** Conventional Commits specification

### Projects to Study
- Clara Provider App - SwiftUI architecture
- Digital Doctor Graph - LangGraph + MCP patterns
- VHS Evals - Testing at scale

### Areas of Focus
- [ ] Deepen SwiftUI knowledge (animations, performance)
- [ ] Master LangGraph for complex workflows
- [ ] Improve testing coverage across projects
- [ ] Learn MCP integration patterns
- [ ] Develop custom hooks and skills

---

## Quick Reference

### Swift Commands
```bash
# Build
xcodebuild build -scheme "Clara Provider" -destination "generic/platform=iOS"

# Test
xcodebuild test -scheme "Clara Provider" -destination "platform=iOS Simulator,name=iPhone 15"

# Lint
swiftlint
```

### Python Commands
```bash
# Activate venv
source .venv/bin/activate

# Run tests
pytest --cov

# Run with reload
python src/main.py
```

### Git Commands
```bash
# Commit with template
git add -A
git commit -m "TYPE: Description"

# Check status
git status
git log --oneline -5

# Push when ready
git push origin main
```

### Claude Code Commands
```bash
/done              # End session, archive work
/memory            # View/edit memory files
/help              # Show all commands
/mcp               # List available MCPs
```

---

## Notes for Claude Code

When working with me:

1. **Always reference CLAUDE.md** - I've documented architecture and standards
2. **Use hooks to prevent disasters** - They're enabled for a reason
3. **Commit frequently** - Safety and tracking
4. **Test before declaring done** - Quality matters
5. **Ask questions** - I prefer clarity over assumptions
6. **Document decisions** - Commit messages tell the story

---

**Last Updated:** November 6, 2025
**Memory Version:** 1.0
**Projects:** 3 active, multiple consulting
**Philosophy:** Vibe code with guardrails, ship with confidence

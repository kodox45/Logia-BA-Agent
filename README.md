# BA System V5 — Project Template

Template repository for the BA System V5 dual-agent architecture (BA Agent + Claude Code).

## Usage

Clone this repo and remove `.git/` to start a new project:

```bash
git clone <repo-url> my-project
cd my-project
rm -rf .git
```

This is handled automatically by the `ba-init` skill — not intended for manual use.

## Directory Structure

### `.ba/` — BA Agent workspace (BA writes, CC reads)

| Directory | Purpose |
|-----------|---------|
| `discovery/` | Problem statement, constraints |
| `requirements/` | Features, roles, NFRs |
| `design/` | Layout, style, screens, components, flows |
| `design/assets/` | Uploaded logos, images |
| `validation/` | Traceability matrix |
| `triggers/` | CC trigger files (request/iteration) |
| `locks/` | Coordination locks |

Runtime files (`state.json`, `index.json`, all output JSONs) are created dynamically by BA during the workflow and excluded via `.gitignore`.

### `.claude/` — Claude Code workspace (CC writes, BA reads status)

| Directory | Purpose |
|-----------|---------|
| `skills/prototype/` | Prototype generator skill + HTML patterns |
| `proposal/` | Technical proposal output |
| `implementation/agents/` | Implementation sub-agent plans |
| `status/` | CC status exports (BA polls these) |
| `errors/` | CC error reports |
| `escalations/` | CC escalation requests |
| `approval/` | BA writes user decisions here |

### Root files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | CC agent instructions (read on every invocation) |
| `prototype/` | Generated HTML prototype output |

## Architecture

- **BA Agent** (Claude Desktop): User-facing, produces structured specs in `.ba/`
- **CC Agent** (Claude Code): Reads specs, executes technical tasks autonomously
- Communication via trigger files and status polling — no direct interaction

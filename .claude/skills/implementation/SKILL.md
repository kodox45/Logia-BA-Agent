---
name: implementation
description: PLACEHOLDER — to be rewritten
trigger:
  - implementation-request.json
output: src/, server/, tests/
strategy: agent-teams
team: dynamic (builders + validators from master-plan.json team_composition)
version: 6.0
---

# Implementation Orchestration — Lead Agent v6.0

> **Source:** v5 implementation/SKILL.md (587 lines)
> **Status:** PLACEHOLDER — content to be discussed and rewritten
> **Changes from v5:**
> - Frontmatter FIXED: `skill:` → `name:`, added `description`, `trigger`, `output`
> - Agent templates moved from .claude/agents/ to resources/agents/
> - Validation logic moved to scripts/validate-impl.sh
> - SKILL.md to be trimmed to ~450 lines


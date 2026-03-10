---
name: proposal
description: PLACEHOLDER — to be rewritten
trigger:
  - proposal-request.json
output: .claude/proposal/
strategy: sub-agents
team: 1 Lead + 3 Core (T-ENTITY, T-API, T-SYSTEM) + 1 Integrator (T-INTEGRATE) + 1 Validator (T-VALIDATE) + 1 Optional (T-PROTO-EXTRACT)
version: 6.0
---

# Proposal Generator — Sub-Agents v6.0

> **Source:** v5 proposal/SKILL.md (816 lines)
> **Status:** PLACEHOLDER — content to be discussed and rewritten
> **Changes from v5:**
> - Agent templates moved from .claude/agents/ to resources/agents/
> - Validation logic moved from monolithic hook to scripts/validate-proposal.sh
> - SKILL.md to be trimmed to ~450 lines with schemas extracted to resources/
> - Fix: agent spawn reference "via Task" → "via Agent"


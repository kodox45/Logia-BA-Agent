#!/usr/bin/env bash
# validate-draft.sh — Dispatcher hook (v6)
# Routes validation to the appropriate skill-specific validator based on active mode.
# Fired on SubagentCompleted and TaskCompleted events.
#
# Exit codes:
#   0 = valid (or no files to validate)
#   2 = validation failed (blocks task completion)

set -euo pipefail

# Drain stdin (hook metadata)
cat > /dev/null 2>&1 || true

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SKILLS_DIR="${PROJECT_DIR}/.claude/skills"

# --- Detect active mode from output directories ---

# Prototype mode: check if prototype/index.html exists
if [ -f "${PROJECT_DIR}/prototype/index.html" ]; then
  VALIDATOR="${SKILLS_DIR}/prototype/scripts/validate-prototype.sh"
  if [ -f "$VALIDATOR" ]; then
    exec bash "$VALIDATOR" "$PROJECT_DIR"
  else
    echo "WARN: Prototype validator not found at ${VALIDATOR}"
    exit 0
  fi
fi

# Proposal mode: check if .claude/proposal/ has files
if [ -d "${PROJECT_DIR}/.claude/proposal" ] && [ "$(ls -A "${PROJECT_DIR}/.claude/proposal" 2>/dev/null)" ]; then
  VALIDATOR="${SKILLS_DIR}/proposal/scripts/validate-proposal.sh"
  if [ -f "$VALIDATOR" ]; then
    exec bash "$VALIDATOR" "$PROJECT_DIR"
  else
    # Proposal validator not yet ported to v6
    exit 0
  fi
fi

# Foundation builder mode: check for implementation files
if [ -d "${PROJECT_DIR}/.claude/implementation" ] && [ "$(ls -A "${PROJECT_DIR}/.claude/implementation" 2>/dev/null)" ]; then
  VALIDATOR="${SKILLS_DIR}/foundation-builder/scripts/validate-foundation.sh"
  if [ -f "$VALIDATOR" ]; then
    exec bash "$VALIDATOR" "$PROJECT_DIR"
  else
    exit 0
  fi
fi

# No active mode detected — nothing to validate
exit 0

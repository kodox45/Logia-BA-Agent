#!/usr/bin/env bash
# validate-draft.sh — TaskCompleted hook for proposal draft validation
# Fired on every task completion. Validates any existing draft JSON files
# in .claude/proposal/drafts/ to ensure teammates produce valid output.
#
# Exit codes:
#   0 = valid (or no drafts yet)
#   2 = invalid draft detected (blocks task completion)

set -euo pipefail

# Read stdin (hook metadata) — drain to avoid broken pipe
cat > /dev/null 2>&1 || true

DRAFTS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/proposal/drafts"

# If drafts directory doesn't exist yet, nothing to validate
if [ ! -d "$DRAFTS_DIR" ]; then
  exit 0
fi

ERRORS=""

# check_structure FILE — verify non-empty, starts with {, ends with }
check_structure() {
  local file="$1"
  local name
  name=$(basename "$file")

  if [ ! -s "$file" ]; then
    ERRORS="${ERRORS}${name}: file is empty\n"
    return 1
  fi

  local first_char
  first_char=$(head -c 1 "$file")
  if [ "$first_char" != "{" ]; then
    ERRORS="${ERRORS}${name}: does not start with {\n"
    return 1
  fi

  local last_char
  last_char=$(tr -d '[:space:]' < "$file" | tail -c 1)
  if [ "$last_char" != "}" ]; then
    ERRORS="${ERRORS}${name}: does not end with } (possibly truncated)\n"
    return 1
  fi

  return 0
}

# check_key FILE KEY — verify file contains "KEY"
check_key() {
  local file="$1"
  local key="$2"
  local name
  name=$(basename "$file")

  if ! grep -q "\"${key}\"" "$file"; then
    ERRORS="${ERRORS}${name}: missing required key \"${key}\"\n"
  fi
}

# --- Validate each draft if it exists ---

if [ -f "$DRAFTS_DIR/_entities-draft.json" ]; then
  check_structure "$DRAFTS_DIR/_entities-draft.json" && \
    check_key "$DRAFTS_DIR/_entities-draft.json" "entities"
fi

if [ -f "$DRAFTS_DIR/_api-design-draft.json" ]; then
  if check_structure "$DRAFTS_DIR/_api-design-draft.json"; then
    # Client-only apps use "storage_operations", full-stack use "endpoints"
    if ! grep -q '"endpoints"' "$DRAFTS_DIR/_api-design-draft.json" && \
       ! grep -q '"storage_operations"' "$DRAFTS_DIR/_api-design-draft.json"; then
      ERRORS="${ERRORS}_api-design-draft.json: missing \"endpoints\" or \"storage_operations\"\n"
    fi
  fi
fi

if [ -f "$DRAFTS_DIR/_tech-stack-draft.json" ]; then
  check_structure "$DRAFTS_DIR/_tech-stack-draft.json" && \
    check_key "$DRAFTS_DIR/_tech-stack-draft.json" "frontend"
fi

if [ -f "$DRAFTS_DIR/_architecture-draft.json" ]; then
  check_structure "$DRAFTS_DIR/_architecture-draft.json" && \
    check_key "$DRAFTS_DIR/_architecture-draft.json" "folder_structure"
fi

# --- Implementation validation ---

IMPL_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/implementation"

if [ -d "$IMPL_DIR" ]; then
  # Validate master-plan.json if it exists
  if [ -f "$IMPL_DIR/master-plan.json" ]; then
    if check_structure "$IMPL_DIR/master-plan.json"; then
      if ! grep -q '"tasks"' "$IMPL_DIR/master-plan.json"; then
        ERRORS="${ERRORS}master-plan.json: missing required key \"tasks\"\n"
      fi
      if ! grep -q '"team_composition"' "$IMPL_DIR/master-plan.json"; then
        ERRORS="${ERRORS}master-plan.json: missing required key \"team_composition\"\n"
      fi
    fi
  fi

  # Validate approved-context.json if it exists
  if [ -f "$IMPL_DIR/approved-context.json" ]; then
    if check_structure "$IMPL_DIR/approved-context.json"; then
      if ! grep -q '"status"' "$IMPL_DIR/approved-context.json"; then
        ERRORS="${ERRORS}approved-context.json: missing required key \"status\"\n"
      fi
    fi
  fi

  # Validate validation-report.json if it exists
  if [ -f "$IMPL_DIR/validation-report.json" ]; then
    if check_structure "$IMPL_DIR/validation-report.json"; then
      if ! grep -q '"results"' "$IMPL_DIR/validation-report.json"; then
        ERRORS="${ERRORS}validation-report.json: missing required key \"results\"\n"
      fi
    fi
  fi
fi

# --- Report ---

if [ -n "$ERRORS" ]; then
  echo -e "Draft validation failed:\n${ERRORS}" >&2
  exit 2
fi

exit 0

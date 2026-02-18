---
name: implementation-setup
description: Analyzes approved proposal and BA specs to generate a project-specific implementation plan and orchestration skill. Produces master-plan.json + generated SKILL.md.
trigger: /implementation-setup (via .cc-prompt)
output: .claude/implementation/ + .claude/skills/implementation/SKILL.md
strategy: single-agent (generator)
---

# Implementation Setup — Generator

## What This Does

Analyze the approved proposal + BA specification files and generate:
1. `approved-context.json` — merged proposal + approval modifications
2. `master-plan.json` — task registry with dependencies and team composition
3. `.claude/skills/implementation/SKILL.md` — orchestration instructions for Lead (Session 2)
4. `implementation-setup-status.json` — completion signal for BA polling

**You are a one-pass generator.** Read inputs, analyze, generate artifacts, verify, exit.
Do NOT spawn teammates. Do NOT create tasks. Do NOT write source code.

---

## Step 0: Setup

```
ENSURE directories exist (create if missing):
  .claude/implementation/
  .claude/skills/implementation/
  .claude/status/

WRITE initial status to .claude/status/implementation-setup-status.json:
  {
    "operation": "implementation-setup",
    "version": "1.0",
    "status": { "current": "in_progress", "started_at": "{ISO-8601}" },
    "progress": { "percentage": 5, "step": "Setup", "message": "Initializing generator" },
    "output": null,
    "error": null
  }
```

---

## Step 1: Read All Inputs

### Required Files (FAIL if any missing)

Read each file and extract the specified information:

| File | Extract |
|------|---------|
| `.claude/proposal/entities.json` | Entity names, fields, relationships, field types |
| `.claude/proposal/api-design.json` | Endpoints or storage_operations, CRUD methods, data shapes |
| `.claude/proposal/tech-stack.json` | `app_type`, `frontend.framework`, `backend`, `testing`, `build_required`, `summary` |
| `.claude/proposal/architecture.json` | `folder_structure`, `screen_mapping`, `component_architecture`, `data_flow`, `state_shape` |
| `.claude/proposal/technical-proposal.json` | Consolidated view — cross-reference with other files |
| `.claude/approval/approval-response.json` | `status`, `decisions[]`, `modifications[]` |
| `.ba/requirements/features.json` | All features with `priority`, `acceptance_criteria[]`, `business_rules[]` |

```
IF any required file is missing or unreadable:
  WRITE error status:
    { "error": { "type": "missing_source", "message": "Required file missing: {path}",
      "file": "{path}", "recoverable": false } }
  EXIT immediately
```

### Optional Files (continue with reduced detail if missing)

| File | Extract | Fallback |
|------|---------|----------|
| `.ba/design/screens.json` | Screen definitions, section layouts, component refs | Use architecture.json screen_mapping only |
| `.ba/design/flows.json` | User journeys with steps, screen transitions | Derive from features.json |
| `.ba/design/components.json` | Component types, states, behavior | Derive from architecture.json |
| `.ba/requirements/nfr.json` | Performance, security, integrations | Assume defaults for app_type |
| `.ba/discovery/constraints.json` | Budget, timeline, technical limits | No constraints |
| `.ba/design/style.json` | Colors, typography, spacing, tokens | Use defaults |
| `prototype/index.html` | Reference implementation (read for design patterns, NOT copy) | No reference |

```
Update status: { percentage: 15, step: "Reading inputs", message: "All inputs loaded" }
```

---

## Step 2: Apply Approval Modifications

```
READ .claude/approval/approval-response.json

IF status == "approved":
  No modifications needed. Copy proposal data as-is.

IF status == "approved_with_modifications":
  FOR EACH modification in modifications[]:
    Apply entity renames → update entity names in context
    Apply feature rejections → mark features as excluded
    Apply constraint additions → add to constraints list
  Track which fields were modified and why.

WRITE .claude/implementation/approved-context.json:
  {
    "version": "1.0",
    "status": "{approved | approved_with_modifications}",
    "timestamp": "{ISO-8601}",
    "approval_ref": ".claude/approval/approval-response.json",
    "entities": { ...from entities.json, with modifications applied },
    "api_design": { ...from api-design.json, with modifications applied },
    "tech_stack": { ...from tech-stack.json },
    "architecture": { ...from architecture.json },
    "features": { ...from features.json, with rejections applied },
    "modifications_applied": [ ...list of changes, or empty array ]
  }

Update status: { percentage: 20, step: "Approval", message: "Approval modifications applied" }
```

---

## Step 3: Analyze Project

### App Type Detection

```
READ tech-stack.json:
  IF backend == null AND app_type == "client-only"
  THEN → app_type = "client-only"

  ELSE IF nfr.json exists AND nfr.integrations has 2+ entries
  THEN → app_type = "integration-heavy"

  ELSE → app_type = "standard-fullstack"
```

### Complexity Tier Detection

```
entity_count = count(entities.json.entities)
screen_count = count(architecture.json.screen_mapping)
role_count = count(distinct roles referenced in features.json)

IF entity_count <= 5 AND screen_count <= 3 AND role_count == 1
THEN → complexity = "simple"

ELSE IF entity_count <= 15 AND screen_count <= 10 AND role_count <= 4
THEN → complexity = "medium"

ELSE → complexity = "complex"
```

### Team Composition Decision

Based on app_type and complexity, select teammates:

| App Type | Complexity | Teammates |
|----------|-----------|-----------|
| client-only | simple | builder-frontend, validator-frontend |
| client-only | medium | builder-frontend, builder-state, validator-frontend |
| standard-fullstack | simple | builder-frontend, builder-backend, validator-frontend |
| standard-fullstack | medium | builder-frontend, builder-backend, validator-frontend, validator-backend |
| standard-fullstack | complex | builder-frontend, builder-backend, builder-infra, validator-frontend, validator-backend |
| integration-heavy | any | above + builder-integrations, validator-integration |

### Foundation Approach Detection

```
IF app_type == "client-only" AND tech-stack.build_required == false:
  foundation = "cdn-shell"
  → Create src/ directory
  → Generate index.html shell with CDN links from tech-stack.json
  → NO npm, NO package.json, NO tsconfig, NO types directory
  → CDN pins: use versions from tech-stack.json (e.g., Alpine @3, Tailwind CDN)

ELSE IF app_type == "client-only" AND tech-stack.build_required == true:
  foundation = "client-build"
  → Create folder structure from architecture.json
  → Generate package.json with dependencies from tech-stack.json
  → Generate tsconfig.json
  → Run npm install
  → Generate shared types from entities.json

ELSE (fullstack):
  foundation = "fullstack"
  → Create folder structure from architecture.json (including server/)
  → Generate package.json with all dependencies
  → Generate tsconfig.json
  → Run npm install
  → Generate shared types from entities.json
  → Generate shared constants from style.json, features.json, roles.json
```

### Validation Approach Detection

```
IF tech-stack.testing.unit.choice contains "jest" OR "vitest" OR "mocha":
  validation_approach = "test-framework"
  → Validator writes test files with describe/it blocks
  → Phase B: run tests, analyze results

ELSE IF tech-stack.testing.unit.choice contains "Manual" OR "N/A":
  validation_approach = "code-review"
  → Validator writes validation-checklist.md from spec
  → Phase B: read source code, verify against checklist
  → Output: validation-report.json
```

```
Update status: { percentage: 25, step: "Analysis", message: "Project analyzed: {app_type}, {complexity}" }
```

---

## Step 4: Generate Master Plan

Create the task list based on analysis results.

### Task Generation Rules

Tasks are **goal-oriented per domain**, not per-file:
- Each task has a clear **Goal** (what to achieve)
- Each task has **References** to proposal/BA files (entities, screens, features, flows)
- Each task has **Acceptance criteria** (how to know it's done)
- Teammate determines internally: how many files, which files, internal structure

### CDN Client-Only Simple (2 tasks)

For single-file CDN apps (like todo-app with Alpine.js):

**Build Task 1**: "Build complete application UI"
```
owner: builder-frontend
description:
  Domain: src/
  Goal: Generate the full application in src/index.html. This is a single-file
    CDN app — all HTML, CSS, and JavaScript in one file.

  Foundation (already created by Lead):
    src/index.html shell with CDN links (<head> with Tailwind CSS, Alpine.js, Lucide Icons)

  Read: .claude/proposal/entities.json (entity names, fields, types, relationships)
  Read: .claude/proposal/api-design.json (storage operations, localStorage keys, CRUD methods)
  Read: .claude/proposal/architecture.json (component architecture, state shape, data flow)
  Read: .ba/requirements/features.json (all features with acceptance criteria and business rules)
  Read: .ba/design/screens.json (screen layouts, sections, component placement)
  Read: .ba/design/flows.json (user journeys, step sequences, screen transitions)
  Read: .ba/design/components.json (component states, behaviors, interactions)
  Read: .ba/design/style.json (colors, typography, spacing, design tokens)
  Read: prototype/index.html (reference for design patterns — do NOT copy, implement from spec)

  Acceptance:
  - All must-have features functional with acceptance criteria met
  - All should-have features included
  - All entities fully implemented with all fields from entities.json
  - All storage operations from api-design.json working (localStorage CRUD)
  - State shape matches architecture.json state_shape
  - All screens rendered (main view + modal overlays)
  - All user flows completable end-to-end
  - Responsive layout (mobile-first)
  - Accessible (ARIA labels, keyboard navigation, semantic HTML)
  - Dark mode toggle (if specified in features)
  - No placeholder text, no TODO comments, no lorem ipsum
depends_on: []
```

**Validation Task 1**: "Validate application against specification"
```
owner: validator-frontend
description:
  Domain: .claude/implementation/
  Goal: Verify the generated application meets all acceptance criteria through
    code review (no test framework for CDN-only apps).

  Phase A (start immediately — parallel with builder):
    Read: .ba/requirements/features.json (acceptance criteria for each feature)
    Read: .claude/proposal/entities.json (expected data structures)
    Read: .ba/design/flows.json (expected user journeys)
    Write: .claude/implementation/validation-checklist.md
      Each acceptance criterion → checklist item with expected behavior
      Each business rule → verification step
      Each user flow → end-to-end scenario

  Phase B (after "Build complete application UI" task completes):
    Monitor builder task via TaskList()/TaskGet()
    Read: src/index.html (the generated application)
    Verify against each checklist item:
      - Required HTML elements present
      - Alpine.js directives correct (x-data, x-model, x-show, x-for, @click)
      - localStorage operations match api-design.json
      - All acceptance criteria addressed in code
      - Business rules enforced
      - Accessibility basics present
      - No placeholder text, no TODO comments
    Write: .claude/implementation/validation-report.json
depends_on: [] (Phase A starts immediately; Phase B waits for builder internally)
```

### Fullstack Apps (multiple tasks)

For apps with backend, database, auth, etc.:

Generate build tasks grouped by domain:
- **Foundation build tasks**: shared types, shared constants, project config
- **Backend build tasks**: routes, services, middleware, database schema (1-3 tasks by complexity)
- **Frontend build tasks**: components, pages, state management, API client (1-3 tasks by complexity)
- **Integration build tasks**: auth flows, external APIs, webhooks (if integration-heavy)

Generate validation tasks per domain:
- **Frontend validation**: component tests, page tests, a11y tests
- **Backend validation**: API endpoint tests, service tests
- **Integration validation**: auth flow tests, API integration tests

Set dependencies:
- Backend build tasks may have sequential dependencies
- Frontend build tasks may depend on backend (API client depends on routes)
- Validation tasks have NO blockedBy (Phase A starts immediately)
- QA task blocked by all build + validation tasks

### Write Master Plan

```
WRITE .claude/implementation/master-plan.json:
  {
    "version": "1.0",
    "generated_at": "{ISO-8601}",
    "project": {
      "name": "{from trigger or proposal}",
      "app_type": "{client-only | standard-fullstack | integration-heavy}",
      "complexity": "{simple | medium | complex}",
      "foundation": "{cdn-shell | client-build | fullstack}"
    },
    "team_composition": [
      {
        "name": "{teammate-name}",
        "agent_template": ".claude/agents/{builder|validator}.md",
        "domain": "{description}",
        "exclusive_write": ["{directory paths}"]
      }
    ],
    "tasks": [
      {
        "id": "T-{NNN}",
        "subject": "{goal-oriented title}",
        "owner": "{teammate-name}",
        "description": "{full task description with Domain, Goal, Read refs, Acceptance}",
        "depends_on": ["{task IDs}"],
        "active_form": "{present continuous verb phrase}"
      }
    ],
    "validation_approach": "{test-framework | code-review}",
    "estimated_files": {count},
    "metadata": {
      "entity_count": {N},
      "screen_count": {N},
      "feature_count": { "must": {N}, "should": {N}, "could": {N} },
      "operation_count": {N}
    }
  }

Update status: { percentage: 40, step: "Master plan", message: "Task registry generated with {N} tasks" }
```

---

## Step 5: Generate Implementation SKILL.md

Write `.claude/skills/implementation/SKILL.md` with **all 8 sections** below. This file must be **self-contained** — Lead reads only this file + agent templates, never the generator.

### Section 1: Project Context

```markdown
## 1. Project Context

Project: {project_name}
App Type: {app_type}
Complexity: {complexity}
Generated: {ISO-8601 timestamp}

### Tech Stack
- Frontend: {framework} + {styling}
- Backend: {backend_framework | "None (client-only)"}
- Database: {database | "localStorage"}
- Auth: {auth_method | "None"}
- Testing: {test_framework | "Manual (code review)"}

### Scope
- Entities: {count} ({comma-separated names})
- Screens: {count} ({S-xxx IDs})
- Features: {must_count} must + {should_count} should
- Operations: {count}
- Estimated files: {count}

### Approval Modifications
{list of changes, or "None — proposal approved without modifications"}

### Source References
proposal: .claude/proposal/
ba_specs: .ba/
agent_templates: .claude/agents/
approved_context: .claude/implementation/approved-context.json
```

### Section 2: Foundation Setup

Instructions for Lead to execute BEFORE spawning teammates:

```markdown
## 2. Foundation Setup

Execute these steps before spawning any teammates.
```

**FOR cdn-shell foundation**:
```markdown
### 2.1 Create Directory
  mkdir src/

### 2.2 Generate HTML Shell
  Write src/index.html with:
  - <!DOCTYPE html> + <html lang="en">
  - <head> with:
    - <meta charset="UTF-8"> + viewport meta
    - <title>{project_name}</title>
    - Tailwind CSS CDN: <script src="https://cdn.tailwindcss.com"></script>
    - Alpine.js CDN: <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3/dist/cdn.min.js"></script>
    - Lucide Icons CDN: <script src="https://unpkg.com/lucide@0.460.0/dist/umd/lucide.min.js"></script>
    - Tailwind config script block (if custom theme from style.json)
  - <body> with:
    - <div x-data="app()"> as root Alpine scope
    - Empty placeholder comment: <!-- Builder will generate content here -->
    - <script> block with: function app() { return { init() {} } }
  NOTE: Do NOT write application logic. Builder will overwrite the body and script.

### 2.3 No Package Installation
  CDN-only app — skip npm, tsconfig, types generation.
```

**FOR fullstack foundation**:
```markdown
### 2.1 Create Folder Structure
  Create all directories from architecture.json folder_structure

### 2.2 Initialize Project Config
  Generate package.json with dependencies from tech-stack.json
  Generate tsconfig.json
  Run: npm install

### 2.3 Generate Shared Types
  FOR EACH entity in entities.json:
    Write src/types/{entity-kebab-name}.ts with interface + enums
  Write src/types/index.ts barrel export

### 2.4 Generate Shared Constants
  Write src/constants/theme.ts from style.json design tokens
  Write src/constants/options.ts from features.json field options
  Write src/constants/roles.ts from roles.json (if multi-role)
```

### Section 3: Team Composition

```markdown
## 3. Team Composition

| Name | Agent Template | Domain | Exclusive Write |
|------|---------------|--------|----------------|
{table rows from master-plan.json team_composition}

### Spawn Prompt Template

For each teammate, construct a spawn prompt from these 4 parts:

Part 1 — Agent reference:
  "Read .claude/agents/{builder|validator}.md for your core capabilities and workflow."

Part 2 — Domain assignment:
  "You are {name}. Your domain: {domain description}.
   You have EXCLUSIVE write access to: {directories}.
   All other directories are READ-ONLY for you."

Part 3 — Task reference:
  "Use TaskList() to find your assigned tasks (owner: {name}).
   Pick lowest-ID unblocked task first.
   Read .claude/proposal/ for entity/API/architecture specs.
   Read .ba/ for acceptance criteria, screens, flows, business rules."

Part 4 — Coordination:
  "Use mailbox to communicate with other teammates.
   Follow the error resolution protocol in your agent template.
   Send 'blocked' message to Lead if you cannot proceed."
```

### Section 4: Task Registry

```markdown
## 4. Task Registry

Create ALL tasks using TaskCreate, then set dependencies with TaskUpdate.

{FOR EACH task from master-plan.json:}

### Task: "{subject}"
- owner: {teammate-name}
- activeForm: "{present continuous form}"
- description: |
    {full description with Domain, Goal, Read refs, Acceptance}
- depends_on: [{dependency task subjects}]
```

### Section 5: Orchestration Protocol

```markdown
## 5. Orchestration Protocol

### Lead Behavior: REACTIVE
You (Lead) do NOT poll or loop after spawning teammates.
You respond to:
  - TeammateIdle hook → check if all tasks done → if yes, enter QA phase
  - Mailbox messages → handle Tier 3 escalations, arbitrate builder-validator conflicts
  - All tasks completed → enter QA phase (Section 8)

### Teammate Behavior: AUTONOMOUS
  1. TaskList() → find assigned pending tasks
  2. Pick lowest-ID unblocked task
  3. TaskUpdate(status: "in_progress")
  4. Execute task using sub-agents (Task tool) for file generation
  5. Self-verify output (read back all files)
  6. TaskUpdate(status: "completed")
  7. TaskList() → next task
  8. No tasks left → go idle

### Directory Ownership
Each teammate has EXCLUSIVE write access to assigned directories.
Reading ANY directory is allowed.
Cross-directory writes MUST go through Lead.

### Mailbox Message Types
  validation_failure:  validator → builder  (code doesn't meet spec)
  fix_applied:         builder → validator  (fixed, please re-check)
  blocked:             any → Lead           (cannot proceed)
  info:                any → any            (advisory, non-blocking)
  unresolved:          validator → Lead     (Tier 2 exhausted)
```

### Section 6: Validation Protocol

```markdown
## 6. Validation Protocol

### Phase A: Write Validation Artifacts (start immediately)
Validator writes {tests | validation-checklist} from BA specification.
Does NOT wait for builder. Works from spec, not from code.

### Phase B: Execute Validation (after builder completes)
Validator monitors builder task via TaskList().
When builder task "completed" → execute validation.
{FOR test-framework: run tests, analyze results}
{FOR code-review: read source, verify against checklist, write validation-report.json}

### Error Resolution Tiers
Tier 1 — Self-Fix (1 attempt): validator fixes own bug → re-validate
Tier 2 — Builder Coordination (max 2 rounds): send validation_failure → wait fix_applied → re-validate
Tier 3 — Lead Arbitration: send unresolved_validation to Lead → wait for instruction

### Error Classification
COSMETIC → log warning, don't block (style, minor a11y)
FUNCTIONAL → must fix via Tier 1→2→3 (criterion not met, rule violated)
BLOCKING → escalate to user (conflicting req, missing spec)
```

### Section 7: Escalation Protocol

```markdown
## 7. Escalation Protocol

When a requirement is ambiguous, contradictory, or requires a business decision:

1. Teammate sends 'blocked' or 'unresolved' to Lead
2. Lead writes .claude/escalations/{id}.json:
   { escalation_id, timestamp, phase: "implementation", severity,
     context: { task, component, file, issue },
     question, options[], default }
3. Lead updates status with blocker info
4. BA detects escalation during polling, asks user, writes resolution
5. Lead applies resolution and unblocks

Severity rules:
  needs_clarification → continue with default, apply correction later
  blocking → skip this task, continue others
  critical → pause entirely until resolved
```

### Section 8: Completion Criteria

```markdown
## 8. Completion Criteria

### QA Checklist (Lead verifies after all tasks complete)
- [ ] All build tasks status: completed
- [ ] All validation tasks status: completed
- [ ] Validation report shows all FUNCTIONAL checks passing
- [ ] No unresolved escalations
- [ ] All files from architecture.json folder_structure exist
- [ ] No placeholder tokens (TODO, FIXME, lorem ipsum) in any generated file
{FOR cdn-shell: }
- [ ] src/index.html is valid HTML, opens in browser
- [ ] All CDN links resolve
{FOR fullstack: }
- [ ] npm install succeeds without errors
- [ ] Build command succeeds (if configured)
- [ ] All tests pass

### Build Verification
{FOR cdn-shell: No build step — verify file opens in browser}
{FOR fullstack: Run build command from tech-stack.json, verify 0 exit code}

### Final Status
Write to .claude/status/implementation-status.json:
  { operation: "implementation", status: { current: "completed" },
    output: { files_created: [paths], validation_report, team_summary } }

### Cleanup
  DELETE .ba/triggers/implementation-request.json
  KEEP all artifacts (.claude/implementation/, .claude/skills/implementation/)
```

```
Update status: { percentage: 60, step: "SKILL generation", message: "Implementation SKILL.md generated with 8 sections" }
```

---

## Step 6: Verify & Signal

### Verification

```
READ back .claude/implementation/approved-context.json:
  VERIFY: valid JSON, has "status" key, has "entities" key

READ back .claude/implementation/master-plan.json:
  VERIFY: valid JSON, has "tasks" array (non-empty), has "team_composition" array
  VERIFY: every task has: id, subject, owner, description, depends_on
  VERIFY: every team member has: name, agent_template, domain, exclusive_write

READ back .claude/skills/implementation/SKILL.md:
  VERIFY: all 8 sections present (search for ## 1. through ## 8.)
  VERIFY: no truncation (file does not end mid-sentence)
  VERIFY: no placeholder tokens ({...} or TODO)

IF any verification fails:
  FIX the issue and re-verify (max 2 iterations)
```

### Signal Completion

```
WRITE .claude/status/implementation-setup-status.json:
  {
    "operation": "implementation-setup",
    "version": "1.0",
    "status": {
      "current": "completed",
      "started_at": "{from Step 0}",
      "completed_at": "{ISO-8601}"
    },
    "progress": {
      "percentage": 100,
      "step": "Complete",
      "message": "Implementation setup finished. Ready for Session 2."
    },
    "output": {
      "master_plan": ".claude/implementation/master-plan.json",
      "skill_file": ".claude/skills/implementation/SKILL.md",
      "approved_context": ".claude/implementation/approved-context.json",
      "team_composition": {
        "teammates": ["{name1}", "{name2}"],
        "total_tasks": {N},
        "estimated_files": {N}
      }
    },
    "error": null
  }
```

Generator session is complete. Exit.

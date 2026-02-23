---
name: implementation-setup
description: Analyzes approved proposal and BA specs to generate a project intelligence document, layer-based master plan, and orchestration skill. Leverages proposal Session 29 improvements (reading_guide, domain_index, split API files, enriched business rules).
trigger: /implementation-setup (via .cc-prompt)
output: .claude/implementation/ + .claude/skills/implementation/SKILL.md
strategy: single-agent (generator)
---

# Implementation Setup — Generator

## What This Does

Analyze the approved proposal + BA specification files and generate:
1. `approved-context.json` — project intelligence document (extracted analysis, not data dump)
2. `master-plan.json` — task registry with layer-based dependencies and team composition
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
    "version": "2.0",
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
| `.claude/proposal/api-design.json` | Endpoints or storage_operations, CRUD methods, data shapes. **Check for `file_map{}` — see Split API Handling below** |
| `.claude/proposal/tech-stack.json` | `app_type`, `frontend.framework`, `backend`, `testing`, `build_required`, `summary` |
| `.claude/proposal/architecture.json` | `folder_structure`, `screen_mapping`, `component_architecture`, `data_flow`, `state_shape`, `auth_flow` |
| `.claude/proposal/technical-proposal.json` | `reading_guide{}`, `artifacts{}` (incl. `api_design_splits[]`), `coverage_summary{}`, `summary{}` |
| `.claude/approval/approval-response.json` | `status`, `decisions[]`, `modifications[]` |
| `.ba/requirements/features.json` | All features with `priority`, `acceptance_criteria[]`, `business_rules[]` |

### Conditionally Required (REQUIRED for medium+ complexity)

| File | Extract | Fallback (simple projects only) |
|------|---------|----------|
| `.ba/requirements/roles.json` | Role definitions, toggleable_permissions, role-screen access | Assume single role with full access |
| `.ba/design/layout.json` | Navigation type, interfaces{}, sidebar/header config | Use architecture.json screen_mapping only |

```
IF complexity != "simple" AND (roles.json missing OR layout.json missing):
  WRITE error status: { "error": { "type": "missing_source",
    "message": "Required for medium+ complexity: {path}", "recoverable": false } }
  EXIT immediately

IF complexity == "simple" AND files missing:
  Continue with fallback — single role, single interface assumed.
```

### Split API File Handling

```
AFTER reading api-design.json:
  IF api-design.json has file_map{}:
    → This is an INDEX file (domain_index + file_map + auth + summary)
    → Endpoints are in the SPLIT files, NOT the index
    → FOR EACH entry in file_map:
        READ the split file at entry.file path (e.g., .claude/proposal/api-design-orders.json)
    → Store all split file contents for domain cluster extraction
    Note: technical-proposal.json.artifacts.api_design_splits[] also lists all split file paths
  ELSE:
    → This is a monolithic api-design.json — all endpoints inline
    → No split files to read
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

## Step 2: Extract Project Intelligence + Apply Approval

### Apply Approval Modifications

```
READ .claude/approval/approval-response.json

IF status == "approved":
  No modifications needed. Use proposal data as-is.

IF status == "approved_with_modifications":
  FOR EACH modification in modifications[]:
    Apply entity renames → update entity names in context
    Apply feature rejections → mark features as excluded
    Apply constraint additions → add to constraints list
  Track which fields were modified and why.
```

### Write Project Intelligence Document

Instead of dumping all proposal content, write **extracted analysis results**. This document contains EXTRACTED ANALYSIS, not source data. Teammates MUST still read `.claude/proposal/` and `.ba/` directly for implementation details.

```
WRITE .claude/implementation/approved-context.json:
  {
    "version": "2.0",
    "timestamp": "{ISO-8601}",
    "approval": {
      "status": "{approved | approved_with_modifications}",
      "approval_ref": ".claude/approval/approval-response.json",
      "modifications_applied": [ ...list of changes, or empty array ]
    },
    "project_profile": {
      "app_type": "{from Step 3}",
      "complexity": "{from Step 3}",
      "foundation": "{from Step 3}",
      "validation_approach": "{from Step 3}"
    },
    "interface_map": [ ...from Extraction 1 ],
    "domain_clusters": [ ...from Extraction 2 ],
    "guard_chain": { ...from Extraction 3 },
    "state_sharing": [ ...from Extraction 4 ],
    "business_rule_summary": { ...from Extraction 5 },
    "permission_matrix": { ...from Extraction 6 },
    "reading_guide": { ...from Extraction 7 }
  }
```

### 7 Extraction Algorithms

Run these extractions after Step 3 analysis is complete, then write the document.

**Extraction 1 — Interface Map**:
```
SOURCE: layout.json.interfaces{} × architecture.json.screen_mapping[]
ALGORITHM:
  FOR EACH interface in layout.json.interfaces:
    Collect screens from architecture.json.screen_mapping[] where screen belongs to this interface
    Map target_roles from roles.json
OUTPUT:
  [{ "id": "waiter-cashier-ui", "name": "...", "type": "bottom-tabs",
     "target_roles": ["waiter-cashier"],
     "screens": [{ "screen_id": "S-002", "page_component": "OrderListPage", "route": "/pos/orders" }] }]
FALLBACK: If layout.json missing or single-interface → [{ "id": "default", "screens": [all screens] }]
```

**Extraction 2 — Domain Clusters**:
```
SOURCE: api-design.json.domain_index{} + file_map{} + entities.json + features.json
ALGORITHM:
  IF api-design.json has domain_index:
    FOR EACH domain in domain_index:
      Collect entities that belong to this domain
      Collect endpoint_ids from the domain's split file (or inline section)
      Collect screens that reference these entities (from architecture.json.screen_mapping)
      Collect feature_ids via entity-feature traceability (features that reference these entities)
      Collect high_complexity_rules: scan endpoint business_rules[] for formula{}/steps[]/validation{}
  ELSE:
    Create single cluster "all" with all entities/endpoints
OUTPUT:
  [{ "domain": "order-management",
     "entities": ["Order","OrderItem","Table"],
     "endpoint_ids": ["EP-036","EP-037"],
     "split_file": ".claude/proposal/api-design-orders.json",
     "screens": ["S-002","S-003","S-004"],
     "feature_ids": ["F-001","F-002","F-003"],
     "high_complexity_rules": [{ "rule": "Stock deduction", "type": "multi_step", "steps": 5 }] }]
FALLBACK: If client-only → empty array (no API domains)
```

**Extraction 3 — Guard Chain**:
```
SOURCE: architecture.json.auth_flow.middleware + screen_mapping[].guards
ALGORITHM:
  Collect all unique guards from auth_flow and screen_mapping
  Order by dependency (AuthGuard before RoleGuard before PermissionGuard)
  Map each screen to its required guards
OUTPUT:
  { "order": ["AuthGuard","RoleGuard","PermissionGuard","PinGate","ShiftGuard"],
    "screen_guards": { "S-002": ["AuthGuard","RoleGuard","PinGate","ShiftGuard"] } }
FALLBACK: If no auth_flow → { "order": [], "screen_guards": {} }
```

**Extraction 4 — State Sharing**:
```
SOURCE: architecture.json.data_flow.cross_screen_state (or state_shape)
ALGORITHM:
  FOR EACH shared store/state:
    Identify producer screens (write to store)
    Identify consumer screens (read from store)
OUTPUT:
  [{ "store": "orderStore", "producers": ["S-003","S-004"], "consumers": ["S-002","S-006"] }]
FALLBACK: If no cross_screen_state → empty array
```

**Extraction 5 — Business Rule Summary**:
```
SOURCE: All endpoint business_rules[] from api-design (split or monolithic) + features.json
ALGORITHM:
  Scan all endpoints for business_rules[]
  Classify each rule:
    Has formula{} → type: "calculation"
    Has steps[] → type: "multi_step"
    Has validation{} or constraint → type: "constraint"
  Count by type, collect critical rules (multi_step with 3+ steps, calculations with formulas)
OUTPUT:
  { "by_type": { "calculation": 5, "multi_step": 8, "constraint": 12 },
    "critical_rules": [{ "rule": "PPN calculation", "formula": "subtotal * ppn_rate", "domain": "payment" }] }
FALLBACK: If client-only with no business_rules → { "by_type": {}, "critical_rules": [] }
```

**Extraction 6 — Permission Matrix**:
```
SOURCE: roles.json.toggleable_permissions + api-design.json.auth.permission_checks
ALGORITHM:
  FOR EACH toggleable permission:
    Map to affected endpoints (which endpoints check this permission)
    Map to affected screens (which screens show/hide based on this permission)
OUTPUT:
  { "toggleable": [{ "id": "perm-view-stock", "scope": "inventory read",
      "affected_endpoints": ["EP-024"], "affected_screens": ["S-010"] }] }
FALLBACK: If no toggleable_permissions → { "toggleable": [] }
```

**Extraction 7 — Reading Guide**:
```
SOURCE: technical-proposal.json.reading_guide
ALGORITHM: Copy directly from technical-proposal.json
OUTPUT: { ...reading_guide as-is }
FALLBACK: If no reading_guide → {}
```

```
Update status: { percentage: 20, step: "Intelligence extraction", message: "Project intelligence document written" }
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

  ELSE IF architecture.json.app_type == "offline-first"
       OR tech-stack.summary.architecture_pattern contains "offline"
  THEN → app_type = "offline-first"

  ELSE → app_type = "standard-fullstack"
```

### Complexity Tier Detection

```
entity_count = count(entities.json.entities)
screen_count = count(architecture.json.screen_mapping)
role_count = count(distinct roles referenced in features.json)
interface_count = count(layout.json.interfaces) OR 1
domain_group_count = count(api-design.json.domain_index keys) OR 0

IF entity_count <= 5 AND screen_count <= 3 AND role_count == 1
THEN → complexity = "simple"

ELSE IF entity_count <= 15 AND screen_count <= 10 AND role_count <= 4
THEN → complexity = "medium"

ELSE → complexity = "complex"

Post-adjustment:
  IF interface_count > 2 AND complexity == "simple" → bump to "medium"
  IF domain_group_count > 8 AND complexity != "complex" → bump to "complex"
```

### Team Composition Decision

Algorithmic approach based on app_type, complexity, and detected dimensions:

```
Base team (always):
  builder-frontend, validator-frontend

ADD IF app_type != "client-only":
  builder-backend, validator-backend

ADD IF complexity == "complex" AND interface_count > 2:
  Split builder-frontend per interface:
    builder-frontend-{interface_id} for each interface
  (replaces single builder-frontend)

ADD IF app_type == "offline-first":
  builder-sync
  (Owns: Dexie schema, sync engine, service worker, PWA manifest)

ADD IF app_type == "integration-heavy":
  builder-integrations, validator-integration

Validator count rule:
  1 validator per builder group (frontend, backend, sync, integration)
  If frontend split by interface → still 1 validator-frontend for all
```

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

ELSE IF app_type == "offline-first":
  foundation = "offline-first"
  → Fullstack foundation PLUS:
  → Generate Dexie database schema from entities.json
  → Generate PWA manifest from tech-stack.json
  → Generate service worker registration

ELSE (standard-fullstack or integration-heavy):
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
IF tech-stack.testing has unit framework AND e2e framework:
  validation_approach = "hybrid"
  → Unit tests for services/utils (vitest/jest)
  → Component tests for UI (React Testing Library / similar)
  → E2E tests for critical flows (Playwright / Cypress)
  → Code-review for quality/a11y

ELSE IF tech-stack.testing.unit.choice contains "jest" OR "vitest" OR "mocha":
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

**Now run the 7 Extraction Algorithms from Step 2 and write approved-context.json.**

---

## Step 4: Generate Master Plan

Create the task list based on analysis results.

### Task Generation Rules

Tasks are **goal-oriented per domain**, not per-file:
- Each task has a clear **Goal** (what to achieve)
- Each task has **Read (targeted)** directives referencing specific entity names, endpoint IDs, screen IDs
- Each task has **Acceptance criteria** (how to know it's done)
- Teammate determines internally: how many files, which files, internal structure

### Task Description Template

Every task description (all layers) MUST contain these sections:

```
Domain: {directories this task owns}
Goal: {1-2 sentence objective}
Read (targeted):
  {file} → {specific entities/endpoints/screens by name/ID}
Key Business Rules: {embedded from business_rule_summary — formula/steps for this domain}
State Dependencies: {from state_sharing — who produces/consumes stores relevant to this task}
Acceptance: {per-feature criteria with F-xxx IDs}

CRITICAL: Read directives MUST reference specific entity names, endpoint IDs,
screen IDs, and feature IDs — NOT generic "Read: entities.json".
Use reading_guide to determine which file sections each role needs.
```

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

### Non-CDN Apps: Layer-Based Decomposition

For all apps where `foundation != "cdn-shell"`, use layer-based task generation:

**LAYER 1: Core Infrastructure** (1-3 tasks, no dependencies)

```
Task: "Set up frontend infrastructure"
  owner: builder-frontend (or builder-frontend-{first-interface} if split)
  description:
    Domain: src/layouts/, src/routes/, src/components/auth/, src/components/navigation/
    Goal: Implement layout components, routing, auth guards, navigation, store skeletons.

    Read (targeted):
      architecture.json → auth_flow{} (guard chain, login redirect), screen_mapping[].guards
      layout.json → interfaces{} (layout components per interface, nav items, sidebar config)
      roles.json → role names + access patterns (for guard implementation)
      tech-stack.json → frontend section (framework, router, state library)
    Key Business Rules: None (infrastructure layer)
    State Dependencies: Creates store skeletons that Layer 2 will populate
    Acceptance:
      - All layout components render (1 per interface)
      - Auth flow works (login → guard → redirect)
      - All guards from guard_chain implemented
      - Router configured with all routes from screen_mapping
      - Store files created (empty shape, ready for Layer 2)
  depends_on: []
```

```
IF app_type != "client-only":
  Task: "Set up backend infrastructure"
    owner: builder-backend
    description:
      Domain: server/, prisma/ (or db/), shared/
      Goal: Database schema, server setup, auth middleware, base route structure.

      Read (targeted):
        entities.json → ALL entities (for DB schema — every field, relation, enum)
        architecture.json → auth_flow{} (middleware chain), data_flow.sync_flow (if offline-first)
        tech-stack.json → backend section (framework, ORM, database)
        roles.json → role definitions (for RBAC middleware)
      Key Business Rules: None (infrastructure layer)
      State Dependencies: None
      Acceptance:
        - Database schema created with all entities and relationships
        - Server starts without errors
        - Auth middleware chain functional (register, login, token validation)
        - RBAC middleware rejects unauthorized access
        - Base route files created for each domain (empty handlers, ready for Layer 2)
    depends_on: []
```

```
IF app_type == "offline-first":
  Task: "Set up offline infrastructure"
    owner: builder-sync
    description:
      Domain: src/db/, src/services/syncService.ts, public/ (PWA assets)
      Goal: Dexie database schema, sync queue, service worker, PWA manifest.

      Read (targeted):
        entities.json → ALL entities (for Dexie table definitions with indexes)
        architecture.json → data_flow.sync_flow{} (sync strategy, conflict resolution)
        tech-stack.json → pwa{}, offline_storage{}, sync_engine{} sections
      Key Business Rules: None (infrastructure layer)
      State Dependencies: Creates sync service that Layer 2 stores will use
      Acceptance:
        - Dexie schema covers all entities with correct indexes
        - Sync queue table created
        - Service worker registers and caches app shell
        - PWA manifest has correct icons/colors from style.json
        - Offline detection utility works
    depends_on: []
```

**LAYER 2: Domain Features** (1 per domain_cluster, parallel within layer)

```
FOR EACH cluster in domain_clusters (from approved-context.json):

  Task: "Build {cluster.domain} frontend"
    owner: builder-frontend[-{interface}] (match interface that owns cluster.screens)
    description:
      Domain: src/pages/{cluster.screens mapped to page dirs}, src/components/{cluster.domain}/
      Goal: Implement all screens and components for the {cluster.domain} domain.

      Read (targeted — use reading_guide for file navigation):
        entities.json → {cluster.entities} ONLY (e.g., "Order", "OrderItem", "Table")
        {cluster.split_file OR api-design.json filtered to cluster.endpoint_ids}
          → endpoints: {cluster.endpoint_ids} (e.g., EP-036, EP-037, EP-038)
        features.json → {cluster.feature_ids} ONLY (e.g., F-001, F-002, F-003)
        screens.json → sections for {cluster.screens} (e.g., S-002, S-003, S-004)
        flows.json → flows involving {cluster.screens}
        components.json → components referenced in these screens
      Key Business Rules (embedded from cluster.high_complexity_rules):
        {FOR EACH rule in cluster.high_complexity_rules:}
        - "{rule.rule}" [{rule.type}: {formula OR steps count}]
      State Dependencies (from state_sharing):
        Produces: {stores this domain writes to}
        Consumes: {stores this domain reads from}
      Acceptance (per-feature from features.json):
        {FOR EACH feature_id in cluster.feature_ids:}
        - {feature_id}: {acceptance_criteria summary}
    depends_on: ["Set up frontend infrastructure"]

  IF app_type != "client-only":
    Task: "Build {cluster.domain} backend"
      owner: builder-backend
      description:
        Domain: server/routes/{cluster.domain}/, server/services/{cluster.domain}/
        Goal: Implement all API endpoints and business logic for {cluster.domain}.

        Read (targeted):
          {cluster.split_file OR api-design.json filtered to cluster.endpoint_ids}
            → ALL endpoints in this domain (handlers, validation, business rules)
          entities.json → {cluster.entities} ONLY (for type references and relations)
          features.json → {cluster.feature_ids} (for acceptance criteria)
        Key Business Rules (embedded):
          {FOR EACH rule in cluster.high_complexity_rules:}
          - "{rule.rule}" [{rule.type}: {formula OR steps count}, side_effects: {list}]
        State Dependencies: None (backend is stateless per-request)
        Acceptance:
          - All {cluster.endpoint_ids} return correct responses
          - Business rules enforced (calculations match formulas, multi-step sequences complete)
          - Permission checks on protected endpoints
          - Input validation on all mutation endpoints
      depends_on: ["Set up backend infrastructure"]

  Task: "Validate {cluster.domain}"
    owner: validator-frontend (or validator-backend if backend-only domain)
    description:
      Domain: .claude/implementation/ (reports), tests/{cluster.domain}/ (if test-framework)
      Goal: Validate all features in {cluster.domain} against specification.

      Phase A (start immediately — parallel with builders):
        Read: features.json → {cluster.feature_ids} acceptance criteria
        Read: {cluster.split_file OR api-design.json} → expected responses
        Write: {tests OR validation-checklist} from spec
        Each acceptance criterion → test case / checklist item
        Each business rule → verification step with expected values

      Phase B (after "Build {cluster.domain} frontend/backend" tasks complete):
        Execute validation against built code
        Write: validation results to .claude/implementation/
    depends_on: [] (Phase A starts immediately; Phase B waits internally)
```

**LAYER 3: Cross-Cutting Concerns** (conditional, after Layer 2)

```
IF app_type == "offline-first":
  Task: "Implement sync engine integration"
    owner: builder-sync
    description:
      Domain: src/services/, src/stores/ (sync hooks only)
      Goal: Wire sync engine to all domain stores, implement conflict resolution.

      Read (targeted):
        architecture.json → data_flow.sync_flow{} (conflict resolution strategy)
        entities.json → ALL entities (sync priority ordering)
      Acceptance:
        - Each store syncs to server when online
        - Conflict resolution handles all entity types
        - Offline queue drains correctly on reconnect
    depends_on: [All Layer 2 backend tasks]

IF tech-stack has printing/export/webhooks:
  Task per concern (e.g., "Implement receipt printing", "Implement CSV export")
    owner: builder-frontend or builder-integrations
    depends_on: [Related Layer 2 tasks that produce the data]
```

**LAYER 4: Integration & Polish** (after Layers 2+3)

```
Task: "Seed data and end-to-end verification"
  owner: validator-frontend (or validator-backend)
  description:
    Domain: .claude/implementation/
    Goal: Create seed data for all entities, verify complete user flows end-to-end.

    Read (targeted):
      entities.json → ALL entities (for seed data generation)
      flows.json → ALL flows (for end-to-end scenarios)
      features.json → must-have features (for critical path verification)
    Acceptance:
      - Seed data covers all entities with realistic values
      - All critical user flows complete without errors
      - Cross-domain flows work (e.g., order → payment → inventory)
  depends_on: [All Layer 2 + Layer 3 tasks]
```

### Write Master Plan

```
WRITE .claude/implementation/master-plan.json:
  {
    "version": "2.0",
    "generated_at": "{ISO-8601}",
    "project": {
      "name": "{from trigger or proposal}",
      "app_type": "{client-only | standard-fullstack | offline-first | integration-heavy}",
      "complexity": "{simple | medium | complex}",
      "foundation": "{cdn-shell | client-build | fullstack | offline-first}",
      "interface_map": [ ...from approved-context.json ],
      "domain_clusters": [ ...from approved-context.json, names only for overview ]
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
        "layer": {0-4},
        "description": "{full task description with Domain, Goal, Read (targeted), Key Business Rules, State Dependencies, Acceptance}",
        "depends_on": ["{task IDs}"],
        "active_form": "{present continuous verb phrase}"
      }
    ],
    "validation_approach": "{test-framework | code-review | hybrid}",
    "estimated_files": {count},
    "metadata": {
      "entity_count": {N},
      "screen_count": {N},
      "interface_count": {N},
      "domain_cluster_count": {N},
      "feature_count": { "must": {N}, "should": {N}, "could": {N} },
      "operation_count": {N}
    }
  }

Update status: { percentage: 40, step: "Master plan", message: "Task registry generated with {N} tasks across {L} layers" }
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

### Interfaces
{N} interfaces: {FOR EACH interface: "{name}" ({screen_count} screens)}
{OR "Single interface (default)" for simple projects}

### Domain Clusters
{N} clusters: {FOR EACH cluster: "{domain}" ({entity_count} entities, {endpoint_count} endpoints)}
{OR "None (client-only)" for CDN apps}

### Split API Files
{FOR EACH split file: "- {path}"}
{OR "None — monolithic api-design.json" OR "None — client-only"}

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

**FOR fullstack / offline-first foundation**:
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

**ADDITIONALLY for offline-first foundation**:
```markdown
### 2.5 Generate Dexie Schema
  Read entities.json → create Dexie table definitions with indexes
  Write src/db/database.ts with:
    - Dexie instance
    - Table definitions for ALL entities
    - Version migration
    - Index definitions (primary keys + foreign keys + search fields)

### 2.6 PWA Setup
  Write public/manifest.json from tech-stack.json (name, icons, theme_color)
  Write src/sw-register.ts (service worker registration)
  Write public/sw.js (app shell caching strategy)
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

Part 3 — Task reference (ENHANCED with reading targets):
  "Use TaskList() to find your assigned tasks (owner: {name}).
   Pick lowest-ID unblocked task first.

   Your reading targets (from reading_guide):
   {IF builder-frontend}: architecture.json → screen_mapping + component_architecture; screens.json → your assigned screens; entities.json → summary only (types are in src/types/)
   {IF builder-backend}: entities.json → FULL (all fields, relations); api-design → use domain_index to find your domain's split file; architecture.json → auth_flow + data_flow
   {IF builder-sync}: architecture.json → data_flow.sync_flow; entities.json → FULL (for Dexie schema); tech-stack.json → pwa + offline_storage sections
   {IF validator}: features.json → acceptance_criteria for your domain's feature_ids; flows.json → flows involving your domain's screens

   Always read .ba/requirements/features.json for acceptance criteria.
   Always read .claude/implementation/approved-context.json for domain_clusters and business_rule_summary."

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

### Task: "{subject}" [Layer {layer}]
- owner: {teammate-name}
- activeForm: "{present continuous form}"
- description: |
    {full description using Task Description Template:
     Domain, Goal, Read (targeted) with specific IDs,
     Key Business Rules, State Dependencies, Acceptance with F-xxx IDs}
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
{FOR hybrid: run unit tests + component tests + e2e tests, then code-review for quality/a11y}

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
{FOR fullstack / offline-first: }
- [ ] npm install succeeds without errors
- [ ] Build command succeeds (if configured)
- [ ] All tests pass
{FOR offline-first additionally: }
- [ ] Service worker registers
- [ ] App works offline (basic test)
- [ ] Sync queue processes on reconnect

### Build Verification
{FOR cdn-shell: No build step — verify file opens in browser}
{FOR fullstack: Run build command from tech-stack.json, verify 0 exit code}
{FOR offline-first: Run build + verify PWA audit basics}

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
  VERIFY: valid JSON
  VERIFY: version == "2.0"
  VERIFY: has project_profile with app_type, complexity, foundation, validation_approach
  VERIFY: has interface_map array (non-empty for medium+ complexity)
  VERIFY: has domain_clusters array (non-empty for non-client-only apps)
  VERIFY: has reading_guide object
  VERIFY: has approval.status key

READ back .claude/implementation/master-plan.json:
  VERIFY: valid JSON, has "tasks" array (non-empty), has "team_composition" array
  VERIFY: every task has: id, subject, owner, layer, description, depends_on
  VERIFY: every team member has: name, agent_template, domain, exclusive_write
  VERIFY: fullstack tasks have targeted Read directives (reference specific entity names, endpoint IDs)
  VERIFY: tasks have layer field (0-4) with correct dependency ordering (Layer N depends on Layer N-1)
  VERIFY: version == "2.0"

READ back .claude/skills/implementation/SKILL.md:
  VERIFY: all 8 sections present (search for ## 1. through ## 8.)
  VERIFY: no truncation (file does not end mid-sentence)
  VERIFY: no placeholder tokens ({...} or TODO)
  VERIFY: Section 1 includes Interfaces, Domain Clusters, Split API Files subsections
  VERIFY: Section 3 spawn prompt Part 3 includes reading targets

IF any verification fails:
  FIX the issue and re-verify (max 2 iterations)
```

### Signal Completion

```
WRITE .claude/status/implementation-setup-status.json:
  {
    "operation": "implementation-setup",
    "version": "2.0",
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
        "layers": {L},
        "estimated_files": {N}
      }
    },
    "error": null
  }
```

Generator session is complete. Exit.

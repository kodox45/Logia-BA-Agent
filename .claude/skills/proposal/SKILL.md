---
name: proposal
description: Agent Teams proposal generator. Spawns 2 specialized teammates for parallel analysis, cross-validates, and produces 6 technical proposal files.
trigger:
  - proposal-request.json
output: .claude/proposal/
strategy: agent-teams
team: 1 Lead + 2 Teammates (T-DATA, T-SYSTEM)
---

# Proposal Generator — Agent Teams

## What To Build

Generate 6 technical specification files from BA output:

1. `entities.json` — Data model (entities, attributes, relationships)
2. `api-design.json` — API endpoints or localStorage operations
3. `tech-stack.json` — Technology choices with rationale
4. `architecture.json` — Folder structure, auth flow, screen mapping
5. `technical-proposal.json` — Consolidated decisions + coverage report
6. `technical-proposal.md` — Human-readable summary (only human-readable file)

**Team approach:** The Lead ingests sources, classifies the project, then spawns two
specialized teammates — T-DATA (entities + API) and T-SYSTEM (tech stack + architecture)
— to work in parallel. The Lead cross-validates their drafts, resolves conflicts, writes
the final 6 output files, and signals completion.

---

## Step 0: Detect & Setup

**Inputs:** Trigger file at `.ba/triggers/proposal-request.json`

```
1. READ .ba/triggers/proposal-request.json
2. PARSE sources{} → file path map
3. ENSURE .claude/proposal/ exists (create if not)
4. ENSURE .claude/proposal/drafts/ exists (create if not)
5. CHECK prototype/index.html exists → set HAS_PROTOTYPE = true/false
6. CHECK .claude/status/prototype-status.json exists → set HAS_PROTOTYPE_STATUS = true/false
7. WRITE initial status to trigger's output.status_file:
   { progress: { percentage: 5, step: "Setup", message: "Initializing proposal generation" } }
```

**Error:** If trigger is malformed JSON → BLOCKING error (code PROPOSAL_001), stop.

---

## Step 1: Ingest All Sources

**Inputs:** All source files from trigger's `sources{}`

Read files in this order (domain context first, then detailed specs):

**Required** (missing → BLOCKING error):
1. `index.json` — project.name, file paths, summary counts
2. `nfr.json` — security.authentication, api_response, offline_capability, integrations[]
3. `roles.json` — roles[].id, permissions[], toggleable_permissions, hierarchy
4. `features.json` — must/should/could_have[] with fields[], business_rules[], acceptance_criteria[], user_story.action
5. `screens.json` — screens[].sections[], component references, role_access

**Optional** (missing → note, continue):
6. `constraints.json` — technical[] (framework preferences), budget, timeline
7. `problem.json` — Domain vocabulary, entity name hints
8. `stakeholders.json` — User type names
9. `components.json` — states[], variants[], behavior
10. `flows.json` — steps[] with screen_ref, action, actor_switch
11. `layout.json` — Navigation structure, interface type
12. `style.json` — Color tokens
13. `manifest.json` — assets[]
14. `traceability.json` — Feature-to-screen coverage matrix
15. `prd.json` — Scope confirmation
16. `prototype/index.html` — Mock data arrays, CRUD handlers
17. `prototype-status.json` — changes_applied[], features_covered[]

```
FOR EACH file:
  IF exists → read and parse JSON (or HTML for prototype)
  IF missing AND required → BLOCKING error (PROPOSAL_001: missing_source), stop
  IF missing AND optional → note as unavailable, continue
  IF JSON parse fails → retry once, then BLOCKING error (PROPOSAL_002)
```

**Required files:** index.json, nfr.json, roles.json, features.json, screens.json.
If any required file is missing → error status, delete trigger, stop.

**Pre-condition checks:**
- features.json contains at least 1 must_have feature → else BLOCKING (PROPOSAL_003)
- roles.json contains at least 1 role → else BLOCKING (PROPOSAL_004)

Update status: `{ percentage: 15, step: "Ingestion", message: "Read N source files" }`

---

## Step 2: Classify & Prepare Shared Context

**Inputs:** nfr.json, constraints.json, features.json, roles.json, screens.json

### App Type Detection

```
IF nfr.security.authentication == false
   AND (nfr.performance.api_response contains "N/A" OR "client-side")
   AND (constraints.technical mentions "no server" OR "single user" OR "offline only")
THEN → app_type = "client-only"

ELSE IF nfr.integrations[] has 2+ entries (WebSocket, payment, storage, etc.)
THEN → app_type = "integration-heavy"

ELSE IF nfr.reliability.offline_capability == true
THEN → app_type = "offline-first"

ELSE → app_type = "standard-fullstack"
```

### Complexity Tier Detection

```
Count entity candidates from features.json object nouns
  (unique nouns from user_story.action — skip "view", "monitor", "track" actions)
Count screens from screens.json
Count roles from roles.json

IF entities <= 5 AND screens <= 2 AND roles == 1
THEN → complexity = "simple"

ELSE IF entities <= 15 AND screens <= 10 AND roles <= 4
THEN → complexity = "medium"

ELSE → complexity = "complex"
```

### Write Shared Context

Write `.claude/proposal/drafts/_shared-context.json`:

```json
{
  "project_name": "from index.json",
  "app_type": "client-only | integration-heavy | offline-first | standard-fullstack",
  "complexity_tier": "simple | medium | complex",
  "has_prototype": true,
  "has_prototype_status": false,
  "counts": { "features_must": 6, "features_should": 4, "features_could": 0, "roles": 1, "screens": 2, "entity_candidates": 3 },
  "source_paths": { "features": ".ba/requirements/features.json", "roles": "...", "nfr": "...", "screens": "...", "..." : "..." },
  "unavailable_sources": ["manifest"]
}
```

Include ALL source paths from the trigger's sources{}. This context provides classification
and file locations only. Teammates MUST read BA files directly — shared context is NOT a
proxy for BA data.

Update status: `{ percentage: 20, step: "Classification", message: "Classifying architecture and complexity" }`

---

## Step 3: Create Team & Assign Work

### 3.1 Team Creation

Create the agent team with two specialized teammates. Each teammate receives a
self-contained prompt with all algorithms and rules needed for their domain.

### 3.2 T-DATA Teammate Prompt

Create teammate **T-DATA** with this prompt:

````
You are T-DATA, a specialized data modeling agent in the proposal team.

## Your Mission
1. Extract entities from BA specification files
2. Design API endpoints or localStorage operations
3. Write two draft files for the Lead to cross-validate

## Setup
Read `.claude/proposal/drafts/_shared-context.json` for classification and file paths.
Then read ALL BA source files directly from the paths listed there.

CRITICAL: Read the actual BA files. The shared context only tells you WHERE files are
and WHAT the classification is. All entity/field/rule data comes from the BA files.

## Task 1: Entity Extraction (6-Step Algorithm)

### Step 1: Feature-Fields Extraction (Primary Source)
```
FOR EACH feature in features.json (must_have + should_have + could_have):
  Extract OBJECT NOUN from user_story.action:
    "manage tasks" → "Task"
    "set priority" → "Task" (modifies existing entity)
    "view dashboard" → SKIP (aggregation, NOT entity)
    "filter tasks" → SKIP (UI behavior, NOT entity)

  Collect all fields[] → candidate attributes
  Group by object noun → candidate entities

CRITICAL: Dashboard/aggregation features are NOT entities.
  Fields named total_*, count_*, average_* → computed values
  Actions "view", "monitor", "track", "filter", "sort" → likely UI-only
```

### Step 2: Consolidation
```
FOR EACH unique object noun:
  Merge fields from all features referencing this noun
  Track source_features[] (which F-xxx contributed)
  Track source per field: "F-xxx.fields[n]"
  Resolve naming conflicts → flag as escalation if unresolvable
```

### Step 3: Relationship Detection
```
FROM features.json:  roles_allowed[] → ownership (entity belongs_to User)
FROM flows.json:     Sequential creation → one-to-many
FROM roles.json:     toggleable_permissions → many-to-many with pivot
FROM screens.json:   Multiple entity sections → display relationships
FROM prototype:      Mock data FK patterns, navigateTo chains
```

### Step 4: Type Inference per Field

| Field Name Pattern | Type | Constraints |
|---|---|---|
| `*_id`, `*_ref` | `uuid` | FK reference |
| `*_date`, `*_at`, `*_time` | `timestamp` | |
| `*_price`, `*_amount`, `*_cost` | `decimal` | |
| `*_count`, `*_total`, `*_quantity` | `integer` | |
| `*_enabled`, `*_active`, `is_*`, `has_*` | `boolean` | |
| `*_description`, `*_notes`, `*_content` | `text` | |
| `*_url`, `*_link`, `*_path` | `string` | `max_length: 500` |
| `*_email` | `string` | `max_length: 255, format: email` |
| `*_status` | `enum` | values from options[] |
| Field with `options[]` | `enum` | values from options[] |
| Field with `required: true` | (any) | `required: true` |
| Default | `string` | `max_length: 255` |

State machine detection:
```
IF field type == "enum" AND field name contains "status":
  Infer transitions from flows.json step sequences
  Map allowed_roles from roles.json permissions
  Generate state_machine object per status field
```

### Step 5: Prototype Enrichment (if has_prototype)
```
Read prototype/index.html:
  FROM appState(): Mock data arrays → validate field list, add missed fields
  FROM screen sections: @submit → POST, table columns → GET list, edit → PATCH, delete → DELETE
  Cross-validate with BA specs: mismatches → flag in gaps
```

### Step 6: Cross-Validation
```
FOR EACH must_have feature:
  ASSERT: maps to at least 1 entity OR acknowledged as UI-only
  ASSERT: ALL fields[] appear in some entity's attributes
  ASSERT: ALL business_rules[] captured

FOR EACH entity:
  ASSERT: has at least 1 source_feature (no orphans)
  ASSERT: relationships reference existing entities
```

### Implicit Entity Tiers
- **Tier 1 (always):** System fields (id, createdAt, updatedAt) on every entity.
  User entity if roles require authentication.
- **Tier 2 (with evidence):** Notification (if "notify"/"alert" in rules),
  Attachment (if file upload fields), Permission (if toggleable_permissions),
  Settings (if "settings" features). Include evidence string.
- **Tier 3 (never auto-add):** Soft-delete, audit log, cache, i18n.
  Add to recommendations[] only.

### Entity Category Values
- `business` — BA presents to user for review
- `system` — Auto-approved (id, timestamps)
- `reference` — Foreign keys, explained as relationships

## Task 2: API / Operations Design

### For Standard/Integration-Heavy/Offline-First Apps
```
FOR EACH entity (non-junction):
  Generate CRUD: GET list, GET :id, POST, PATCH :id, DELETE :id
  EXCEPTIONS: Singleton → no list/delete. Read-only → no create/update/delete.
              Junction → managed via parent endpoints.

FOR EACH flow: Map steps to API sequences. Action endpoints beyond CRUD:
  "approve" → PATCH /api/{entity}/:id/approve
  "assign"  → POST /api/{entity}/:id/assign

FOR EACH role: Authorization rules per endpoint from permissions[]
FOR EACH business_rule: Attach to most relevant endpoint with source reference
```

### For Client-Only Apps
```
FOR EACH entity:
  Describe localStorage operations: read(key), write(key), delete(key)
  Document storage key: "todos" → Task[], "preferences" → UserPreferences
  NO REST endpoints. NO auth middleware.
```

### Endpoint ID Assignment
- Use `EP-001` through `EP-NNN` (sequential, globally unique)
- Every endpoint has `related_entity` referencing an entity name

## Output Files

### _entities-draft.json
Write to `.claude/proposal/drafts/_entities-draft.json`.

Structure: `{ version, storage_type, entities[], recommendations[], decisions_requiring_approval[], summary{} }`

Each entity: `{ name (PascalCase), description, source_features[], table_name (snake_case_plural or storage_key), type (standard|junction|singleton), attributes[], relationships[], indexes[] }`

Each attribute: `{ name (camelCase), type (uuid|string|text|integer|decimal|boolean|enum|timestamp), category (business|system|reference), required, unique, default, source (F-xxx.fields[n] or inferred:technical or inferred:structural) }`
- Enum attributes add: `values[]`, `state_machine{}` (if status field)

Each relationship: `{ target, type (many-to-one|one-to-many|many-to-many), foreign_key, cascade_delete }`
Each index: `{ fields[], unique }`
Summary: `{ total_entities, total_fields, relationships, junction_tables, decisions_pending }`

### _api-design-draft.json
Write to `.claude/proposal/drafts/_api-design-draft.json`.

**Full-stack apps:** `{ version, base_path, auth{}, endpoints[], decisions_requiring_approval[], summary{} }`
Each endpoint: `{ id (EP-xxx), method, path, description, source_features[], auth_required, roles_allowed[], params{query[], path[], body[]}, response{success{}, errors[]}, business_rules[], related_entity }`

**Client-only apps:** `{ version, storage_type: "localStorage", storage_operations[], decisions_requiring_approval[], summary{} }`
Each operation: `{ entity, storage_key, operations: ["read","write","delete"], data_shape }`

## Decision IDs
Your D-xxx range: **D-001 to D-049**. Never use D-050+.

## Mailbox Protocol
If you discover something that affects T-SYSTEM's domain (e.g., entity count changes
tech stack needs, or auth entity implies auth middleware):
  → Send a message to T-SYSTEM describing the finding

## Quality Gates
After writing each draft file:
1. Read the file back
2. Verify: valid JSON structure, no truncation, no placeholders
3. If issues found → fix and re-verify (max 2 attempts)
````

### 3.3 T-SYSTEM Teammate Prompt

Create teammate **T-SYSTEM** with this prompt:

````
You are T-SYSTEM, a specialized system architecture agent in the proposal team.

## Your Mission
1. Determine the technology stack with rationale
2. Design the system architecture (folders, auth flow, data flow, screen mapping)
3. Write two draft files for the Lead to cross-validate

## Setup
Read `.claude/proposal/drafts/_shared-context.json` for classification and file paths.
Then read ALL BA source files directly from the paths listed there.

CRITICAL: Read the actual BA files. The shared context only tells you WHERE files are
and WHAT the classification is. All requirements/design data comes from the BA files.

## Task 1: Tech Stack Decision

### Default Stack (no override signals)
```
FRONTEND:   React 18 + TypeScript, Tailwind CSS 3, React Context + useReducer,
            React Router v6, Axios, Vite
BACKEND:    Express.js 4 + TypeScript, PostgreSQL, Prisma, JWT + bcrypt, Zod
TESTING:    Jest, React Testing Library, Supertest
DEV TOOLS:  Vite, ESLint, Prettier
```

### Override Rules — Frontend Framework

| Signal | Override |
|---|---|
| `constraints.technical` mentions "Vue" or "Angular" | Switch to that framework |
| `nfr.usability.primary_device: "mobile"` | Add PWA manifest + service worker |
| `nfr.reliability.offline_capability: true` | Add Workbox + IndexedDB |
| Screens > 20 | Consider Next.js |

### Override Rules — State Management

| Signal | Override |
|---|---|
| Entities <= 5, single interface | React Context (default) |
| Entities 6-12, multi-interface | React Context + useReducer (default) |
| Entities > 12 OR real-time OR complex workflows | Zustand or Redux Toolkit |

### Override Rules — Backend Framework

| Signal | Override |
|---|---|
| `nfr.performance.concurrent_users > 1000` | Fastify instead of Express |
| `nfr.integrations` includes WebSocket | Add Socket.io or ws |
| Complex auth (OAuth, SSO, multi-tenant) | Consider NestJS |

### Override Rules — Database

| Signal | Override |
|---|---|
| `constraints.budget.type: "none"` + `timeline.urgency: "critical"` | SQLite |
| `nfr.integrations` has "Firebase" or "Supabase" | Use that BaaS |
| `nfr.reliability.offline_capability: true` + mobile | SQLite (client) + PostgreSQL (server) |

### Override Rules — Auth

| Signal | Override |
|---|---|
| `nfr.security.auth_method: "OAuth"` or "Google" | Add Passport.js + OAuth |
| `nfr.security.authentication: false` | Skip auth entirely |
| Mixed auth | JWT for admins + anonymous for others |

### Integration-Driven Additions

| `nfr.integrations[]` | Package |
|---|---|
| Payment gateway (Midtrans, Stripe) | midtrans-client / stripe SDK |
| WebSocket | socket.io / ws |
| S3-compatible storage | @aws-sdk/client-s3 |
| Email (SMTP) | nodemailer |

### Client-Only Override
```
IF app_type == "client-only":
  frontend.framework = "Alpine.js v3 (CDN)" OR user preference
  frontend.styling = "Tailwind CSS (CDN)"
  backend = OMIT entirely (set to null)
  database = "localStorage"
  auth = OMIT
  build_tools = OMIT (CDN-only)
```

### Source Tracking per Choice
Every choice must include:
- `source`: "default" | "override:nfr" | "override:constraints"
- `rationale`: Why this choice
- `requires_approval`: true for major choices (framework, DB), false for utilities

## Task 2: Architecture Design

```
1. Generate folder structure based on tech stack:
   Standard: src/ + server/ + tests/ + prisma/
   Client-only: src/ only (or single file for CDN apps)

2. Map screens to page components/routes:
   FOR EACH screen in screens.json:
     { screen_id, page_component (PascalCase), route (kebab-case) }

3. Define auth flow (if applicable):
   JWT: Login → POST /auth/login → token → localStorage → Authorization header
   Client-only: SKIP (no auth)

4. Define data flow:
   Frontend: Component → API call → Context/state update → Re-render
   Client-only: Component → localStorage read/write → Alpine reactive update

5. Seed data requirements:
   FROM roles.json → seed role records
   FROM features.json → seed default config
   Client-only: no seed data (localStorage starts empty)

6. Screen mapping array
```

## Output Files

### _tech-stack-draft.json
Write to `.claude/proposal/drafts/_tech-stack-draft.json`.

Structure: `{ version, frontend{}, backend{}, testing{}, dev_tools{}, decisions_requiring_approval[], summary{} }`

Each choice object has: `{ choice, version?, source, rationale, requires_approval, packages[]? }`
- `source`: "default" | "override:nfr" | "override:constraints"
- `requires_approval`: true for major choices (framework, DB), false for utilities

Frontend keys: framework, language, styling, state_management, routing, http_client, packages[]
Backend keys: framework, language, database, orm, auth, validation, packages[]
Testing keys: unit, component, api, e2e
Dev tools keys: bundler, linter, formatter

For client-only: set `backend` to `null`, omit backend-only fields.

### _architecture-draft.json
Write to `.claude/proposal/drafts/_architecture-draft.json`.

Structure: `{ version, pattern, description, app_type, complexity_tier, folder_structure{}, auth_flow, data_flow{}, screen_mapping[], seed_data, decisions_requiring_approval[], summary{} }`

- `folder_structure`: key=path, value=description (e.g., `"src/pages/": "Page components"`)
- `auth_flow`: `{ type, steps[], middleware }` or `null` for client-only
- `screen_mapping[]`: `{ screen_id, page_component (PascalCase), route (kebab-case) }`
- `seed_data`: `{ description, items[{entity, records[], source}] }` or `null` for client-only

## Decision IDs
Your D-xxx range: **D-050 to D-099**. Never use D-001-049.

## Mailbox Protocol
If you discover something that affects T-DATA's domain (e.g., tech stack choice
affects entity storage format, or auth decision affects User entity shape):
  → Send a message to T-DATA describing the finding

## Quality Gates
After writing each draft file:
1. Read the file back
2. Verify: valid JSON structure, no truncation, no placeholders
3. If issues found → fix and re-verify (max 2 attempts)
````

### 3.4 Task List with Dependencies

After creating teammates, create this task list:

```
Task 1 (T-DATA):   "Extract entities from BA specs → write _entities-draft.json"
                    No dependencies

Task 2 (T-DATA):   "Design API/operations → write _api-design-draft.json"
                    Blocked by: Task 1

Task 3 (T-SYSTEM): "Determine tech stack → write _tech-stack-draft.json"
                    No dependencies

Task 4 (T-SYSTEM): "Design architecture → write _architecture-draft.json"
                    Blocked by: Task 3

Task 5 (Lead):     "Cross-validate all drafts"
                    Blocked by: Tasks 1, 2, 3, 4
```

Tasks 1 and 3 run in parallel. Task 2 starts after Task 1. Task 4 starts after Task 3.
Task 5 (Lead) starts after all four teammate tasks complete.

### 3.5 Status Updates During Wait

While teammates work, update status at these milestones:

| When | % | Message |
|------|---|---------|
| Team created | 25% | Teammates spawned — T-DATA and T-SYSTEM working in parallel |
| Any task completes | 35-60% | T-DATA/T-SYSTEM completed {task name} |
| All tasks complete | 65% | All drafts received — starting cross-validation |

---

## Step 4: Cross-Validate

**Inputs:** All 4 draft files from `.claude/proposal/drafts/`

Read all drafts:
- `_entities-draft.json` (from T-DATA)
- `_api-design-draft.json` (from T-DATA)
- `_tech-stack-draft.json` (from T-SYSTEM)
- `_architecture-draft.json` (from T-SYSTEM)

### 8 Consistency Checks

| # | Check | Fix on Fail |
|---|-------|-------------|
| 1 | **Entity ↔ API:** Every entity has endpoints/ops, every endpoint has related_entity | Add missing mappings |
| 2 | **Tech ↔ Architecture:** Folder structure matches stack; client-only has no server/ | Fix architecture |
| 3 | **Feature Coverage:** Every must_have maps to entity or is UI-only | BLOCKING gap |
| 4 | **Naming:** Entity=PascalCase, fields=camelCase across all drafts | Normalize |
| 5 | **D-xxx Unique:** T-DATA 001-049, T-SYSTEM 050-099, no overlaps | Lead reassigns D-100+ |
| 6 | **EP-xxx Sequential:** No gaps, no duplicates | Renumber |
| 7 | **Business Rules:** Every must_have rule attached to endpoint or constraint | Attach to nearest |
| 8 | **State Machines:** Reachable states, valid transitions, terminal=empty | Fix or remove |

### Per-Feature Coverage Determination

```
FOR EACH feature in features.json:
  Determine status:
    fully_covered    — entity mapping + ALL fields + ALL rules + ALL criteria have path
    partially_covered — some fields/rules/criteria missing
    gap              — no entity AND not UI-only, OR critical rule unmapped
    ui_only          — pure UI behavior (filter, sort, theme toggle)

  Count: fields_mapped, fields_total, rules_mapped, rules_total,
         criteria_testable, criteria_manual, criteria_total
  List: entities[], endpoints[], gaps[], inferred_rules[]
```

### Infer Rules for should/could Features

```
FOR should/could features with business_rules_count == 0:
  Infer sensible defaults:
    "name must be unique"
    "default priority is medium"
    "cannot delete while in active state"
  Mark each: source: "inferred:default"
```

### Must-Have Blocking Gap Handling

```
IF any must_have feature has status == "gap":
  Mark proposal as having BLOCKING gaps
  Flag prominently in technical-proposal.json and .md
  Still generate proposal — do NOT abort
  Consider escalation via .claude/escalations/ if business decision needed
```

Update status: `{ percentage: 75, step: "Validation", message: "Cross-validating coverage" }`

---

## Step 5: Write Final Output Files

**Inputs:** Validated and corrected draft data

Writing order (dependencies first):

```
1. entities.json          ← Foundation, referenced by API
2. api-design.json        ← References entities
3. tech-stack.json        ← Independent
4. architecture.json      ← References tech + entities + screens
5. technical-proposal.json ← Consolidates everything
6. technical-proposal.md   ← Human-readable summary
```

### Lead Synthesis Actions

The Lead does NOT copy-paste drafts. Synthesis includes:

1. **MERGE** decisions_requiring_approval from all 4 drafts → unified list (Lead new decisions get D-100+)
2. **BUILD** coverage[] array from Step 4 per-feature analysis
3. **RESOLVE** cross-draft conflicts (entity names ↔ screen mapping, auth choice ↔ API endpoints)
4. **FIX** entity ↔ API cross-references (every endpoint.related_entity must match an entity.name)
5. **GENERATE** statistics: total_entities, total_endpoints, total_decisions, coverage breakdown

### Per-File Writing

For each output file:

```
1. Compose final JSON from validated draft data + Lead synthesis
2. WRITE to .claude/proposal/{filename}
3. READ the file back
4. VERIFY: valid JSON, no truncation, all cross-references valid
5. IF issues → fix and re-verify (max 2 iterations)
```

For files > 200 lines: write incrementally (structural shell → content sections → closing).

### technical-proposal.md Structure

Sections: Executive Summary → 1. Data Model (entity table, relationships, decisions)
→ 2. API Design (endpoint table or localStorage ops, decisions)
→ 3. Tech Stack (layer/choice/rationale table, decisions)
→ 4. Architecture (folder structure, auth flow, data flow, decisions)
→ All Decisions Requiring Approval (unified D-xxx table)
→ Coverage Summary (priority × status matrix)
→ Next Steps (review → approve → implement)

If BLOCKING gaps exist: prominent warning in Executive Summary.

### Status Milestones

| File | % | Message |
|------|---|---------|
| entities.json written | 80% | Writing entities.json |
| api-design.json + tech-stack.json | 85% | Writing API and tech stack |
| architecture.json | 90% | Writing architecture |
| technical-proposal.json | 95% | Writing proposal summary |
| technical-proposal.md | 95% | Writing human-readable proposal |

---

## Step 6: Signal Completion

```
1. WRITE .claude/status/proposal-ready.json with:
   operation: "proposal", version: "1.0"
   status.current: "completed", started_at, updated_at, completed_at
   progress: { percentage: 100, step: "Complete", message: "Proposal generated successfully — 6 files written" }
   proposal: { summary: ".claude/proposal/technical-proposal.md", detailed: "...json",
     artifacts: [entities.json, api-design.json, tech-stack.json, architecture.json, technical-proposal.json, technical-proposal.md] }
   awaiting: "user_approval"
   decisions_requiring_approval: [collected from all files]
   next_action: { actor: "user", action: "Review proposal and provide approval via BA Agent" }

2. DELETE trigger file: .ba/triggers/proposal-request.json

3. Drafts directory is KEPT (not deleted) for audit trail.
```

---

## Critical Rules

1. **Read ALL BA files DIRECTLY** — Teammates read `.ba/` files, never rely on shared context as a data proxy. Shared context provides classification and paths only.

2. **D-xxx ID ranges are strict** — T-DATA: D-001 to D-049. T-SYSTEM: D-050 to D-099. Lead: D-100+. No overlaps.

3. **EP-xxx sequential and globally unique** — T-DATA assigns endpoint IDs. Sequential numbering, no gaps.

4. **Shared context is classification only** — It contains app_type, complexity, counts, and file paths. NOT a replacement for reading BA files.

5. **Drafts are kept** — Never delete `.claude/proposal/drafts/`. They serve as audit trail.

6. **Forward slashes in all paths** — Never use backslashes, even on Windows.

7. **Write incrementally for files > 200 lines** — Shell first, then content sections, then closing. Prevents truncation.

8. **Self-verify after writing** — Read back every file, check JSON validity, no truncation, no placeholders.

9. **Every entity needs source_features[]** — No orphan entities without feature provenance.

10. **Every endpoint needs related_entity** — No orphan endpoints without entity connection.

11. **Must-have gaps are BLOCKING** — Flag prominently in proposal, but still generate all files. Do NOT abort.

12. **Client-only apps: api-design.json uses storage_operations** — No REST endpoints, no auth middleware, no server routes.

13. **Teammates must message each other** — When a decision crosses domain boundaries (entity count affects tech stack, auth affects entity model), send a message.

14. **Always use Agent Teams** — No single-session fallback. The team structure is required for this skill.

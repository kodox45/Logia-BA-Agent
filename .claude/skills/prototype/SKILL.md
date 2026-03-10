---
name: prototype
description: >
  Single-agent prototype generator. Reads BA specification files from .ba/ and generates
  a fully interactive multi-file HTML prototype with semantic theming, Chart.js dashboards,
  and role-based navigation. Assembles into a self-contained index.html for artifact display.
trigger:
  - prototype-request.json
  - prototype-iteration.json
output: prototype/index.html
strategy: single-agent
technology: HTML + Tailwind CSS (CDN) + Alpine.js v3 + Alpine Focus Plugin + Chart.js @4 + Inline SVGs (Lucide-style)
version: 6.0
---

# Prototype Generator v6

## What To Build

A multi-file prototype under `prototype/` that assembles into `prototype/index.html`:

- **Interactive** — navigation, modals, form validation, toasts, data tables with sort/filter/pagination, Chart.js dashboards
- **Theme-agnostic** — semantic token system adapts to any color scheme (light or dark)
- **Responsive** — adapts to primary_device from nfr.json; sidebar collapses on mobile
- **Role-switchable** — dropdown to switch between all roles; sections show/hide per role_visibility
- **Domain-realistic** — mock data derived from BA files (entity names, field values, locale formatting)
- **Accessible** — ARIA landmarks, focus trapping in modals, keyboard navigation, WCAG AA contrast

---

## Output Architecture

The generator produces individual files for maintainability, then assembles them:

```
prototype/
├── index.html              ← assembled self-contained file (artifact-ready)
├── screens/
│   ├── S-001.html          ← individual screen HTML fragments
│   ├── S-002.html
│   └── ...
├── assets/                 ← copied from .ba/design/assets/ (if manifest.json has logos)
│   ├── logo-full.jpg
│   └── logo-icon-only.png
├── state.js                ← appState function + mock data
└── charts.js               ← chart data definitions + chartManager
```

**Why multi-file:** Each screen is generated independently (~100-300 lines), keeping
context focused and enabling targeted iteration. The final `index.html` inlines everything
for artifact display and standalone browser viewing (no server needed).

**Iteration benefit:** When the user requests changes to one screen, only that screen
file is regenerated and re-assembled — other screens remain untouched.

---

## Checkpoint System (Anti-Compaction)

Large projects (15+ screens) may trigger context compaction mid-generation. The checkpoint
system ensures no work is duplicated or lost.

### On Every File Write

After successfully generating each output file (state.js, charts.js, each screen fragment,
layout shell), update `prototype/.checkpoint.json`:

```json
{
  "started_at": "ISO-8601",
  "completed_files": ["state.js", "charts.js", "screens/S-001.html", "screens/S-002.html"],
  "current_step": "4.3",
  "next_screen_index": 2,
  "total_screens": 17
}
```

### On Resume (After Compaction)

```
BEFORE starting generation:
  IF prototype/.checkpoint.json exists:
    READ checkpoint
    SKIP steps for completed_files
    RESUME from current_step at next_screen_index
    LOG: "Resuming from checkpoint — {N} files already generated"

  IF prototype/.checkpoint.json does NOT exist:
    Start from Step 1 (normal flow)
```

### Lock File

```
BEFORE Step 1:
  WRITE prototype/.lock with PID/timestamp
  This prevents duplicate agent spawning on compaction events.

AFTER Step 7 (Export):
  DELETE prototype/.lock
  DELETE prototype/.checkpoint.json
```

---

## Step 1: Ingest BA Files

Read ALL source files from the trigger's `sources{}`. Build a complete mental model
BEFORE generating any code.

**Read in this order** (domain context first, then constraints, then visual, then behavior):

### 1.1 problem.json (`.ba/discovery/problem.json`)
- Extract: `statement`, `current_process.steps[].description`
- Derive: Domain vocabulary — entity names, action verbs, business terminology
- Derive: App name from problem context
- IF not found → RECOVERABLE: use project name from trigger

### 1.2 roles.json (`.ba/requirements/roles.json`)
- Extract: `roles[].id`, `roles[].name`, `hierarchy.chain[]`
- Build: Role list for role switcher, ordered by hierarchy (least→most privileged)
- Note: First role in hierarchy is the default active role

### 1.3 features.json (`.ba/requirements/features.json`)
- Extract: `must_have[]`, `should_have[]` (ignore `could_have`/`wont_have` for prototype)
- Per must_have feature: `title`, `fields[]`, `fields[].required`, `fields[].options[]`, `business_rules[]`, `acceptance_criteria[]`, `screen_refs[]`, `roles_allowed[]`
- Note: `should_have` features may omit `fields` and `business_rules` (optional)
  - IF should_have lacks `fields[]` → skip form field generation
  - IF should_have lacks `business_rules[]` → skip validation rule derivation
  - Always use `acceptance_criteria[]` and `screen_refs[]` if present
- Build: Required field list → form validation rules (@blur checks)
- Build: Dropdown options → `<select>` option lists
- Build: Feature-to-screen map from `screen_refs[]`

### 1.4 nfr.json (`.ba/requirements/nfr.json`)
- Extract: `usability.primary_device`, `usability.accessibility`, `security.authentication`
- Derive: `primary_device` → responsive emphasis (mobile-first vs desktop-first)
- Derive: `authentication` → include/exclude login screen elements
- IF not found → RECOVERABLE: default desktop, WCAG AA, auth=true

### 1.5 layout.json (`.ba/design/layout.json`)
- FIRST: Check if `interfaces` key exists (multi-interface layout)
- IF `interfaces` exists:
  - Extract each `interfaces.{key}` with `name`, `type`, `target_roles[]`, `navigation`, `sidebar`
  - Build: Role-to-interface mapping from `target_roles[]`
  - Each interface gets a separate layout shell
- ELSE (single-interface):
  - Extract: `type` (sidebar|topnav|hybrid|minimal)
- Extract (per interface or single): `navigation.primary[]`, `navigation.secondary[]`
- Extract: `sidebar` config (position, width, behavior, mobile_behavior)
- Extract: `responsive.mobile_navigation` (bottom-tabs|hamburger|drawer)
- Extract: `responsive.breakpoints`, `content.max_width`, `content.padding`

### 1.6 style.json (`.ba/design/style.json`)
- Extract ALL categories: feel, colors (12+), typography, spacing, borders, shadows, components
- Detect theme: parse `colors.background` luminance → light (>=50%) or dark (<50%)
- READ `resources/token-system.md` → apply semantic token mapping
- Note `components.buttons` and `components.corners` for pattern adaptation
- Note `gradient` key if present → gradient CTA buttons

### 1.7 screens.json (`.ba/design/screens.json`)
- Extract: `screens[].id`, `name`, `purpose`, `priority`, `feature_refs[]`, `role_access[]`
- Per screen, per section: `name`, `position`, `description`, `components[]`, `role_visibility[]`
- Build: Screen rendering order (Step 2.B)
- Build: Section visibility map (section → which roles see it)
- RULE: If `role_visibility` omitted → section visible to ALL roles in `role_access`
- RULE: If `role_visibility` specified → section visible ONLY to those roles

### 1.8 components.json (`.ba/design/components.json`)
- Extract: `components[].id`, `name`, `purpose`, `used_in[]`, `states[]`, `variants[]`, `behavior`
- Build: State rendering map — for each component with states[], generate x-show conditions
- Build: Variant color map — map variant `color` to status token classes

### 1.9 flows.json (`.ba/design/flows.json`)
- Extract: `flows[].steps[]` with `screen_ref`, `action`, `result`, `actor_switch`
- Build: Navigation wiring — which @click leads to which screen
- Build: Actor switch points — steps where role changes
- Build: Form submit targets — which forms navigate where on success

### 1.10 manifest.json (`.ba/design/manifest.json`) — OPTIONAL
- Extract: `assets[]`, `brand_materials`, `design_references[]`
- Use `brand_materials.app_name` for app title, `brand_materials.tagline` for subtitle
- **Asset handling** (logo files):
  - IF `assets[]` contains items with `type: "logo"`:
    - Record logo paths from `assets[].path` (relative to project root)
    - Map `used_in[]` to determine placement: sidebar header, compact/collapsed sidebar, login screen, receipt, etc.
    - The logo with `"sidebar header icon"` or `"compact"` in `used_in` → sidebar collapsed state
    - The logo with `"Brand Header"` or `"header"` in `used_in` → sidebar expanded / topnav header
  - IF `brand_materials.icon_style === "custom"` AND logo assets exist:
    - Prototype MUST use `<img>` tags referencing the actual logo files — NOT Lucide icon placeholders
    - Logo paths: `assets/{filename}` (relative to prototype/index.html)
    - Apply appropriate sizing: sidebar logos typically `h-8` to `h-10`, login logos `h-16` to `h-20`
  - IF `brand_materials.icon_style === "lucide"` or no logo assets → use inline SVG Lucide icon as app logo
  - IF `brand_materials.icon_style === "text"` or no manifest → text-only app name
- IF manifest.json not found → skip, use text-only branding from problem.json

---

## Step 2: Plan

Before generating any files, derive these from the ingested data:

### A. Layout Mode Detection
```
FIRST: Check for multi-interface layout
IF layout.interfaces exists:
  FOR EACH interface_key in layout.interfaces:
    Extract: name, type, target_roles[], navigation, sidebar config
    Generate a SEPARATE layout shell for each interface
    Wrap each shell in: x-show="currentInterface === '{interface_key}'"
    Screen `interface` field determines which shell it renders inside
    Role switching changes currentInterface automatically via interfaceMap
    Each interface has its OWN navigation items from its own navigation{}

ELSE (single-interface layout):
  IF layout.type == "sidebar"  → sidebar-layout-shell + sidebar-navigation
  IF layout.type == "topnav"   → topnav-layout-shell + topnav-navigation
  IF layout.type == "hybrid"   → sidebar-navigation + topnav header bar
  IF layout.type == "minimal"  → topnav-layout-shell (simplified)

Mobile adaptation (per interface in multi-interface mode):
  IF mobile_navigation == "bottom-tabs" → add mobile-bottom-tabs at < 640px
  IF mobile_navigation == "hamburger"   → sidebar collapses to hamburger
  IF mobile_navigation == "drawer"      → sidebar becomes slide-in drawer
```

### B. Screen Rendering Order
```
Single-interface:
  1. Screens in navigation.primary[] order
  2. Screens in navigation.secondary[] order
  3. Unreferenced screens (by array order)

Multi-interface:
  Group screens by `interface` field, apply same ordering per interface.
```

### C. Data Strategy
```
FROM problem.json: domain vocabulary → entity names, action verbs
FROM features.json: field names → table columns, form labels
FROM features.json: fields[].options[] → dropdown values, badge labels, filter options
FROM roles.json: role names → demo user names per role
FROM nfr.json + problem.json: locale context → currency format, date format

Generate per data table/list:
  - 8-12 mock records with realistic variety
  - Mix of statuses from fields[].options[]
  - Names appropriate to locale context
  - Dates spread across recent 30 days
  - At least 1 edge case (long name, zero value, empty optional field)
```

### D. Chart Strategy
```
Identify screens with dashboard/analytics purpose (from screen.purpose or name):
  - Dashboard screens → stat-cards + 2-3 charts (line trend, bar comparison, donut breakdown)
  - Report screens → data table + 1-2 charts
  - Other screens → no charts

Chart data source:
  - Derive from mock data arrays in state.js
  - Use domain-realistic labels (from features.json entity names)
  - Match chart colors to semantic tokens (primary, accent, success, warning)
```

### E. Interaction Map
```
FROM flows.json steps:
  Map step.action → @click="navigateTo('{step.screen_ref}')"
  Map step with actor_switch → role-aware demo comment
  Map form submit → @submit.prevent="handleSubmit(); navigateTo('{next_screen}')"

FROM components.json states:
  Map component states → x-show conditions in appState

FROM features.json business_rules:
  Map validation rules → @blur handlers on form fields
```

---

## Step 3: Configure

READ `resources/token-system.md` and apply:

1. **Tailwind config** — Section 3 of token-system.md. Map ALL style.json colors to
   semantic tokens. Compute derived colors (inset, muted, subtle). Detect dark/light theme.

2. **Custom CSS** — Section 4 of token-system.md. x-cloak, scrollbar, gradient, print styles.

3. **CDN order** — Section 7 of token-system.md. Tailwind → Config → Fonts → Chart.js → Alpine Focus → Alpine (no Lucide CDN — icons use inline SVGs).

4. **appState** — READ `resources/appstate-template.md` for the complete template. Fill with:
   - Roles from roles.json
   - Interface map from layout.json (if multi-interface)
   - Navigation items from layout.json
   - Mock data arrays from Step 2.C
   - Format helpers (locale, currency from nfr.json/problem.json)

5. **chartManager** — Section 8 of token-system.md. Chart.js integration outside Alpine.

---

## Step 4: Generate (Multi-File)

Generate files in this order. Each screen is a separate file.

### 4.0 Copy Design Assets

```
IF manifest.json has assets[] with type="logo":
  CREATE prototype/assets/ directory
  COPY each logo file from .ba/design/assets/{filename} → prototype/assets/{filename}
  VERIFY files exist after copy
  UPDATE checkpoint

IF no manifest or no logo assets:
  SKIP (no assets/ directory needed)
```

### 4.1 Generate `prototype/state.js`

Write the complete appState function from Step 3.4 plus all mock data arrays.
This file is NOT a runnable JS file — it is an inline `<script>` content block
that will be injected into index.html during assembly.

Contents:
- `function appState() { return { ... } }` — full state with all properties
- Mock data arrays (orders, menuItems, users, etc.)
- Format helpers (formatDate, formatCurrency)
- Chart data objects (datasets for each chart)

### 4.2 Generate `prototype/charts.js`

Write the chartManager object (from token-system.md Section 8.1) plus
chart data definitions for each dashboard/analytics screen.

### 4.3 Generate `prototype/screens/S-xxx.html` (one per screen)

FOR EACH screen in rendering order (Step 2.B):

```
WRITE prototype/screens/{screen.id}.html:

  <!-- Screen: {screen.name} ({screen.id}) -->
  <div id="{screen.id}"
       x-show="currentScreen === '{screen.id}'"
       x-transition:enter="transition ease-out duration-200"
       x-transition:enter-start="opacity-0"
       x-transition:enter-end="opacity-100"
       x-cloak
       class="p-4 sm:p-6 lg:p-8">

    <!-- Page header -->
    <div class="mb-6">
      <h1 class="text-2xl font-bold text-heading">{screen.name}</h1>
      <p class="mt-1 text-sm text-body">{screen.purpose}</p>
    </div>

    FOR EACH section (ordered by position):
      Apply role_visibility via x-show if specified
      Render components using patterns from resources/patterns/
      Use semantic token classes (bg-surface, text-heading, border-line)
      Wire interactions from Step 2.E
      Charts: add <canvas> + x-effect for deferred init

  </div>
  <!-- /Screen: {screen.name} ({screen.id}) -->
```

**Pattern adaptation:** READ patterns from `resources/patterns/*.html` as STYLE REFERENCE.
Adapt structure, classes, and ARIA attributes to each screen's content.
Do NOT mechanically copy-paste patterns.

**After every 3 screens:** Pause and verify no unclosed tags in the last batch.

### 4.4 Generate Layout Shell

Write the layout shell(s) as a fragment. This will be assembled between the
opening `<body>` tag and the screen content.

Multi-interface: one shell per interface, each wrapped in x-show.
Single-interface: one shell based on layout.type.

Include: sidebar/topnav navigation, role switcher, notification bell, mobile menu.

**Logo rendering in layout shell:**
```
IF icon_style === "custom" AND prototype/assets/ has logo files:
  Sidebar expanded:  <img src="assets/{full-logo}" alt="{app_name}" class="h-8">
  Sidebar collapsed: <img src="assets/{icon-logo}" alt="{app_name}" class="h-8 w-8">
  Topnav header:     <img src="assets/{full-logo}" alt="{app_name}" class="h-8">
  Login screen:      <img src="assets/{full-logo}" alt="{app_name}" class="h-16 mx-auto">

  NEVER use <i data-lucide="..."> as logo placeholder when custom logos exist.

ELSE:
  Use Lucide icon or text-only based on icon_style setting.
```

---

## Step 5: Assemble `prototype/index.html`

Combine all generated files into a single self-contained HTML file:

```
1. WRITE head:
   <!DOCTYPE html>, <html>, <head>
   CDN links (token-system.md Section 7)
   Tailwind config <script> (from Step 3.1)
   Custom CSS <style> (from Step 3.2)
   </head>

2. INLINE state.js:
   READ prototype/state.js → wrap in <script>...</script>

3. INLINE charts.js:
   READ prototype/charts.js → wrap in <script>...</script>

4. WRITE body open:
   <body x-data="appState()" class="min-h-screen bg-page">
   Toast container (z-[55])

5. INLINE layout shell:
   READ layout fragment → append

6. INLINE screens (in rendering order):
   <main ...>
   FOR EACH screen file in prototype/screens/:
     READ prototype/screens/{id}.html → append
   </main>

7. WRITE closing:
   Shared confirmation dialog
   </main> closing
   </body></html>
   NOTE: No Lucide init script needed — all icons use inline SVGs (Rule 11)

8. VERIFY: Read assembled index.html back, check for truncation
```

**The assembled index.html is the artifact-ready output.** Screen files in
`prototype/screens/` are kept for iteration reference.

---

## Step 6: Validate (20-Point Checklist)

READ `prototype/index.html` back in full. CHECK all 20 points. FIX any failures (max 2 iterations).

### Structure Checks
1. File starts with `<!DOCTYPE html>` and ends with `</html>`
2. CDN order: Tailwind → Config → Fonts → Chart.js → Alpine Focus → Alpine (no Lucide CDN)
3. `x-data="appState()"` on `<body>`, NO `x-cloak` on `<body>`
4. `<body>` has `class="... bg-page"` (semantic token, not hardcoded color)

### Completeness Checks
5. Every screen from screens.json has `<div id="{screen.id}" x-show="currentScreen === '{screen.id}'">`
6. Every must_have feature is represented in at least one screen
7. Every role appears as an option in the role switcher
8. Every `navigation.primary[]` item has a nav link with `@click="navigateTo(...)"`

### Functionality Checks
9. Every `navigateTo('{id}')` references a screen id that exists as `<div id="{id}">`
10. Every function in `@click`/`@submit` handlers exists in appState (addToast, openModal, confirm)
11. Every `x-model` references a property initialized in appState or local `x-data`
12. Modal/confirm state variables are initialized in appState

### Theme Checks
13. No hardcoded `bg-white`, `bg-gray-*`, `text-gray-*` outside status badge conditionals
14. All cards use `bg-surface`, all text uses `text-heading`/`text-body`/`text-muted`
15. Status badges use `bg-status-*-bg text-status-*-text` token classes

### Quality Checks
16. No unreplaced `{placeholder}` tokens (search for `/{[a-z]+-[a-z]+}/` pattern)
17. All HTML tags properly closed (count `<div>` vs `</div>`, `<template>` vs `</template>`)
18. Charts: every `<canvas id="...">` has a matching `chartManager.init()` call in x-effect

### Asset & Icon Checks
19. If manifest.json has `icon_style: "custom"` + logo assets: no `<i data-lucide="...">` used as app logo — must be `<img src="assets/...">`; verify `prototype/assets/` directory contains the copied logo files
20. No `<i data-lucide="...">` tags anywhere — all icons must use inline `<svg>` markup (tag-based Lucide rendering fails on x-show hidden elements)

**On failure:** Log `[FAIL] Check #{N}: {description}`, fix, re-validate (max 2 iterations).

---

## Step 7: Export

### Status Update
Write to path from trigger's `output.status_file`:
```json
{
  "operation": "prototype",
  "version": "6.0",
  "status": {
    "current": "completed",
    "started_at": "{ISO-8601}",
    "updated_at": "{ISO-8601}",
    "completed_at": "{ISO-8601}"
  },
  "progress": { "percentage": 100, "step": "Complete", "message": "Prototype generated" },
  "output": {
    "path": "prototype/index.html",
    "screens_generated": ["{screen IDs}"],
    "features_covered": ["{feature IDs}"],
    "screen_files": ["prototype/screens/{id}.html"],
    "charts_included": true
  },
  "error": null,
  "iteration": 1
}
```

### Trigger Cleanup
DELETE the processed trigger file from `.ba/triggers/`.

### Progress Milestones
| Step | Progress | Message |
|------|----------|---------|
| Step 1 start | 5% | Reading BA specification files |
| After Step 2 | 15% | Planning generation strategy |
| After Step 3 | 20% | Configuring design tokens |
| After Step 4.0 | 25% | Design assets copied |
| After state.js | 30% | State and mock data generated |
| After charts.js | 35% | Chart configurations generated |
| Screen batch 1 | 50% | Generating screens (batch 1) |
| Screen batch 2 | 65% | Generating screens (batch 2) |
| Screen batch 3 | 80% | Generating screens (batch 3) |
| After Step 5 | 90% | Assembling index.html |
| After Step 6 | 95% | Validating prototype |
| After Step 7 | 100% | Complete |

---

## Iteration Mode

When trigger is `prototype-iteration.json`:

```
1. READ iteration payload: changes_requested[], iteration number, keep_unchanged[]
2. BACKUP: copy index.html → index.v{N-1}.html
3. RE-READ all 10 BA files (they may have changed between iterations)
4. IDENTIFY affected screens from changes_requested[].component
5. FOR EACH affected screen:
   a. RE-GENERATE prototype/screens/{screen.id}.html with changes applied
   b. Use updated BA data + change request description
6. VERIFY keep_unchanged[] screen files were NOT modified
7. RE-ASSEMBLE index.html (Step 5) — reads ALL screen files including unchanged ones
8. RE-RUN Step 6 validation (full 18-point checklist)
9. EXPORT status with iteration number incremented
10. DELETE iteration trigger file
```

Iteration is efficient because only affected screen files are regenerated.
The assembly step re-reads all files but doesn't re-generate them.

---

## Pattern Reference

Read patterns at `resources/patterns/*.html` as STYLE REFERENCE.
All patterns use semantic token classes (bg-surface, text-heading, border-line).

| File | Patterns | Use For |
|------|----------|---------|
| navigation.html | sidebar-navigation, topnav-navigation, mobile-bottom-tabs, breadcrumbs, tabs, role-switcher, notification-bell, stepper-indicator | Layout shell, nav, role switching |
| data-display.html | data-table, data-table-dynamic, card-grid, list-view, stat-card, badge, avatar, empty-state, tabs-panel, timeline, drawer-panel | Content display, metrics, detail views |
| forms.html | text-input, select-dropdown, checkbox-group, radio-group, textarea, toggle-switch, search-input, form-section, form-wizard, date-picker, file-upload, login-form | Forms, filters, search, auth |
| feedback.html | modal-dialog, toast-notification, inline-alert, loading-spinner, skeleton-loader, progress-bar, empty-state-message, confirmation-dialog, tooltip | Feedback, loading, modals |
| actions.html | button-primary, button-group, dropdown-menu, fab, search-bar, filter-bar | Actions, menus, buttons |
| layout.html | page-container, responsive-grid, section-header, sidebar-layout-shell, topnav-layout-shell, card-container, spacing-utilities, accordion | Page structure, grids |
| charts.html | bar-chart, line-chart, donut-chart, sparkline, chart-card | Dashboard visualizations |

For complex or uncommon patterns (kanban, calendar, print-preview, gallery), read
`resources/advanced-patterns.md` which provides structural guidance without full HTML.

---

## Critical Rules

1. **NO x-cloak on `<body>`** — causes permanent white screen if Alpine CDN is slow
2. **ONE x-data="appState()" on `<body>`** — single global state; local x-data OK for widgets
3. **Semantic tokens only** — never hardcode `bg-white`, `text-gray-900`, etc. in patterns or output. Use `bg-surface`, `text-heading`, `border-line`. (Exception: status badge conditionals)
4. **ALL screens** need `x-show` + `x-transition` + `x-cloak`
5. **Read ALL 10 BA files** BEFORE generating any code
6. **Forward slashes** in all file paths
7. **Generate screens individually** — one file per screen, then assemble
8. **Self-verify** after writing — read back and check structure
9. **Mock data must be domain-realistic** — derive from BA files, never lorem ipsum
10. **Charts init via x-effect + $nextTick** — never init Chart.js on hidden canvas
11. **Use inline SVGs for icons** — Lucide `<i data-lucide="...">` tag-based rendering fails on hidden x-show elements (icons render only after becoming visible, causing flash). Instead, copy the SVG markup directly: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">...</svg>`. Get SVG paths from Lucide's icon library.
12. **Toast z-index below modals** — z-[55] for toasts (above sidebar z-30, below modal z-50)
13. **Use actual brand assets when provided** — if manifest.json has `icon_style: "custom"` and logo files exist in `.ba/design/assets/`, the prototype MUST use `<img src="assets/{filename}">` for all logo placements. Never fall back to Lucide icon placeholders when custom logos are available.

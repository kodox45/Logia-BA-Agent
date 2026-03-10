# Semantic Token System

This document defines the theme-agnostic token architecture used by all prototype pattern
files. The token system ensures patterns work identically on light themes, dark themes,
and any custom color scheme defined in style.json.

Read this file when generating the Tailwind config (Step 3.A) and when adapting patterns
to a project's style.json.

---

## 1. Why Tokens

Pattern HTML files use semantic class names (`bg-surface`, `text-heading`) instead of
hardcoded Tailwind colors (`bg-white`, `text-gray-900`). This means:

- The same `data-table` pattern renders correctly on a light corporate theme AND a dark
  POS terminal theme — no pattern-level changes needed.
- style.json is the single source of truth for all visual decisions.
- The model only maps style.json values to Tailwind config ONCE, then patterns "just work".

---

## 2. Token Definitions

### 2.1 Background Tokens

| Token Class | Maps to (style.json) | Purpose | Light Example | Dark Example |
|-------------|----------------------|---------|---------------|--------------|
| `bg-page` | `colors.background` | Page/body background | `#F9FAFB` | `#0F1923` |
| `bg-surface` | `colors.surface` | Cards, panels, sidebars | `#FFFFFF` | `#162433` |
| `bg-surface-el` | `colors.surface_elevated` | Elevated surfaces (dropdowns, modals, hover states) | `#F3F4F6` | `#1C2E42` |
| `bg-inset` | derived: 3% darker than `surface` | Table stripes, input fills, disabled backgrounds | `#F9FAFB` | `#1A2B3C` |

### 2.2 Text Tokens

| Token Class | Maps to (style.json) | Purpose |
|-------------|----------------------|---------|
| `text-heading` | `colors.text_primary` | Headings, labels, primary content |
| `text-body` | `colors.text_secondary` | Body text, descriptions |
| `text-muted` | derived: 40% opacity of `text_secondary` | Placeholders, timestamps, disabled text |

### 2.3 Border & Line Tokens

| Token Class | Maps to (style.json) | Purpose |
|-------------|----------------------|---------|
| `border-default` | `colors.border` | Card borders, dividers, table lines |
| `border-subtle` | derived: 50% opacity of `border` | Light separators inside cards |
| `ring-focus` | `colors.primary` | Focus rings on interactive elements |

### 2.4 Brand / Accent Tokens

| Token Class | Maps to (style.json) | Purpose |
|-------------|----------------------|---------|
| `bg-primary` / `text-primary` | `colors.primary` | Primary actions, active states, links |
| `bg-primary-light` | `colors.primary_light` | Primary hover backgrounds, selected row highlights |
| `bg-primary-dark` | `colors.primary_dark` | Primary pressed/active states |
| `bg-secondary` | `colors.secondary` | Secondary accents |
| `bg-accent` | `colors.accent` | Accent highlights, decorative elements |

### 2.5 Status Tokens (Universal — NOT derived from style.json theme)

These use Tailwind's built-in semantic palette because status colors must be
universally recognizable regardless of theme.

| Status | Background | Text | Dot/Icon |
|--------|-----------|------|----------|
| Success | `bg-green-100` / dark: `bg-green-900/30` | `text-green-800` / dark: `text-green-400` | `bg-green-500` |
| Warning | `bg-yellow-100` / dark: `bg-yellow-900/30` | `text-yellow-800` / dark: `text-yellow-400` | `bg-yellow-500` |
| Error | `bg-red-100` / dark: `bg-red-900/30` | `text-red-800` / dark: `text-red-400` | `bg-red-500` |
| Info | `bg-blue-100` / dark: `bg-blue-900/30` | `text-blue-800` / dark: `text-blue-400` | `bg-blue-500` |

**Dark theme detection:** If `colors.background` luminance < 50%, use the dark variants
for status colors. The Tailwind config handles this via the `statusBg` and `statusText`
utility mappings (see Section 3).

---

## 3. Tailwind Config Template

This is the COMPLETE Tailwind config the prototype generator writes into `<script>`.
Every value comes from style.json — no hardcoding.

```javascript
tailwind.config = {
  theme: {
    extend: {
      colors: {
        // ── Background tokens ──
        page:         '{colors.background}',
        surface:      '{colors.surface}',
        'surface-el': '{colors.surface_elevated}',
        inset:        '{derived: surface darkened 3%}',

        // ── Text tokens ──
        heading:  '{colors.text_primary}',
        body:     '{colors.text_secondary}',
        muted:    '{derived: text_secondary at 40% opacity, computed as hex}',

        // ── Border tokens ──
        line:     '{colors.border}',
        subtle:   '{derived: border at 50% opacity, computed as hex}',

        // ── Brand tokens ──
        primary:  {
          DEFAULT: '{colors.primary}',
          light:   '{colors.primary_light}',
          dark:    '{colors.primary_dark}',
        },
        secondary: '{colors.secondary}',
        accent:    '{colors.accent}',

        // ── Status tokens (conditional on theme) ──
        // IF dark theme (background luminance < 50%):
        'status-success-bg':   'rgba(34,197,94,0.15)',
        'status-success-text': '#4ADE80',
        'status-warning-bg':   'rgba(245,158,11,0.15)',
        'status-warning-text': '#FBBF24',
        'status-error-bg':     'rgba(239,68,68,0.15)',
        'status-error-text':   '#F87171',
        'status-info-bg':      'rgba(59,130,246,0.15)',
        'status-info-text':    '#60A5FA',
        // IF light theme (background luminance >= 50%):
        // 'status-success-bg':   '#DCFCE7',
        // 'status-success-text': '#166534',
        // (and so on for warning, error, info)

        // ── Raw semantic colors (for direct use) ──
        error:   '{colors.error}',
        warning: '{colors.warning}',
        success: '{colors.success}',
        info:    '{colors.info}',
      },
      fontFamily: {
        sans: [{typography.font_family}],
      },
      fontSize: {
        // Scale based on typography.base_size and typography.scale
        xs:   ['{base * scale^-2}', { lineHeight: '1rem' }],
        sm:   ['{base * scale^-1}', { lineHeight: '1.25rem' }],
        base: ['{typography.base_size}', { lineHeight: '1.5rem' }],
        lg:   ['{base * scale^1}', { lineHeight: '1.75rem' }],
        xl:   ['{base * scale^2}', { lineHeight: '1.75rem' }],
        '2xl': ['{base * scale^3}', { lineHeight: '2rem' }],
        '3xl': ['{base * scale^4}', { lineHeight: '2.25rem' }],
      },
      borderRadius: {
        sm:      '{borders.radius_sm}',
        DEFAULT: '{borders.radius}',
        lg:      '{borders.radius_lg}',
        full:    '{borders.radius_full}',
      },
      boxShadow: {
        sm:      '{shadows.sm}',
        DEFAULT: '{shadows.md}',
        lg:      '{shadows.lg}',
      },
    }
  }
}
```

### 3.1 Derived Color Computation

Some tokens require computation from style.json values. Apply these formulas:

```
inset   = darken(surface, 3%)     // or lighten 3% if light theme
muted   = mix(text_secondary, background, 60%)  // 40% opacity simulation
subtle  = mix(border, background, 50%)          // 50% opacity simulation

"darken" for dark themes = decrease lightness in HSL by N%
"darken" for light themes = decrease lightness in HSL by N%
"mix(color, bg, weight)" = blend color into background at weight%
```

Compute to a final hex value — do NOT use `rgba()` for token colors because Tailwind
classes like `bg-muted/50` (opacity modifier) need a solid base color.

Exception: Status background colors (`status-*-bg`) use `rgba()` because they overlay
on `surface` and need transparency.

### 3.2 Dark Theme Detection

```
Parse colors.background hex → convert to HSL → check lightness:
  IF lightness < 50% → dark theme
  IF lightness >= 50% → light theme

This determines:
  1. Which status color variants to use (Section 2.5)
  2. Whether to darken or lighten for derived colors
  3. Scrollbar track/thumb colors
  4. Hover state direction (lighter for dark, darker for light)
```

### 3.3 Gradient Support

If style.json has a `gradient` key:

```javascript
// Add to <style> block (not Tailwind config — gradients need CSS)
.gradient-primary {
  background: {gradient.primary};  // e.g., "linear-gradient(135deg, #1A6FC4, #42B4F5)"
}
.gradient-primary-hover:hover {
  filter: brightness(1.1);
}
```

Use `.gradient-primary` on primary CTA buttons when the project has a gradient defined.
Fall back to solid `bg-primary` when no gradient exists.

---

## 4. Custom CSS Block

Beyond Tailwind config, the prototype needs a `<style>` block for things Tailwind
cannot express. Generate this from style.json:

```css
/* ── Required for Alpine.js ── */
[x-cloak] { display: none !important; }

/* ── Smooth scroll ── */
html { scroll-behavior: smooth; }

/* ── Font stack ── */
body { font-family: {typography.font_family}; }

/* ── Scrollbar (adapt to theme) ── */
::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: {colors.background}; }
::-webkit-scrollbar-thumb { background: {colors.border}; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: {colors.primary}; }

/* ── Gradient (if defined) ── */
/* {gradient CSS from 3.3} */

/* ── Print styles (for receipt/report screens) ── */
@media print {
  .no-print { display: none !important; }
  body { background: white !important; color: black !important; }
}
```

---

## 5. Pattern Token Usage Reference

Quick reference for pattern file authors. When writing or adapting a pattern:

### Backgrounds
```
Page background       → bg-page
Card / panel          → bg-surface
Dropdown / modal      → bg-surface-el
Table stripe / input  → bg-inset
Hover (interactive)   → hover:bg-surface-el
Selected row          → bg-primary-light (with appropriate opacity)
Disabled element      → bg-inset opacity-60
```

### Text
```
Heading / label       → text-heading
Body / description    → text-body
Placeholder / helper  → text-muted
Link / active item    → text-primary
Error message         → text-error
```

### Borders
```
Card border           → border-line
Divider inside card   → border-subtle
Focus ring            → ring-primary (focus:ring-2 ring-primary)
Input border          → border-line (focus: ring-primary)
```

### Interactive States
```
Button primary        → bg-primary text-white hover:bg-primary-dark
Button secondary      → bg-surface-el text-heading hover:bg-inset border-line
Button ghost          → text-primary hover:bg-primary-light
Button danger         → bg-error text-white hover:brightness-90
Sidebar active item   → bg-primary-light text-primary border-r-2 border-primary
Nav link hover        → hover:bg-surface-el hover:text-heading
```

### Status Badges
```
Success badge → bg-status-success-bg text-status-success-text
Warning badge → bg-status-warning-bg text-status-warning-text
Error badge   → bg-status-error-bg text-status-error-text
Info badge    → bg-status-info-bg text-status-info-text
```

---

## 6. Token Validation

After generating the Tailwind config, verify:

1. Every token class in Section 5 resolves to a color in the config
2. No pattern file uses hardcoded Tailwind grays (`bg-white`, `bg-gray-50`, `text-gray-900`)
   except inside status badge conditional classes
3. `bg-page` is used on `<body>` or root container
4. `bg-surface` is used on all cards and panels
5. `text-heading` contrast ratio against `bg-surface` meets WCAG AA (4.5:1)
6. `text-body` contrast ratio against `bg-surface` meets WCAG AA (4.5:1)
7. `text-muted` contrast ratio against `bg-surface` meets WCAG AA (3:1 for large text)
   or AAA informational (used for non-critical hints)

---

## 7. CDN Order (Updated for v6)

```html
<!-- 1. Tailwind CSS -->
<script src="https://cdn.tailwindcss.com"></script>
<!-- 2. Tailwind Config (inline, from Section 3) -->
<script>tailwind.config = { ... }</script>
<!-- 3. Google Fonts (if typography.font_family needs it) -->
<link href="https://fonts.googleapis.com/css2?family={font}&display=swap" rel="stylesheet">
<!-- 4. Chart.js (before Alpine so charts can be initialized in Alpine callbacks) -->
<script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
<!-- 5. Alpine.js Focus Plugin (BEFORE Alpine core) -->
<script defer src="https://cdn.jsdelivr.net/npm/@alpinejs/focus@3/dist/cdn.min.js"></script>
<!-- 6. Alpine.js (defer) -->
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3/dist/cdn.min.js"></script>
```

**Changes from v5:**
- Chart.js @4 added at position 4 (loaded synchronously before Alpine defer)
- All version pins use major-only (`@3`, `@4`)
- Lucide CDN REMOVED — icons use inline `<svg>` markup instead of `<i data-lucide>` tags.
  Tag-based Lucide rendering fails on Alpine x-show hidden elements (icons only render
  after becoming visible, causing flash). Inline SVGs work immediately regardless of
  visibility state. The model generates SVG paths from its knowledge of Lucide icon designs.

---

## 8. Chart.js Integration with Alpine

Chart.js instances must live OUTSIDE Alpine's reactive system. Canvas elements inside
`x-show` containers need deferred initialization.

### 8.1 Chart Manager (add after appState definition)

```javascript
const chartManager = {
  instances: {},

  init(canvasId, type, data, options = {}) {
    this.destroy(canvasId);
    const ctx = document.getElementById(canvasId)?.getContext('2d');
    if (!ctx) return;
    this.instances[canvasId] = new Chart(ctx, {
      type,
      data,
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          legend: { labels: { color: '{colors.text_secondary}' } }
        },
        scales: type === 'doughnut' || type === 'pie' ? {} : {
          x: { ticks: { color: '{colors.text_secondary}' }, grid: { color: '{colors.border}30' } },
          y: { ticks: { color: '{colors.text_secondary}' }, grid: { color: '{colors.border}30' } }
        },
        ...options
      }
    });
  },

  destroy(canvasId) {
    if (this.instances[canvasId]) {
      this.instances[canvasId].destroy();
      delete this.instances[canvasId];
    }
  },

  destroyAll() {
    Object.keys(this.instances).forEach(id => this.destroy(id));
  }
};
```

### 8.2 Screen-Level Chart Initialization

Charts initialize when their parent screen becomes visible:

```html
<div x-show="currentScreen === 'S-008'"
     x-effect="if (currentScreen === 'S-008') {
       $nextTick(() => {
         chartManager.init('revenue-chart', 'line', revenueData);
         chartManager.init('category-chart', 'doughnut', categoryData);
       });
     }"
     x-cloak>
  <!-- Chart containers here -->
</div>
```

Use `x-effect` + `$nextTick` instead of `@shown` because `@shown` is not a native
Alpine event. `x-effect` runs whenever `currentScreen` changes, and `$nextTick` ensures
the DOM is rendered before Chart.js measures the canvas.

### 8.3 Chart Theme Tokens

Chart.js configuration uses style.json colors directly (not Tailwind classes):

```
Chart background:     transparent (inherits from card bg-surface)
Grid lines:           {colors.border} at 20% opacity
Tick labels:          {colors.text_secondary}
Legend text:          {colors.text_secondary}
Dataset colors:       {colors.primary}, {colors.accent}, {colors.success},
                      {colors.warning}, {colors.error}, {colors.info}
Tooltip background:   {colors.surface_elevated}
Tooltip text:         {colors.text_primary}
Tooltip border:       {colors.border}
```

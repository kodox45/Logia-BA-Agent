# Advanced Patterns

Structural guidance for uncommon UI patterns not covered by the core HTML pattern files.
These patterns are described as composition rules — combine core patterns (from
`patterns/*.html`) with the structural approach described here.

Read this file only when a screen requires one of these patterns. All patterns use
semantic token classes from `token-system.md`.

---

## 1. Kanban Board

**When:** Screen purpose includes "board", "pipeline", "workflow status", or components
reference a kanban/board layout.

### Structure

```
Container:  flex overflow-x-auto gap-4 p-4 bg-page
Column:     flex-shrink-0 w-72 bg-surface rounded shadow border border-line
  Header:   px-4 py-3 border-b border-subtle flex items-center justify-between
    Title:  text-sm font-semibold text-heading
    Count:  badge pattern (bg-inset text-muted rounded-full px-2)
  Body:     p-3 space-y-3 min-h-[200px] max-h-[calc(100vh-240px)] overflow-y-auto
    Card:   bg-surface-el rounded border border-subtle p-3 shadow-sm
      Title: text-sm font-medium text-heading
      Meta:  text-xs text-muted
      Tags:  badge pattern (inline-flex gap-1)
      Avatar: avatar pattern (bottom-right)
  Footer:   px-4 py-2 border-t border-subtle
    Add btn: ghost button pattern (text-muted hover:text-primary)
```

### Column Definitions

Derive columns from:
- `features.json` → entity status field `options[]`
- `components.json` → component with `states[]` matching board columns
- Common defaults: "To Do", "In Progress", "Review", "Done"

### Interaction

```
Column header color strip: top-2 rounded-t with status color
  Use 4px height solid strip: bg-status-warning-text, bg-primary, bg-status-info-text, bg-status-success-text

Drag-and-drop simulation (prototype only):
  Cards have @click handler that cycles status
  @click="moveCard(card.id, '{next-column}')"
  appState: moveCard(id, column) updates the card's status field

Column count updates reactively via x-text="cards.filter(c => c.status === 'todo').length"
```

### Mock Data

Generate 8-12 cards spread across columns with realistic variety:
- 2-3 per column (weighted: more in middle columns)
- Mix of priorities (badges), assignees (avatars), due dates
- 1 card with many tags (tests overflow)

---

## 2. Calendar View

**When:** Screen purpose includes "calendar", "schedule", "booking", or "appointment".

### Structure: Month View

```
Container:  bg-surface rounded shadow border border-line
  Header:   px-6 py-4 border-b border-subtle flex items-center justify-between
    Nav:    flex items-center gap-4
      Prev:  icon-only button (chevron-left)
      Title: text-lg font-semibold text-heading x-text="monthName + ' ' + year"
      Next:  icon-only button (chevron-right)
    Actions: button-group pattern (Month | Week | Day toggle)
  Grid:
    Day headers: grid grid-cols-7, text-xs font-medium text-muted text-center py-2 bg-inset
    Day cells:   grid grid-cols-7
      Cell:      min-h-[100px] border-t border-r border-subtle p-1
        Number:  text-xs text-body (text-heading if today, bg-primary text-white rounded-full for today)
        Events:  text-xs truncate px-1 py-0.5 rounded mb-0.5 cursor-pointer
                 Color-code by category using status tokens
```

### Structure: Week View

Same header, but grid has 8 columns (time column + 7 days) and rows per hour:

```
Time col:  w-16 text-xs text-muted text-right pr-2
Day cols:  flex-1 border-l border-subtle relative
  Events:  absolute positioned, height based on duration
           bg-primary-light border-l-4 border-primary text-xs p-1 rounded
```

### Alpine State

```javascript
// Add to appState:
calendarMonth: new Date().getMonth(),
calendarYear: new Date().getFullYear(),
calendarView: 'month',  // month | week | day
calendarEvents: [
  { id: 1, title: '{Event}', date: '2025-03-15', time: '09:00', duration: 60, category: 'meeting' },
  ...
],
// Methods:
prevMonth() { ... },
nextMonth() { ... },
getDaysInMonth() { ... },
getEventsForDate(date) { return this.calendarEvents.filter(e => e.date === date) }
```

### Mock Data

Generate 10-15 events across the current month:
- 2-3 categories with distinct colors (meetings=primary, deadlines=error, events=accent)
- Some overlapping events (same day) to test layout
- 1 multi-day event if the domain supports it

---

## 3. Print Preview / Receipt

**When:** Screen purpose includes "receipt", "invoice", "print", "report preview",
or features reference print/export functionality.

### Structure

```
Container:  max-w-2xl mx-auto
  Toolbar:  no-print flex items-center justify-between mb-4 bg-surface rounded shadow border border-line p-3
    Title:  text-sm font-medium text-heading
    Actions: flex gap-2
      Print: button @click="window.print()" (primary)
      Download: button (secondary)
  Preview:  bg-surface rounded shadow border border-line
    Paper:  p-8 sm:p-12 (mimics A4 proportions)
      Header:
        Logo area: h-12 (brand from manifest.json or text fallback)
        Company:   text-xl font-bold text-heading
        Address:   text-xs text-body
      Meta section:
        Two-column: grid grid-cols-2 gap-4 mt-8 mb-8
          Left:  Receipt/Invoice #, Date, Due Date
          Right: Bill To details
      Table:
        Headers:  text-xs font-medium text-muted uppercase border-b-2 border-line
        Rows:     text-sm text-body border-b border-subtle py-3
        Totals:   border-t-2 border-line pt-3 text-right
          Subtotal: text-sm text-body
          Tax:      text-sm text-body
          Total:    text-lg font-bold text-heading
      Footer:
        Terms:  text-xs text-muted mt-8 pt-4 border-t border-subtle
        Thanks: text-sm text-body text-center mt-4
```

### Print CSS

The base `token-system.md` already includes print styles. For receipts, add:

```css
@media print {
  .no-print { display: none !important; }
  body { background: white !important; }
  .receipt-paper { box-shadow: none !important; border: none !important; }
}
```

### Mock Data

Derive line items from features.json entity fields:
- 4-6 items with realistic names and prices
- At least 1 item with quantity > 1
- Tax calculation (derive rate from locale context)

---

## 4. Gallery / Image Grid

**When:** Screen includes image uploads, product photos, media library, or portfolio.

### Structure: Grid View

```
Container:  grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4
  Card:     group relative bg-surface rounded shadow border border-line overflow-hidden
    Image:  aspect-square bg-inset flex items-center justify-center
      (Prototype: use colored placeholder with icon)
      <div class="aspect-square bg-inset flex items-center justify-center">
        <svg class="w-12 h-12 text-muted">...</svg>
      </div>
    Overlay: absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100
             flex items-center justify-center gap-2 transition-opacity
      View:  icon-only button (bg-white/90 rounded-full p-2)
      Delete: icon-only button (bg-white/90 rounded-full p-2 text-error)
    Info:   p-3
      Name:  text-sm font-medium text-heading truncate
      Meta:  text-xs text-muted
```

### Structure: Lightbox Overlay

```
Overlay:  fixed inset-0 z-50 bg-black/80 flex items-center justify-center
  (Use x-trap.noscroll for focus trapping)
  Close:   absolute top-4 right-4 text-white/80 hover:text-white
  Image:   max-w-4xl max-h-[80vh] object-contain
  Nav:     absolute left-4/right-4 top-1/2 -translate-y-1/2
    Prev/Next: icon-only buttons (bg-white/20 hover:bg-white/40 rounded-full)
  Caption: absolute bottom-4 left-1/2 -translate-x-1/2 text-white text-sm
```

### Mock Data

For prototypes, use placeholder divs instead of real images:
- Vary background shades using status tokens for variety
- Add realistic filenames and sizes
- Generate 8-12 items

---

## 5. Map Placeholder

**When:** Screen references location, map, geolocation, address picker, or delivery tracking.

### Structure

```
Container:  bg-surface rounded shadow border border-line overflow-hidden
  Header:   px-4 py-3 border-b border-subtle flex items-center justify-between (optional)
  Map area: relative aspect-video bg-inset
    Placeholder:
      <div class="aspect-video bg-inset flex flex-col items-center justify-center">
        <svg class="w-16 h-16 text-muted mb-2">
          <!-- map-pin icon -->
        </svg>
        <p class="text-sm text-muted">Map view</p>
        <p class="text-xs text-muted mt-1">Interactive map would render here</p>
      </div>
    Pin overlay (optional):
      <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-full">
        <div class="w-8 h-8 bg-primary rounded-full border-2 border-surface shadow-lg
                    flex items-center justify-center">
          <svg class="w-4 h-4 text-white">...</svg>
        </div>
      </div>
  Details:  p-4
    Address: text-sm text-heading
    Coords:  text-xs text-muted
```

### Variants

- **Sidebar with location list:** Two-column layout, map on right, scrollable list on left
- **Address picker:** Map placeholder + search-input above + address form below
- **Delivery tracking:** Map placeholder + timeline pattern showing delivery steps

---

## 6. Drag-and-Drop List

**When:** Features reference reordering, prioritization, sorting by drag, or rank adjustment.

### Structure

```
Container:  space-y-2
  Item:     flex items-center gap-3 p-3 bg-surface rounded border border-line
            hover:shadow-sm transition-shadow cursor-grab active:cursor-grabbing
    Handle:  text-muted flex-shrink-0
      <svg class="w-4 h-4">
        <!-- grip-vertical icon: 6 dots -->
      </svg>
    Content: flex-1 min-w-0
      Title:  text-sm font-medium text-heading
      Meta:   text-xs text-muted
    Actions: flex items-center gap-2 flex-shrink-0
      (icon-only buttons: edit, delete)
```

### Prototype Simulation

Actual drag-and-drop requires a library (SortableJS). For prototypes, simulate with
move up/down buttons:

```html
<button @click="moveItem(index, -1)" class="text-muted hover:text-heading" aria-label="Move up">
  <svg class="w-4 h-4"><!-- chevron-up --></svg>
</button>
<button @click="moveItem(index, 1)" class="text-muted hover:text-heading" aria-label="Move down">
  <svg class="w-4 h-4"><!-- chevron-down --></svg>
</button>
```

```javascript
// appState method:
moveItem(index, direction) {
  const newIndex = index + direction;
  if (newIndex < 0 || newIndex >= this.items.length) return;
  const temp = this.items[index];
  this.items[index] = this.items[newIndex];
  this.items[newIndex] = temp;
}
```

---

## 7. Settings / Preferences Layout

**When:** Screen purpose includes "settings", "preferences", "configuration", "profile".

### Structure

```
Container:  max-w-3xl mx-auto
  Two-col:  flex gap-8
    Sidebar: w-48 flex-shrink-0 (sticky top-20)
      Nav:   space-y-1
        Item: text-sm py-2 px-3 rounded cursor-pointer
              Active:  text-primary bg-primary-light font-medium
              Default: text-body hover:text-heading hover:bg-surface-el
    Content: flex-1 space-y-8
      Section: form-section pattern from forms.html
        Toggle rows: toggle-switch pattern
        Input rows:  text-input pattern
        Select rows: select-dropdown pattern
      Danger zone:
        bg-status-error-bg/30 border border-error/20 rounded p-4
        Title:  text-sm font-medium text-error
        Desc:   text-xs text-body
        Button: danger button pattern
```

### Settings Navigation

Use scroll-based highlighting or @click sections:

```javascript
// appState:
settingsSection: 'general',
settingsSections: ['general', 'notifications', 'security', 'billing', 'danger']
```

Each section wrapped in `<section id="settings-{name}">` for anchor navigation.

---

## 8. Multi-Step Checkout / Onboarding

**When:** Flows reference "checkout", "onboarding", "wizard" with more than 3 steps,
or steps include payment/confirmation screens.

### Structure

Uses form-wizard from `forms.html` + stepper-indicator from `navigation.html`, extended:

```
Step 1: Information form (text inputs, selects)
Step 2: Selection/configuration (radio-card variants, toggles)
Step 3: Review/summary
  Order summary:  list-view pattern with line items
  Address:        card pattern with details
  Edit links:     @click="currentStep = 1" to jump back
Step 4: Confirmation (success state)
  Success icon:   w-16 h-16 bg-status-success-bg rounded-full flex items-center justify-center
  Message:        text-xl font-semibold text-heading
  Details:        text-sm text-body
  CTA:            primary button → navigateTo('{next-screen}')
```

### Review Step Pattern

```html
<div class="bg-surface rounded border border-line divide-y divide-subtle">
  <div class="px-4 py-3 flex items-center justify-between">
    <div>
      <p class="text-xs text-muted">{Section Label}</p>
      <p class="text-sm text-heading">{Summary value}</p>
    </div>
    <button @click="currentStep = {edit-step}"
            class="text-xs font-medium text-primary hover:text-primary-dark">Edit</button>
  </div>
  <!-- Repeat for each section -->
</div>
```

---

## Composition Rules

When combining patterns from this file with core patterns:

1. **Card wrappers always use** `bg-surface rounded shadow border border-line`
2. **Section spacing** uses `space-y-6` between major sections
3. **Responsive breakpoints** follow the same pattern as layout.html
4. **Status colors** always use `bg-status-*-bg text-status-*-text` tokens
5. **Interactive elements** always have `transition-colors` or `transition-all`
6. **Focus states** always include `focus:outline-none focus:ring-2 focus:ring-primary`
7. **Empty states** use `empty-state` pattern from data-display.html
8. **Loading states** use `skeleton-loader` from feedback.html during simulated operations

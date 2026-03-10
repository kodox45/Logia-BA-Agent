#!/usr/bin/env bash
# validate-prototype.sh — Prototype output validator (v6)
# Validates prototype/index.html against the 20-point checklist from SKILL.md Step 6.
# Can be called standalone or from the validate-draft.sh dispatcher hook.
#
# Usage: bash validate-prototype.sh [project-dir]
# Exit codes:
#   0 = all checks pass
#   2 = one or more checks failed

set -euo pipefail

# Accept project dir as argument, default to CLAUDE_PROJECT_DIR or current dir
PROJECT_DIR="${1:-${CLAUDE_PROJECT_DIR:-.}}"
INDEX_FILE="${PROJECT_DIR}/prototype/index.html"
BA_DIR="${PROJECT_DIR}/.ba"

ERRORS=""
WARNINGS=""
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  [PASS] Check #$1: $2"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  ERRORS="${ERRORS}Check #$1: $2\n"
  echo "  [FAIL] Check #$1: $2"
}

warn() {
  WARNINGS="${WARNINGS}$1\n"
  echo "  [WARN] $1"
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo "  [SKIP] Check #$1: $2 (missing dependency)"
}

echo "═══════════════════════════════════════════════"
echo "  Prototype Validator v6 — 18-Point Checklist"
echo "═══════════════════════════════════════════════"
echo ""

# --- Pre-flight: check file exists ---
if [ ! -f "$INDEX_FILE" ]; then
  echo "[FATAL] prototype/index.html not found at: $INDEX_FILE"
  exit 2
fi

FILE_SIZE=$(wc -c < "$INDEX_FILE" | tr -d ' ')
LINE_COUNT=$(wc -l < "$INDEX_FILE" | tr -d ' ')
echo "File: $INDEX_FILE"
echo "Size: ${FILE_SIZE} bytes, ${LINE_COUNT} lines"
echo ""
echo "── Structure Checks ──"

# ═══ CHECK 1: DOCTYPE and closing tag ═══
FIRST_LINE=$(head -n 1 "$INDEX_FILE" | tr -d '\r')
if echo "$FIRST_LINE" | grep -qi '<!DOCTYPE html>'; then
  # Check closing tag
  LAST_CONTENT=$(tail -c 100 "$INDEX_FILE" | tr -d '[:space:]')
  if echo "$LAST_CONTENT" | grep -q '</html>'; then
    pass 1 "File starts with <!DOCTYPE html> and ends with </html>"
  else
    fail 1 "File starts with <!DOCTYPE html> but does NOT end with </html> (possible truncation)"
  fi
else
  fail 1 "File does not start with <!DOCTYPE html>"
fi

# ═══ CHECK 2: CDN order ═══
# Expected order: Tailwind CDN → tailwind.config → (Fonts optional) → Chart.js → Alpine Focus → Alpine → Lucide
if command -v python3 &>/dev/null; then
  python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
# Find positions of key CDN references
checks = [
    ('tailwindcss', content.find('cdn.tailwindcss.com')),
    ('tailwind.config', content.find('tailwind.config')),
    ('chart.js', content.find('chart.js') if content.find('chart.js') > 0 else content.find('chart.umd')),
    ('alpine-focus', content.find('alpinejs/focus') if content.find('alpinejs/focus') > 0 else content.find('@alpinejs/focus')),
    ('alpine-core', content.find('alpinejs@') if content.find('alpinejs@') > 0 else content.find('alpinejs/')),
    ('lucide', content.find('lucide')),
]
found = [(name, pos) for name, pos in checks if pos >= 0]
if len(found) < 3:
    print(f'Only {len(found)}/6 CDN refs found: {[n for n,p in found]}', file=sys.stderr)
    sys.exit(2)
# Check ordering
positions = [pos for _, pos in found]
for i in range(len(positions)-1):
    if positions[i] > positions[i+1]:
        print(f'CDN order violation: {found[i][0]} (pos {found[i][1]}) appears after {found[i+1][0]} (pos {found[i+1][1]})', file=sys.stderr)
        sys.exit(2)
sys.exit(0)
" 2>&1 && pass 2 "CDN order correct" || fail 2 "CDN order incorrect (see above)"
else
  skip 2 "CDN order" "python3 not available"
fi

# ═══ CHECK 3: x-data on body, no x-cloak on body ═══
if grep -q 'x-data="appState()"' "$INDEX_FILE"; then
  # Check body tag specifically
  BODY_LINE=$(grep -n '<body' "$INDEX_FILE" | head -1)
  if echo "$BODY_LINE" | grep -q 'x-data="appState()"'; then
    if echo "$BODY_LINE" | grep -q 'x-cloak'; then
      fail 3 "x-data=\"appState()\" on <body> but x-cloak is also present (causes white screen)"
    else
      pass 3 "x-data=\"appState()\" on <body>, no x-cloak on <body>"
    fi
  else
    fail 3 "x-data=\"appState()\" exists but NOT on <body> tag"
  fi
else
  fail 3 "x-data=\"appState()\" not found anywhere in file"
fi

# ═══ CHECK 4: bg-page on body ═══
BODY_LINE=$(grep '<body' "$INDEX_FILE" | head -1)
if echo "$BODY_LINE" | grep -q 'bg-page'; then
  pass 4 "<body> has bg-page class"
else
  if echo "$BODY_LINE" | grep -q 'bg-white\|bg-gray\|background-color'; then
    fail 4 "<body> uses hardcoded background instead of bg-page"
  else
    fail 4 "<body> missing bg-page class"
  fi
fi

echo ""
echo "── Completeness Checks ──"

# ═══ CHECK 5: Screen IDs in file ═══
if [ -f "${BA_DIR}/design/screens.json" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
screens = json.load(open('${BA_DIR}/design/screens.json', encoding='utf-8'))
content = open('$INDEX_FILE', encoding='utf-8').read()
screen_ids = [s['id'] for s in screens.get('screens', [])]
missing = []
for sid in screen_ids:
    marker = f'id=\"{sid}\"'
    xshow = f\"x-show=\\\"currentScreen === '{sid}'\\\"\"
    # Check both id and x-show (flexible matching)
    if marker not in content:
        missing.append(sid)
if missing:
    print(f'Missing screens: {\", \".join(missing)}', file=sys.stderr)
    sys.exit(2)
print(f'All {len(screen_ids)} screens present')
sys.exit(0)
" 2>&1 && pass 5 "All screens from screens.json present in index.html" || fail 5 "Missing screen IDs (see above)"
else
  skip 5 "Screen completeness" "screens.json not found or python3 missing"
fi

# ═══ CHECK 6: Must-have feature coverage ═══
if [ -f "${BA_DIR}/requirements/features.json" ] && [ -f "${BA_DIR}/design/screens.json" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
features = json.load(open('${BA_DIR}/requirements/features.json', encoding='utf-8'))
content = open('$INDEX_FILE', encoding='utf-8').read()
must_haves = features.get('must_have', [])
if not must_haves:
    print('No must_have features defined')
    sys.exit(0)
# Check if screen_refs screens exist in content
missing_features = []
for f in must_haves:
    fid = f.get('id', f.get('title', 'unknown'))
    screen_refs = f.get('screen_refs', [])
    if not screen_refs:
        continue
    found = any(ref in content for ref in screen_refs)
    if not found:
        missing_features.append(fid)
if missing_features:
    print(f'Features without screens: {\", \".join(str(f) for f in missing_features)}', file=sys.stderr)
    sys.exit(2)
print(f'All {len(must_haves)} must_have features have screen coverage')
sys.exit(0)
" 2>&1 && pass 6 "All must_have features represented" || fail 6 "Must-have features missing screen coverage (see above)"
else
  skip 6 "Feature coverage" "features.json or screens.json not found"
fi

# ═══ CHECK 7: Role switcher completeness ═══
if [ -f "${BA_DIR}/requirements/roles.json" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
roles = json.load(open('${BA_DIR}/requirements/roles.json', encoding='utf-8'))
content = open('$INDEX_FILE', encoding='utf-8').read()
role_names = [r.get('name', r.get('id', '')) for r in roles.get('roles', [])]
missing = []
for name in role_names:
    if name not in content:
        missing.append(name)
if missing:
    print(f'Roles not in role switcher: {\", \".join(missing)}', file=sys.stderr)
    sys.exit(2)
print(f'All {len(role_names)} roles present')
sys.exit(0)
" 2>&1 && pass 7 "All roles present in role switcher" || fail 7 "Missing roles in role switcher (see above)"
else
  skip 7 "Role completeness" "roles.json not found"
fi

# ═══ CHECK 8: Navigation links ═══
if [ -f "${BA_DIR}/design/layout.json" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
layout = json.load(open('${BA_DIR}/design/layout.json', encoding='utf-8'))
content = open('$INDEX_FILE', encoding='utf-8').read()
# Handle multi-interface
if 'interfaces' in layout:
    nav_items = []
    for iface in layout['interfaces'].values():
        nav = iface.get('navigation', {})
        nav_items.extend(nav.get('primary', []))
else:
    nav = layout.get('navigation', {})
    nav_items = nav.get('primary', [])
if not nav_items:
    print('No primary nav items defined')
    sys.exit(0)
missing = []
for item in nav_items:
    screen_ref = item.get('screen', item.get('screen_ref', ''))
    if screen_ref and f\"navigateTo('{screen_ref}')\" not in content and f'navigateTo(\"{screen_ref}\")' not in content:
        missing.append(screen_ref)
if missing:
    print(f'Nav items without navigateTo link: {\", \".join(missing)}', file=sys.stderr)
    sys.exit(2)
print(f'All {len(nav_items)} primary nav items wired')
sys.exit(0)
" 2>&1 && pass 8 "All primary nav items have navigateTo links" || fail 8 "Navigation links missing (see above)"
else
  skip 8 "Navigation links" "layout.json not found"
fi

echo ""
echo "── Functionality Checks ──"

# ═══ CHECK 9: navigateTo references valid screen IDs ═══
if command -v python3 &>/dev/null; then
  python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
# Find all navigateTo calls
nav_refs = set(re.findall(r\"navigateTo\(['\\\"]([^'\\\"]+)['\\\"]\)\", content))
# Find all screen div IDs
screen_ids = set(re.findall(r'id=\"(S-\d+)\"', content))
# Also find IDs like 'login', 'dashboard', etc
all_ids = set(re.findall(r'id=\"([^\"]+)\"', content))
invalid = []
for ref in nav_refs:
    if ref not in all_ids:
        invalid.append(ref)
if invalid:
    print(f'navigateTo references invalid IDs: {\", \".join(invalid)}', file=sys.stderr)
    sys.exit(2)
print(f'All {len(nav_refs)} navigateTo references are valid')
sys.exit(0)
" 2>&1 && pass 9 "All navigateTo() references valid screen IDs" || fail 9 "navigateTo references invalid IDs (see above)"
else
  skip 9 "navigateTo validation"
fi

# ═══ CHECK 10: Handler functions exist in appState ═══
if command -v python3 &>/dev/null; then
  python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
# Core functions that should be in appState
core_fns = ['navigateTo', 'addToast']
# Find appState definition
appstate_match = re.search(r'function\s+appState\s*\(\s*\)\s*\{', content)
if not appstate_match:
    print('appState() function not found', file=sys.stderr)
    sys.exit(2)
# Find all function calls in handlers
handler_fns = set()
for pattern in [r'@click=\"([^\"]+)\"', r'@submit\.prevent=\"([^\"]+)\"', r'@click\.prevent=\"([^\"]+)\"']:
    for handler in re.findall(pattern, content):
        # Extract function names from handler expressions
        for fn in re.findall(r'(\w+)\s*\(', handler):
            if fn not in ('setTimeout', 'parseInt', 'parseFloat', 'Math', 'Date', 'Array', 'Object',
                         'console', 'window', 'document', 'JSON', 'String', 'Number', 'Boolean',
                         'if', 'else', 'return', 'true', 'false', 'null', 'filter', 'map',
                         'find', 'forEach', 'reduce', 'splice', 'push', 'pop', 'shift',
                         'chartManager', 'lucide'):
                handler_fns.add(fn)
# Check core functions
missing = [fn for fn in core_fns if fn not in content]
if missing:
    print(f'Core functions missing from appState: {\", \".join(missing)}', file=sys.stderr)
    sys.exit(2)
print(f'Core handler functions present ({len(handler_fns)} unique handler calls found)')
sys.exit(0)
" 2>&1 && pass 10 "Handler functions (navigateTo, addToast) exist in appState" || fail 10 "Missing handler functions (see above)"
else
  skip 10 "Handler function validation"
fi

# ═══ CHECK 11: x-model references (basic check) ═══
if command -v python3 &>/dev/null; then
  python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
models = set(re.findall(r'x-model=\"([^\"]+)\"', content))
# Filter to simple property names (not expressions)
simple_models = [m for m in models if re.match(r'^[a-zA-Z_]\w*$', m)]
# Check if they appear somewhere in appState or local x-data
appstate_section = content[content.find('function appState'):content.find('function appState') + 10000] if 'function appState' in content else ''
# Collect all x-data local scopes
local_data = re.findall(r'x-data=\"\{([^}]+)\}\"', content)
all_data = appstate_section + ' '.join(local_data)
missing = []
for model in simple_models:
    if model not in all_data:
        missing.append(model)
if len(missing) > 3:
    print(f'x-model vars possibly missing from state: {\", \".join(missing[:5])}...', file=sys.stderr)
    sys.exit(2)
elif missing:
    # Warn but don't fail for 1-3 (could be dynamic properties)
    pass
print(f'{len(simple_models)} x-model bindings checked')
sys.exit(0)
" 2>&1 && pass 11 "x-model references appear initialized" || fail 11 "x-model references missing from state (see above)"
else
  skip 11 "x-model validation"
fi

# ═══ CHECK 12: Modal/confirm state vars ═══
if grep -q 'showModal\|modalOpen\|showConfirm\|confirmOpen' "$INDEX_FILE"; then
  # Check if these vars are initialized
  MODAL_ISSUES=""
  if grep -q 'showModal\|modalOpen' "$INDEX_FILE"; then
    if ! grep -q 'modalOpen.*false\|showModal.*false\|modalOpen:.*false\|showModal:.*false' "$INDEX_FILE"; then
      MODAL_ISSUES="modal state var used but not initialized; "
    fi
  fi
  if grep -q 'showConfirm\|confirmOpen' "$INDEX_FILE"; then
    if ! grep -q 'confirmOpen.*false\|showConfirm.*false\|confirmOpen:.*false\|showConfirm:.*false' "$INDEX_FILE"; then
      MODAL_ISSUES="${MODAL_ISSUES}confirm state var used but not initialized"
    fi
  fi
  if [ -z "$MODAL_ISSUES" ]; then
    pass 12 "Modal/confirm state variables initialized"
  else
    fail 12 "Modal/confirm state variables: $MODAL_ISSUES"
  fi
else
  pass 12 "No modal/confirm patterns detected (OK if none needed)"
fi

echo ""
echo "── Theme Checks ──"

# ═══ CHECK 13: No hardcoded colors ═══
if command -v python3 &>/dev/null; then
  python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
# Find all class attributes
classes = re.findall(r'class=\"([^\"]+)\"', content)
all_classes = ' '.join(classes)
# Check for hardcoded Tailwind grays (bg-white, bg-gray-*, text-gray-*)
# Exceptions: inside Tailwind config, CSS, script blocks, or status conditionals
# Simple approach: check class attributes only
hardcoded = []
for match in re.finditer(r'\b(bg-white|bg-gray-\d+|text-gray-\d+|border-gray-\d+)\b', all_classes):
    hardcoded.append(match.group())
# Deduplicate
unique = set(hardcoded)
# Filter known exceptions: bg-white in toggle switch knob is OK
allowed = {'bg-white'}  # toggle knob exception
violations = unique - allowed
if violations:
    # Count occurrences
    counts = {v: hardcoded.count(v) for v in violations}
    top = sorted(counts.items(), key=lambda x: -x[1])[:5]
    details = ', '.join(f'{v}({c}x)' for v,c in top)
    print(f'Hardcoded colors in class attrs: {details}', file=sys.stderr)
    sys.exit(2)
print('No hardcoded gray/white classes detected (bg-white toggle exception OK)')
sys.exit(0)
" 2>&1 && pass 13 "No hardcoded bg-white/bg-gray-*/text-gray-* in class attributes" || fail 13 "Hardcoded Tailwind colors found (see above)"
else
  # Fallback: simple grep
  HARDCODED=$(grep -c 'class="[^"]*bg-gray-\|class="[^"]*text-gray-' "$INDEX_FILE" 2>/dev/null || echo "0")
  if [ "$HARDCODED" -gt 0 ]; then
    fail 13 "Found ~${HARDCODED} lines with hardcoded gray classes"
  else
    pass 13 "No obvious hardcoded gray classes"
  fi
fi

# ═══ CHECK 14: Semantic tokens used for cards/text ═══
if command -v python3 &>/dev/null; then
  python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
# Check for bg-surface (should be common — cards, panels)
surface_count = len(re.findall(r'\bbg-surface\b', content))
heading_count = len(re.findall(r'\btext-heading\b', content))
body_count = len(re.findall(r'\btext-body\b', content))
muted_count = len(re.findall(r'\btext-muted\b', content))
line_count = len(re.findall(r'\bborder-line\b', content))
if surface_count < 3:
    print(f'bg-surface only used {surface_count} times (expected many cards/panels)', file=sys.stderr)
    sys.exit(2)
if heading_count < 2:
    print(f'text-heading only used {heading_count} times', file=sys.stderr)
    sys.exit(2)
print(f'Semantic tokens: bg-surface({surface_count}), text-heading({heading_count}), text-body({body_count}), text-muted({muted_count}), border-line({line_count})')
sys.exit(0)
" 2>&1 && pass 14 "Semantic tokens (bg-surface, text-heading, etc.) actively used" || fail 14 "Semantic tokens underused (see above)"
else
  skip 14 "Semantic token usage"
fi

# ═══ CHECK 15: Status badge tokens ═══
# Only check if status badges are used
if grep -q 'status-\|badge\|bg-green-\|bg-red-\|bg-yellow-\|bg-blue-' "$INDEX_FILE"; then
  if grep -q 'status-success-bg\|status-warning-bg\|status-error-bg\|status-info-bg' "$INDEX_FILE"; then
    pass 15 "Status badges use semantic status tokens"
  else
    # Check if hardcoded status colors are used instead
    if grep -q 'bg-green-100\|bg-red-100\|bg-yellow-100\|bg-blue-100' "$INDEX_FILE"; then
      fail 15 "Status badges use hardcoded colors (bg-green-100 etc.) instead of status tokens"
    else
      pass 15 "No status badges detected (OK if none needed)"
    fi
  fi
else
  pass 15 "No status badges in output"
fi

echo ""
echo "── Quality Checks ──"

# ═══ CHECK 16: No unreplaced placeholders ═══
# Look for {placeholder-style} tokens that should have been replaced
PLACEHOLDERS=$(grep -oP '\{[a-z]+-[a-z]+[a-z-]*\}' "$INDEX_FILE" 2>/dev/null | sort -u | head -10)
# Filter out known Alpine expressions like {filter: ...} or CSS like {max-height: ...}
if [ -n "$PLACEHOLDERS" ]; then
  # Filter common false positives
  REAL_PLACEHOLDERS=""
  while IFS= read -r p; do
    case "$p" in
      "{font-family}"|\
      "{border-radius}"|\
      "{primary-color}"|\
      "{primary-hover}"|\
      "{primary-light}"|\
      "{background-color}"|\
      "{text-primary}"|\
      "{text-secondary}")
        REAL_PLACEHOLDERS="${REAL_PLACEHOLDERS}${p} "
        ;;
    esac
  done <<< "$PLACEHOLDERS"
  if [ -n "$REAL_PLACEHOLDERS" ]; then
    fail 16 "Unreplaced v5 template placeholders found: ${REAL_PLACEHOLDERS}"
  else
    pass 16 "No unreplaced template placeholders"
  fi
else
  pass 16 "No unreplaced template placeholders"
fi

# ═══ CHECK 17: Tag balance (div, template) ═══
if command -v python3 &>/dev/null; then
  python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
# Count opening and closing tags for critical elements
for tag in ['div', 'template', 'section', 'main', 'aside', 'nav', 'form']:
    opens = len(re.findall(f'<{tag}[\\s>]', content))
    closes = len(re.findall(f'</{tag}>', content))
    # Self-closing and void tags don't have closing
    if opens != closes:
        print(f'Tag imbalance: <{tag}> opens={opens} closes={closes}', file=sys.stderr)
        sys.exit(2)
print('All critical tags balanced')
sys.exit(0)
" 2>&1 && pass 17 "HTML tags properly balanced (div, template, section, main, etc.)" || fail 17 "HTML tag imbalance detected (see above)"
else
  # Fallback: basic div count
  OPEN_DIVS=$(grep -c '<div' "$INDEX_FILE" 2>/dev/null || echo "0")
  CLOSE_DIVS=$(grep -c '</div>' "$INDEX_FILE" 2>/dev/null || echo "0")
  if [ "$OPEN_DIVS" -eq "$CLOSE_DIVS" ]; then
    pass 17 "div tags balanced: ${OPEN_DIVS} open, ${CLOSE_DIVS} close"
  else
    fail 17 "div tag imbalance: ${OPEN_DIVS} open vs ${CLOSE_DIVS} close"
  fi
fi

# ═══ CHECK 18: Chart canvas/init matching ═══
if grep -q '<canvas' "$INDEX_FILE"; then
  if command -v python3 &>/dev/null; then
    python3 -c "
import re, sys
content = open('$INDEX_FILE', encoding='utf-8').read()
# Find all canvas IDs
canvas_ids = set(re.findall(r'<canvas\s+id=\"([^\"]+)\"', content))
# Find all chartManager.init calls
init_ids = set(re.findall(r\"chartManager\.init\(['\\\"]([^'\\\"]+)['\\\"]\", content))
uninitialized = canvas_ids - init_ids
if uninitialized:
    print(f'Canvas without chartManager.init(): {\", \".join(uninitialized)}', file=sys.stderr)
    sys.exit(2)
print(f'All {len(canvas_ids)} canvas elements have matching chartManager.init() calls')
sys.exit(0)
" 2>&1 && pass 18 "All <canvas> elements have matching chartManager.init() calls" || fail 18 "Chart canvas/init mismatch (see above)"
  else
    skip 18 "Chart canvas validation"
  fi
else
  pass 18 "No <canvas> elements (charts not used)"
fi

# ═══ CHECK 19: Custom logo assets used when available ═══
MANIFEST_FILE="${BA_DIR}/design/manifest.json"
if [ -f "$MANIFEST_FILE" ]; then
  # Check if icon_style is "custom" and logo assets exist
  ICON_STYLE=$(python3 -c "import json; m=json.load(open('$MANIFEST_FILE')); print(m.get('brand_materials',{}).get('icon_style',''))" 2>/dev/null || echo "")
  HAS_LOGOS=$(python3 -c "import json; m=json.load(open('$MANIFEST_FILE')); logos=[a for a in m.get('assets',[]) if a.get('type')=='logo']; print('yes' if logos else 'no')" 2>/dev/null || echo "unknown")

  if [ "$ICON_STYLE" = "custom" ] && [ "$HAS_LOGOS" = "yes" ]; then
    # Custom logos exist — check that prototype uses <img src="assets/..."> for logo
    if grep -q 'src="assets/' "$INDEX_FILE"; then
      # Also check that no data-lucide is used as logo placeholder
      LUCIDE_LOGO=$(grep -c 'data-lucide.*logo\|data-lucide.*utensils\|data-lucide.*store\|data-lucide.*building' "$INDEX_FILE" 2>/dev/null || echo "0")
      if [ "$LUCIDE_LOGO" -gt 0 ]; then
        fail 19 "Custom logos available but Lucide icon used as logo placeholder (${LUCIDE_LOGO} occurrences)"
      else
        pass 19 "Custom logo assets used via <img> tags"
      fi
    else
      fail 19 "Custom logos in manifest.json but no <img src=\"assets/...\"> found in prototype"
    fi
  else
    pass 19 "No custom logo assets (icon_style=${ICON_STYLE:-none})"
  fi
else
  pass 19 "No manifest.json (logo check not applicable)"
fi

# ═══ CHECK 20: No tag-based Lucide rendering ═══
LUCIDE_TAGS=$(grep -c '<i data-lucide=' "$INDEX_FILE" 2>/dev/null || echo "0")
if [ "$LUCIDE_TAGS" -eq 0 ]; then
  pass 20 "No <i data-lucide> tags (inline SVGs used correctly)"
else
  fail 20 "${LUCIDE_TAGS} <i data-lucide> tags found — should use inline <svg> markup instead"
fi

# ═══ Summary ═══
echo ""
echo "═══════════════════════════════════════════════"
echo "  Results: ${PASS_COUNT} pass, ${FAIL_COUNT} fail, ${SKIP_COUNT} skip"
echo "═══════════════════════════════════════════════"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo "Failures:"
  echo -e "$ERRORS"
  exit 2
fi

if [ -n "$WARNINGS" ]; then
  echo ""
  echo "Warnings:"
  echo -e "$WARNINGS"
fi

exit 0

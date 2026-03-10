# appState Template

This is the complete Alpine.js appState template for the prototype generator.
SKILL.md Step 3.4 references this file. Read it when generating `prototype/state.js`.

Fill all `{...}` placeholders with values derived from BA files during Step 1-2.

---

## Template

```javascript
function appState() {
  return {
    // ═══════════════════════════════════════════════
    // 1. AUTHENTICATION
    // ═══════════════════════════════════════════════
    // Include if nfr.json security.authentication is present
    isLoggedIn: false,
    loginEmail: '',
    loginPassword: '',
    loginError: '',
    loginLoading: false,

    handleLogin() {
      this.loginLoading = true;
      this.loginError = '';
      setTimeout(() => {
        this.loginLoading = false;
        if (this.loginEmail && this.loginPassword) {
          this.isLoggedIn = true;
          // Smart role detection from email/username for demo purposes
          const u = this.loginEmail.toLowerCase();
          // Map known keywords to roles (derive from roles.json role names)
          // Example: if (u.includes('admin')) this.currentRole = 'admin';
          {login_role_detection_logic}
          this.currentInterface = '{default_interface}';
          this.currentScreen = '{post_login_screen}';
          this.screenHistory = [];
          this.addToast('success', '{login_success_message}');
        } else {
          this.loginError = '{login_error_message}';
        }
      }, 800);
    },

    handleLogout() {
      this.isLoggedIn = false;
      this.loginEmail = '';
      this.loginPassword = '';
      this.currentScreen = '{login_screen_id}';
      this.screenHistory = [];
    },

    // ═══════════════════════════════════════════════
    // 2. NAVIGATION
    // ═══════════════════════════════════════════════
    currentScreen: '{first_screen_id}',
    screenHistory: [],
    sidebarCollapsed: false,
    mobileMenuOpen: false,

    navigateTo(screen) {
      this.screenHistory.push(this.currentScreen);
      this.currentScreen = screen;
      this.mobileMenuOpen = false;
      window.scrollTo(0, 0);
    },

    goBack() {
      if (this.screenHistory.length) {
        this.currentScreen = this.screenHistory.pop();
      }
    },

    // ═══════════════════════════════════════════════
    // 3. MULTI-INTERFACE (only if layout.interfaces exists)
    // ═══════════════════════════════════════════════
    // Omit this entire section for single-interface layouts
    currentInterface: '{first_interface_key}',

    // Map each role to its primary interface
    // Built from layout.interfaces[].target_roles[]
    interfaceMap: {
      // '{role-id}': '{interface-key}',
      {interface_map_entries}
    },

    // Navigate to dashboard hub (common in multi-interface layouts)
    goToHub() {
      this.currentInterface = '{hub_interface_key}';
      this.currentScreen = '{hub_screen_id}';
      this.screenHistory = [];
      this.mobileMenuOpen = false;
      window.scrollTo(0, 0);
    },

    // Enter a specific module/interface
    enterModule(screen, iface) {
      if (iface) this.currentInterface = iface;
      this.screenHistory = ['{hub_screen_id}'];
      this.currentScreen = screen;
      this.mobileMenuOpen = false;
      window.scrollTo(0, 0);
    },

    // ═══════════════════════════════════════════════
    // 4. ROLES
    // ═══════════════════════════════════════════════
    currentRole: '{first_role_id}',

    // Built from roles.json — ordered by hierarchy (least→most privileged)
    roles: [
      // { id: '{role.id}', name: '{role.name}' },
      {roles_array}
    ],

    switchRole(role) {
      this.currentRole = role;
      // Multi-interface: switch interface based on role→interface map
      if (this.interfaceMap && this.interfaceMap[role]) {
        this.currentInterface = this.interfaceMap[role];
      }
      // Navigate to first screen accessible by this role
      const firstScreen = this.getFirstScreenForRole(role);
      if (firstScreen) this.navigateTo(firstScreen);
    },

    getFirstScreenForRole(role) {
      const match = this._navItems.find(item =>
        !item.roles || item.roles.includes(role)
      );
      return match ? match.screen_ref : this.currentScreen;
    },

    // Navigation items from layout.json for role-based screen lookup
    // Each: { screen_ref: 'S-xxx', roles: ['role1'] or null (all roles) }
    _navItems: [
      {nav_items_array}
    ],

    // ═══════════════════════════════════════════════
    // 5. TOAST SYSTEM
    // ═══════════════════════════════════════════════
    toasts: [],
    toastId: 0,

    addToast(type, message) {
      const id = ++this.toastId;
      this.toasts.push({ id, type, message, visible: true });
      setTimeout(() => this.removeToast(id), 4000);
    },

    removeToast(id) {
      const t = this.toasts.find(x => x.id === id);
      if (t) t.visible = false;
      setTimeout(() => {
        this.toasts = this.toasts.filter(x => x.id !== id);
      }, 300);
    },

    // ═══════════════════════════════════════════════
    // 6. MODAL SYSTEM
    // ═══════════════════════════════════════════════
    activeModal: null,
    modalData: {},

    openModal(name, data = {}) {
      this.activeModal = name;
      this.modalData = data;
    },

    closeModal() {
      this.activeModal = null;
      this.modalData = {};
    },

    // ═══════════════════════════════════════════════
    // 7. CONFIRMATION DIALOG
    // ═══════════════════════════════════════════════
    confirmOpen: false,
    confirmMessage: '',
    confirmAction: null,

    confirm(message, action) {
      this.confirmMessage = message;
      this.confirmAction = action;
      this.confirmOpen = true;
    },

    // ═══════════════════════════════════════════════
    // 8. NOTIFICATIONS
    // ═══════════════════════════════════════════════
    notificationCount: 3,
    notificationOpen: false,

    notifications: [
      // Generate 3-5 domain-realistic notifications
      // { id: 1, title: '...', time: '...', read: false },
      {notifications_array}
    ],

    markAllRead() {
      this.notifications.forEach(n => n.read = true);
      this.notificationCount = 0;
    },

    // ═══════════════════════════════════════════════
    // 9. SEARCH (Global)
    // ═══════════════════════════════════════════════
    globalSearch: '',
    globalSearchOpen: false,

    // ═══════════════════════════════════════════════
    // 10. MOCK DATA ARRAYS
    // ═══════════════════════════════════════════════
    // Generate from features.json entities + fields.
    // Each array: 8-12 records with realistic domain data.
    //
    // Naming: use entity names from features (camelCase plural)
    // Example: orders, menuItems, employees, transactions
    //
    // Each record must include:
    //   - id (sequential or realistic format like "ORD-001")
    //   - All fields from features.json for this entity
    //   - status field using values from fields[].options[]
    //   - created_at/date field (spread across recent 30 days)
    //   - At least 1 edge case record (long name, zero value, empty optional)

    {mock_data_arrays}

    // ═══════════════════════════════════════════════
    // 11. FORM STATE
    // ═══════════════════════════════════════════════
    // For each form screen, create state properties for:
    //   - Each form field (x-model binding)
    //   - Form-level error state
    //   - Submission loading state
    //   - Validation error messages per field
    //
    // Naming: {entity}{Field} for fields, {entity}Errors for error map
    // Example: newOrderTable, newOrderNotes, newOrderErrors: {}

    {form_state_properties}

    // Form handlers: validate required fields, show toast, navigate
    {form_handler_methods}

    // ═══════════════════════════════════════════════
    // 12. TABLE/LIST STATE
    // ═══════════════════════════════════════════════
    // For each data table screen, create filter/sort/pagination state:
    //   - {entity}Filter: 'all' (active tab/filter)
    //   - {entity}Search: '' (search query)
    //   - {entity}SortKey: '{default_column}'
    //   - {entity}SortAsc: true
    //   - {entity}Page: 1
    //   - {entity}PerPage: 10
    //
    // Computed getters:
    //   - get filtered{Entity}() — applies filter + search
    //   - get paginated{Entity}() — applies pagination to filtered

    {table_state_properties}

    // ═══════════════════════════════════════════════
    // 13. FORMATTING HELPERS
    // ═══════════════════════════════════════════════
    formatDate(dateStr) {
      return new Date(dateStr).toLocaleDateString('{locale}', {
        year: 'numeric', month: 'short', day: 'numeric'
      });
    },

    formatDateTime(dateStr) {
      return new Date(dateStr).toLocaleString('{locale}', {
        year: 'numeric', month: 'short', day: 'numeric',
        hour: '2-digit', minute: '2-digit'
      });
    },

    formatCurrency(amount) {
      return new Intl.NumberFormat('{locale}', {
        style: 'currency', currency: '{currency}'
      }).format(amount);
    },

    formatNumber(num) {
      return new Intl.NumberFormat('{locale}').format(num);
    },

    formatPercent(value) {
      return new Intl.NumberFormat('{locale}', {
        style: 'percent', minimumFractionDigits: 1
      }).format(value / 100);
    },

    // Time-ago for notifications/activity feeds
    timeAgo(dateStr) {
      const diff = Date.now() - new Date(dateStr).getTime();
      const mins = Math.floor(diff / 60000);
      if (mins < 1) return 'Just now';
      if (mins < 60) return mins + 'm ago';
      const hrs = Math.floor(mins / 60);
      if (hrs < 24) return hrs + 'h ago';
      const days = Math.floor(hrs / 24);
      return days + 'd ago';
    },

    // Initials for avatar components
    getInitials(name) {
      return name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
    },

    // ═══════════════════════════════════════════════
    // 14. CHART DATA
    // ═══════════════════════════════════════════════
    // Define chart datasets as plain objects.
    // chartManager.init() uses these when the screen becomes visible.
    //
    // Use semantic colors from style.json (raw hex, not Tailwind classes):
    //   primary:  '{colors.primary}'
    //   accent:   '{colors.accent}'
    //   success:  '{colors.success}'
    //   warning:  '{colors.warning}'
    //   error:    '{colors.error}'
    //   info:     '{colors.info}'
    //
    // Example:
    // revenueChartData: {
    //   labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    //   datasets: [{
    //     label: 'Revenue',
    //     data: [1200000, 1900000, 800000, 1500000, 2100000, 2800000, 2200000],
    //     borderColor: '{colors.primary}',
    //     backgroundColor: '{colors.primary}20',
    //     tension: 0.4, fill: true
    //   }]
    // },

    {chart_data_objects}

    // ═══════════════════════════════════════════════
    // 15. DOMAIN-SPECIFIC LOGIC
    // ═══════════════════════════════════════════════
    // Business logic derived from features.json business_rules[]:
    //   - Calculation formulas (tax, discount, total)
    //   - Status transition logic
    //   - Conditional field visibility
    //   - Custom validation rules beyond required fields
    //
    // Keep methods small and focused. Name after the business action.
    // Example: calculateOrderTotal(), canApproveRequest(), getStatusColor()

    {domain_specific_methods}
  }
}
```

---

## Placeholder Reference

| Placeholder | Source | Description |
|-------------|--------|-------------|
| `{first_screen_id}` | layout.json `navigation.primary[0].screen_ref` | Initial screen on load |
| `{first_role_id}` | roles.json `hierarchy.chain[0]` or `roles[0].id` | Default active role |
| `{first_interface_key}` | layout.json first key in `interfaces{}` | Default interface (multi-interface only) |
| `{hub_interface_key}` | layout.json interface with `type: "fullscreen-grid"` or first | Hub interface key |
| `{hub_screen_id}` | layout.json hub interface's `screen_ref` | Hub screen ID |
| `{login_screen_id}` | screens.json screen with login purpose | Login screen ID |
| `{post_login_screen}` | Same as `{hub_screen_id}` or `{first_screen_id}` | Screen after login |
| `{locale}` | nfr.json or problem.json locale context | e.g., `'id-ID'`, `'en-US'` |
| `{currency}` | Derived from locale/domain | e.g., `'IDR'`, `'USD'` |
| `{login_success_message}` | Derive from locale | e.g., `'Login berhasil!'` |
| `{login_error_message}` | Derive from locale | e.g., `'Email dan password harus diisi.'` |
| `{roles_array}` | roles.json | Array of `{ id, name }` objects |
| `{interface_map_entries}` | layout.json interfaces[].target_roles[] | Role-to-interface map |
| `{nav_items_array}` | layout.json navigation.primary[] | Array of `{ screen_ref, roles }` |
| `{notifications_array}` | Derived from domain context | 3-5 realistic notifications |
| `{mock_data_arrays}` | features.json entities + fields | Domain data arrays |
| `{form_state_properties}` | screens.json form screens + features.json fields | Form bindings |
| `{form_handler_methods}` | flows.json + features.json | Submit/validate methods |
| `{table_state_properties}` | screens.json list/table screens | Filter/sort/page state |
| `{chart_data_objects}` | Derived from mock data | Chart.js dataset objects |
| `{domain_specific_methods}` | features.json business_rules[] | Domain logic methods |
| `{login_role_detection_logic}` | roles.json role names | If/else for demo login |

---

## Section Checklist

After generating state.js, verify every section is populated:

- [ ] Section 1: Auth present if nfr.json has authentication
- [ ] Section 2: navigateTo, goBack methods present
- [ ] Section 3: Multi-interface section present only if layout.interfaces exists
- [ ] Section 4: All roles from roles.json listed
- [ ] Section 5: Toast system complete (add, remove, auto-dismiss)
- [ ] Section 6: Modal system complete (open, close, data passing)
- [ ] Section 7: Confirmation dialog complete
- [ ] Section 8: Notifications with domain-realistic content
- [ ] Section 10: At least one mock data array per entity
- [ ] Section 11: Form state for every form screen
- [ ] Section 12: Table state for every list/table screen
- [ ] Section 13: All format helpers use correct locale
- [ ] Section 14: Chart data for every dashboard/analytics screen
- [ ] Section 15: Business rule methods from features.json
- [ ] No `{placeholder}` tokens remain
- [ ] Every x-model in screen files references a property defined here

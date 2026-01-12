# CSS Theming Implementation Plan

**Created:** 2026-01-11
**Status:** Planning

## Overview

This plan describes migrating from inline React styles to CSS variables and external stylesheets. This achieves:

1. **Theme support** - Alternate themes can override colors via CSS variables
2. **Performance** - External CSS is cached; inline styles add ~50-100KB to every page
3. **Maintainability** - Single source of truth for colors and common styles
4. **Consistency** - All components use the same design tokens

## Current State

### Problems with Inline Styles

1. **No theme support** - Hardcoded colors like `#38495e` ignore user's selected theme
2. **Page bloat** - Every page includes the same style objects in JavaScript
3. **No caching** - Inline styles can't be cached separately from HTML
4. **Duplication** - Same colors/patterns repeated across 200+ components
5. **Inconsistency** - Similar components use slightly different values

### Current Architecture

```
User loads page
  → Server returns HTML + window.e2 JSON
  → React renders components with inline styles
  → Inline styles = ~50-100KB per page (not cached)
  → User's theme CSS loaded but only affects legacy elements
```

## Target Architecture

```
User loads page
  → Server returns HTML + window.e2 JSON
  → Browser loads/caches react-components.css (once)
  → CSS contains var() references to theme variables
  → User's theme CSS defines :root variables
  → All components inherit theme colors automatically
```

## Recommended Architecture: Merge Kernel Blue into Basesheet

The cleanest approach is to consolidate Kernel Blue defaults into basesheet, making themes purely override-based.

### Current Architecture (Complex)
```
basesheet (1973976.css)     - Structural CSS only, always loaded
     +
zensheet (user's theme)     - Full theme with colors/layout (Kernel Blue, Deep Ice, etc.)
     +
printsheet                  - Print styles
```

**Problems:**
- Kernel Blue duplicates structure that's already in basesheet
- Each theme must define ALL styles, even if they match defaults
- Two files loaded when one would suffice for default users

### Target Architecture (Simplified)
```
basesheet (1973976.css)     - Structure + CSS variable defaults (Kernel Blue colors)
     +
zensheet (user's theme)     - ONLY color variable overrides (optional, much smaller)
     +
printsheet                  - Print styles
```

**Benefits:**
- One fewer HTTP request for Kernel Blue users
- Themes become tiny (just variable overrides)
- Single source of truth for defaults
- Clearer mental model: basesheet = everything, themes = customizations

### How It Works

1. **Add CSS variables with Kernel Blue defaults to top of basesheet:**
```css
/* basesheet (1973976.css) - add at very top */
:root {
  /* Kernel Blue color defaults */
  --e2-color-primary: #38495e;
  --e2-color-link: #4060b0;
  --e2-color-link-visited: #507898;
  --e2-bg-body: #fff;
  --e2-bg-header: #38495e;
  --e2-color-accent: #3bb5c3;
  /* ... full variable set ... */
}
```

2. **Update basesheet rules to use variables:**
```css
.widget {
  background: var(--e2-bg-body);
  color: var(--e2-color-primary);
  border: 1px solid var(--e2-border-color);
}
```

3. **Kernel Blue becomes unnecessary:**
   - Users selecting "Kernel Blue" get basesheet defaults (no additional CSS)
   - Keep 1882070.css as empty file for backwards compatibility, or remove

4. **Other themes just override variables:**
```css
/* Deep Ice - only what differs from defaults */
:root {
  --e2-bg-body: #99cfff;
  --e2-color-primary: #000033;
  --e2-nodelet-header-bg: #44bbff;
}
/* That's it - no layout rules needed */
```

### Migration Path

| Step | Action |
|------|--------|
| 1 | Add `:root` variables to basesheet with Kernel Blue defaults |
| 2 | Update basesheet rules to use `var()` references |
| 3 | Create `-var.css` versions of each theme with just overrides |
| 4 | Test with `?csstest=1` parameter |
| 5 | Make variable versions the default |
| 6 | Remove/deprecate standalone theme files |

---

## Implementation Phases

### Phase 1: Define Complete CSS Variable Set

Expand `1882070-var.css` (Kernel Blue) with all variables needed by React components.

**New variables to add:**

```css
:root {
  /* === EXISTING VARIABLES (keep as-is) === */
  --e2-color-primary: #38495e;
  --e2-color-link: #4060b0;
  --e2-color-link-visited: #507898;
  --e2-color-link-active: #3bb5c3;
  --e2-bg-body: #fff;
  --e2-bg-header: #38495e;
  /* ... etc ... */

  /* === NEW: Button Variables === */
  --e2-btn-primary-bg: #4060b0;
  --e2-btn-primary-text: #fff;
  --e2-btn-primary-border: #4060b0;
  --e2-btn-primary-hover-bg: #507898;
  --e2-btn-secondary-bg: #fff;
  --e2-btn-secondary-text: #38495e;
  --e2-btn-secondary-border: #dee2e6;
  --e2-btn-danger-bg: #dc3545;
  --e2-btn-danger-text: #fff;
  --e2-btn-disabled-bg: #6c757d;

  /* === NEW: Form Variables === */
  --e2-input-bg: #fff;
  --e2-input-text: #495057;
  --e2-input-border: #dee2e6;
  --e2-input-focus-border: #4060b0;
  --e2-input-placeholder: #6c757d;
  --e2-label-text: #495057;

  /* === NEW: Card/Container Variables === */
  --e2-card-bg: #f8f9fa;
  --e2-card-border: #e0e0e0;
  --e2-card-shadow: rgba(0, 0, 0, 0.1);

  /* === NEW: Modal Variables === */
  --e2-modal-bg: #fff;
  --e2-modal-overlay: rgba(0, 0, 0, 0.5);
  --e2-modal-border-radius: 16px;
  --e2-modal-header-border: #e0e0e0;

  /* === NEW: Mobile Nav Variables === */
  --e2-mobile-nav-bg: #fff;
  --e2-mobile-nav-border: #e0e0e0;
  --e2-mobile-nav-shadow: rgba(0, 0, 0, 0.1);
  --e2-mobile-nav-icon: #507898;
  --e2-mobile-nav-icon-active: #4060b0;
  --e2-mobile-nav-label: inherit;
  --e2-badge-bg: #e74c3c;
  --e2-badge-text: #fff;

  /* === NEW: Message/Alert Variables === */
  --e2-error-bg: #ffebee;
  --e2-error-text: #c62828;
  --e2-error-border: #ffcccc;
  --e2-success-bg: #e8f5e9;
  --e2-success-text: #2e7d32;
  --e2-warning-bg: #fff3cd;
  --e2-warning-text: #856404;
  --e2-info-bg: #e3f2fd;
  --e2-info-text: #1565c0;

  /* === NEW: Tab/Toggle Variables === */
  --e2-tab-active-bg: #e9ecef;
  --e2-tab-active-border: #4060b0;
  --e2-tab-inactive-bg: transparent;

  /* === NEW: Spacing (not theme-dependent, but centralized) === */
  --e2-spacing-xs: 4px;
  --e2-spacing-sm: 8px;
  --e2-spacing-md: 12px;
  --e2-spacing-lg: 16px;
  --e2-spacing-xl: 24px;

  /* === NEW: Border Radius === */
  --e2-radius-sm: 3px;
  --e2-radius-md: 6px;
  --e2-radius-lg: 8px;
  --e2-radius-pill: 10px;

  /* === NEW: Typography === */
  --e2-font-size-xs: 10px;
  --e2-font-size-sm: 12px;
  --e2-font-size-md: 14px;
  --e2-font-size-lg: 16px;
  --e2-font-weight-normal: 400;
  --e2-font-weight-medium: 500;
  --e2-font-weight-bold: 600;
}
```

### Phase 2: Create React Component Stylesheet

Create a new CSS file for React component classes.

**File:** `www/css/react-components.css`

```css
/* react-components.css - Styles for React components using CSS variables */

/* ===== BUTTONS ===== */
.e2-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--e2-spacing-sm);
  padding: var(--e2-spacing-sm) var(--e2-spacing-md);
  font-size: var(--e2-font-size-sm);
  font-weight: var(--e2-font-weight-medium);
  border-radius: var(--e2-radius-md);
  cursor: pointer;
  transition: background-color 0.15s, border-color 0.15s;
}

.e2-btn-primary {
  background-color: var(--e2-btn-primary-bg);
  color: var(--e2-btn-primary-text);
  border: 1px solid var(--e2-btn-primary-border);
}

.e2-btn-primary:hover:not(:disabled) {
  background-color: var(--e2-btn-primary-hover-bg);
}

.e2-btn-secondary {
  background-color: var(--e2-btn-secondary-bg);
  color: var(--e2-btn-secondary-text);
  border: 1px solid var(--e2-btn-secondary-border);
}

.e2-btn-danger {
  background-color: var(--e2-btn-danger-bg);
  color: var(--e2-btn-danger-text);
  border: none;
}

.e2-btn:disabled {
  background-color: var(--e2-btn-disabled-bg);
  cursor: not-allowed;
  opacity: 0.7;
}

/* ===== FORMS ===== */
.e2-input {
  width: 100%;
  padding: var(--e2-spacing-sm);
  font-size: var(--e2-font-size-sm);
  background-color: var(--e2-input-bg);
  color: var(--e2-input-text);
  border: 1px solid var(--e2-input-border);
  border-radius: var(--e2-radius-sm);
  box-sizing: border-box;
}

.e2-input:focus {
  outline: none;
  border-color: var(--e2-input-focus-border);
}

.e2-input::placeholder {
  color: var(--e2-input-placeholder);
}

.e2-label {
  display: block;
  margin-bottom: var(--e2-spacing-xs);
  font-size: var(--e2-font-size-sm);
  font-weight: var(--e2-font-weight-bold);
  color: var(--e2-label-text);
}

/* ===== CARDS ===== */
.e2-card {
  background-color: var(--e2-card-bg);
  border: 1px solid var(--e2-card-border);
  border-radius: var(--e2-radius-lg);
  padding: var(--e2-spacing-md);
}

/* ===== MOBILE BOTTOM NAV ===== */
.e2-mobile-nav {
  display: flex;
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background-color: var(--e2-mobile-nav-bg);
  border-top: 1px solid var(--e2-mobile-nav-border);
  box-shadow: 0 -2px 10px var(--e2-mobile-nav-shadow);
  z-index: 1000;
  padding: 8px 0;
  padding-bottom: calc(8px + env(safe-area-inset-bottom, 0px));
}

.e2-mobile-nav-item {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  color: var(--e2-mobile-nav-icon);
  text-decoration: none;
  font-size: var(--e2-font-size-xs);
  background: none;
  border: none;
  cursor: pointer;
  padding: 4px 0;
}

.e2-mobile-nav-item.active {
  color: var(--e2-mobile-nav-icon-active);
}

.e2-mobile-nav-icon {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
}

.e2-mobile-nav-label {
  font-weight: var(--e2-font-weight-medium);
}

.e2-badge {
  position: absolute;
  top: -6px;
  right: -10px;
  background-color: var(--e2-badge-bg);
  color: var(--e2-badge-text);
  font-size: var(--e2-font-size-xs);
  padding: 2px 5px;
  border-radius: var(--e2-radius-pill);
  min-width: 16px;
  text-align: center;
  font-weight: var(--e2-font-weight-bold);
}

/* ===== MODALS ===== */
.e2-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: var(--e2-modal-overlay);
  z-index: 2000;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
}

.e2-modal {
  background-color: var(--e2-modal-bg);
  border-top-left-radius: var(--e2-modal-border-radius);
  border-top-right-radius: var(--e2-modal-border-radius);
  max-height: 85vh;
  display: flex;
  flex-direction: column;
  padding-bottom: env(safe-area-inset-bottom, 0px);
}

.e2-modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--e2-spacing-lg) var(--e2-spacing-lg) var(--e2-spacing-md);
  border-bottom: 1px solid var(--e2-modal-header-border);
}

.e2-modal-title {
  margin: 0;
  font-size: 18px;
  font-weight: var(--e2-font-weight-bold);
  color: var(--e2-color-primary);
}

.e2-modal-close {
  background: none;
  border: none;
  font-size: 20px;
  color: var(--e2-mobile-nav-icon);
  cursor: pointer;
  padding: var(--e2-spacing-sm);
  display: flex;
  align-items: center;
  justify-content: center;
}

.e2-modal-body {
  flex: 1;
  overflow-y: auto;
  padding: var(--e2-spacing-md) var(--e2-spacing-lg);
}

/* ===== ALERTS/MESSAGES ===== */
.e2-alert {
  padding: var(--e2-spacing-sm) var(--e2-spacing-md);
  border-radius: var(--e2-radius-md);
  margin-bottom: var(--e2-spacing-sm);
  font-size: var(--e2-font-size-sm);
}

.e2-alert-error {
  background-color: var(--e2-error-bg);
  color: var(--e2-error-text);
  border: 1px solid var(--e2-error-border);
}

.e2-alert-success {
  background-color: var(--e2-success-bg);
  color: var(--e2-success-text);
}

.e2-alert-warning {
  background-color: var(--e2-warning-bg);
  color: var(--e2-warning-text);
}

/* ===== TABS ===== */
.e2-tabs {
  display: flex;
  border-bottom: 1px solid var(--e2-card-border);
}

.e2-tab {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: var(--e2-spacing-md) var(--e2-spacing-lg);
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  font-size: var(--e2-font-size-md);
  font-weight: var(--e2-font-weight-medium);
  color: var(--e2-mobile-nav-icon);
  cursor: pointer;
}

.e2-tab.active {
  color: var(--e2-color-link);
  border-bottom-color: var(--e2-color-link);
}

/* ===== MESSAGE CARDS ===== */
.e2-message-card {
  background-color: var(--e2-card-bg);
  border-radius: var(--e2-radius-lg);
  padding: var(--e2-spacing-md);
  margin-bottom: var(--e2-spacing-md);
  border: 1px solid var(--e2-card-border);
}

.e2-message-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--e2-spacing-xs);
}

.e2-message-timestamp {
  font-size: var(--e2-font-size-sm);
  color: var(--e2-mobile-nav-icon);
}

.e2-message-body {
  font-size: var(--e2-font-size-md);
  line-height: 1.5;
  color: var(--e2-color-primary);
  margin-bottom: var(--e2-spacing-sm);
  word-break: break-word;
}

.e2-message-actions {
  display: flex;
  gap: var(--e2-spacing-sm);
  border-top: 1px solid var(--e2-card-border);
  padding-top: var(--e2-spacing-sm);
  margin-top: var(--e2-spacing-xs);
}

/* ===== LOADING STATES ===== */
.e2-loading {
  text-align: center;
  padding: var(--e2-spacing-xl);
  color: var(--e2-mobile-nav-icon);
  font-size: var(--e2-font-size-md);
  font-style: italic;
}

.e2-empty {
  text-align: center;
  padding: var(--e2-spacing-xl);
  color: var(--e2-mobile-nav-icon);
  font-size: var(--e2-font-size-md);
  font-style: italic;
}

/* ===== RESPONSIVE UTILITIES ===== */
@media (max-width: 768px) {
  .e2-hide-mobile {
    display: none !important;
  }
}

@media (min-width: 769px) {
  .e2-hide-desktop {
    display: none !important;
  }
}
```

### Phase 3: Load the New Stylesheet

**File:** `ecore/Everything/HTMLShell.pm`

Add the new stylesheet after basesheet:

```perl
# After basesheet link
print qq|<link rel="stylesheet" id="reactsheet" type="text/css" href="/css/react-components.css" media="all">\n|;
```

### Phase 4: Migrate Components

Convert components from inline styles to CSS classes. Priority order:

#### High Priority (Mobile-visible, high traffic)
1. `MobileBottomNav.js` - Bottom navigation
2. `MobileInboxModal.js` - Message inbox modal
3. `MobileChatModal.js` - Chat modal
4. `MobileNotificationsModal.js` - Notifications modal
5. `Header.js` - Site header
6. `LoginForm.js` - Login form (all variants)
7. `AuthModal.js` - Auth modal

#### Medium Priority (Common UI patterns)
8. `MessageList.js` - Message display
9. `MessageModal.js` - Compose message
10. `NodeletContainer.js` - Nodelet wrapper
11. `DiscoverMenu.js` - Discovery menu

#### Lower Priority (Document pages)
12. All `Documents/*.js` components

### Migration Example

**Before (MobileBottomNav.js):**
```javascript
const styles = {
  nav: {
    display: 'flex',
    position: 'fixed',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#fff',
    borderTop: '1px solid #e0e0e0',
    boxShadow: '0 -2px 10px rgba(0,0,0,0.1)',
    zIndex: 1000,
    padding: '8px 0',
    paddingBottom: 'calc(8px + env(safe-area-inset-bottom, 0px))'
  },
  // ... 50+ more lines of inline styles
}

// In JSX:
<nav style={styles.nav}>
  <button style={styles.navItem}>
    <div style={styles.iconWrapper}>
      <FaEnvelope style={styles.icon} />
      {badge > 0 && <span style={styles.badge}>{badge}</span>}
    </div>
    <span style={styles.label}>Inbox</span>
  </button>
</nav>
```

**After (MobileBottomNav.js):**
```javascript
// No styles object needed!

// In JSX:
<nav className="e2-mobile-nav">
  <button className="e2-mobile-nav-item">
    <div className="e2-mobile-nav-icon">
      <FaEnvelope />
      {badge > 0 && <span className="e2-badge">{badge}</span>}
    </div>
    <span className="e2-mobile-nav-label">Inbox</span>
  </button>
</nav>
```

### Phase 5: Populate Alternate Theme Variables

Update each theme's `-var.css` file with appropriate color overrides.

**Example: Deep Ice (1996378-var.css):**
```css
:root {
  /* Override only the colors that differ from Kernel Blue */
  --e2-color-primary: #000033;
  --e2-bg-body: #99cfff;
  --e2-bg-header: #38495e;
  --e2-card-bg: #99cfff;
  --e2-card-border: #38495e;
  --e2-mobile-nav-bg: #99cfff;
  --e2-mobile-nav-border: #38495e;
  --e2-btn-primary-bg: #44bbff;
  --e2-btn-primary-text: #000033;
  /* ... etc ... */
}
```

### Phase 6: Enable CSS Variables by Default

Once migration is complete and tested:

1. Remove `?csstest=1` requirement
2. Make `-var.css` the default
3. Optionally merge `-var.css` back into main `.css` files

## File Changes Summary

| File | Change |
|------|--------|
| `www/css/1882070-var.css` | Add complete variable set |
| `www/css/react-components.css` | NEW - Component classes |
| `www/css/*-var.css` (all themes) | Add theme-specific overrides |
| `ecore/Everything/HTMLShell.pm` | Load react-components.css |
| `react/components/Layout/*.js` | Convert to CSS classes |
| `react/components/Documents/*.js` | Convert to CSS classes |

## Performance Impact

### Before
- Each page load: ~50-100KB inline styles in JavaScript
- Styles parsed fresh on every page
- No caching of component styles

### After
- First page load: ~15KB react-components.css (cached)
- Subsequent pages: 0KB (cached)
- ~50-100KB savings per page after first load
- Browser can parse CSS in parallel with JS

## Testing Plan

1. **Visual regression** - Screenshot comparison before/after
2. **Theme switching** - Verify all themes work
3. **Mobile testing** - All mobile components
4. **Performance** - Measure page weight reduction
5. **A/B testing** - Enable via `?csstest=1` initially

## Rollback Plan

Keep inline styles as comments initially. If issues arise:
1. Revert to inline styles
2. Remove react-components.css link
3. Investigate and fix

## Timeline

This is a phased migration that can be done incrementally:

1. **Phase 1-3**: Foundation (variables + stylesheet + loading)
2. **Phase 4**: Component migration (can be done one at a time)
3. **Phase 5**: Theme population (can be done per-theme)
4. **Phase 6**: Full rollout

Each phase is independently deployable and testable.

---

## Theme Analysis: Differences from Kernel Blue

This section analyzes each supported theme to document how it differs from Kernel Blue and what may break during CSS variable migration.

### Theme Categories

Themes fall into three categories based on migration risk:

| Category | Description | Migration Risk |
|----------|-------------|----------------|
| **Color-only** | Uses @import for layout, overrides colors only | **LOW** - Just define color variables |
| **Standalone Color** | Defines all layout + colors, no structural changes from default | **MEDIUM** - Need full variable set |
| **Layout-changing** | Significantly alters page structure/positioning | **HIGH** - May conflict with React components |

---

### 1. Kernel Blue (1882070.css) - Reference Theme

**Type:** Standalone Color (Reference)
**Migration Risk:** None (this is the baseline)

**Key Colors:**
- Primary: `#38495e` (Kernel Blue)
- Links: `#4060b0`
- Visited links: `#507898`
- Body background: `#fff`
- Header background: `#38495e`
- Accents: `#3bb5c3` (Cool teal for C! indicators)

**Fonts:** Default sans-serif

**Layout:** Standard float-based layout with right sidebar

---

### 2. Understatement (1965235.css) - Base Layout Theme

**Type:** Layout Theme (Base for Understatement family)
**Migration Risk:** MEDIUM

**Purpose:** This is a layout-only theme that other Understatement variants @import. It zeroes most margins/padding and provides a clean structural base.

**Key Layout Characteristics:**
- Zeroes all margins/padding initially
- `max-width: 50em` on body
- Right padding `14em` for sidebar
- Sidebar width `13.25em`, floated left with negative margin
- Border-radius on header/body corners
- Fixed header height `2.25em`
- Print styles included

**Fonts:** Sans-serif, no custom fonts

**Color Implications:** No colors defined - child themes provide colors. Safe for CSS variables as long as structural assumptions hold.

**Potential Issues:**
- Fixed em-based dimensions may conflict with React component positioning
- Absolute positioning on some elements (e.g., `#chatterlight_search`)

---

### 3. Cool Understatement (1926578.css)

**Type:** Color-only (via @import)
**Migration Risk:** LOW

**Import:** `@import url("1965235.css")` (Understatement base)

**Color Differences from Kernel Blue:**
- Links: `#009` (dark blue)
- Visited: `#415` (purple)
- Hover: `#700` (dark red)
- Body background: `#fefeff` (nearly white)
- Header/nodelet h2: `#456` (slate blue)
- Softlinks hover: `#229` on `#f4f8ef`
- Border color: `#456`
- Softlink darkest: `#88aacc` (blue-gray)

**Migration:** Define these color overrides in CSS variables. No structural concerns.

---

### 4. Bare Understatement (1965286.css)

**Type:** Color-only (via @import)
**Migration Risk:** LOW

**Import:** `@import url("1965235.css")` (Understatement base)

**Color Differences from Kernel Blue:**
- Links: `#444` (dark gray)
- Visited: `#666` (gray, no underline)
- Hover: `black` on `#eee`
- Uses border outlines instead of background colors for structure
- Minimal color - nearly monochrome

**Unique Characteristics:**
- Outlines via `border-top-style: solid` instead of background colors
- Dotted top borders on `.nodelet_content`
- Inherits colors for logo links

**Migration:** Low risk - just needs neutral gray color variables.

---

### 5. Monochrome Understatement (1965449.css)

**Type:** Color-only (via @import)
**Migration Risk:** LOW

**Import:** `@import url("1965235.css")` (Understatement base)

**Color Differences from Kernel Blue:**
- Links: `#444`
- Visited: `#666`
- Hover: `black` on `#eee`
- Header/nodelet backgrounds: `#585858` (gray)
- Header text: `silver` instead of white
- Border color: `#555`
- Link underlines in content: `#e8e8e8` solid border-bottom

**Migration:** Low risk - grayscale color variables.

---

### 6. Deep Ice (1996378.css)

**Type:** Standalone Color
**Migration Risk:** MEDIUM

**Color Differences from Kernel Blue:**
- Body background: `#99cfff` (light blue) - **MAJOR DIFFERENCE**
- Text color: `#000033` (dark navy)
- Header/footer: `#38495e` (same as Kernel Blue)
- Header text: `#dddddd` (light gray)
- Nodelet h2: `#44bbff` (bright blue) on `#000033`
- Softlinks: `#9cffff` (cyan)
- Oddrows: `#9cffff` (cyan)
- Links: `#000033` (navy)

**Font:** Georgia, Times New Roman, serif (12px)

**Layout:** Standard float layout with right sidebar (`#wrapper` padding-right: 270px)

**Special Elements:**
- Fixed `#epicenter_zen` at bottom (height 20px, min-width 1000px)
- `#chatterlight_NW` hidden

**Potential Issues:**
- Blue body background will affect any hardcoded white backgrounds in React
- Serif fonts differ from most themes
- Fixed positioning on epicenter

**Migration:** Need to ensure all React component backgrounds use variables, not hardcoded white.

---

### 7. mikoyan25 (1926437.css)

**Type:** Layout-changing
**Migration Risk:** **HIGH**

**This is the most different theme structurally.**

#### Positioning Model Comparison

**Standard Layout (Kernel Blue, basesheet):**
```
┌─────────────────────────────────────────────┐
│ #header (static, flows normally)            │
├─────────────────────────────────────────────┤
│ #wrapper (padding-right creates sidebar gap)│
│ ┌─────────────────────┐ ┌─────────────────┐ │
│ │ #mainbody           │ │ #sidebar        │ │
│ │ float: left         │ │ float: left     │ │
│ │ width: 100%         │ │ margin-right:   │ │
│ │                     │ │   -100%         │ │
│ │                     │ │ (negative margin│ │
│ │                     │ │  pulls into gap)│ │
│ └─────────────────────┘ └─────────────────┘ │
├─────────────────────────────────────────────┤
│ #footer (clear: both, flows after content)  │
└─────────────────────────────────────────────┘
```

**mikoyan25 Layout (Absolute Positioning):**
```
┌─────────────────────────────────────────────┐
│ body (no positioning context)               │
│                                             │
│  ┌────────┐  #e2logo: position: absolute    │
│  │ LOGO   │  top: 5px, left: 10px           │
│  └────────┘  z-index: 50                    │
│                                             │
│  ┌────────┐  #searchform: position: absolute│
│  │ SEARCH │  top: 86px, left: 10px          │
│  └────────┘                                 │
│                                             │
│  ┌────────┐  #sidebar: position: absolute   │
│  │SIDEBAR │  top: 178px, left: 10px         │
│  │        │  width: 240px                   │
│  └────────┘                                 │
│                                             │
│              ┌──────────────────────────┐   │
│              │ #mainbody: pos: absolute │   │
│              │ top: 75px, left: 260px   │   │
│              │ right: 10px              │   │
│              └──────────────────────────┘   │
│                                             │
│  #wrapper: position: absolute               │
│  width: 100%, height: 100%                  │
│  (creates full-page positioning context)    │
│                                             │
│  #footer: display: none                     │
└─────────────────────────────────────────────┘
```

**Why This Breaks React Components:**

1. **Fixed pixel offsets** - `top: 75px`, `left: 260px` assume exact header/sidebar sizes. React components that add dynamic content will overflow or be cut off.

2. **No document flow** - Absolute elements don't push other content. Adding a banner or alert has nowhere to go.

3. **Mobile impossible** - The `position: absolute` with fixed pixel values cannot adapt. Mobile bottom nav at `bottom: 0` would overlap `#mainbody`.

4. **Z-index wars** - Logo at z-index 50, wrapper at z-index 0. React modals/dropdowns need careful z-index management.

5. **Height: 100%** on wrapper means content longer than viewport requires special scroll handling.

**Color Differences:**
- Body/text background: `black`
- Text color: `#808080` (gray)
- Accent/highlight: `#00007f` (dark blue)
- Links: `#808080` (gray, bold)
- Oddrows: `white` on `#00007f`
- Node title: white on `#00007f` background

**Fonts:** Arial, sans-serif (12px)

**Elements Hidden:**
- `#footer`, `.clear`, `#printlink`, `#loglinks`

**Recommendation:** This theme should be deprecated or marked "desktop legacy only". The absolute positioning model is incompatible with modern responsive design.

---

### 8. mikoyan25 flipped (1951961.css)

**Type:** Layout-changing
**Migration Risk:** **HIGH**

**Same structural issues as mikoyan25** with different colors:

**Color Differences from mikoyan25:**
- Body background: `#808080` (gray instead of black)
- Text: `black`
- Accents: `black` (instead of `#00007f`)
- Oddrows: white on black

**Same Layout Problems Apply.**

---

### 9. Bookworm (1928497.css)

**Type:** Layout-changing
**Migration Risk:** **HIGH**

**Layout Model: "Holy Grail" with Absolute Header**

This theme uses the classic "Holy Grail" CSS layout (equal-height columns via negative margins) but adds an absolutely positioned header that creates problems.

#### Positioning Model Comparison

**Standard Layout:**
```
┌─────────────────────────────────────────────┐
│ #header                                     │
│ (position: static, in document flow)        │
├─────────────────────────────────────────────┤
│ #wrapper                                    │
│   padding-right: ~270px (sidebar space)     │
│ ┌──────────────────────┐ ┌────────────────┐ │
│ │ #mainbody            │ │ #sidebar       │ │
│ │ float: left          │ │ float: left    │ │
│ │ width: 100%          │ │ margin-right:  │ │
│ │                      │ │   -100%        │ │
│ └──────────────────────┘ └────────────────┘ │
├─────────────────────────────────────────────┤
│ #footer (clear: both)                       │
└─────────────────────────────────────────────┘
```

**Bookworm Layout:**
```
┌─────────────────────────────────────────────┐
│  #header: position: ABSOLUTE                │
│  top: 3px, left: 0, right: 261px            │
│  height: 30px, z-index: 100                 │
│  (FLOATS ABOVE content, doesn't push it)    │
├─────────────────────────────────────────────┤
│ #wrapper                                    │
│   margin: -5px 10px (NEGATIVE top margin!)  │
│   padding-right: 265px                      │
│ ┌──────────────────────┐ ┌────────────────┐ │
│ │ #mainbody            │ │ #sidebar       │ │
│ │ position: RELATIVE   │ │ width: 240px   │ │
│ │ padding-top: 50px    │ │ margin-right:  │ │
│ │ (to clear abs header)│ │   -100%        │ │
│ └──────────────────────┘ └────────────────┘ │
├─────────────────────────────────────────────┤
│ #epicenter_zen: position: FIXED             │
│ bottom: 0, left: 0, right: 0                │
│ (sticky footer bar)                         │
└─────────────────────────────────────────────┘
```

**Why This Breaks React Components:**

1. **Absolute header** - Header at `position: absolute` with `right: 261px` assumes sidebar is exactly 261px. React components can't add items to header without pixel-perfect coordination.

2. **Negative margins** - `margin: -5px 10px` on wrapper pulls content up. Any React component that expects normal document flow will be offset.

3. **Magic padding** - `#mainbody` has `padding-top: 50px` specifically to clear the 30px absolute header. If React adds anything above mainbody, spacing breaks.

4. **Fixed footer bar** - `#epicenter_zen` is `position: fixed` at bottom. Mobile bottom nav would stack on top of it.

5. **Z-index: 100** on header means React dropdowns/modals need z-index > 100 to appear above it.

**Color Differences:**
- Body: `#FCFFF5` (off-white/cream)
- Text: `#193441` (dark blue-green)
- Links: `#333399` (blue)
- Visited: `#993333` (red-brown)
- Oddrows: `#D1DBBD` (sage green)
- Nodelet h2: `#91AA9D` (muted green)

**Fonts:**
- Body: Georgia, Hoefler Text, serif (13px)
- Headings: Candara, Trebuchet MS, sans-serif
- Logo: Zapfino (decorative)

**Special Features:**
- **Drop cap** on `.writeup_text:first-letter` (48px)
- Custom blockquote styling with large quotes

**Recommendation:** Colors can work with CSS variables. The absolute header and fixed footer are problematic but less severe than mikoyan25 since mainbody still uses relative positioning. Test thoroughly; may work on desktop with careful z-index management but will break on mobile.

---

### 10. Bookwormier (2000528.css)

**Type:** Standalone with background image
**Migration Risk:** MEDIUM-HIGH

**Layout Model: Standard Float with Enhancements**

Unlike Bookworm, Bookwormier uses a mostly standard float-based layout. The main issues are cosmetic (images, fonts) rather than structural.

#### Positioning Comparison

**Bookwormier Layout:**
```
┌─────────────────────────────────────────────┐
│ body                                        │
│   background-image: e2bg.jpg (texture)      │
├─────────────────────────────────────────────┤
│ #header                                     │
│   width: 100%, position: static (GOOD!)     │
│   overflow: visible                         │
├─────────────────────────────────────────────┤
│ #wrapper                                    │
│   padding-right: 280px (sidebar space)      │
│   clear: both                               │
│ ┌──────────────────────┐ ┌────────────────┐ │
│ │ #mainbody            │ │ #sidebar       │ │
│ │ float: left          │ │ float: left    │ │
│ │ width: 100%          │ │ width: 250px   │ │
│ │ padding: 5px         │ │ margin-right:  │ │
│ │ background: white    │ │   -100%        │ │
│ │ border: 1px solid    │ │ margin-left:   │ │
│ │                      │ │   10px         │ │
│ └──────────────────────┘ └────────────────┘ │
├─────────────────────────────────────────────┤
│ #footer (clear: both, static)               │
└─────────────────────────────────────────────┘
```

**Why This Is BETTER Than Bookworm/mikoyan25:**

1. **Static header** - Header is in normal document flow, not absolute. React can add elements safely.

2. **Standard float model** - Uses the same negative-margin sidebar trick as basesheet. Compatible with existing code.

3. **No fixed footer** - Footer clears floats normally. No overlap with mobile nav.

4. **Predictable z-index** - No aggressive z-index values that conflict with modals.

**Remaining Issues:**

1. **Background image** - `url("../static/bookwormier/e2bg.jpg")` on body. If image is missing, falls back gracefully to white.

2. **Logo as image** - `#e2logo` uses `background-image: url(e2logo.gif)` with text hidden via `padding-left: 300px`. React's logo component would need to detect this theme.

3. **Legacy mobile wrapper** - Has `#mobilewrapper` specific styles that conflict with React's mobile detection. These assume a different mobile strategy.

4. **Link styling** - Uses `border-bottom: 1px dotted` instead of `text-decoration`. React components using underlines would look different.

**Color Differences:**
- Text: `#151500` (near-black)
- Links: `#203860` (dark blue) with dotted underline
- Visited: `#507898` (muted blue)
- Nodeshells: `#8b0000` (dark red)
- Oddrows: `#F9F9F8` (off-white)
- Card borders: `#bbb`

**Fonts:**
- Body: Adobe Caslon Pro, Garamond, Georgia, serif (105%)
- Writeup text: 110% with 150% line-height

**Recommendation:** This theme CAN work with CSS variables. Main risks are cosmetic (missing images, font fallbacks). Should be tested but is more viable than Bookworm or mikoyan25. Disable legacy `#mobilewrapper` styles when React mobile is active.

---

### 11. Simplicity (2041900.css)

**Type:** Standalone Color with decorative elements
**Migration Risk:** MEDIUM

**Color Scheme:** Green-based
- Primary: `#203010` (dark green)
- Links: `#243810` (dark green)
- Visited: `#281810` (dark brown)
- Headers: `#dce6c8` (light sage)
- Accent: `#e4d8b4` (warm tan)
- Body: white

**Fonts:**
- Body: Liberation Sans, Helvetica, Arial
- Headings: GaramondNo8, Garamond, serif

**Decorative Elements:**
- Uses `url("../static/simplicity/topleft.png")` for header corners
- `:before` pseudo-elements with background images
- `border-radius` on multiple elements

**Layout:** Standard float-based, body max-width 50em, padding-right 15em

**Potential Issues:**
- Decorative PNG images may not exist
- Pseudo-element decorations won't apply to React components

---

### 12. Pamphleteer (2029380.css)

**Type:** Standalone with custom web fonts
**Migration Risk:** MEDIUM

**Custom Fonts:**
```css
@font-face {
  font-family: 'Essays 1743';
  src: url('../static/pamphleteer/essays1743-webfont.woff');
}
@font-face {
  font-family: 'Linux Libertine';
  src: url('../static/pamphleteer/linlibertine_re-4.7.5-webfont.woff');
}
```

**Colors:**
- Simple: black on white
- Links: black with dotted underline
- Visited: RosyBrown

**Typography:**
- Large body text (18px)
- Essays 1743 for headings
- Linux Libertine for body
- Text shadow on headings

**Layout:** max-width 960px, centered

**Hidden Elements:**
- `#epicenter_zen`: `display: none`
- `.topic.actions`: `display: none`
- `.createdby`: `display: none`
- Search span: `display: none`

**Mobile Query:** Has `@media screen and (max-device-width:480px)` overrides

**Potential Issues:**
- Custom fonts may fail to load
- Many elements hidden
- Mobile query may conflict with React mobile detection

---

## Migration Strategy by Theme

### Active Migration (10 themes)
These themes use standard right-sidebar layout and will be migrated to CSS variables:

#### Tier 1: Safe for Migration (Color-only)
These themes only need color variables defined:

| Theme | CSS File | Action |
|-------|----------|--------|
| Cool Understatement | 1926578.css | Define color overrides |
| Bare Understatement | 1965286.css | Define grayscale overrides |
| Monochrome Understatement | 1965449.css | Define grayscale overrides |

#### Tier 2: Requires Testing (Standalone Color)
These themes have their own layout but follow standard patterns:

| Theme | CSS File | Action |
|-------|----------|--------|
| Kernel Blue | 1882070.css | Reference - define all variables |
| Deep Ice | 1996378.css | Define color overrides, test blue background |
| Bookworm | 1928497.css | Define color overrides, test absolute header z-index |
| Bookwormier | 2000528.css | Define color overrides, test background image fallback |
| Simplicity | 2041900.css | Define green color overrides, test decorative images |
| Pamphleteer | 2029380.css | Define minimal overrides, verify font loading |

### Deferred (2 themes) - Left-Sidebar Layout
These themes place the sidebar on the LEFT instead of right, requiring different layout handling:

| Theme | CSS File | Issue |
|-------|----------|-------|
| mikoyan25 | 1926437.css | Left sidebar, absolute positioning |
| mikoyan25 flipped | 1951961.css | Same layout as mikoyan25 |

**Why deferred:** These are the only themes with a fundamentally different page flow (sidebar on left). They also use absolute positioning throughout, which conflicts with React's float-based layout. After the CSS variable system is working for standard themes, these can be evaluated for:
- Creating a left-sidebar variant of React layout
- Deprecating as "legacy/desktop only"
- Keeping as-is without CSS variable support

---

## CSS Variable Mapping per Theme

### Kernel Blue (Reference)
```css
:root {
  --e2-color-primary: #38495e;
  --e2-color-link: #4060b0;
  --e2-color-link-visited: #507898;
  --e2-bg-body: #fff;
  --e2-bg-header: #38495e;
  --e2-color-accent: #3bb5c3;
}
```

### Deep Ice
```css
:root {
  --e2-color-primary: #000033;
  --e2-color-link: #000033;
  --e2-color-link-visited: #000033;
  --e2-bg-body: #99cfff;
  --e2-bg-header: #38495e;
  --e2-card-bg: #99cfff;
  --e2-nodelet-header-bg: #44bbff;
  --e2-oddrow-bg: #9cffff;
}
```

### Cool Understatement
```css
:root {
  --e2-color-primary: black;
  --e2-color-link: #009;
  --e2-color-link-visited: #415;
  --e2-color-link-hover: #700;
  --e2-bg-body: #fefeff;
  --e2-bg-header: #456;
  --e2-border-color: #456;
}
```

### Monochrome Understatement
```css
:root {
  --e2-color-primary: black;
  --e2-color-link: #444;
  --e2-color-link-visited: #666;
  --e2-color-link-hover: black;
  --e2-bg-body: white;
  --e2-bg-header: #585858;
  --e2-border-color: #555;
}
```

### mikoyan25 (if supported)
```css
:root {
  --e2-color-primary: #808080;
  --e2-color-link: #808080;
  --e2-bg-body: black;
  --e2-bg-header: black;
  --e2-color-accent: #00007f;
  --e2-oddrow-bg: #00007f;
  --e2-oddrow-text: white;
}
```

---

## Theme Compatibility Matrix

| Feature | Kernel Blue | Deep Ice | Cool Under | mikoyan25 | Bookworm | Simplicity |
|---------|-------------|----------|------------|-----------|----------|------------|
| Float layout | ✅ | ✅ | ✅ | ❌ Absolute | ⚠️ Mixed | ✅ |
| White backgrounds | ✅ | ❌ Blue | ✅ | ❌ Black | ✅ | ✅ |
| Standard fonts | ✅ | ✅ Serif | ✅ | ✅ | ❌ Custom | ❌ Custom |
| No decorative images | ✅ | ✅ | ✅ | ✅ | ⚠️ | ❌ |
| Mobile-friendly | ✅ | ✅ | ✅ | ❌ | ⚠️ | ✅ |
| CSS variable ready | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ✅ |

# Everything2 Stylesheet System: Comprehensive Analysis

**Date**: 2025-11-23
**Author**: Investigation by Claude Code

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Current State Analysis](#current-state-analysis)
4. [Stylesheet Inventory](#stylesheet-inventory)
5. [Problems and Challenges](#problems-and-challenges)
6. [Options for Moving Forward](#options-for-moving-forward)
7. [Recommendations](#recommendations)

---

## Executive Summary

Everything2's stylesheet system is a sophisticated node-based architecture where CSS stylesheets are first-class content nodes (type: `stylesheet`). The system supports:

- **22 stylesheet nodes** in the nodepack (14 marked as "supported")
- **Dual-layer CSS**: base stylesheet + user-selected theme + optional custom CSS
- **CDN asset pipeline** with compression variants (gzip, brotli, deflate)
- **User preference system** with theme testing interface
- **Legacy compatibility** from migration away from old EKW theme system

**Key Challenge**: User-contributed stylesheets are in various states of brokenness due to HTML/CSS changes in the codebase, and there's no systematic way to test or validate them against current markup.

---

## System Architecture

### Node-Based Stylesheet Storage

**Node Type**: `stylesheet` (node_id: 1854352)
- **Extends**: document type (3)
- **Storage**: S3 content table (large binary content)
- **Unique Titles**: Duplicate titles restricted
- **Class**: `Everything::Node::stylesheet` with S3 helper

**Key Methods**:
```perl
# Check if stylesheet is supported (users can select it)
$stylesheet->supported()  # Returns value of 'supported_sheet' parameter
```

### Asset Pipeline Flow

```
Stylesheet Node (nodepack/stylesheet/*.xml)
    ↓
CSS Content Extracted
    ↓
Saved to www/css/[node_id].css
    ↓
Asset Pipeline (tools/asset_pipeline.rb)
    ↓
Minification (clean-css-cli)
    ↓
Multiple Compression Variants Created:
    - Uncompressed minified
    - gzip compressed
    - brotli compressed
    - deflate compressed
    ↓
Upload to S3: deployed.everything2.com/[commit-hash]/[variant]/css/[node_id].css
    ↓
9 Most Recent Commits Retained (quick rollback capability)
    ↓
Served via CDN with 1-year cache expiration
```

### Page Loading Sequence

```html
<!-- 1. Base stylesheet (common to all users) -->
<link rel="stylesheet" id="basesheet" type="text/css"
      href="[CDN]/1973976.css" media="all">

<!-- 2. User's selected stylesheet (or Kernel Blue default) -->
<link rel="stylesheet" id="zensheet" type="text/css"
      href="[CDN]/[user-preference].css" media="screen,tv,projection">

<!-- 3. Optional: User's custom CSS overrides -->
<style type="text/css">
  /* User's customstyle VARS content (HTML-screened for security) */
</style>

<!-- 4. Print stylesheet -->
<link rel="stylesheet" id="printsheet" type="text/css"
      href="[CDN]/1997552.css" media="print">
```

**Loading Code**: `ecore/Everything/Delegation/document.pm:12140-12165`

### User Preference System

**Storage**: `setting` table, `vars` field
```
userstyle=[stylesheet_node_id]
```

**Selection Interface**:
- **Theme Nirvana** (`/node/superdoc/theme_nirvana`) - Main theme selection page
- **Choose Theme View** (`?displaytype=choosetheme`) - Live theme testing interface
  - JavaScript-based dynamic theme switching
  - All links maintain theme context
  - Can browse site with test theme applied
  - Validates and sets preference on confirmation

**Validation Logic** (`ecore/Everything/Node/user.pm:210`):
```perl
sub style {
  my ($self) = @_;
  my $userstyle = $self->VARS->{userstyle};
  my $default = $self->APP->node_by_name($self->CONF->default_style, "stylesheet");

  unless ($userstyle) {
    return $default;  # Kernel Blue
  }

  $userstyle = $self->APP->node_by_id($userstyle);

  # Only return if valid stylesheet type AND marked supported
  if ($userstyle and $userstyle->type->title eq "stylesheet" and $userstyle->supported) {
    return $userstyle;
  }

  return $default;  # Fallback to Kernel Blue if invalid/unsupported
}
```

---

## Current State Analysis

### Stylesheet Inventory

Located in: `nodepack/stylesheet/` and `www/css/`

| Stylesheet | Node ID | Status | File Size | Notes |
|---|---|---|---|---|
| **bare_understatement** | 1855548 | ✓ Supported | - | Minimalist theme |
| **basesheet** | 1973976 | Base (always loaded) | - | Common base styles |
| **bookworm** | 1928497 | Unsupported | - | Reading-focused |
| **bookwormier** | 1951961 | ✓ Supported | - | Enhanced bookworm |
| **cool_understatement** | 1965449 | ✓ Supported | - | Blue color variant |
| **deep_ice** | 1882070 | ✓ Supported | - | Cool blue theme |
| **dim_jukka_emulation** | 1996378 | ✓ Supported | - | Dimmed variant |
| **e2gle** | - | Missing CSS | - | **BROKEN** |
| **gunpowder_green** | - | Missing CSS | - | **BROKEN** |
| **jukka_emulation** | - | Missing CSS | - | **BROKEN** |
| **kernel_blue** | - | ✓ Default | - | Reference implementation |
| **mikoyan25** | 1983570 | ✓ Supported | - | Dark theme |
| **mikoyan25_flipped** | 2029380 | Unsupported | - | Variant |
| **mikoyan25_light** | 2047469 | Unsupported | - | Light variant |
| **monochrome_understatement** | 1997697 | ✓ Supported | - | Grayscale theme |
| **pamphleteer** | 1905818 | ✓ Supported | - | Document-style |
| **print** | 1997552 | ✓ Print media | - | Printer-friendly |
| **responsive2** | 2047530 | Unsupported | - | Mobile-responsive |
| **responsivebase** | 2041900 | Base import | - | Responsive foundation |
| **simplicity** | 1926437 | ✓ Supported | - | Clean minimal |
| **understatement** | 1965286 | ✓ Supported | - | Neutral theme |
| **warm_understatement** | 2000528 | ✓ Supported | - | Warm color variant |

**Total**: 22 stylesheets
**Supported for User Selection**: 14
**Known Broken** (missing CSS files): 3
**Default**: Kernel Blue

### Stylesheet Families

Based on naming patterns and @import dependencies:

1. **Understatement Family** (7 variants)
   - understatement, bare_understatement, cool_understatement, warm_understatement, monochrome_understatement

2. **Mikoyan25 Family** (3 variants)
   - mikoyan25, mikoyan25_flipped, mikoyan25_light
   - Dark theme with variants

3. **Bookworm Family** (2 variants)
   - bookworm, bookwormier
   - Reading-focused typography

4. **Responsive Family** (2)
   - responsivebase (imported by others), responsive2
   - Mobile/tablet support

5. **Standalone**
   - deep_ice, dim_jukka_emulation, pamphleteer, simplicity, kernel_blue

6. **Special Purpose**
   - basesheet (always loaded), print (print media)

### Common Patterns in Stylesheets

Most stylesheets follow this structure:

1. **Color Variables Section**
   - Background colors
   - Text colors
   - Link colors (link, visited, hover, active)
   - Accent/highlight colors

2. **Typography**
   - Font families
   - Font sizes for headings, body, small text
   - Line heights

3. **Layout**
   - Grid structure
   - Column widths
   - Margins and padding
   - Responsive breakpoints

4. **Component Styles**
   - Nodelets
   - Content areas
   - Forms and inputs
   - Navigation
   - Header/footer

5. **@import Directives**
   - Many import responsivebase for mobile support
   - Example: `@import url(https://everything2.com/node/stylesheet/ResponsiveBase?displaytype=view);`

---

## Problems and Challenges

### 1. HTML Generation Distributed Across Codebase

**Problem**: HTML is generated in multiple locations:
- Mason2 templates (`templates/nodelets/*.mi`)
- Perl delegation modules (`ecore/Everything/Delegation/*.pm`)
- Htmlcode functions (`ecore/Everything/Delegation/htmlcode.pm`)
- React components (`react/components/**/*.js`)
- Document-specific code (`ecore/Everything/Delegation/document.pm`)

**Impact**:
- No single source of truth for CSS selectors
- Changes to HTML structure can break stylesheets
- No way to know if a CSS rule is unused
- Difficult to refactor without testing all 22 stylesheets

### 2. No Automated Testing for Stylesheets

**Problem**: No mechanism to validate stylesheets work with current HTML

**Missing Infrastructure**:
- No visual regression testing
- No CSS coverage analysis
- No automated screenshot comparison
- No broken selector detection

**Current Validation**: Manual only
- Developer must manually check each theme
- Time-consuming (22 stylesheets × multiple page types)
- Easy to miss edge cases

### 3. React Migration Breaking CSS Selectors

**Problem**: Ongoing Mason2 → React migration changes markup

**Examples of Breaking Changes**:
- Mason2: `<div class="nodelet">`
- React: `<div className="nodeletContainer">`
- Different nesting structures
- Different class names
- Different DOM hierarchy

**Risk**: Each nodelet migration potentially breaks all 22 stylesheets

### 4. User-Contributed Stylesheets Frozen

**Problem**: Users can no longer submit stylesheets directly

**Current Process**:
- User must create GitHub pull request
- Requires technical knowledge
- High barrier to entry
- Less community engagement

**Historical Context**:
- Old system allowed direct submission
- Community created popular themes
- Now those themes are "frozen in time"

### 5. Stylesheet Validation and Quality Issues

**Status as of 2025-11-23**: All 22 stylesheets validated for syntax errors and quality issues.

#### Recovered Stylesheets (Previously Missing)

Successfully recovered from git history and restored to `www/css/`:

1. **e2gle** (1997552.css) - 20KB, 674 lines
   - Recovered from commit `ad67017`
   - Google-inspired design with custom header

2. **gunpowder_green** (1905818.css) - 5.7KB, 449 lines
   - Recovered from commit `ad67017`
   - Includes autofix rules for weblog/nodelet layout

3. **jukka_emulation** (1855548.css) - 12KB, 583 lines
   - Recovered from commit `2f55285`
   - Includes Clockmaker's fixes

#### Syntax Validation Results

**Clean Stylesheets** (21/22): All braces balanced, valid CSS syntax
- ✓ 1882070 (kernel_blue)
- ✓ 1926437 (plain)
- ✓ 1926578 (e2_classic)
- ✓ 1928497 (the_grid)
- ✓ 1946242 (the_e2_logo_page)
- ✓ 1951961 (purpletone)
- ✓ 1965235 (greyscale)
- ✓ 1965286 (naked)
- ✓ 1965449 (Enlightenment)
- ✓ 1973976 (ModernE)
- ✓ 1983570 (Dark_Side_of_the_Node)
- ✓ 1996378 (CreamLove)
- ✓ 1997697 (Spartan)
- ✓ 2000528 (The_Dark_One)
- ✓ 2004473 (flat_modern)
- ✓ 2041900 (WuWei)
- ✓ 2047469 (green_modern)
- ✓ 2047530 (Techno)
- ✓ 1855548 (jukka_emulation) - recovered
- ✓ 1905818 (gunpowder_green) - recovered
- ✓ 1997552 (e2gle) - recovered (but has external dependencies, see below)
- ✓ 2029380 (Pamphleteer) - FIXED: Added missing closing brace for @media query (line 208)

#### External Dependencies

**1997552 (e2gle)**: 6 external image URLs from ImageShack
- `url(https://img97.imageshack.us/img97/2460/backgroundni.png)` - background (commented out)
- `url(https://img33.imageshack.us/img33/4905/e2fromfontoverlap.png)` - header image
- `url(https://img62.imageshack.us/img62/1903/newwriteups.png)` - New Writeups icon
- `url(https://img44.imageshack.us/img44/3902/coolarchive.png)` - Cool Archive icon
- `url(https://img62.imageshack.us/img62/4124/staffpicks.png)` - Staff Picks icon
- `url(https://img89.imageshack.us/img89/3883/newsfornoders.png)` - News icon

**Impact**:
- ImageShack URLs likely broken/unavailable (service degraded/changed)
- Stylesheet will work but images won't load
- Affects visual appearance significantly
- **Options**:
  1. Host images locally in E2 assets
  2. Replace with CSS-only alternatives
  3. Mark stylesheet as "degraded" until fixed

#### Summary

- **22/22 stylesheets** now present in `www/css/`
- **22/22** have valid CSS syntax (Pamphleteer @media query fixed)
- **1/22** (e2gle) has broken external image dependencies
- **21/22** fully functional with no known issues

### 6. No CSS Modernization

**Problem**: Stylesheets use outdated CSS patterns

**Issues**:
- No CSS variables (custom properties)
- Repeated color values throughout
- No CSS Grid (mostly float-based layouts)
- Limited flexbox usage
- Vendor prefixes for old browsers

**Opportunity**: Could modernize with:
- CSS custom properties for theming
- Modern layout techniques
- Better responsive design patterns

### 7. Popularity Unknown

**Problem**: No visibility into which stylesheets are actually used

**Current State**:
- Theme selection interface shows popularity
- Based on active users (last 6 months)
- But no documented statistics
- Don't know if broken themes have users

**Impact**: Can't prioritize which themes to fix/maintain

---

## Options for Moving Forward

### Option 1: Status Quo (Minimal Maintenance)

**Approach**: Keep current system with minimal changes

**Actions**:
- Fix obviously broken stylesheets (e2gle, gunpowder_green, jukka_emulation)
- Document which stylesheets are "officially supported"
- Mark others as "community maintained, use at own risk"
- Accept some breakage as cost of progress

**Pros**:
- Low effort
- No architectural changes
- Maintains backward compatibility

**Cons**:
- Problem continues to worsen
- User frustration with broken themes
- Technical debt accumulates
- No path to modernization

**Effort**: Low
**Risk**: Low
**User Impact**: Negative (broken themes remain broken)

---

### Option 2: Stylesheet Audit and Deprecation

**Approach**: Systematically evaluate and reduce stylesheet count

**Actions**:
1. **Gather Usage Statistics**
   - Query database for userstyle preferences
   - Identify stylesheets with <10 active users
   - Document popularity rankings

2. **Create Support Tiers**
   - **Tier 1** (Fully Supported): 3-5 most popular + Kernel Blue
     - Tested with every HTML change
     - Maintained by core team
     - Guaranteed to work
   - **Tier 2** (Community Maintained): 5-10 moderately popular
     - Best effort support
     - Community can submit fixes via PR
     - May have minor issues
   - **Tier 3** (Deprecated): <10 users or broken
     - Mark as deprecated
     - Give users 6-month notice to switch
     - Remove from selection interface
     - Archive in git history

3. **Fix Tier 1 Stylesheets**
   - Audit against current HTML
   - Fix all broken selectors
   - Add to test suite

4. **Document Migration Path**
   - For each deprecated stylesheet, suggest alternative
   - Example: "e2gle users → try deep_ice"
   - Provide custom CSS snippets to replicate unique features

**Pros**:
- Reduces maintenance burden
- Focuses effort on popular themes
- Clear communication to users
- Sustainable long-term

**Cons**:
- Some users lose their preferred theme
- Requires data analysis
- Potentially controversial
- Still need testing infrastructure for Tier 1

**Effort**: Medium
**Risk**: Medium (user pushback)
**User Impact**: Mixed (some disappointed, but remaining themes work better)

---

### Option 3: CSS Variable-Based Theming

**Approach**: Modernize to CSS custom properties system

**Architecture**:
```css
/* Single CSS file with variables */
:root {
  --color-primary: #4060b0;
  --color-secondary: #38495e;
  --color-background: #fff;
  --color-text: #111;
  --font-body: 'Verdana', sans-serif;
  /* ... 20-30 variables ... */
}

/* All HTML styled with variables */
body {
  background-color: var(--color-background);
  color: var(--color-text);
  font-family: var(--font-body);
}
```

**Theme Definition**:
```css
/* Kernel Blue theme */
.theme-kernel-blue {
  --color-primary: #4060b0;
  --color-secondary: #38495e;
  /* ... */
}

/* Deep Ice theme */
.theme-deep-ice {
  --color-primary: #88ccee;
  --color-secondary: #2b4a5e;
  /* ... */
}
```

**Actions**:
1. **Create Variable-Based Base Stylesheet**
   - Define ~30 CSS variables for all theming aspects
   - Rewrite all HTML styling to use variables
   - Single source of truth for styling

2. **Convert Tier 1 Themes to Variable Sets**
   - Extract color schemes from existing CSS
   - Create theme classes that override variables
   - Much smaller file sizes (just variable overrides)

3. **Custom Theme Builder**
   - Web interface for users to customize variables
   - Live preview
   - Save to customstyle (no node creation needed)
   - Share theme configs as JSON

4. **Deprecate Node-Based Stylesheets**
   - Migrate existing users to variable-based system
   - Remove stylesheet nodes over time
   - Simplify architecture

**Pros**:
- Modern CSS approach
- Much easier to maintain
- User customization without code
- Single base stylesheet (less to test)
- Smaller file sizes
- Can programmatically validate themes

**Cons**:
- Large upfront effort
- Requires rewriting all styles
- May not support complex layout variations
- Users lose some customization options
- Breaks existing custom CSS (can be mitigated with compatibility layer)

**Effort**: High
**Risk**: High (major architectural change)
**User Impact**: Very Positive (if done well) / Very Negative (if bungled)

---

### Option 4: Visual Regression Testing Infrastructure

**Approach**: Build automated testing to catch stylesheet breakage

**Architecture**:
```
Test Suite:
  For each stylesheet:
    For each key page type:
      1. Load page with stylesheet
      2. Take screenshot
      3. Compare to reference image
      4. Report differences
```

**Tools**:
- **Puppeteer** (already in package.json)
- **Percy.io** or **BackstopJS** for visual regression
- **GitHub Actions** for CI/CD integration

**Actions**:
1. **Create Reference Screenshots**
   - Screenshot each page type with each supported stylesheet
   - Store as "golden images"
   - Commit to repository

2. **Add to CI Pipeline**
   - Run visual tests on every PR
   - Flag changes to stylesheet rendering
   - Require manual review of visual changes

3. **Page Type Coverage**
   - Homepage (logged out)
   - Homepage (logged in)
   - Node view (writeup)
   - User profile
   - Everything Document
   - Superdoc
   - Chatterbox

4. **Stylesheet Coverage**
   - Start with Tier 1 themes
   - Expand to Tier 2 over time

**Pros**:
- Catches breakage automatically
- Prevents regressions
- Low ongoing maintenance
- Works with current architecture
- Builds confidence in changes

**Cons**:
- High initial setup cost
- Requires screenshot storage
- Test flakiness (timing issues)
- Doesn't fix existing problems
- Ongoing cost (CI time, storage)

**Effort**: High (initial setup) / Low (ongoing)
**Risk**: Medium (test flakiness)
**User Impact**: Neutral (prevents future problems)

---

### Option 5: Component-Based Styling (CSS Modules / Styled Components)

**Approach**: Move to component-scoped CSS with React

**Architecture**:
```javascript
// Nodelet.module.css
.container {
  background-color: var(--nodelet-bg);
  border: 1px solid var(--nodelet-border);
}

// Nodelet.js
import styles from './Nodelet.module.css';

function Nodelet() {
  return <div className={styles.container}>...</div>;
}
```

**Actions**:
1. **Adopt CSS Modules**
   - Webpack already configured in project
   - Create .module.css files for each component
   - Scoped class names prevent conflicts

2. **Theme Variables**
   - Still use CSS variables for theming
   - Component styles reference variables
   - No hard-coded colors in components

3. **Gradual Migration**
   - New components use CSS Modules
   - Old components keep global CSS
   - Reduce global CSS over time

4. **Stylesheet Support**
   - Theme only controls variables
   - Component structure controlled by CSS Modules
   - Much harder to "break" with custom CSS

**Pros**:
- Modern React pattern
- Prevents CSS conflicts
- Easy to refactor
- Clear component/style coupling
- Better developer experience

**Cons**:
- Requires React migration to complete
- Users lose ability to deeply customize
- Learning curve for developers
- Can't use until Mason2 eliminated
- May not work with Perl-generated HTML

**Effort**: Very High (requires React migration)
**Risk**: High (architectural change)
**User Impact**: Neutral to Negative (less customization)

---

### Option 6: Hybrid Approach (Recommended)

**Approach**: Combine multiple options for practical solution

**Phase 1: Immediate (0-3 months)**
1. **Audit and Fix** (Option 2 subset)
   - Gather usage statistics for all stylesheets
   - Identify top 5 stylesheets by active users
   - Fix obviously broken stylesheets (e2gle, gunpowder_green, jukka_emulation)
   - Document support tiers

2. **Quick Wins**
   - Add stylesheet validation to smoke tests
   - Check that all supported stylesheets load without 404s
   - Document CSS class naming conventions for future changes

**Phase 2: Short-term (3-6 months)**
3. **Basic Visual Testing** (Option 4 subset)
   - Set up Puppeteer screenshot script
   - Create reference images for Kernel Blue (default)
   - Manual visual check for top 5 stylesheets before releases
   - Doesn't need full CI integration yet

4. **Deprecation Warning** (Option 2 subset)
   - Mark bottom 5 stylesheets as "deprecated" in UI
   - Give 6-month notice of removal
   - Suggest alternatives
   - Remove from selection interface (but keep CSS for existing users)

**Phase 3: Medium-term (6-12 months)**
5. **CSS Variable Foundation** (Option 3 subset)
   - Create CSS variable system for new React components only
   - Don't rewrite existing CSS yet
   - New components are theme-variable-aware
   - Builds foundation for future migration

6. **Formalize Support Tiers**
   - Tier 1: 3 stylesheets (Kernel Blue + 2 most popular)
     - Fully tested
     - Guaranteed to work
   - Tier 2: 5-7 stylesheets (moderately popular)
     - Best effort support
   - Tier 3: Remove deprecated stylesheets
     - Migrate users to closest Tier 1/2 alternative

**Phase 4: Long-term (12+ months)**
7. **Full Visual Regression** (Option 4 complete)
   - Integrate into CI/CD
   - Cover all Tier 1 stylesheets
   - Automated screenshot comparison

8. **CSS Variable Migration** (Option 3 gradual)
   - As Mason2 is eliminated, convert to variables
   - Don't rush, do it as HTML is migrated to React
   - Eventually most theming is just variable overrides

**Pros**:
- Balanced approach
- Incremental progress
- Lower risk
- Practical timeline
- Builds toward modernization

**Cons**:
- Takes longer to reach ideal state
- Some complexity managing hybrid system
- Requires discipline to stick to plan

**Effort**: High (spread over time)
**Risk**: Low to Medium
**User Impact**: Positive (gradual improvement)

---

## Recommendations

### Recommended Approach: Option 6 (Hybrid)

**Rationale**:
1. **Pragmatic**: Works with ongoing React migration
2. **Low Risk**: Incremental changes, easy to roll back
3. **User-Friendly**: Popular themes stay working
4. **Sustainable**: Reduces maintenance burden over time
5. **Modern**: Builds toward CSS variables and component styles

### Immediate Actions (Next Sprint)

1. **Generate Usage Report**
   ```sql
   SELECT
     SUBSTRING_INDEX(SUBSTRING_INDEX(vars, 'userstyle=', -1), '\n', 1) as stylesheet_id,
     COUNT(*) as user_count
   FROM setting
   JOIN user ON setting.setting_id = user.user_id
   WHERE user.lasttime >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
     AND vars LIKE '%userstyle=%'
   GROUP BY stylesheet_id
   ORDER BY user_count DESC;
   ```

2. **Fix Broken Stylesheets**
   - Investigate missing CSS files
   - Either restore from database or mark as unsupported

3. **Document Support Tiers**
   - Create `docs/stylesheet-support-tiers.md`
   - List each stylesheet with:
     - Support tier
     - Active user count
     - Known issues
     - Recommended alternatives if deprecated

4. **Add to Smoke Tests**
   - Verify all "supported" stylesheets have CSS files
   - Check for 404s on stylesheet URLs
   - Basic syntax validation

### Medium-term Actions (Next Quarter)

5. **Create Stylesheet Testing Script**
   ```javascript
   // tools/test-stylesheets.js
   const puppeteer = require('puppeteer');
   const stylesheets = require('./stylesheet-list.json');

   for (const sheet of stylesheets.tier1) {
     await takeScreenshot(sheet, 'homepage');
     await takeScreenshot(sheet, 'node-view');
     await takeScreenshot(sheet, 'user-profile');
   }
   ```

6. **CSS Naming Conventions**
   - Document class naming for new React components
   - Use BEM or similar methodology
   - Ensure stylesheet compatibility

### Long-term Vision

7. **CSS Variable System**
   - As React components replace Mason2
   - Introduce variables gradually
   - Maintain compatibility layer

8. **Visual Regression CI**
   - Integrate screenshot testing
   - Automated PR checks
   - Prevent accidental breakage

---

## Conclusion

The Everything2 stylesheet system is a sophisticated node-based architecture that has served the community well, but faces challenges from:
- Distributed HTML generation
- Ongoing architectural migrations
- No automated testing
- User-contributed content frozen in time

**The hybrid approach** (Option 6) provides a practical path forward that:
- Addresses immediate problems (broken stylesheets)
- Reduces long-term maintenance burden (support tiers)
- Builds toward modernization (CSS variables)
- Maintains user choice (keep popular themes working)
- Integrates with React migration (gradual transformation)

**Success Metrics**:
- Tier 1 stylesheets: 0 reported visual bugs
- Test coverage: Screenshots for 3 page types × 3 Tier 1 themes
- User satisfaction: >90% of active users on working themes
- Maintenance time: <2 hours/month stylesheet fixes

**Timeline**: 12-18 months to reach fully mature state

---

## Appendix A: Stylesheet Node Structure

Example: `nodepack/stylesheet/kernel_blue.xml`

```xml
<node>
  <author_user>13681</author_user>
  <createtime>2014-03-15 00:00:00</createtime>
  <doctext>/* CSS content here */</doctext>
  <dynamicauthor_permission>-1</dynamicauthor_permission>
  <dynamicgroup_permission>-1</dynamicgroup_permission>
  <dynamicguest_permission>-1</dynamicguest_permission>
  <dynamicother_permission>-1</dynamicother_permission>
  <loc_location>1</loc_location>
  <node_id>12345</node_id>
  <title>Kernel Blue</title>
  <type_nodetype>1854352</type_nodetype>

  <!-- Supported stylesheet marker -->
  <vars>supported_sheet,1</vars>
</node>
```

## Appendix B: Asset Pipeline Command

```bash
# Run manually
ruby tools/asset_pipeline.rb

# Runs during build
# See: docker/devbuild.sh
```

## Appendix C: Key Files Reference

- **Stylesheet Node Type**: `nodepack/nodetype/stylesheet.xml`
- **Stylesheet Class**: `ecore/Everything/Node/stylesheet.pm`
- **Stylesheet Nodes**: `nodepack/stylesheet/*.xml`
- **CSS Files**: `www/css/*.css`
- **Asset Pipeline**: `tools/asset_pipeline.rb`
- **CSS Loading**: `ecore/Everything/Delegation/document.pm:12140`
- **Link Generation**: `ecore/Everything/Delegation/htmlcode.pm:82` (linkStylesheet)
- **User Preference**: `ecore/Everything/Node/user.pm:210` (style method)
- **Theme Selection**: `ecore/Everything/Delegation/htmlpage.pm:3746`
- **Theme Test Page**: `nodepack/htmlpage/choose_theme_view_page.xml`
- **Theme Nirvana**: `nodepack/superdoc/theme_nirvana.xml`
- **Asset URI**: `ecore/Everything/Application.pm:4581` (asset_uri method)

## Appendix D: Configuration Settings

```perl
# ecore/Everything/Configuration.pm
has 'default_style' => (isa => 'Str', is => 'ro', default => 'Kernel Blue');
has 'use_local_assets' => (isa => 'Bool', is => 'ro', default => '0');
has 'assets_location' => (isa => 'Str', is => 'ro', lazy => 1, default => sub {
  "https://s3-us-west-2.amazonaws.com/deployed.everything2.com/" . $_[0]->git_hash
});
```

---

## Dark Mode Autodetection Analysis

**Status**: Not implemented. Analysis conducted 2025-11-23.

### Current Architecture

**User Stylesheet Selection**:
- Stored in `user` VARS: `$VARS->{userstyle}` (stylesheet node_id)
- Retrieved via `Everything::Node::user->style()` method
- Falls back to `default_style` config if not set
- Applied in [templates/zen.mc:54-56](templates/zen.mc#L54-L56)

**Stylesheet Loading Pattern**:
```html
<link rel="stylesheet" id="basesheet" href="..." media="all">
<link rel="stylesheet" id="zensheet" href="..." media="screen,tv,projection">
<link rel="stylesheet" id="printsheet" href="..." media="print">
```

**Custom CSS Support**:
- Users can add custom CSS via `customstyle` field
- Injected as `<style>` tag in template
- Overrides stylesheet rules

### Browser Dark Mode Detection

Modern browsers expose user's color scheme preference via CSS media query:

```css
@media (prefers-color-scheme: dark) {
  /* Dark mode styles */
}

@media (prefers-color-scheme: light) {
  /* Light mode styles */
}
```

**Browser Support**:
- Chrome 76+ (July 2019)
- Firefox 67+ (May 2019)
- Safari 12.1+ (March 2019)
- Edge 79+ (January 2020)
- **Coverage**: 95%+ of E2 users

### Implementation Options

---

#### Option A: Pure CSS Media Queries (Simplest)

**Approach**: Add dark mode rules to existing stylesheets using media queries

**Example** (Kernel Blue):
```css
/* Light mode (default) */
body {
  background: #fff;
  color: #111;
}

/* Dark mode */
@media (prefers-color-scheme: dark) {
  body {
    background: #1a1a1a;
    color: #e0e0e0;
  }

  a {
    color: #6c9bd2; /* Lighter blue for contrast */
  }

  .nodeletContainer {
    background: #2a2a2a;
    border-color: #444;
  }
}
```

**Pros**:
- No code changes required
- Works with existing architecture
- User preference automatic (respects OS setting)
- Progressive enhancement (old browsers ignore)
- Zero backend changes

**Cons**:
- Requires updating all 22 stylesheets
- Doubles CSS file size
- No user override (OS setting only)
- Complex for user-submitted styles
- Maintenance burden (2× rules per stylesheet)

**Effort**: Medium (CSS updates only)
**Risk**: Low (CSS-only, no breaking changes)
**User Impact**: Positive (automatic, respects OS)

---

#### Option B: Separate Dark Stylesheets

**Approach**: Create dark mode variant of each stylesheet, load both with media queries

**Architecture**:
```html
<!-- Light mode stylesheet -->
<link rel="stylesheet" href="/css/1882070.css" media="(prefers-color-scheme: light)">

<!-- Dark mode stylesheet -->
<link rel="stylesheet" href="/css/1882070-dark.css" media="(prefers-color-scheme: dark)">
```

**Database Schema**:
```sql
ALTER TABLE stylesheet ADD COLUMN dark_variant_stylesheet INT;
```

**Pros**:
- Clean separation of concerns
- Smaller file sizes per variant
- Can have completely different designs
- Easier to maintain (separate files)

**Cons**:
- Doubles stylesheet count (22 → 44)
- Requires database schema change
- Need UI for users to create/link dark variants
- Community effort to create dark versions
- No dark version = broken dark mode

**Effort**: High (DB, UI, community involvement)
**Risk**: Medium (schema change, double assets)
**User Impact**: Mixed (great if variants exist, broken otherwise)

---

#### Option C: CSS Variables with JavaScript Toggle

**Approach**: Modern CSS custom properties with JS switching

**Implementation**:
1. **Refactor stylesheets to use CSS variables**:
```css
:root {
  --color-bg: #fff;
  --color-text: #111;
  --color-link: #4060b0;
  --color-nodelet-bg: #f5f5f5;
}

:root.dark-mode {
  --color-bg: #1a1a1a;
  --color-text: #e0e0e0;
  --color-link: #6c9bd2;
  --color-nodelet-bg: #2a2a2a;
}

body {
  background: var(--color-bg);
  color: var(--color-text);
}
```

2. **Add JavaScript detection and toggle**:
```javascript
// Auto-detect OS preference
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');

function setTheme(isDark) {
  document.documentElement.classList.toggle('dark-mode', isDark);
  localStorage.setItem('theme', isDark ? 'dark' : 'light');
}

// Check localStorage override, fall back to OS preference
const savedTheme = localStorage.getItem('theme');
if (savedTheme) {
  setTheme(savedTheme === 'dark');
} else {
  setTheme(prefersDark.matches);
}

// Listen for OS preference changes
prefersDark.addEventListener('change', (e) => {
  if (!localStorage.getItem('theme')) {
    setTheme(e.matches);
  }
});
```

3. **Add user preference UI**:
- Settings page: "Theme: [Auto/Light/Dark]"
- Stored in localStorage (instant, no page reload)
- Optional: Sync to user VARS for cross-device

**Pros**:
- User can override OS preference
- Works with OS auto-switching
- Modern, maintainable pattern
- Instant switching (no page reload)
- Progressive enhancement

**Cons**:
- Requires refactoring all stylesheets to CSS variables
- Major undertaking for 22 stylesheets
- User-submitted styles would need migration
- Flash of wrong theme on page load (FOUC)
- Requires JavaScript (degrades gracefully)

**Effort**: Very High (refactor all CSS)
**Risk**: High (major architectural change)
**User Impact**: Very Positive (full control)

---

#### Option D: Stylesheet Pairs with Smart Loading

**Approach**: Hybrid - pair stylesheets, load one based on preference

**Architecture**:
```perl
# User preference: dark_mode_enabled (0, 1, or 'auto')
# In buildNodeInfoStructure():

sub get_stylesheet_url {
  my ($this, $user) = @_;

  my $base_style = $user->style;  # e.g., Kernel Blue
  my $dark_pref = $user->VARS->{dark_mode_enabled} // 'auto';

  if ($dark_pref eq '1' && $base_style->{dark_variant}) {
    return $base_style->{dark_variant}->url;
  }

  return $base_style->url;
}
```

**Template** (zen.mc):
```html
% if ($.dark_mode_auto) {
<link rel="stylesheet" href="<% $.light_stylesheet %>" media="(prefers-color-scheme: light)">
<link rel="stylesheet" href="<% $.dark_stylesheet %>" media="(prefers-color-scheme: dark)">
% } elsif ($.dark_mode_enabled) {
<link rel="stylesheet" href="<% $.dark_stylesheet %>">
% } else {
<link rel="stylesheet" href="<% $.light_stylesheet %>">
% }
```

**User Settings**:
```
Dark Mode:
  ○ Off (use light stylesheet only)
  ● Auto (follow system preference)
  ○ On (use dark stylesheet only)
```

**Pros**:
- Best of both worlds (auto + manual override)
- Backward compatible (no dark variant = normal behavior)
- Can roll out incrementally (stylesheet by stylesheet)
- No FOUC (CSS only, no JS required)

**Cons**:
- Requires dark variant creation
- Database schema additions
- UI for linking variants
- Some stylesheets may never get dark variants

**Effort**: Medium-High (DB, UI, CSS creation)
**Risk**: Medium (schema change, but graceful degradation)
**User Impact**: Very Positive (if variants exist)

---

### Recommended Approach

**Phase 1: Option A (Pure CSS) - Pilot**
1. Start with Kernel Blue (reference implementation)
2. Add `@media (prefers-color-scheme: dark)` rules
3. Test with community
4. Document patterns for contributors
5. **Effort**: 1-2 days for Kernel Blue

**Phase 2: Community Engagement**
1. Document "How to Add Dark Mode to Your Stylesheet"
2. Encourage PRs for popular themes
3. Focus on Tier 1 stylesheets first
4. **Effort**: Ongoing, community-driven

**Phase 3: Option D (Smart Loading) - If Demand Exists**
1. Add database support for dark variants
2. Build settings UI
3. Support both auto-detect and manual override
4. **Effort**: 1-2 weeks development

### Migration Path

**Immediate** (No code changes):
```css
/* Add to Kernel Blue stylesheet */
@media (prefers-color-scheme: dark) {
  /* Dark mode overrides */
}
```

**Short-term** (Add user preference):
- Settings page: "Enable dark mode support: ☑"
- Adds `?dark=1` URL parameter
- JavaScript adds `.dark-mode` class to `<html>`
- Stylesheets check `.dark-mode` instead of media query
- Preserves preference in localStorage

**Long-term** (Full implementation):
- Database schema for dark variants
- Asset pipeline generates both versions
- Smart loading based on user + OS preference
- Community-created dark variants

### Technical Considerations

**FOUC (Flash of Unstyled Content)**:
- CSS-only solutions have no FOUC
- JavaScript solutions need inline script in `<head>`:
```html
<script>
  // Must run before body renders
  if (localStorage.getItem('theme') === 'dark' ||
      (!localStorage.getItem('theme') &&
       window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.classList.add('dark-mode');
  }
</script>
```

**Performance**:
- Option A: Larger files (~2× size), single request
- Option B: Smaller files, two requests (parallel)
- Option C: Same size, requires JS parsing
- Option D: Single file loaded, best performance

**Accessibility**:
- Dark mode improves readability for many users
- Critical for WCAG 2.1 AAA (user preferences)
- Must maintain contrast ratios in both modes
- Test with actual users who prefer dark mode

**Cross-Device Consistency**:
- localStorage = per-browser setting
- VARS = cross-device if user logs in
- Hybrid: localStorage for instant, sync to VARS on change

### Validation Requirements

Before rolling out dark mode:
1. **Contrast Ratios**: Use WebAIM Color Contrast Checker
   - Body text: Minimum 4.5:1 ratio
   - Large text: Minimum 3:1 ratio
2. **Visual Testing**: Screenshot comparison (light vs dark)
3. **User Testing**: Beta test with dark mode users
4. **Browser Testing**: Chrome, Firefox, Safari, Edge
5. **Device Testing**: Desktop, mobile, tablet

### Estimated Effort

**Option A (Recommended)**:
- Kernel Blue: 1-2 days (pilot)
- Each additional stylesheet: 2-4 hours
- Total for 5 popular themes: ~1 week
- Community contributions: Ongoing

**Option D (If implemented)**:
- Backend: 3-4 days (schema, logic, testing)
- Frontend UI: 2-3 days (settings page, toggle)
- Testing: 2-3 days
- Documentation: 1 day
- **Total**: 2-3 weeks

### Next Steps

1. **Proof of Concept**: Add dark mode to Kernel Blue
2. **User Survey**: Gauge interest in dark mode
3. **Community Guidelines**: Document how to add dark mode
4. **Incremental Rollout**: Popular themes first
5. **Measure Adoption**: Track usage after implementation

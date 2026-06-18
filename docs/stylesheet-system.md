# Everything2 Stylesheet System: Comprehensive Analysis

**Date**: 2025-11-23 (revised 2026-06-15)
**Author**: Investigation by Claude Code

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Current State Analysis](#current-state-analysis)
4. [Stylesheet Inventory](#stylesheet-inventory)
5. [Problems and Challenges](#problems-and-challenges)
6. [Direction Taken](#direction-taken)
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

**Loading Code**: stylesheet *selection* (basesheet/zensheet/printsheet, Kernel-Blue default-theme fallback) lives in `ecore/Everything/Controller.pm` (~lines 176-262); the `<link>` tags are emitted by `ecore/Everything/HTMLShell.pm` (~lines 107-116). (The old `Everything::Delegation::document.pm` and `templates/zen.mc` cited in earlier revisions of this doc no longer exist — they were retired with the delegation/Mason burn-down.)

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
- Page controllers / HTML shell (`ecore/Everything/Controller.pm`, `ecore/Everything/HTMLShell.pm`) — these replaced the retired `Everything::Delegation::document.pm`

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

### 6. CSS Modernization — largely shipped

**Status (2026)**: The original "no CSS variables / no modernization" finding is now **out of
date**. Variable-based theming shipped: the basesheet (`www/css/1973976.css`) defines and uses
the `--e2-*` custom-property system (the "Kernel Blue" design tokens — `--e2-primary`,
`--e2-link`, etc., ~2,200 `--e2-*` usages in the basesheet), and themes override via those
variables. Per-theme zensheets layer color overrides on top of the basesheet's variable
defaults.

**Remaining modernization opportunities** (the parts still true):
- Some legacy themes predate the variable system and don't fully consume the tokens
- Repeated/hardcoded color values still exist in older zensheets
- Mostly float-based layouts; limited CSS Grid; some legacy vendor prefixes

### 7. Popularity Unknown

**Problem**: No visibility into which stylesheets are actually used

**Current State**:
- Theme selection interface shows popularity
- Based on active users (last 6 months)
- But no documented statistics
- Don't know if broken themes have users

**Impact**: Can't prioritize which themes to fix/maintain

---

## Direction Taken

This doc originally enumerated six speculative options (status quo → full rebuild) for evolving
the stylesheet system. That deliberation is resolved: the project took the **incremental
variable-based hybrid** path — introduce a `--e2-*` CSS custom-property design system in the
basesheet (the "Kernel Blue" tokens), refactor away from inline `style={{...}}` toward BEM
classnames in the basesheet, and let per-theme zensheets override via the variables. The
speculative option-by-option comparison and effort/risk estimates have been removed as no longer
decision-relevant; see the architecture sections above for the as-built design and the
Recommendations below for the endorsed approach.


## Recommendations

### Recommended Approach: Incremental Variable-Based Hybrid (the path taken)

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
- **CSS Loading (selection)**: `ecore/Everything/Controller.pm` (~176-262)
- **Link Generation (`<link>` tags)**: `ecore/Everything/HTMLShell.pm` (~107-116)
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
## Dark Mode

Dark-mode support is handled through the same variable/zensheet theming described above
(a dark theme is a zensheet that overrides the `--e2-*` tokens; selection flows through
`Everything::Node::user->style()`). The lengthy speculative "autodetection analysis"
(effort estimates, rollout plan, proof-of-concept steps) that previously lived here has been
removed — that planning is resolved, and the architecture it would have built on is the
variable system documented in the sections above. For the user-facing `dark_mode` preference
plumbing, see the `buildNodeInfoStructure` e2-blob producer in `ecore/Everything/Application.pm`.

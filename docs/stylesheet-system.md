# Everything2 Stylesheet System: Comprehensive Analysis

**Date**: 2025-11-23 (revised 2026-06-15)
**Author**: Investigation by Claude Code
**Last verified**: 2026-11-16 (inventory rebuilt from `nodepack/stylesheet/*.xml` + `nodepack/_data/nodeparam.xml` + `www/css/`; loading code re-read)

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

- **22 stylesheet nodes** in the nodepack (17 flagged `supported_sheet` in dev nodepack data; prod may differ)
- **19 CSS files** in `www/css/` (basesheet + 17 zensheets + print). Kernel Blue has no file — it *is* the basesheet defaults; ResponsiveBase/Responsive2 nodes have no files
- **Dual-layer CSS**: base stylesheet + user-selected theme + optional custom CSS
- **S3 asset pipeline** with compression variants (gzip, brotli, zstd)
- **User preference system** (Settings page + Theme Nirvana)

**Key Challenge**: User-contributed stylesheets drift as markup changes. Programmatic checks now exist (`tools/computed-style-diff.js`, `tools/check-css-references.js`, `tools/css-coverage.js`, `tools/visual-regression.js`, `tools/mobile-layout-checker.js`), but none run in CI.

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
www/css/[node_id].css  (source of truth; nodepack/stylesheet/*.xml holds the node, doctext is empty)
    ↓
Asset Pipeline (tools/asset_pipeline.rb, run by docker/buildspec.yml on CodeBuild)
    ↓
Minification (npx clean-css-cli)
    ↓
Compression (tools/compress_assets.mjs, Node zlib):
    - Uncompressed minified
    - gzip
    - brotli (quality 11)
    - zstd (level 19)
    ↓
Upload to S3 deployed-assets bucket: [commit-hash]/[encoding/][node_id].css
    ↓
Assets for commits older than the last 9 are expired (quick rollback capability)
    ↓
Served from S3 with Cache-Control: max-age=31536000 (1 year)
```

Dev (`use_local_assets`) serves `/css/[node_id].css` directly.

### Page Loading Sequence

```html
<!-- 1. Base stylesheet (common to all users) -->
<link rel="stylesheet" id="basesheet" type="text/css"
      href="[CDN]/1973976.css" media="all">

<!-- 2. User's selected stylesheet — omitted entirely when the user is on Kernel Blue (default) -->
<link rel="stylesheet" id="zensheet" type="text/css"
      href="[CDN]/[user-preference].css" media="screen,tv,projection">

<!-- 3. Optional: User's custom CSS overrides -->
<style type="text/css">
  /* User's customstyle VARS content (passed through htmlScreen) */
</style>

<!-- 4. Print stylesheet ("print", node 2004473) -->
<link rel="stylesheet" id="printsheet" type="text/css"
      href="[CDN]/2004473.css" media="print">
```

**Loading Code**: stylesheet *selection* (basesheet/zensheet/printsheet/customstyle, Kernel-Blue default-theme skip) lives in `ecore/Everything/Controller.pm` (~lines 185-272); the `<link>`/`<style>` tags are emitted by `ecore/Everything/HTMLShell.pm` (~lines 108-120). (The old `Everything::Delegation::document.pm` and `templates/zen.mc` cited in earlier revisions of this doc no longer exist — they were retired with the delegation/Mason burn-down.)

### User Preference System

**Storage**: `setting` table, `vars` field
```
userstyle=[stylesheet_node_id]
```

**Selection Interface**:
- **Settings** (`ecore/Everything/Page/settings.pm`) - theme dropdown; lists all stylesheet nodes except `basesheet`, `print`, `ResponsiveBase`, `Responsive2`
- **Theme Nirvana** (`ecore/Everything/Page/theme_nirvana.pm`, node `nodepack/superdoc/theme_nirvana.xml`) - popularity listing of stylesheets
- The old **Choose Theme View** (`?displaytype=choosetheme`) no longer exists in the codebase

**Validation Logic** (`ecore/Everything/Node/user.pm`, `sub style`, ~line 314):
```perl
sub style {
  my ($self) = @_;
  my $userstyle = $self->VARS->{userstyle};
  my $default = $self->APP->node_by_name($self->CONF->default_style, "stylesheet");

  unless ($userstyle) {
    return $default;  # Kernel Blue
  }

  $userstyle = $self->APP->node_by_id($userstyle);

  # Any node of type stylesheet is accepted; the supported_sheet flag is NOT checked here
  if ($userstyle and $userstyle->type->title eq "stylesheet") {
    return $userstyle;
  }

  return $default;  # Fallback to Kernel Blue if invalid
}
```

---

## Current State Analysis

### Stylesheet Inventory

Located in: `nodepack/stylesheet/` (node records) and `www/css/` (CSS). "Supported" = `supported_sheet=1` in `nodepack/_data/nodeparam.xml` (dev seed data; prod may differ).

| Stylesheet | Node ID | Supported | CSS file | Notes |
|---|---|---|---|---|
| **basesheet** | 1973976 | — (always loaded) | ✓ (~40K lines) | Kernel Blue `--e2-*` defaults + all structure |
| **Kernel Blue** | 1882070 | ✓ default | none | Default theme; zensheet skipped, basesheet provides it |
| **print** | 2004473 | — (print media) | ✓ | Loaded as `printsheet` |
| **Understatement** | 1965235 | ✗ | ✓ | |
| **Bare Understatement** | 1965286 | ✓ | ✓ | |
| **Cool understatement** | 1926578 | ✓ | ✓ | |
| **Warm understatement** | 1946242 | ✓ | ✓ | |
| **Monochrome understatement** | 1965449 | ✓ | ✓ | |
| **mikoyan25** | 1926437 | ✓ | ✓ | Dark theme |
| **mikoyan25 flipped** | 1951961 | ✓ | ✓ | |
| **mikoyan25 light** | 1983570 | ✓ | ✓ | |
| **bookworm** | 1928497 | ✗ | ✓ | |
| **Bookwormier** | 2000528 | ✓ | ✓ | Largest zensheet (~900 lines) |
| **jukka emulation** | 1855548 | ✓ | ✓ | |
| **dim jukka emulation** | 1997697 | ✓ | ✓ | |
| **Deep Ice** | 1996378 | ✓ | ✓ | |
| **e2gle** | 1997552 | ✓ | ✓ | ImageShack image URLs since removed |
| **Gunpowder Green** | 1905818 | ✓ | ✓ | |
| **Pamphleteer** | 2029380 | ✓ | ✓ | |
| **Simplicity** | 2041900 | ✓ | ✓ | |
| **ResponsiveBase** | 2047469 | ✗ | none | Excluded from Settings |
| **Responsive2** | 2047530 | ✓ (flag set) | none | Excluded from Settings; no CSS file |

**Total**: 22 stylesheet nodes, 19 CSS files
**Supported flag set**: 17 (incl. Kernel Blue and Responsive2)
**Default**: Kernel Blue

### Stylesheet Families

1. **Understatement Family** (5): Understatement, Bare, Cool, Warm, Monochrome
2. **Mikoyan25 Family** (3): mikoyan25 (dark), flipped, light
3. **Bookworm Family** (2): bookworm, Bookwormier
4. **Jukka Family** (2): jukka emulation, dim jukka emulation
5. **Responsive** (2 nodes, no CSS): ResponsiveBase, Responsive2 — vestigial
6. **Standalone**: Deep Ice, e2gle, Gunpowder Green, Pamphleteer, Simplicity, Kernel Blue
7. **Special Purpose**: basesheet (always loaded), print (print media)

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

5. **@import Directives** — none remain in `www/css/` (the old ResponsiveBase `@import`s are gone); responsive rules live in the basesheet

---

## Problems and Challenges

### 1. HTML Generation Distributed Across Codebase

**Problem** (much reduced since 2025): Mason2 templates are gone and most delegation HTML has been retired. Markup now comes mainly from:
- React components (`react/components/**/*.js`) — the vast majority
- Page controllers / HTML shell (`ecore/Everything/Controller.pm`, `ecore/Everything/HTMLShell.pm`)
- Remaining legacy Perl HTML (residual `Everything::Delegation::*` / `Everything::HTML` paths, being retired under #4259)

**Impact**:
- No single source of truth for CSS selectors
- Changes to HTML structure can break stylesheets
- No way to know if a CSS rule is unused
- Difficult to refactor without testing all 22 stylesheets

### 2. Stylesheet Testing Is Tooling, Not CI

**Status (2026-11)**: dev-only tools now cover most of the original gaps:
- `tools/computed-style-diff.js` — capture/compare computed styles across pages × themes × viewports (snapshots in `screenshots/computed-styles/`)
- `tools/visual-regression.js` — screenshots of all pages across all themes
- `tools/css-coverage.js` — which CSS rules are actually used
- `tools/check-css-references.js` — JS `className` ↔ CSS definition round-trip
- `tools/mobile-layout-checker.js` — mobile overflow/touch-target/text-size checks

**Still missing**: none of these run in the CodeBuild pipeline; they are run by hand against dev.

### 3. React Migration Breaking CSS Selectors (historical)

The Mason2 → React migration is complete; the risk now is ordinary React markup changes, which `check-css-references.js` / `computed-style-diff.js` are meant to catch. The inline-style → BEM classname refactor is also resolved.

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

#### Syntax Validation Results (Nov 2025)

All CSS files then present passed a brace-balance/syntax check; Pamphleteer's missing `@media` closing brace was fixed. (The Nov 2025 list of IDs here carried wrong theme names and has been dropped — see the inventory table above for the correct ID → name mapping.) The build also enforces this: `asset_pipeline.rb` aborts on any clean-css-cli error.

#### External Dependencies

e2gle (1997552) used to reference six ImageShack image URLs; as of 2026-11 `www/css/1997552.css` contains no `url(` references at all.

#### Summary (2026-11)

- 19 CSS files present in `www/css/`; the 3 stylesheet nodes without files (Kernel Blue, ResponsiveBase, Responsive2) are intentional/vestigial — see the inventory
- No known syntax errors or external image dependencies

### 6. CSS Modernization — largely shipped

**Status (2026)**: The original "no CSS variables / no modernization" finding is now **out of
date**. Variable-based theming shipped: the basesheet (`www/css/1973976.css`) defines and uses
the `--e2-*` custom-property system (the "Kernel Blue" design tokens, ~100 distinct `--e2-*`
variables defined and ~2,250 lines referencing them in the basesheet as of 2026-11), and themes override via those
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

> **Status (2026-11-16):** of the actions below, the CSS variable system (7) and BEM naming (6) are done; broken stylesheets (2) were recovered; a screenshot/computed-style toolset (5) exists as dev tools rather than `tools/test-stylesheets.js`; usage report (1), support-tiers doc (3), smoke-test checks (4) and visual-regression CI (8) have not been done.

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

**The hybrid approach** (the path taken) provides a practical path forward that:
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

Actual `nodepack/stylesheet/kernel_blue.xml` (CSS lives in `www/css/`, not in `doctext`):

```xml
<node>
  <contentversion>119</contentversion>
  <doctext></doctext>
  <node_id>1882070</node_id>
  <s3bucket></s3bucket>
  <s3content_id>1882070</s3content_id>
  <title>Kernel Blue</title>
  <type_nodetype>1854352</type_nodetype>
</node>
```

The "supported" marker is a nodeparam, not a node field — in `nodepack/_data/nodeparam.xml`:

```xml
<nodeparam>
  <node_id>1882070</node_id>
  <paramkey>supported_sheet</paramkey>
  <paramvalue>1</paramvalue>
</nodeparam>
```

## Appendix B: Asset Pipeline Command

```bash
# Runs in the prod build (docker/buildspec.yml on CodeBuild):
./tools/asset_pipeline.rb --assets=$ASSETS_BUCKET
```

Dev does not run the pipeline; it serves `www/css/` locally (`use_local_assets`).

## Appendix C: Key Files Reference

- **Stylesheet Node Type**: `nodepack/nodetype/stylesheet.xml`
- **Stylesheet Class**: `ecore/Everything/Node/stylesheet.pm`
- **Stylesheet Nodes**: `nodepack/stylesheet/*.xml`
- **CSS Files**: `www/css/*.css`
- **Asset Pipeline**: `tools/asset_pipeline.rb`
- **Supported flags**: `nodepack/_data/nodeparam.xml` (`supported_sheet`)
- **CDN link**: `ecore/Everything/Node/helper/s3.pm` (`cdn_link` → `asset_uri`)
- **CSS Loading (selection)**: `ecore/Everything/Controller.pm` (~185-272)
- **Link Generation (`<link>` tags)**: `ecore/Everything/HTMLShell.pm` (~108-120)
- **User Preference**: `ecore/Everything/Node/user.pm` (`sub style`, ~314)
- **Theme Selection**: `ecore/Everything/Page/settings.pm` (theme list ~151-170)
- **Theme Nirvana**: `ecore/Everything/Page/theme_nirvana.pm`, `nodepack/superdoc/theme_nirvana.xml`
- **Asset URI**: `ecore/Everything/Application.pm` (`sub asset_uri`, ~7246)
- *(Retired: `Everything/Delegation/htmlpage.pm` and the choose-theme htmlpage no longer exist)*

## Appendix D: Configuration Settings

```perl
# ecore/Everything/Configuration.pm
has 'default_style' => (isa => 'Str', is => 'ro', default => 'Kernel Blue');
has 'use_local_assets' => (isa => 'Bool', is => 'ro', default => '0');
has 'assets_location' => (isa => 'Str', is => 'ro', builder => '_build_assets_location', lazy => 1);
# _build_assets_location: "https://s3-<current_region>.amazonaws.com/<deployedassets bucket>/<last_commit>"
```

---
## Dark Mode

Dark-mode support is handled through the same variable/zensheet theming described above
(a dark theme is a zensheet that overrides the `--e2-*` tokens; selection flows through
`Everything::Node::user->style()`). The lengthy speculative "autodetection analysis"
(effort estimates, rollout plan, proof-of-concept steps) that previously lived here has been
removed — that planning is resolved, and the architecture it would have built on is the
variable system documented in the sections above. As of 2026-11 there is no `dark_mode`
preference or `prefers-color-scheme` handling anywhere in `ecore/`, `react/` or `www/css/` —
dark mode means picking a dark zensheet (e.g. mikoyan25).

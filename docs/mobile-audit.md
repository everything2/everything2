# Mobile Optimization Audit Report

**Generated:** 2026-11-16 (regenerated; previous run 2026-01-10 reported 220/255 with issues)
**Last verified:** 2026-11-16
**Tool:** `node tools/mobile-audit.js` (static scan of `react/components/Documents/*.js`; no browser)

> **Count caveat:** the tool's glob also matches co-located `*.test.js` files (244 of the 479 counted), which inflates "Total" and the pass rate. Against the 235 real Document components, 43 have issues (~82% pass). The issue lists below contain only real components.

## Summary

| Metric | Count |
|--------|-------|
| Total document components | 479 |
| Components with issues | 43 |
| Components passing | 436 |
| Pass rate | 91% |

## Issues by Type

| Issue Type | Count | Severity | Description |
|------------|-------|----------|-------------|
| DUPLICATE_H1 | 33 | Warning | Component renders its own H1 when PageHeader already provides one |
| MISSING_USE_IS_MOBILE | 16 | Info | No responsive hook for mobile-specific styling |
| HARDCODED_PADDING | 4 | Info | Fixed padding that doesn't adapt to mobile |
| HARDCODED_MAX_WIDTH | 3 | Info | Fixed maxWidth that doesn't adapt to mobile |

---

## Priority 1: Duplicate H1 Tags (33 files)

These components render their own `<h1>` tag, creating duplicate headings since PageHeader already renders the page title. This is a **user-visible issue** that affects both UX and accessibility.

**Fix pattern:**
1. Remove the `<h1>` element from the component
2. Keep any intro/description text as a `<p>` element
3. Remove unused `headerStyle` and `titleStyle` constants

**Example (from CoolArchive.js):**
```jsx
// BEFORE - duplicate H1
<div style={headerStyle}>
  <h1 style={titleStyle}>Cool Archive</h1>
  <p style={introStyle}>Description text...</p>
</div>

// AFTER - no duplicate H1
<p style={introStyle}>Description text...</p>
```

### Files to fix:

| File | Status |
|------|--------|
| CategoryDisplay.js | ⬜ Pending |
| CategoryEdit.js | ⬜ Pending |
| Collaboration.js | ⬜ Pending |
| CostumeRemover.js | ⬜ Pending |
| Datastash.js | ⬜ Pending |
| Dbtable.js | ⬜ Pending |
| Debatecomment.js | ⬜ Pending |
| DebatecommentEdit.js | ⬜ Pending |
| DrNatesSecretLab.js | ⬜ Pending |
| E2GiftShop.js | ⬜ Pending |
| E2client.js | ⬜ Pending |
| EditWeblogMenu.js | ⬜ Pending |
| EditorBeta.js | ⬜ Pending |
| EverythingPollArchive.js | ⬜ Pending |
| EverythingPollCreator.js | ⬜ Pending |
| EverythingPollDirectory.js | ⬜ Pending |
| EverythingQuoteServer.js | ⬜ Pending |
| NewUserImages.js | ⬜ Pending |
| NodeBackup.js | ⬜ Pending |
| QuickRename.js | ⬜ Pending |
| RecalculateXp.js | ⬜ Pending |
| RecalculatedUsers.js | ⬜ Pending |
| SQLPrompt.js | ⬜ Pending |
| SanctifyUser.js | ⬜ Pending |
| Settings.js | ⬜ Pending |
| TopicArchive.js | ⬜ Pending |
| UnimplementedPage.js | ⬜ Pending |
| UserEdit.js | ⬜ Pending |
| UserEditVars.js | ⬜ Pending |
| UserSearch.js | ⬜ Pending |
| VotingExperienceSystem.js | ⬜ Pending |
| WharfingerLinebreaker.js | ⬜ Pending |
| WhatDoesWhat.js | ⬜ Pending |

---

## Priority 2: Hardcoded Dimensions (7 files)

These components have hardcoded padding or maxWidth that doesn't adapt to mobile viewports.

**Fix pattern:**
```jsx
// Add import
import { useIsMobile } from '../../hooks/useMediaQuery'

// Add hook
const isMobile = useIsMobile()

// Update styles
const containerStyle = {
  padding: isMobile ? '0' : '20px',
  maxWidth: isMobile ? '100%' : '1200px',
  margin: '0 auto'
}
```

### Files with hardcoded padding:

- [ ] DoIHaveSwineFlu.js
- [ ] EverythingUserPoll.js
- [ ] TeddismsGenerator.js
- [ ] UserRelations.js

### Files with hardcoded maxWidth:

- [ ] DoIHaveSwineFlu.js
- [ ] EverythingUserPoll.js
- [ ] UserRelations.js

---

## Priority 3: Missing useIsMobile Hook (16 files)

These components have inline styles but don't use the `useIsMobile` hook for responsive behavior. Lower priority since CSS media queries may handle basic cases.

<details>
<summary>Click to expand full list (16 files)</summary>

- CategoryEdit.js
- DoIHaveSwineFlu.js
- E2ColorToy.js
- EditorBeta.js
- EverythingPollCreator.js
- EverythingUserPoll.js
- IronNoderProgress.js
- Nodegroup.js
- NodingSpeedometer.js
- QuickRename.js
- ReputationGraph.js
- Settings.js
- SiteTrajectory.js
- TeddismsGenerator.js
- UserEdit.js
- UserRelations.js

</details>

---

## How to Use This Report

1. **Start with Priority 1** (Duplicate H1s) - these are user-visible issues
2. **Verify programmatically** with `node tools/mobile-layout-checker.js [url]` (dev only; checks overflow, touch targets, text size via computed styles) — fall back to `node tools/browser-debug.js screenshot-mobile [url]` only for spot checks
3. **Mark items complete** by changing ⬜ to ✅ in this document
4. **Re-run audit** periodically: `node tools/mobile-audit.js --markdown > docs/mobile-audit.md`

## Related Tools

- `node tools/mobile-audit.js` - Run full audit (exits 1 when any file has issues)
- `node tools/mobile-audit.js --h1-only` - List only duplicate H1 files
- `node tools/mobile-audit.js --json` - JSON output for scripting
- `node tools/mobile-layout-checker.js [url] | --sweep [--quick|--all-themes] [--user U] [--json]` - Computed-style mobile layout checks
- `node tools/browser-debug.js screenshot-mobile [url]` - Take mobile screenshot
- `node tools/browser-debug.js screenshot-as-mobile [user] [url]` - Mobile screenshot as user


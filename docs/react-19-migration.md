# React 19 Migration Plan

**Status**: Planned (Not Started)
**Priority**: Medium
**Estimated Effort**: 5-7 hours
**Blocked By**: Ongoing delegation migration work

## Executive Summary

Everything2's React codebase is in excellent shape for React 19 migration. **One critical blocker exists**: the abandoned `react-collapsible` dependency that only supports React ≤18. The migration requires replacing this dependency, updating tests, and validating all React components.

**Risk Level**: Low (clean codebase, well-tested)
**Breaking Changes Impact**: Minimal (no deprecated APIs in use)

---

## Current State Analysis

### ✅ Code Quality Assessment (Completed 2025-11-16)

**React Components**: 37 files analyzed
**Test Coverage**: 53 tests, 100% passing
**Deprecated API Usage**: None found

| Check | Status | Details |
|-------|--------|---------|
| PropTypes | ✅ None | No migration needed |
| defaultProps | ✅ None | Using ES6 defaults |
| String refs | ✅ None | Using ref callbacks/useRef |
| Legacy context | ✅ None | Using modern Context API |
| ReactDOM.render | ✅ None | Already using createRoot |
| findDOMNode | ✅ None | Using DOM refs |

### 📦 Dependency Analysis

| Package | Current | React 19 Support | Action Required |
|---------|---------|------------------|-----------------|
| **react-collapsible** | 2.10.0 | ❌ **BLOCKER** (max React 18) | Must replace |
| react-modal | 3.16.3 | ✅ Yes (explicit ^19 support) | Update to latest |
| react-idle-timer | 5.7.2 | ✅ Yes (>=16) | No changes needed |
| @testing-library/react | 14.3.1 | ⚠️ Needs update (16.3.0+) | Update required |

**Critical Finding**: `react-collapsible` last updated June 2022, abandoned project.

---

## Migration Strategy

### Option A: Radix UI Replacement (Recommended)

**Effort**: 3-4 hours
**Risk**: Low
**Maintainability**: High

Replace `react-collapsible` with `@radix-ui/react-collapsible`:
- Modern, actively maintained
- React 19 compatible
- Accessible by default
- Similar API

**Implementation**:
```javascript
// Before (react-collapsible)
import Collapsible from 'react-collapsible'

<Collapsible
  trigger={title}
  open={nodeletIsOpen}
  transitionTime="200"
  onTriggerOpening={() => showNodelet(title, true)}
  onTriggerClosing={() => showNodelet(title, false)}
>
  {children}
</Collapsible>

// After (@radix-ui/react-collapsible)
import * as Collapsible from '@radix-ui/react-collapsible'

<Collapsible.Root
  open={nodeletIsOpen}
  onOpenChange={(open) => showNodelet(title, open)}
>
  <Collapsible.Trigger>{title}</Collapsible.Trigger>
  <Collapsible.Content>{children}</Collapsible.Content>
</Collapsible.Root>
```

### Option B: Custom Implementation

**Effort**: 5-7 hours
**Risk**: Medium
**Maintainability**: High (no dependencies)

Build a simple collapse component using CSS transitions:
- Zero dependencies
- Full control over behavior
- Matches exact current functionality

### Option C: Fork react-collapsible

**Effort**: 4-6 hours
**Risk**: Medium-High
**Maintainability**: Low (ongoing maintenance burden)

**Not Recommended**: Adds technical debt.

---

## Migration Steps

### Phase 1: Preparation (2-3 hours)

**1.1 Replace react-collapsible**

Choose Option A or B and implement replacement in:
- `react/components/NodeletContainer.js` (primary usage)

Affected components (verify after replacement):
- VitalsPortal
- NewWriteupsPortal
- RecommendedReadingPortal
- NewLogsPortal
- RandomNodesPortal
- DeveloperPortal
- QuickReferencePortal
- NeglectedDrafts
- SignInPortal

**1.2 Update test setup**

Edit `react/test-setup.js`:
```diff
- // Suppress console errors in tests (optional)
- const originalError = console.error;
- beforeAll(() => {
-   console.error = (...args) => {
-     if (
-       typeof args[0] === 'string' &&
-       args[0].includes('Warning: ReactDOM.render')
-     ) {
-       return;
-     }
-     originalError.call(console, ...args);
-   };
- });
-
- afterAll(() => {
-   console.error = originalError;
- });
```

**1.3 Run React 19 codemod**

```bash
npx codemod@latest react/19/migration-recipe
```

Review and commit changes.

### Phase 2: Dependency Updates (30 minutes)

**2.1 Update package.json**

```json
{
  "dependencies": {
    "browserslist": "^4.28.0",
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "react-idle-timer": "^5.7.2",
    "react-modal": "^3.16.3"
  },
  "devDependencies": {
    "@babel/core": "^7.28.5",
    "@babel/preset-env": "^7.28.5",
    "@babel/preset-react": "^7.28.5",
    "@testing-library/jest-dom": "^6.1.5",
    "@testing-library/react": "^16.3.0",
    "@testing-library/user-event": "^14.5.1",
    "babel-jest": "^29.7.0",
    "babel-loader": "^8.4.1",
    "clean-css": "^5.3.3",
    "clean-css-cli": "^5.6.3",
    "css-loader": "^6.11.0",
    "file-loader": "^6.2.0",
    "jest": "^29.7.0",
    "jest-environment-jsdom": "^29.7.0",
    "react-icons": "^4.12.0",
    "style-loader": "^3.3.4",
    "terser": "^5.44.1",
    "webpack-cli": "^4.10.0"
  },
  "overrides": {
    "js-yaml": "^4.1.1"
  }
}
```

**2.2 Install dependencies**

```bash
# Remove old collapsible
npm uninstall react-collapsible

# Install Radix (if using Option A)
npm install @radix-ui/react-collapsible

# Update React
npm install react@^19.2.0 react-dom@^19.2.0

# Update testing library
npm install -D @testing-library/react@^16.3.0

# Clean install
npm install
```

### Phase 3: Testing (2-3 hours)

**3.1 Run automated tests**

```bash
# Run React tests
npm test

# Run in Docker container
docker exec e2devapp sh -c "cd /var/everything && npm test"
```

**Expected**: All 53 tests should pass. If failures occur, likely async/timing related.

**3.2 Manual testing checklist**

Test all nodelets in browser (http://localhost:9080):

- [ ] **Sign In Portal** - Collapse/expand functionality
- [ ] **Vitals Portal** - Sections expand/collapse correctly
- [ ] **New Writeups Portal** - Content displays when expanded
- [ ] **Developer Portal** - Page/news sections work
- [ ] **Random Nodes Portal** - Nodes list shows/hides
- [ ] **Recommended Reading Portal** - Cool nodes/staff picks work
- [ ] **New Logs Portal** - Daylog links display correctly
- [ ] **Quick Reference Portal** - Search and results work
- [ ] **Neglected Drafts** - Draft list functions properly

**3.3 Test collapse/expand states**

For each nodelet:
- [ ] Starts in correct state (open/closed per user preference)
- [ ] Clicking title toggles state smoothly
- [ ] Animation/transition works (200ms as configured)
- [ ] State persists on page navigation
- [ ] No console errors
- [ ] No visual regressions

**3.4 Test modal functionality**

Verify `react-modal` still works:
- [ ] Modals open correctly
- [ ] Overlay blocks background interaction
- [ ] ESC key closes modal
- [ ] Close button works
- [ ] Focus management correct

**3.5 Test idle timer**

Verify `react-idle-timer` still works:
- [ ] Idle detection triggers after inactivity
- [ ] Resume detection works on interaction
- [ ] No console warnings

### Phase 4: Integration Testing (1-2 hours)

**4.1 Docker build verification**

```bash
./docker/devbuild.sh
```

Verify:
- [ ] Webpack build succeeds
- [ ] No React 19 warnings in build output
- [ ] All Perl tests pass (26/26)
- [ ] All React tests pass (53/53)
- [ ] Application starts successfully

**4.2 Cross-browser testing**

Test in:
- [ ] Chrome/Edge (latest)
- [ ] Firefox (latest)
- [ ] Safari (if available)

**4.3 Performance check**

- [ ] Page load time comparable to React 18
- [ ] Nodelet expand/collapse feels responsive
- [ ] No memory leaks (check DevTools)

---

## Rollback Plan

If critical issues arise:

```bash
# Revert package.json changes
git restore package.json package-lock.json

# Reinstall React 18
npm install

# Rebuild
./docker/devbuild.sh
```

---

## Post-Migration Validation

**Success Criteria**:
- ✅ All 53 React tests passing
- ✅ All 26 Perl tests passing
- ✅ Zero npm vulnerabilities
- ✅ No console errors/warnings
- ✅ All nodelets functional
- ✅ Modal dialogs work
- ✅ Idle timer works
- ✅ Webpack build succeeds

**Performance Benchmarks** (establish baseline before migration):
- Time to Interactive (TTI)
- First Contentful Paint (FCP)
- Nodelet expand/collapse duration

---

## Benefits of Migration

**Immediate**:
- Security patches and bug fixes
- Better TypeScript support
- Improved error reporting

**Long-term**:
- Access to Actions API (optimistic UI)
- Server Components support (when needed)
- Better async rendering
- Improved debugging tools
- Community support (React 18 EOL eventually)

**Maintenance**:
- Replace abandoned dependency (react-collapsible)
- Modern, maintained alternatives
- Reduced technical debt

---

## Timeline Estimate

| Phase | Duration | Can Parallelize? |
|-------|----------|------------------|
| Phase 1: Preparation | 2-3 hours | No |
| Phase 2: Dependencies | 30 minutes | No |
| Phase 3: Testing | 2-3 hours | Partially |
| Phase 4: Integration | 1-2 hours | No |
| **Total** | **5-7 hours** | |

**Recommended**: Allocate 1-2 days for careful migration and testing.

---

## Pre-Migration Checklist

Before starting:

- [ ] Complete all delegation migration work
- [ ] Create feature branch: `issue/XXXX/react-19-migration`
- [ ] Establish performance baselines
- [ ] Backup current package-lock.json
- [ ] Notify team of planned upgrade
- [ ] Schedule testing time
- [ ] Review [official React 19 guide](https://react.dev/blog/2024/04/25/react-19-upgrade-guide)

---

## Questions for Discussion

1. **Timing**: When to schedule migration?
   - After delegation work complete
   - Low-traffic period preferred
   - Allow 2-3 days for testing

2. **Collapsible replacement**: Which option?
   - **Recommended**: Option A (Radix UI)
   - Proven, maintained, accessible

3. **Testing scope**: How extensive?
   - Full manual testing of all nodelets
   - Cross-browser validation
   - Performance benchmarking

4. **Deployment strategy**:
   - Direct to production after testing?
   - Beta test period?
   - Gradual rollout?

---

## Resources

- [Official React 19 Upgrade Guide](https://react.dev/blog/2024/04/25/react-19-upgrade-guide)
- [React 19 Release Notes](https://react.dev/blog/2024/12/05/react-19)
- [Radix UI Collapsible](https://www.radix-ui.com/primitives/docs/components/collapsible)
- [Testing Library React 19 Updates](https://testing-library.com/docs/react-testing-library/intro/)
- [Codemod React 19 Migration](https://docs.codemod.com/guides/migrations/react-18-19)

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-11-16 | Defer migration until delegation complete | Avoid context switching, complete current work stream first |
| 2025-11-16 | Recommend Radix UI for collapsible | Modern, maintained, React 19 compatible, accessible |
| 2025-11-16 | Stay on React 18.3.1 for now | Safe, stable, zero vulnerabilities after current updates |

---

**Document Version**: 1.0
**Last Updated**: 2025-11-16
**Next Review**: When delegation work 90% complete
**Owner**: Development Team

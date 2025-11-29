# $PAGELOAD Elimination Plan

## Executive Summary

`$PAGELOAD` is a legacy global hashref that pollutes scope across the E2 codebase. It was originally used as a side-channel for passing data between delegation functions and the page rendering system. With the migration to React and modern controller/API architecture, this global can and should be eliminated.

**Current Status**: `$PAGELOAD` is defined in [Request.pm:15](../ecore/Everything/Request.pm#L15) with a comment "Pageload is going to go away"

**Goal**: Completely remove `$PAGELOAD` from the codebase and replace its functionality with proper return values, $REQUEST object properties, or React component state.

## What is $PAGELOAD?

`$PAGELOAD` is a hashref that gets passed to every delegation function (htmlcode, document, htmlpage, container, opcode, maintenance, nodelet) as the 6th parameter. It's initialized as an empty hashref `{}` for each request and used to:

1. **Store side-channel data** between delegation functions
2. **Control page rendering** (nodelets, headers, CSS classes)
3. **Cache computed values** within a single request
4. **Pass flags** that affect HTML generation

### Known $PAGELOAD Keys

From analyzing the codebase, `$PAGELOAD` uses these keys:

| Key | Purpose | Used By | Migration Strategy |
|-----|---------|---------|-------------------|
| `pageheader` | Insert content at page top | document.pm (13 uses) | Move to React component or remove |
| `pagenodelets` | Override displayed nodelets | document.pm (5 uses), container.pm (1 use) | Move to Page class `buildReactData()` |
| `noparsecodelinks` | Disable code link parsing | document.pm (3 uses) | Move to request flag or component prop |
| `my_writeup` | Cache current user's writeup on e2node | htmlcode.pm | Return from function instead of side-channel |
| `edcoollink` | Cache C! link for editors | htmlcode.pm | Return from function instead of side-channel |
| `notshown` | Track hidden writeups | htmlcode.pm | Return from function instead of side-channel |
| `e2nodeCategories` | Track if categories listed | htmlcode.pm | Return from function instead of side-channel |

## Files Using $PAGELOAD

### Core Files (11 files in ecore/)

1. **Everything/HTML.pm** - 9 uses
   - Line 37, 62: Declaration as global var
   - Line 636, 638: Pass to htmlcode delegation
   - Line 663: Pass to nodelet delegation
   - Line 727: Pass to htmlpage delegation
   - Line 736: Pass to container delegation
   - Line 1084: Initialize to `{}`
   - Line 1207: Pass to opcode delegation
   - Line 1276: Get from `$REQUEST->PAGELOAD`

2. **Everything/Request.pm** - 1 use
   - Line 15: Define as hashref attribute

3. **Everything/Application.pm** - 1 use
   - Line 6442: Pass `undef` as placeholder to delegation

4. **Everything/Delegation/htmlcode.pm** - 16 uses
   - Multiple reads/writes to various keys (see table above)

5. **Everything/Delegation/document.pm** - 30+ uses
   - Most common file for `$PAGELOAD` usage
   - Sets `pageheader`, `pagenodelets`, `noparsecodelinks`

6. **Everything/Delegation/htmlpage.pm** - Uses in function signatures
   - Multiple functions accept but don't use it

7. **Everything/Delegation/container.pm** - 2 uses
   - Reads `pagenodelets` key
   - Pass through in function signatures

8. **Everything/Delegation/opcode.pm** - Uses in function signatures
   - Functions accept but mostly don't use it

9. **Everything/Delegation/maintenance.pm** - 24+ uses
   - All function signatures (unused parameter)

10. **Everything/Page/node_tracker.pm** - 1 use
    - Function signature (unused)

11. **Everything/Page.pm** - May have uses (need to verify)

### Documentation Files (6 files in docs/)

These are references only, not actual code:
- docs/ajax_update_system_analysis.md
- docs/legacy-js-to-react-migration.md
- docs/developer-sourcemap-system.md
- docs/htmlpage-critical-path-analysis.md
- docs/htmlpage-react-migration-analysis.md
- docs/modernization-priorities.md
- docs/other-users-nodelet-spec.md
- CLAUDE.md

## Migration Strategy

### Phase 1: Identify Actual Usage (CURRENT)

**Goal**: Distinguish between functions that actually use `$PAGELOAD` vs. those that just accept it

**Tasks**:
- [x] Grep for all `$PAGELOAD` references
- [x] Identify all keys used in the hashref
- [ ] Categorize usage patterns (read, write, read-write)
- [ ] Count functions that accept but never use `$PAGELOAD`

**Deliverable**: This document

### Phase 2: Eliminate Unused Parameters

**Goal**: Remove `$PAGELOAD` parameter from functions that don't use it

**Estimated Impact**: ~60% of delegation function signatures

**Process**:
1. Identify functions that accept `$PAGELOAD` but never read from or write to it
2. Remove the parameter from function signature
3. Update callers in HTML.pm to not pass it
4. Test that delegation still works

**High Priority Targets**:
- `Everything/Delegation/maintenance.pm` - ALL 24 functions just accept and ignore it
- `Everything/Delegation/opcode.pm` - Most functions ignore it
- `Everything/Delegation/htmlpage.pm` - Many functions ignore it

**Risk**: Low - these functions don't use it anyway

### Phase 3: Replace Cache Usage with Return Values

**Goal**: Eliminate side-channel caching pattern

**Functions Using $PAGELOAD as Cache**:

1. **`htmlcode.pm` caching patterns**:
   ```perl
   # BEFORE (bad - side channel)
   $PAGELOAD->{my_writeup} = $N;
   # ... later ...
   $MINE = delete $PAGELOAD->{my_writeup};

   # AFTER (good - explicit return)
   my $my_writeup = find_my_writeup($N);
   ```

2. **`htmlcode.pm` - infofunctions cache**:
   ```perl
   # BEFORE
   $PAGELOAD->{$CACHE_NAME} = $infofunctions;

   # AFTER - use REQUEST object or local variable
   $REQUEST->{_cache}{infofunctions} = $infofunctions;
   ```

3. **`htmlcode.pm` - edcoollink cache**:
   ```perl
   # BEFORE
   $PAGELOAD->{edcoollink} = $DB->sqlSelectHashref(...);

   # AFTER - return from function or use REQUEST cache
   return { ..., edcoollink => $link };
   ```

**Process**:
1. Identify each cached value
2. Determine if it's used across multiple function calls
3. If single function scope: use local variable or return value
4. If cross-function scope: use `$REQUEST->{_cache}` or pass explicitly
5. Update tests

**Risk**: Medium - requires careful tracking of data flow

### Phase 4: Move Page Control to React

**Goal**: Replace `pageheader`, `pagenodelets`, `noparsecodelinks` with React props

**Current Usage**:

1. **`pageheader`** - Used to inject content at top of page (13 uses in document.pm)
   ```perl
   # BEFORE
   $PAGELOAD->{pageheader} = '<!-- at end -->' . htmlcode('settingsDocs');

   # AFTER - React component
   # Return from buildReactData():
   return {
     pageHeader: 'settingsDocs',  # Component name
   };
   ```

2. **`pagenodelets`** - Override nodelets for specific pages (6 uses)
   ```perl
   # BEFORE
   $PAGELOAD->{pagenodelets} = "$nlid,";

   # AFTER - Page class
   sub buildReactData {
     return {
       pagenodelets => [1234, 5678],  # Array of nodelet IDs
     };
   }
   ```

3. **`noparsecodelinks`** - Disable code link parsing (3 uses)
   ```perl
   # BEFORE
   $PAGELOAD->{noparsecodelinks} = 1;

   # AFTER - Component prop or parser option
   <ParseLinks text={content} parseCodeLinks={false} />
   ```

**Process**:
1. For each React-migrated page:
   - Move `pagenodelets` to `buildReactData()` return value
   - Remove `pageheader` usage (deprecated with Mason2 templates)
   - Remove `noparsecodelinks` (control in ParseLinks component)
2. For legacy Mason2 pages:
   - Keep minimal `$PAGELOAD` support temporarily
   - Document deprecation
   - Plan migration

**Risk**: Low for React pages, Medium for Mason2 pages

### Phase 5: Remove from Delegation Signatures

**Goal**: Stop passing `$PAGELOAD` to delegation functions entirely

**Affected Files**:
- `Everything/HTML.pm` - All delegation callers
- All `Everything/Delegation/*.pm` files

**Process**:
1. Update delegation function signatures to remove `$PAGELOAD` parameter:
   ```perl
   # BEFORE
   sub my_function {
     my ($DB, $query, $GNODE, $USER, $VARS, $PAGELOAD, $APP, @args) = @_;

   # AFTER
   sub my_function {
     my ($DB, $query, $GNODE, $USER, $VARS, $APP, @args) = @_;
   ```

2. Update callers in HTML.pm:
   ```perl
   # BEFORE
   $delegation->($DB, $query, $GNODE, $USER, $VARS, $PAGELOAD, $APP, @args);

   # AFTER
   $delegation->($DB, $query, $GNODE, $USER, $VARS, $APP, @args);
   ```

3. Remove global declaration in HTML.pm:
   ```perl
   # DELETE
   use vars qw($PAGELOAD);
   ```

**Risk**: High - affects many delegation functions, must be done atomically

### Phase 6: Remove from Request.pm

**Goal**: Delete `$PAGELOAD` attribute entirely

**Files to Update**:
- `Everything/Request.pm` - Remove `has 'PAGELOAD'` line
- `Everything/HTML.pm` - Remove `$PAGELOAD = $REQUEST->PAGELOAD` line

**Process**:
1. Verify no remaining references in code
2. Delete `has 'PAGELOAD'` from Request.pm
3. Delete initialization in HTML.pm
4. Run full test suite
5. Deploy and monitor

**Risk**: Low if previous phases complete successfully

## Burndown Checklist

### Phase 1: Analysis ✅ COMPLETE
- [x] Document all $PAGELOAD usage
- [x] Categorize by usage pattern
- [x] Create elimination plan

### Phase 2: Remove Unused Parameters (Estimated: 2-3 hours)
- [ ] Audit `Everything/Delegation/maintenance.pm` (24 functions - all unused)
- [ ] Remove $PAGELOAD from maintenance.pm signatures
- [ ] Update HTML.pm caller for maintenance delegations
- [ ] Audit `Everything/Delegation/opcode.pm`
- [ ] Remove $PAGELOAD from unused opcode functions
- [ ] Update HTML.pm caller for opcode delegations
- [ ] Audit `Everything/Delegation/htmlpage.pm`
- [ ] Remove $PAGELOAD from unused htmlpage functions
- [ ] Update HTML.pm caller for htmlpage delegations
- [ ] Run test suite
- [ ] Commit: "Remove unused $PAGELOAD parameters from delegation functions"

### Phase 3: Replace Cache Usage (Estimated: 4-6 hours)
- [ ] `htmlcode.pm` - Replace `my_writeup` cache
  - [ ] Refactor `canseewriteup` to return value instead of side-channel
  - [ ] Update `addwriteup` to receive value explicitly
- [ ] `htmlcode.pm` - Replace `edcoollink` cache
  - [ ] Move to REQUEST->{_cache} or pass explicitly
  - [ ] Update page_header and related functions
- [ ] `htmlcode.pm` - Replace `notshown` tracking
  - [ ] Return from canseewriteup function
  - [ ] Pass to consumers explicitly
- [ ] `htmlcode.pm` - Replace `e2nodeCategories` flag
  - [ ] Use local variable or return value
- [ ] `htmlcode.pm` - Replace `infofunctions` cache
  - [ ] Move to REQUEST->{_cache}
- [ ] Run test suite
- [ ] Commit: "Replace $PAGELOAD caching with explicit return values"

### Phase 4: React Migration (Estimated: 6-8 hours)
- [ ] Survey all `pageheader` uses in document.pm
  - [ ] Identify which are React pages vs Mason2
  - [ ] For React pages: remove (no longer needed)
  - [ ] For Mason2 pages: document deprecation
- [ ] Survey all `pagenodelets` uses
  - [ ] Chatterlight: Move to `buildReactData()` ✅ (already done)
  - [ ] Chatterlight Classic: Move to `buildReactData()` ✅ (already done)
  - [ ] Settings pages: Move to `buildReactData()`
  - [ ] Login page: Move to `buildReactData()`
  - [ ] User Settings: Move to `buildReactData()`
- [ ] Survey all `noparsecodelinks` uses
  - [ ] Everything Bugs: Add prop to ParseLinks
  - [ ] Source code display: Add prop to ParseLinks
  - [ ] Other uses: Migrate to component props
- [ ] Update `container.pm` to not read `pagenodelets`
- [ ] Run test suite
- [ ] Commit: "Move page control from $PAGELOAD to React/Page classes"

### Phase 5: Remove Delegation Parameter (Estimated: 3-4 hours)
- [ ] Update all `Everything/Delegation/htmlcode.pm` function signatures
- [ ] Update all `Everything/Delegation/document.pm` function signatures
- [ ] Update all `Everything/Delegation/container.pm` function signatures
- [ ] Update all `Everything/Delegation/nodelet.pm` function signatures (if exists)
- [ ] Update HTML.pm caller for htmlcode delegations
- [ ] Update HTML.pm caller for document delegations
- [ ] Update HTML.pm caller for container delegations
- [ ] Update HTML.pm caller for nodelet delegations
- [ ] Remove `use vars qw($PAGELOAD);` from HTML.pm
- [ ] Run test suite
- [ ] Commit: "Remove $PAGELOAD parameter from all delegation functions"

### Phase 6: Final Cleanup (Estimated: 1 hour)
- [ ] Remove `has 'PAGELOAD'` from Request.pm
- [ ] Remove `$PAGELOAD = $REQUEST->PAGELOAD` from HTML.pm
- [ ] Remove `$PAGELOAD = {}` initialization from HTML.pm
- [ ] Search for any remaining references
- [ ] Update documentation files
- [ ] Run full test suite
- [ ] Run smoke tests
- [ ] Commit: "Complete $PAGELOAD elimination"
- [ ] Create PR for review
- [ ] Deploy to production

## Testing Strategy

### Per-Phase Testing

After each phase:
1. Run unit test suite: `./tools/parallel-test.sh`
2. Run smoke tests: `./tools/smoke-test.rb`
3. Check for Perl errors in logs
4. Manual testing of affected pages

### Critical Pages to Test

These pages use $PAGELOAD heavily and must be tested:

1. **Settings Pages** (pageheader usage)
   - User Settings
   - Display Settings
   - Privacy Settings
   - Message Settings

2. **Chatterlight Pages** (pagenodelets usage)
   - Chatterlight
   - Chatterlight Classic

3. **Login/Signup** (pagenodelets usage)
   - Login page
   - New user signup

4. **Code Display** (noparsecodelinks usage)
   - Everything Bugs
   - Source code views

5. **E2nodes** (my_writeup, edcoollink, notshown cache)
   - Any e2node page
   - Editor views

### Regression Risks

**High Risk**:
- E2node rendering (heavy htmlcode.pm usage)
- Editor features (edcoollink, page_header)
- Chatterbox/nodelets (pagenodelets)

**Medium Risk**:
- Settings pages (pageheader)
- Login flow (pagenodelets)

**Low Risk**:
- API endpoints (don't use delegation)
- React-only pages (don't use legacy rendering)

## Benefits of Elimination

1. **Cleaner Code**: No more magic global side-channels
2. **Better Testability**: Functions have explicit inputs/outputs
3. **Easier Debugging**: Data flow is visible
4. **Performance**: No unnecessary parameter passing
5. **React Migration**: Removes legacy coupling
6. **Reduced Cognitive Load**: One less global to track

## Timeline Estimate

- **Phase 1**: ✅ Complete (this document)
- **Phase 2**: 1 day (remove unused params)
- **Phase 3**: 2 days (replace caching)
- **Phase 4**: 3 days (React migration)
- **Phase 5**: 1 day (remove from signatures)
- **Phase 6**: 0.5 days (final cleanup)

**Total**: ~7.5 days of focused work

## Success Criteria

- [ ] Zero references to `$PAGELOAD` in ecore/ directory
- [ ] All tests passing
- [ ] Smoke tests passing
- [ ] No Perl errors in production logs
- [ ] Critical pages rendering correctly
- [ ] Editor features working
- [ ] Chatterbox/nodelets working
- [ ] Settings pages working

## Notes

- This is a purely internal refactoring - no user-facing changes
- Can be done incrementally over multiple PRs
- Each phase should be independently deployable
- Keep rollback plan ready for each phase
- Update CLAUDE.md after completion

---

**Document Version**: 1.0
**Created**: 2025-11-28
**Status**: Planning Phase

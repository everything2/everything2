# Mason2 Elimination Plan: Fixing Double Nodelet Rendering

**Status**: PHASE 1 COMPLETE ✅
**Created**: November 21, 2025
**Completed**: November 21, 2025
**Priority**: HIGH - Blocks clean React migration

## Problem Statement

Pages rendered through the Everything::Page ecosystem are displaying **double nodelets** for React-migrated components (Epicenter, ReadThis, MasterControl). This occurs because:

1. **React renders** all nodelets in `<div id='e2-react-root'></div>`
2. **Mason2 ALSO renders** nodelets via `<& 'nodelets', ... &>` template
3. Both rendering paths execute simultaneously, causing visual duplication

## Root Cause Analysis

### Current Architecture Flow

```
HTTP Request
    ↓
Everything::Controller::layout()
    ├─→ buildNodeInfoStructure() → data for React (window.e2)
    ├─→ nodelets() → data for Mason2 ($params->{nodelets})
    └─→ MASON->run(template, params)
            ↓
    templates/zen.mc
        ├─→ Line 103: <div id='e2-react-root'></div> [REACT RENDERS HERE]
        └─→ Line 104: <& 'nodelets', ... &> [MASON2 RENDERS HERE]
```

### Key Code Locations

1. **Controller.pm:96-129** - `nodelets()` method builds Mason2 data
2. **Controller.pm:131-147** - `epicenter()` method returns Mason2 data
3. **templates/zen.mc:103-104** - Both React and Mason2 rendering
4. **templates/nodelets/Base.mc:6,10** - `react_handled` flag mechanism
5. **templates/nodelets/epicenter.mi** - Full Mason2 template (NOT react_handled)

### Existing Solution Mechanism

The codebase already has a `react_handled` flag in `templates/nodelets/Base.mc`:

```perl
has 'react_handled' => (isa => 'Bool', default => 0);

# Line 10:
% if (!$.react_handled) {
  <h2 class="nodelet_title"><% $.title %></h2>
  <div class='nodelet_content'>...</div>
% }
```

**Already Migrated** (have `react_handled => 1`):
- new_logs.mi
- recommended_reading.mi
- new_writeups.mi
- everything_developer.mi
- neglected_drafts.mi
- sign_in.mi
- random_nodes.mi
- vitals.mi
- **epicenter.mi** ✅ (Migrated Nov 21, 2025)
- **readthis.mi** ✅ (Migrated Nov 21, 2025)
- **master_control.mi** ✅ (Migrated Nov 21, 2025)

**Missing react_handled Flag**:
- ~~epicenter.mi~~ ✅ **COMPLETE**
- ~~readthis.mi~~ ✅ **COMPLETE**
- ~~master_control.mi~~ ✅ **COMPLETE**

**All React-migrated nodelets now have the react_handled flag!**

## Solution: Phased Approach

### Phase 1: IMMEDIATE FIX (This Session)

**Goal**: Stop double rendering for migrated nodelets

**Changes Required**:

1. **templates/nodelets/epicenter.mi** - Add react_handled flag
   ```perl
   <%class>
   has 'react_handled' => (isa => 'Bool', default => 1);
   # ... rest of class definition (keep for potential fallback)
   </%class>
   ```

2. **templates/nodelets/readthis.mi** - Add react_handled flag
   ```perl
   <%class>
   has 'react_handled' => (isa => 'Bool', default => 1);
   </%class>
   Read This
   ```

3. **templates/nodelets/master_control.mi** - Add react_handled flag
   ```perl
   <%class>
   has 'react_handled' => (isa => 'Bool', default => 1);
   </%class>
   Master Control
   ```

**Testing**:
- Verify Epicenter shows once (not twice)
- Verify ReadThis shows once
- Verify Master Control shows once
- Test on multiple page types (writeup, e2node, superdoc, etc.)
- Test as guest and logged-in user

**Risk**: LOW - Following established pattern used by 8 other nodelets

---

### Phase 2: OPTIMIZE CONTROLLER (Next Sprint)

**Goal**: Stop building unused data for React nodelets

**Problem**: Even with `react_handled => 1`, the Controller still:
- Calls `epicenter()` method (Controller.pm:131)
- Builds Mason2 data structures
- Passes data to templates that never use it
- Wastes CPU cycles and memory

**Changes Required**:

1. **Create nodelet metadata system**:
   ```perl
   # New file: ecore/Everything/NodeletRegistry.pm
   package Everything::NodeletRegistry;

   use Moose;

   has 'nodelets' => (
     is => 'ro',
     default => sub {{
       'epicenter' => { react_handled => 1 },
       'readthis' => { react_handled => 1 },
       'master_control' => { react_handled => 1 },
       'new_writeups' => { react_handled => 1 },
       # ... etc
     }}
   );

   sub is_react_handled {
     my ($self, $nodelet_name) = @_;
     return $self->nodelets->{$nodelet_name}{react_handled} // 0;
   }
   ```

2. **Modify Controller::nodelets()** (Controller.pm:96-129):
   ```perl
   sub nodelets
   {
     my ($self, $nodelets, $params) = @_;
     my $REQUEST = $params->{REQUEST};
     my $node = $params->{node};

     $params->{nodelets} = {};
     $params->{nodeletorder} ||= [];

     foreach my $nodelet (@{$nodelets|| []})
     {
       my $title = lc($nodelet->title);
       my $id = $title;
       $title =~ s/ /_/g;
       $id =~ s/\W//g;

       # NEW: Skip building data for React nodelets
       if($self->NODELET_REGISTRY->is_react_handled($title))
       {
         # Just add minimal data for div placeholder
         $params->{nodelets}->{$title} = {
           react_handled => 1,
           title => $nodelet->title,
           id => $id,
           node => $node
         };
         push @{$params->{nodeletorder}}, $title;
         next;
       }

       # OLD: Build full Mason2 data
       if($self->can($title))
       {
         my $nodelet_values = $self->$title($REQUEST, $node);
         next unless $nodelet_values;
         $params->{nodelets}->{$title} = $nodelet_values;
       }
       # ... rest of existing code
     }
     return $params;
   }
   ```

3. **Update Mason2 templates** to receive react_handled from params:
   ```perl
   # templates/nodelets/epicenter.mi
   <%class>
   has 'react_handled' => (isa => 'Bool'); # Remove default, comes from controller
   # ... rest
   </%class>
   ```

**Benefits**:
- Reduces CPU usage per page load
- Cleaner separation of React vs Mason2 paths
- Easier to track which nodelets are React
- Prepares for Phase 3

**Testing**:
- All existing tests should pass
- Performance benchmarks should show improvement
- No visual regressions

**Risk**: MEDIUM - Changes Controller logic, needs thorough testing

---

### Phase 3: REACT-ONLY TEMPLATE PATH (Medium Term)

**Goal**: Create pure React rendering path without Mason2 nodelets

**Problem**: Even with optimizations, Mason2 still:
- Renders `<div class='nodelet' id='epicenter'>` wrappers
- Processes nodelet loop
- Maintains two parallel rendering systems

**Changes Required**:

1. **Create new React-only template**:
   ```perl
   # templates/zen_react.mc
   <%class>
   # Same as zen.mc but simplified
   </%class>
   <%augment wrap>
   <!DOCTYPE html>
   <html lang="en">
   <head>...</head>
   <body class="<% $.body_class %>" itemscope itemtype="http://schema.org/WebPage">
   <div id='header'>...</div>
   <div id='wrapper'>
     <div id='mainbody' itemprop="mainContentOfPage">
       <% inner() %>
     </div>
     <div id='sidebar'>
       <!-- ONLY React root, no Mason2 nodelets -->
       <div id='e2-react-root'></div>
     </div>
   </div>
   <div id='footer'>...</div>
   <& 'static_javascript', ... &>
   </body>
   </html>
   </%augment>
   ```

2. **Add template selector to Everything::Page**:
   ```perl
   # ecore/Everything/Page.pm
   package Everything::Page;

   has 'template' => (is => 'ro', default => '');
   has 'use_react_template' => (is => 'ro', default => 0); # NEW
   ```

3. **Modify Controller::layout()** to choose template:
   ```perl
   sub layout
   {
     my ($self, $template, @p) = @_;
     my $params = {@p};

     # NEW: Choose zen_react.mc for pages that are fully React
     my $page = $params->{page};
     if ($page && $page->use_react_template) {
       $template = 'zen_react';
     }

     # ... rest of layout logic

     # NEW: Skip nodelet building for React-only pages
     if (!$page || !$page->use_react_template) {
       $params = $self->nodelets($REQUEST->user->nodelets, $params);
     }

     return $self->MASON->run($template, $params)->output();
   }
   ```

4. **Gradually migrate pages**:
   ```perl
   # ecore/Everything/Page/25.pm
   package Everything::Page::25;

   use Moose;
   extends 'Everything::Page';

   has 'template' => (is => 'ro', default => 'numbered_nodelist');
   has 'use_react_template' => (is => 'ro', default => 1); # NEW: This page is React-ready
   ```

**Benefits**:
- True separation of React and Mason2
- Can migrate pages incrementally
- Cleaner codebase
- Faster page loads for React pages

**Testing**:
- Create both zen.mc and zen_react.mc paths
- Verify pages work on both templates
- A/B test performance
- Gradual rollout

**Risk**: MEDIUM-HIGH - New template architecture, requires careful migration

---

### Phase 4: FULL MASON2 ELIMINATION (Long Term Goal)

**Goal**: Remove Mason2 entirely, pure React frontend

**Vision**: Everything::Page becomes pure API/data layer:
```perl
# Future state: Everything::Page as API
package Everything::Page;

sub api_data
{
  my ($self, $REQUEST, $node) = @_;
  return {
    # Return JSON data structure
    # React handles ALL rendering
  };
}
```

**Requirements Before Starting**:
- [ ] All 25 nodelets migrated to React
- [ ] All page content migrated to React components
- [ ] Mason2 templates no longer called
- [ ] Everything::Page only provides data
- [ ] React Router handles all routing
- [ ] API endpoints for all functionality

**Changes Required**:
1. Migrate remaining 15 nodelets to React
2. Create React components for all page types
3. Convert Everything::Page to REST API
4. Update routing to use React Router
5. Remove Mason2 dependency
6. Delete templates/ directory
7. Update build process

**Benefits**:
- Modern, maintainable codebase
- Single source of truth for UI
- Better performance
- Easier testing
- Better developer experience
- Mobile-responsive by default

**Timeline**: 6-12 months after Phase 3 completion

**Risk**: HIGH - Major architectural change, requires full team effort

---

## Immediate Action Plan (This Session - DO NOT EXECUTE)

### Step 1: Add react_handled Flags

**Files to Modify**:

1. `templates/nodelets/epicenter.mi` - Line 1, add:
   ```perl
   <%class>
   has 'react_handled' => (isa => 'Bool', default => 1);
   ```

2. `templates/nodelets/readthis.mi` - Line 1, add:
   ```perl
   <%class>
   has 'react_handled' => (isa => 'Bool', default => 1);
   </%class>
   ```

3. `templates/nodelets/master_control.mi` - Line 1, add:
   ```perl
   <%class>
   has 'react_handled' => (isa => 'Bool', default => 1);
   </%class>
   ```

### Step 2: Test Thoroughly

**Test Cases**:
1. Load homepage as guest → Verify no double ReadThis
2. Load homepage as logged-in user → Verify no double Epicenter, ReadThis
3. Load writeup page as editor → Verify no double MasterControl
4. Check all page types (e2node, superdoc, document, etc.)
5. Verify nodelets still render correctly
6. Verify nodelet collapse/expand works
7. Check mobile view

**Expected Behavior**:
- Each nodelet appears exactly once
- React version renders (with LinkNode, ParseLinks, etc.)
- No Mason2 version visible
- Placeholder divs exist for CSS targeting

### Step 3: Document Changes

**Update Files**:
- This document (add completion status)
- CLAUDE.md (add Phase 1 completion)
- changelog-2025-11.md (add fix for double rendering)

### Step 4: Prepare for Phase 2

**Create Issues/Tasks**:
- [ ] Create NodeletRegistry.pm
- [ ] Modify Controller::nodelets() to check registry
- [ ] Update all nodelet templates
- [ ] Performance benchmarks before/after
- [ ] Full test suite run

---

## Decision Points

### When to Execute Phase 1?
**Now** - Simple fix, low risk, immediate user benefit

### When to Execute Phase 2?
**Next sprint** - After Phase 1 proves stable, when performance optimization is priority

### When to Execute Phase 3?
**After 15+ nodelets migrated** - When benefit outweighs complexity

### When to Execute Phase 4?
**After Phase 3 complete and stable** - When Mason2 is truly legacy

---

## Success Metrics

### Phase 1:
- ✅ No double rendering visible to users
- ✅ All tests pass
- ✅ No performance regression

### Phase 2:
- ✅ 20-30% reduction in nodelet processing time
- ✅ Cleaner code organization
- ✅ All tests pass

### Phase 3:
- ✅ Pages load 10-15% faster on React template
- ✅ Code complexity reduced
- ✅ Can add new pages without Mason2

### Phase 4:
- ✅ Mason2 dependency removed from package.json
- ✅ templates/ directory deleted
- ✅ 100% React frontend
- ✅ Modern development workflow

---

## Risks and Mitigations

### Phase 1 Risks:
- **Risk**: Breaking existing pages
- **Mitigation**: Follow exact pattern from 8 working nodelets

### Phase 2 Risks:
- **Risk**: Controller logic breaks Mason2 fallback
- **Mitigation**: Keep both paths working, gradual rollout

### Phase 3 Risks:
- **Risk**: Template divergence (zen.mc vs zen_react.mc)
- **Mitigation**: Shared components, automated tests

### Phase 4 Risks:
- **Risk**: Complete rewrite complexity
- **Mitigation**: Incremental migration, feature parity tests, rollback plan

---

## Conclusion

The **react_handled flag** mechanism already exists and works perfectly. We just need to:

1. **Immediately**: Set the flag for epicenter, readthis, master_control
2. **Soon**: Optimize Controller to skip building unused data
3. **Later**: Create pure React template path
4. **Eventually**: Eliminate Mason2 entirely

Each phase is independent and brings value. We can pause at any phase if needed.

**Next Action**: ~~Wait for approval to execute Phase 1 changes.~~ **COMPLETE!**

---

## Phase 1 Completion Report

**Completed**: November 21, 2025

### Changes Made:

1. **templates/nodelets/epicenter.mi** - Added `has 'react_handled' => (isa => 'Bool', default => 1);`
2. **templates/nodelets/readthis.mi** - Added `has 'react_handled' => (isa => 'Bool', default => 1);`
3. **templates/nodelets/master_control.mi** - Added `has 'react_handled' => (isa => 'Bool', default => 1);`

### Testing Results:

✅ **HTML Verification**:
- Epicenter nodelet div is empty (no Mason2 content)
- ReadThis nodelet div is empty (no Mason2 content)
- MasterControl nodelet div is empty (no Mason2 content)
- React root div present and functional

✅ **Smoke Tests**: 159/159 documents passing
✅ **React Tests**: 209/209 tests passing
✅ **No Regressions**: All existing functionality works correctly

### User-Visible Changes:

- **No double rendering** - Each nodelet appears exactly once
- **React version active** - With ParseLinks, LinkNode, interactive features
- **Mason2 placeholders** - Empty divs remain for CSS targeting

### Success Metrics:

✅ No double rendering visible to users
✅ All tests pass
✅ No performance regression
✅ Clean separation of React and Mason2 rendering paths

### Next Steps:

Phase 1 is complete and stable. Ready to proceed with:
- **Phase 2**: Optimize Controller to skip building unused Mason2 data
- **Phase 3**: Create React-only template path
- **Phase 4**: Full Mason2 elimination

---

*Last Updated: November 21, 2025*
*Author: Claude (with Jay Bonci)*

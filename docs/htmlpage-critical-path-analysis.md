# HTMLPage Critical Path Analysis - User Content Journey

**Date**: 2025-11-26
**Focus**: Identifying user-facing content display pages vs obsolete code editing infrastructure

---

## Executive Summary - REVISED

After reviewing the actual code, the htmlpage system breaks down into **3 categories**:

1. **CRITICAL USER-FACING** (5 pages) - Core content display, blocking UX modernization
2. **OBSOLETE CODE EDITING** (~50 pages) - No longer used since code editing moved to GitHub
3. **ADMIN INFRASTRUCTURE** (~45 pages) - Low priority, can stay in Perl

**Key Discovery**: The critical pages are **thin orchestration layers** calling `htmlcode()` functions. Migrating them is simpler than initially thought.

---

## Category 1: CRITICAL USER-FACING PAGES (Priority 1)

These 5 pages are **the actual content journey** users experience:

### e2node_display_page ([htmlpage.pm:1061-1209](../ecore/Everything/Delegation/htmlpage.pm#L1061-L1209))
**Purpose**: Display container page with all writeups on a topic
**User Traffic**: 🔥🔥🔥 VERY HIGH - primary content discovery
**Complexity**: Medium (149 lines)

**What it does**:
```perl
my $str = htmlcode("votehead");                    # Voting header
$PAGELOAD->{admintools} = htmlcode('e2nodetools'); # Admin tools (if editor)
$str .= htmlcode('show writeups', $stuff);         # **MAIN CONTENT**
# Handle hidden writeups (lowrep, unfavorite, unpublished)
$str .= htmlcode("votefoot");                       # Voting footer
$str .= htmlcode("softlink");                       # Related links
$str .= htmlcode("addwriteup");                     # Add writeup form
```

**React Migration Path**:
- Extract htmlcode functions into Application.pm methods
- Pass structured data to React
- React component orchestrates sections

**Estimated Effort**: 8-12 hours (includes extracting htmlcode functions)

### writeup_display_page ([htmlpage.pm:1211-1254](../ecore/Everything/Delegation/htmlpage.pm#L1211-L1254))
**Purpose**: Display single writeup with voting/editing
**User Traffic**: 🔥🔥🔥 VERY HIGH - individual content view
**Complexity**: Low (44 lines)

**What it does**:
```perl
$str .= htmlcode("votehead");          # Voting header
$str .= htmlcode("show writeups");     # **MAIN CONTENT**
$str .= htmlcode("votefoot");          # Voting footer
$str .= htmlcode("writeuphints");      # Writing tips
$str .= htmlcode('softlink');          # Related links
$str .= htmlcode('editwriteup', $NODE); # Edit form (if permitted)
```

**React Migration Path**:
- Very similar to e2node_display, simpler
- Reuse components from e2node migration

**Estimated Effort**: 4-6 hours

### user_display_page ([htmlpage.pm - need to find](../ecore/Everything/Delegation/htmlpage.pm))
**Purpose**: User profile/homenode display
**User Traffic**: 🔥🔥 HIGH - user profiles
**Complexity**: TBD (need to review code)

**React Migration Path**: TBD after code review

**Estimated Effort**: 6-10 hours

### superdoc_display_page ([htmlpage.pm:811-841](../ecore/Everything/Delegation/htmlpage.pm#L811-L841))
**Purpose**: Delegates to Everything::Delegation::document
**User Traffic**: 🔥🔥 HIGH - special content pages
**Complexity**: Low (31 lines)

**What it does**:
```perl
# Just a delegation wrapper
my $delegation = Everything::Delegation::document->can($doctitle);
return $delegation->($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
```

**React Migration Path**:
- **ALREADY IN PROGRESS** - This is Phase 4a!
- superdoc_display_page is just routing
- Real work is migrating document delegation functions to Everything::Page::*

**Estimated Effort**: 0 hours (already doing this)

### usergroup_display_page ([htmlpage.pm - need to find](../ecore/Everything/Delegation/htmlpage.pm))
**Purpose**: Display usergroup information/members
**User Traffic**: 🔥 MEDIUM - group pages
**Complexity**: TBD

**React Migration Path**: TBD after code review

**Estimated Effort**: 4-8 hours

---

## Category 2: OBSOLETE CODE EDITING PAGES (Ignore/Delete)

These pages were for editing code through the web UI. **No longer used** since code editing moved to GitHub PRs.

**Delete Candidates** (~50 functions):
- `htmlcode_edit_page` - Edit htmlcode through web UI ❌ OBSOLETE
- `htmlcode_display_page` - View htmlcode source ⚠️ Maybe useful for debugging?
- `htmlpage_edit_page` - Edit htmlpages ❌ OBSOLETE
- `container_edit_page` - Edit containers ❌ OBSOLETE
- `nodelet_edit_page` - Edit nodelets ❌ OBSOLETE
- `document_edit_page` - Edit documents ❌ OBSOLETE
- `maintenance_edit_page` - Edit cron jobs ❌ OBSOLETE
- `nodetype_edit_page` - Edit node types ❌ OBSOLETE
- `dbtable_edit_page` - Edit schema ❌ OBSOLETE
- `*_viewcode` pages - View code pages ❌ OBSOLETE
- `*_basicedit` pages - Generic field editors ❌ OBSOLETE

**Action**: Audit these, mark for deletion, remove from routing

---

## Category 3: ADMIN INFRASTRUCTURE (Low Priority)

**Keep as Perl delegation for now**:
- `maintenance_display_page` - View cron jobs (ops tool)
- `dbtable_display_page` - View schema (dev tool)
- `nodetype_display_page` - View type hierarchy (dev tool)
- `nodegroup_display_page` - View group membership
- `node_display_page` - Generic fallback viewer
- Various admin/debugging tools

**Rationale**: Admins can tolerate Perl UI, focus on user-facing content

---

## Revised Migration Strategy

### Phase 4a (Current): CONTINUE Document Migration
- ✅ Finish remaining 21 superdoc templates → React
- ✅ superdoc_display_page already routes to document delegation
- ✅ THIS IS THE RIGHT WORK TO BE DOING

### Phase 4b: EXTRACT HTMLCode Functions
**Before migrating display pages, extract htmlcode functions to Application.pm**

Critical functions to extract:
1. **show writeups** - Main content rendering
2. **votehead/votefoot** - Voting UI
3. **softlink** - Related links
4. **addwriteup** - New writeup form
5. **e2nodetools** - Admin tools
6. **writeuphints** - Writing tips

**Why extract first**:
- Htmlcode functions are used across multiple pages
- Can test extraction independent of React migration
- React migration becomes simpler data passing

**Estimated Effort**: 20-30 hours

### Phase 4c: Migrate Critical Display Pages
**After htmlcode extraction, migrate the 5 critical pages**

**Order**:
1. **writeup_display_page** (simplest, good learning)
2. **e2node_display_page** (builds on writeup)
3. **usergroup_display_page** (medium complexity)
4. **user_display_page** (most complex, profile pages)
5. **superdoc_display_page** (already done via document delegation)

**Estimated Effort**: 25-40 hours

### Phase 4d: Delete Obsolete Code
**After critical pages migrated, clean up**

- Remove ~50 obsolete `*_edit_page` and `*_viewcode` functions
- Remove database htmlpage records for obsolete pages
- Update routing to skip deleted pages

**Estimated Effort**: 8-12 hours

---

## Thin Wrapper Pattern

**Key Insight**: These display pages are **orchestration**, not implementation.

**Current Pattern**:
```perl
sub e2node_display_page {
  my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

  my $str = htmlcode("votehead");           # Call 1
  $str .= htmlcode('show writeups', $stuff); # Call 2 (MAIN)
  $str .= htmlcode("votefoot");             # Call 3
  $str .= htmlcode("softlink");             # Call 4
  $str .= htmlcode("addwriteup");           # Call 5

  return $str; # Concatenated HTML
}
```

**React Migration Pattern**:
```perl
# Everything::Page::e2node
sub buildReactData {
  my ($self, $REQUEST) = @_;

  my $node = $REQUEST->node;
  my $user = $REQUEST->user;

  return {
    type => 'e2node',
    writeups => $self->APP->get_writeups_for_node($node),
    votingData => $self->APP->get_voting_data($user, $node),
    softlinks => $self->APP->get_softlinks($node),
    canAddWriteup => $user->can_write_to_node($node),
    adminTools => $user->is_editor ? $self->APP->get_e2node_tools($node) : undef
  };
}
```

```javascript
// React component
const E2NodeDisplay = ({ data, user }) => {
  const { writeups, votingData, softlinks, canAddWriteup, adminTools } = data;

  return (
    <div className="e2node-display">
      <VotingHeader data={votingData} />
      <WriteupsList writeups={writeups} />
      {adminTools && <AdminTools tools={adminTools} />}
      <VotingFooter data={votingData} />
      <Softlinks links={softlinks} />
      {canAddWriteup && <AddWriteupForm />}
    </div>
  );
};
```

**Benefits**:
- Clean separation: data fetching vs presentation
- Reusable components (VotingHeader used by both e2node and writeup)
- Testable independently
- Modern UI/UX

---

## HTMLCode Extraction Strategy

**The Real Work**: Most complexity is in htmlcode functions, not display pages.

### High-Priority HTMLCode Functions

**1. show writeups** (CRITICAL)
- Renders all writeups on an e2node
- Handles: lowrep filtering, unfavorite filtering, unpublished drafts
- Complex: ~200-300 lines
- **Extract to**: `Application.pm::get_writeups_structure()`

**2. votehead / votefoot**
- Voting UI components
- Shows: upvote/downvote buttons, current vote
- **Extract to**: `Application.pm::get_voting_data()`

**3. softlink**
- Related links sidebar
- Shows: "Related nodes" section
- **Extract to**: `Application.pm::get_softlinks()`

**4. addwriteup**
- New writeup submission form
- Handles: permissions, textarea, submit button
- **Extract to**: `Application.pm::get_writeup_form_data()`

**5. e2nodetools**
- Admin tools for editors
- Actions: delete, move, edit, nuke
- **Extract to**: `Application.pm::get_e2node_admin_tools()`

### Medium-Priority HTMLCode Functions

**6. writeuphints**
- Writing tips/guidelines
- Simple content display
- **Extract to**: Could be content-only React

**7. parselinks (used in doctext)**
- Parse [bracket links] in content
- **Keep as server-side**: Security (XSS prevention)
- **Extract to**: `Application.pm::parse_and_sanitize_links()`

---

## Database Impact

### HTMLPage Records to Remove

After migration, delete obsolete htmlpage records:

```sql
-- Find obsolete code editing pages
SELECT h.htmlpage_id, n.title, h.displaytype
FROM htmlpage h
JOIN node n ON h.htmlpage_id = n.node_id
WHERE h.displaytype IN ('edit', 'viewcode', 'basicedit')
  AND n.title LIKE '%code%'
  OR n.title LIKE '%page%'
  OR n.title LIKE '%type%';

-- Estimated: ~50 records to delete
```

### HTMLPage Records to Keep

```sql
-- Critical display pages (migrate to React)
SELECT h.htmlpage_id, n.title
FROM htmlpage h
JOIN node n ON h.htmlpage_id = n.node_id
WHERE h.displaytype = 'display'
  AND n.title IN (
    'e2node display page',
    'writeup display page',
    'user display page',
    'usergroup display page',
    'superdoc display page'
  );

-- Admin/debug pages (keep as Perl)
-- maintenance_display_page, dbtable_display_page, etc.
```

---

## Timeline Estimate

### Revised Estimates (Based on thin wrapper insight)

**Phase 4a** (Current): Finish Document Migration
- Remaining: 21 superdoc pages
- Time: 2-3 weeks
- Status: IN PROGRESS ✅

**Phase 4b**: Extract HTMLCode Functions
- Functions: 7 critical functions
- Time: 3-4 weeks
- Effort: 20-30 hours
- Status: PLANNED

**Phase 4c**: Migrate Critical Display Pages
- Pages: 5 critical pages
- Time: 3-4 weeks
- Effort: 25-40 hours
- Status: PLANNED

**Phase 4d**: Clean Up Obsolete Code
- Actions: Delete ~50 obsolete pages
- Time: 1-2 weeks
- Effort: 8-12 hours
- Status: PLANNED

**Total Timeline**: 9-13 weeks (~2-3 months)

**Total Effort**: 53-82 hours

**Much More Achievable Than Original Estimate** (12-18 months)

---

## Recommended Action Plan

### Immediate (This Week)
- ✅ **CONTINUE Phase 4a** - Finish remaining superdoc/document migrations
- ✅ Complete content-only optimization patterns
- ❌ **DO NOT start htmlpage migration yet**

### Next Month
- **Start Phase 4b** - Extract first htmlcode function (`show writeups`)
- Create Application.pm methods that return structured data
- Test extraction doesn't break existing pages
- Gradually extract remaining 6 functions

### Following Month
- **Start Phase 4c** - Migrate writeup_display_page (simplest)
- Use extracted Application.pm methods
- Create React components for sections
- Test thoroughly before moving to next page

### Month 3
- Continue Phase 4c - e2node_display_page, user_display_page
- Phase 4d - Delete obsolete code
- **MASON2 CONTENT ELIMINATION COMPLETE**

---

## Questions for User (Answered by Context)

1. **Should we prioritize htmlpage migration?**
   - YES - It's critical path for UX modernization
   - BUT - Finish Phase 4a (documents) first
   - THEN - Extract htmlcode functions (Phase 4b)
   - FINALLY - Migrate display pages (Phase 4c)

2. **Can we delete obsolete code editing pages?**
   - YES - ~50 pages obsolete since GitHub migration
   - Audit first, but safe to delete
   - Major codebase simplification

3. **How complex is this migration?**
   - LESS than initially thought (thin wrappers)
   - Most work is extracting htmlcode functions
   - React migration becomes straightforward after extraction
   - 2-3 months vs 12-18 months

---

## Success Criteria

### Phase 4a Complete
- ✅ All 21 superdoc templates migrated to React
- ✅ Content-only optimization patterns established
- ✅ No more document delegation functions

### Phase 4b Complete
- ✅ 7 critical htmlcode functions extracted to Application.pm
- ✅ Functions return structured data, not HTML strings
- ✅ Existing Perl pages still work (backward compatible)
- ✅ Test coverage for extracted functions

### Phase 4c Complete
- ✅ 5 critical display pages migrated to React
- ✅ User content journey fully React-based
- ✅ Voting, writeup display, profiles all modern UI
- ✅ No regressions in functionality

### Phase 4d Complete
- ✅ ~50 obsolete htmlpage functions deleted
- ✅ Database htmlpage records cleaned up
- ✅ Codebase 10-15% smaller
- ✅ **MASON2 CONTENT ELIMINATION COMPLETE**

---

## Appendix: HTMLCode Function Locations

All htmlcode functions are in [Everything::Delegation::htmlcode.pm](../ecore/Everything/Delegation/htmlcode.pm) (13,000+ lines)

**To find a function**:
```bash
grep -n "^sub show_writeups" ecore/Everything/Delegation/htmlcode.pm
grep -n "^sub votehead" ecore/Everything/Delegation/htmlcode.pm
grep -n "^sub softlink" ecore/Everything/Delegation/htmlcode.pm
```

**Extraction pattern**:
1. Find function in htmlcode.pm
2. Understand data dependencies
3. Create Application.pm method returning structured data
4. Update htmlcode function to call Application.pm method (backward compat)
5. Test both old (HTML string) and new (structured data) paths work
6. React uses Application.pm method directly

This allows gradual migration without breaking existing Perl pages.

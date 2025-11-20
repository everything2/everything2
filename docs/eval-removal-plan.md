# eval() Removal Plan - Everything2 Security & Performance Initiative

## Executive Summary

This document outlines a comprehensive plan to remove all `eval()` calls from the Everything2 codebase. Removing eval() will:
- **Close major security vulnerabilities** - Code evaluation on user input is a critical security risk
- **Enable Devel::NYTProf profiling** - eval() blocks proper performance profiling
- **Improve code maintainability** - Static code is easier to understand and debug
- **Reduce runtime errors** - Compile-time checking catches more bugs

**IMPORTANT NOTE:** Mason templates in XML node files are NOT a security risk. They are controlled server-side templates that don't process user input. The migration of these templates (like the recent oppressor_superdoc work) is for architecture simplification, not security.

## Recently Completed (2025-11-19)

### ✅ ajax_update Opcode eval() Removal - COMPLETED

**Location:** `ecore/Everything/Delegation/document.pm` (ajax_update function)

**What Was Fixed:**
Two eval() calls in the ajax_update function were replaced with direct delegation calls:

1. **Message Mode** (line 22683):
   - **Removed:** `my $op = getNode('message','opcode'); eval($$op{code});`
   - **Replaced with:** `Everything::Delegation::opcode::message($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);`

2. **Vote Mode** (line 22688):
   - **Removed:** `my $op = getNode('vote','opcode'); eval($$op{code});`
   - **Replaced with:** `Everything::Delegation::opcode::vote($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);`

**Module Import Added:**
Added `use Everything::Delegation::opcode;` to document.pm to support the delegation calls.

**Benefits Achieved:**
- ✅ Eliminated eval() security risks for voting and messaging
- ✅ Removed 2 database queries (getNode() calls) per operation
- ✅ Removed 2 Perl::Critic violations
- ✅ Clearer code path for debugging

**Documentation:**
- Updated `/docs/ajax_update_system_analysis.md` with detailed before/after analysis
- Documented all 12 ajax_update modes

---

## Current eval() Usage Analysis

### Location Summary

Based on codebase analysis, eval() usage falls into these categories:

#### 1. **parseCode/embedCode System** (HIGHEST PRIORITY - SECURITY CRITICAL)
**Files:**
- `ecore/Everything/HTML.pm` - Core parseCode/embedCode/evalCode implementation
- Multiple delegation files importing parseCode

**Security Risk:** This system evaluates arbitrary Perl code that may come from user input (homenodes, user-generated content, etc.)

**Usage Pattern:**
```perl
# parseCode processes: [% perl %], [{ htmlcode }], [" variable "]
# Then calls evalCode which does: eval $code
$text =~ s/\[(.*?)\]/embedCode("$1")/egsx;
```

**Critical parseCode() Call Sites (User Content):**
- `ecore/Everything/Delegation/htmlcode.pm:1355` - **Superdoc processing** (may process user content)
- `ecore/Everything/Delegation/document.pm:19845` - **User nlcode** (user homenode code - HIGH RISK)
- `ecore/Everything/HTML.pm:828` - Legacy displayPage path (depends on content source)

**Other parseCode() Calls (Need Investigation):**
- `ecore/Everything/Delegation/htmlpage.pm:1819` - document display
- `ecore/Everything/Delegation/htmlpage.pm:3758` - fullpage display
- `ecore/Everything/Delegation/htmlcode.pm:904` - text processing
- `ecore/Everything/Delegation/htmlcode.pm:8049` - content processing
- `ecore/Everything/Delegation/htmlcode.pm:8196` - node doctext
- `ecore/Everything/Delegation/htmlcode.pm:12333` - page display
- `ecore/Everything/Delegation/htmlcode.pm:12715` - inline code
- `ecore/Everything/Delegation/document.pm:2724` - document doctext

**Core Implementation:**
- `ecore/Everything/HTML.pm:603-623` - `evalCode()` function (does the actual eval)
- `ecore/Everything/HTML.pm:684-715` - `embedCode()` function (parser)
- `ecore/Everything/HTML.pm:719-745` - `parseCode()` function (entry point)

**Estimated Instances:** 15+ direct calls, plus the core implementation

#### 2. **PluginFactory eval() - Module Loading** (HIGH PRIORITY)
**File:** `ecore/Everything/PluginFactory.pm:60`

**Usage:**
```perl
eval("use $evalclass") or do { if($@){$self->errors->{"$evalclass"} = $@} };
```

**Purpose:** Dynamic module loading for plugins

**Replacement Strategy:** Generate static plugin list at build time

#### 3. **Data Structure eval() - Deserialization** (MEDIUM PRIORITY)
**Files:**
- `ecore/Everything/Delegation/htmlcode.pm:3670` - Weblog special handler (dynamic subroutine creation)
- `ecore/Everything/Delegation/htmlcode.pm:13649` - Node data deserialization
- `ecore/Everything/Delegation/document.pm:18934` - Tomb data (nodeproto)
- `ecore/Everything/Delegation/document.pm:21235` - Node crypt data
- `ecore/Everything/API.pm:93` - Subroutine reference eval

**Usage Pattern:**
```perl
# Data deserialization
my $DATA = eval('my ' . $N->{data});

# Dynamic subroutine creation (weblog)
eval( q|$weblogspecials{ remove } = sub { ... }|);
```

**Replacement Strategy:**
- For data: Use JSON or proper Perl serialization (Storable/JSON::XS)
- For dynamic subs: Refactor to static function with parameters

#### 4. **Error Handling eval() - Exception Catching** (LOW PRIORITY)
**Files:**
- `ecore/Everything/NodeBase.pm:924, 2639` - Database operation error handling
- `ecore/Everything/Delegation/document.pm:19373, 19419, 19779, 19805, 20331` - SQL error handling
- `ecore/Everything/Delegation/htmlcode.pm:13512` - Try/catch block

**Usage Pattern:**
```perl
eval { $DB->{dbh}->do($sql) };
```

**Note:** These are block eval{}, not string eval(), and are **safe to keep**. They're used for exception handling, not code evaluation.

#### 5. **JavaScript eval() - Client-side** (OUT OF SCOPE)
**Files:**
- `ecore/Everything/Delegation/htmlcode.pm:611, 612` - Form eval in JavaScript
- `ecore/Everything/Delegation/document.pm:12645` - Radio button JavaScript

**Note:** These are JavaScript `eval()` calls in strings, not Perl eval(). Should be addressed in separate JavaScript modernization effort.

## Removal Priority & Roadmap

### Phase 1: parseCode/embedCode Removal (CRITICAL - Weeks 1-4)

**Goal:** Eliminate all code evaluation from user-generated content

**Security Context:**
- The parseCode system allows `[% perl code %]`, `[{ htmlcode }]`, `[" variables "]` in content
- **HIGHEST RISK:** User homenode code (nlcode) processed through parseCode at document.pm:19845
- **MEDIUM RISK:** Superdoc content that may contain user input
- **LOWER RISK:** Static admin-only content (but still architectural cleanup needed)

**Strategy:**
1. **Immediate:** Disable parseCode on user-generated content (homenodes, user nlcode)
2. **Short-term:** Replace remaining parseCode() calls with safe alternatives
3. **Long-term:** Remove embedCode/evalCode/parseCode functions entirely

**Steps:**
1. ✅ Audit all parseCode() call sites (DONE - see above)
2. ⬜ **URGENT:** Investigate user nlcode usage (document.pm:19845)
   - Determine if users can still create new nlcode
   - Plan migration path for existing user nlcode
   - Disable eval() on user content ASAP
3. ⬜ Audit each parseCode() call site to determine:
   - Does it process user input? (SECURITY CRITICAL)
   - Does it process admin-only content? (CLEANUP)
   - Can it be replaced with delegation calls?
4. ⬜ For user content sites:
   - Disable parseCode immediately (breaking change but necessary for security)
   - Migrate existing user nlcode to safe alternatives
   - Notify users of deprecated features
5. ⬜ For admin content sites:
   - Replace with direct delegation function calls
   - Migrate any remaining embedded code to delegation functions
6. ⬜ Remove parseCode() calls from delegation functions
7. ⬜ Deprecate parseCode/embedCode/evalCode functions
8. ⬜ Remove deprecated functions after verification

**Testing Strategy:**
- **Security testing:** Verify no user input reaches eval()
- Functional testing for each call site
- User communication plan for breaking changes
- Regression test all affected pages

**Estimated Effort:** 2-3 weeks (shorter if we disable user nlcode immediately)

### Phase 2: PluginFactory Static Plugin List (HIGH - Week 5)

**Goal:** Replace dynamic module loading with static plugin list

**Current Implementation:**
```perl
eval("use $evalclass")
```

**Replacement:**
```perl
# Build-time generation of plugin list
my %STATIC_PLUGINS = (
    'HTMLRouter' => 'Everything::Router::HTMLRouter',
    'JSONRouter' => 'Everything::Router::JSONRouter',
    # ... all plugins enumerated
);

# Runtime usage:
my $class = $STATIC_PLUGINS{$pluginname};
require $class if $class;  # or use Module::Runtime
```

**Steps:**
1. ⬜ Audit all plugins in `ecore/Everything/` subdirectories
2. ⬜ Create build script to generate static plugin map
3. ⬜ Update PluginFactory to use static map
4. ⬜ Test plugin loading with static list
5. ⬜ Remove eval() from PluginFactory

**Testing Strategy:**
- Verify all plugins load correctly
- Test each plugin type (Router, Delegation, etc.)
- Check for missing plugins

**Estimated Effort:** 1 week

### Phase 3: Data Deserialization (MEDIUM - Week 6)

**Goal:** Replace eval() deserialization with safe alternatives

**Current Usage:**
- Node data structures stored as Perl code strings
- eval() used to deserialize back to data structures

**Replacement Options:**

**Option A: JSON (Recommended)**
```perl
# Serialize:
$node->{data} = encode_json($data_structure);

# Deserialize:
my $DATA = decode_json($node->{data});
```

**Option B: Storable**
```perl
# Serialize:
$node->{data} = freeze($data_structure);

# Deserialize:
my $DATA = thaw($node->{data});
```

**Steps:**
1. ⬜ Identify all data fields using eval() deserialization:
   - Weblog special handler in htmlcode:3670 ✅ TO REMOVE (refactor to static function)
   - Node `data` field in htmlcode:13649 ✅ TO REMOVE
   - ~~Tomb `data` field in document.pm:18934~~ ⏸️ RETAINED (see Tomb Exception below)
   - Node crypt `data` field in document.pm:21235 ✅ TO REMOVE
   - API subroutine reference in API.pm:93 ✅ TO INVESTIGATE (may move to Phase 4)
2. ⬜ Choose serialization format (recommend JSON for readability)
3. ⬜ Create migration script to convert existing data (excluding tomb)
4. ⬜ Update write paths to use new serialization
5. ⬜ Update read paths to use new deserialization
6. ⬜ Handle backward compatibility during transition
7. ⬜ Remove eval() calls after full migration (excluding tomb)

**Migration Strategy:**
```perl
# Hybrid approach during transition:
my $DATA;
if ($node->{data} =~ /^{/) {  # JSON
    $DATA = decode_json($node->{data});
} else {  # Legacy Perl code
    $DATA = eval('my ' . $node->{data});  # Keep temporarily
}
```

**Testing Strategy:**
- Test data round-trip (serialize -> deserialize)
- Verify all existing data migrates correctly
- Check for data corruption

**Estimated Effort:** 1 week

#### Tomb eval() Exception - Must Retain

**IMPORTANT:** The eval() used for tomb deserialization (`document.pm:18934` - Dr. Nate's Secret Lab) **MUST BE RETAINED** due to fundamental architecture constraints.

**Why Tomb Uses eval():**
- Tomb stores deleted nodes as Data::Dumper serialized Perl data structures in the database
- These structures must be deserialized using eval() to restore the original node objects
- This allows admins to inspect and potentially restore deleted nodes

**Why We Can't Remove It (Yet):**

**Ideal Solution:** Eliminate tomb entirely by implementing soft deletes (tombstone records)
- Add `deleted` flag to the `node` table instead of moving nodes to separate tomb table
- Preserves referential integrity while maintaining deletion history
- Allows queries to include/exclude deleted nodes as needed

**Challenge:** This is a foundational data model change that breaks core assumptions:
- `getNode()` and related functions assume nodes are either present or completely gone
- Would require special handling throughout codebase to filter deleted nodes
- Database queries would need modification to handle deleted flag
- Significant testing required to ensure no unintended access to deleted content

**Interim Solution:** Migrate tomb from Data::Dumper to Storable
- More secure serialization format than Data::Dumper eval()
- Still requires deserialization but without arbitrary code execution
- **Challenge:** Requires batch conversion of entire tomb table
- **Complexity:** Different Data::Dumper formats in existing tomb records make migration non-trivial
- Multi-step process with potential compatibility issues

**Security Assessment:** ✅ NOT A SECURITY CONCERN
- Dr. Nate's Secret Lab is admin-only restricted superdoc
- Only trusted administrators can access tomb functionality
- Node ownership restricted to admin usergroup
- No user input processed through this eval()

**Recommendation:**
- **Short-term:** Keep tomb eval() as-is (safe due to admin-only access)
- **Medium-term:** Consider Storable migration if profiling shows tomb as bottleneck
- **Long-term:** Implement soft delete architecture as part of broader data model improvements

**Status:** ⏸️ **DEFERRED** - Tomb eval() will remain until soft delete architecture is implemented

### Phase 4: API Subroutine eval() (LOW - Week 7)

**Goal:** Remove subroutine reference eval() in API.pm:93

**Current Usage:**
```perl
eval ("\$subroutineref = $perlcode")
```

**Investigation Needed:**
- Understand use case for this eval()
- Determine if still needed or legacy code
- Find safer alternative if needed

**Steps:**
1. ⬜ Investigate API.pm:93 usage context
2. ⬜ Determine if functionality still required
3. ⬜ Design replacement if needed (possibly delegation pattern)
4. ⬜ Implement replacement
5. ⬜ Test thoroughly
6. ⬜ Remove eval()

**Estimated Effort:** 3-5 days

### Phase 5: JavaScript eval() Remediation (DEFERRED)

**Note:** JavaScript `eval()` calls should be addressed in separate JavaScript modernization initiative.

**Files to address later:**
- `ecore/Everything/Delegation/htmlcode.pm:611, 612`
- `ecore/Everything/Delegation/document.pm:12645`

## Verification & Testing Plan

### Per-Phase Testing
- Unit tests for each modified function
- Integration tests for affected workflows
- Regression tests for unchanged functionality

### Final Verification
1. ⬜ Run full test suite
2. ⬜ Verify no eval() in production code paths:
   ```bash
   grep -r "eval\s*[(\"]" ecore/ --include="*.pm" | grep -v "## no critic" | grep -v "^#"
   ```
3. ⬜ Enable Devel::NYTProf and verify profiling works
4. ⬜ Security audit - confirm no code evaluation paths remain
5. ⬜ Performance testing - verify no regressions
6. ⬜ Load testing in staging environment

### Documentation Updates
- ⬜ Update coding standards to prohibit eval()
- ⬜ Document new serialization format
- ⬜ Update delegation migration guide
- ⬜ Add eval() to forbidden patterns in code review checklist

## Risk Mitigation

### Identified Risks
1. **Breaking existing functionality** - Comprehensive testing required
2. **Data migration failures** - Need rollback plan for Phase 3
3. **Performance regressions** - Benchmark before/after
4. **Incomplete migration** - Thorough grep audits needed

### Mitigation Strategies
- Feature flagging for major changes
- Parallel running of old/new code during transition
- Extensive staging environment testing
- Incremental rollout to production
- Quick rollback procedures

## Success Criteria

### Phase 1 Complete When:
- ✅ All parseCode() calls removed from production code paths
- ✅ All Mason-style templates migrated to delegation functions
- ✅ Test suite passes
- ✅ No regression in functionality

### Phase 2 Complete When:
- ✅ PluginFactory uses static plugin list
- ✅ No eval() in module loading
- ✅ All plugins load correctly

### Phase 3 Complete When:
- ✅ All data fields use JSON/Storable serialization
- ✅ No eval() for data deserialization
- ✅ Data integrity verified

### Project Complete When:
- ✅ All Perl string eval() removed from ecore/
- ✅ Devel::NYTProf profiling functional
- ✅ Security audit passes
- ✅ All tests pass
- ✅ Documentation updated

## Timeline

**Total Estimated Duration:** 7 weeks

- **Weeks 1-4:** Phase 1 - parseCode/embedCode removal
- **Week 5:** Phase 2 - PluginFactory static list
- **Week 6:** Phase 3 - Data deserialization
- **Week 7:** Phase 4 - API cleanup + final verification

## parseCode Investigation Findings (2025-11-18)

**CRITICAL FINDING:** After systematic investigation of all parseCode() call sites, **NO USER-GENERATED CONTENT IS CURRENTLY PROCESSED THROUGH parseCode()**.

### Investigation Results:

All 11 parseCode() calls fall into these categories:

#### 1. Admin-Only Content (No Security Risk)
- `htmlcode.pm:1355` - Superdoc doctext (type_nodetype == 14) - Admin-controlled superdocs
- `htmlcode.pm:8049` - xmlsuperdoctext - Admin-controlled superdocs
- `htmlcode.pm:8196` - xmlsuggestion - System content
- `document.pm:19845` - Nodelet nlcode - Admin-only, deprecated (all current nodelets have empty nlcode)

#### 2. System-Controlled Content (No Security Risk)
- `document.pm:2724` - not_found_node doctext - System node
- `htmlcode.pm:12333` - Legacy PAGE{page} fallback - System page templates
- `htmlpage.pm:1819` - document_display_page - Document type doctext (✅ VERIFIED: Only Content Editors usergroup can create/edit)
- `htmlpage.pm:3758` - fullpage display - PAGE{page} system templates

#### 3. Static Code (No Security Risk)
- `htmlcode.pm:904` - parsecode htmlcode (NOT CALLED ANYWHERE)
- `htmlcode.pm:12715` - Static hardcoded preference form string

### Security Assessment:

**Previous Assessment:** "HIGHEST RISK - User nlcode (homenode code) at document.pm:19845"

**Actual Finding:** The nlcode at document.pm:19845 is:
- On **nodelet** nodes, not user homenodes
- Used only in admin-only function `nate_s_secret_unborg_doc` (checks `isAdmin($USER)`)
- All nodelets in codebase have **empty** nlcode fields
- Modern nodelets use delegation functions instead
- This is deprecated legacy code, not active user feature

**Revised Risk Level:**
- **Direct security risk: MINIMAL** - No parseCode calls on user-controllable content found
- **Indirect risk: MODERATE** - Future developers could accidentally add parseCode on user content
- **Architectural technical debt: HIGH** - parseCode prevents profiling and is complexity debt

### Revised Priorities:

The removal of parseCode is still important for these reasons:

1. **Development governance** - CRITICAL: Ensure all code changes go through GitHub workflow with testing, review, and build processes
2. **Enable Devel::NYTProf profiling** - parseCode blocks performance analysis
3. **Architectural cleanup** - Remove eval() technical debt
4. **Future-proof security** - Prevent accidental introduction of code eval on user content
5. **Continue superdoc migration** - Move remaining superdocs to delegation functions

### Document Type Permissions Verification:

**Finding:** Document and oppressor_document types restricted to Content Editors usergroup (923653):
- `document` type (node_id: 3): `writers_user: 923653`, `deleters_user: 923653`
- `oppressor_document` type (node_id: 1983713): `writers_user: 923653`, `readers_user: 923653`, `deleters_user: 923653`

**Conclusion:** Regular users CANNOT create or edit document type nodes. All document doctext is admin-controlled.

### Final Security Verdict:

**✅ NO MALICIOUS CODE INJECTION VULNERABILITY FOUND**

All parseCode() calls process admin-controlled or system content only. No user-generated content is evaluated through parseCode().

**⚠️ DEVELOPMENT GOVERNANCE ISSUE REMAINS**

While there's no risk of malicious code injection, there IS a process problem:
- Former admins who still own superdocs/documents can edit them directly through web interface
- These edits bypass proper development workflows:
  - No GitHub PR review
  - No automated testing
  - No build verification
  - No version control history
  - No team visibility
- Changes go directly to production without validation

**Conclusion:** parseCode removal remains HIGH PRIORITY for development governance, not malicious attack prevention.

### Recommended Next Steps (Priority Order):

1. ✅ **Verify document type permissions** - COMPLETED - Only Content Editors can create/edit documents
2. ⬜ **HIGH PRIORITY: Continue superdoc migration** - Move ALL remaining type 14 superdocs to delegation functions
   - Prevents former admins from editing code through web interface
   - Ensures all code changes go through GitHub PR workflow
   - See Appendix B for list of remaining superdocs with doctext
3. ⬜ **Remove low-hanging fruit** - Delete unused parsecode htmlcode (904), remove static parseCode call (12715)
4. ⬜ **Deprecate legacy PAGE parseCode** - Migrate remaining PAGE{page} calls to delegation
5. ⬜ **Remove parseCode/embedCode/evalCode** - After all call sites migrated
6. ⬜ **Enable Devel::NYTProf** - Verify profiling works
7. ⬜ **Audit superdoc/document ownership** - Review which former admins still own editable nodes

## Next Steps

1. Review and approve revised findings and priorities
2. Verify document type permissions to confirm no user access
3. Begin systematic parseCode removal (architectural cleanup, not emergency security fix)
4. Continue with other eval() removal phases (PluginFactory, data deserialization)
5. Track progress via GitHub issues/project board

## Appendix A: eval() Inventory

### String eval() (Must Remove)
- `ecore/Everything/PluginFactory.pm:60` - Module loading
- `ecore/Everything/HTML.pm` - embedCode/evalCode implementation
- `ecore/Everything/Delegation/htmlcode.pm:3670` - Weblog special handler (dynamic subroutine creation)
- `ecore/Everything/Delegation/htmlcode.pm:13649` - Data deserialize (was 13630 in earlier analysis)
- ~~`ecore/Everything/Delegation/document.pm:18934` - Tomb data~~ ⏸️ **RETAINED** - See Phase 3 Tomb Exception
- `ecore/Everything/Delegation/document.pm:21235` - Crypt data
- `ecore/Everything/API.pm:93` - Subroutine reference
- ~~`ecore/Everything/Delegation/document.pm:22683` - ajax_update message mode~~ ✅ **COMPLETED** (2025-11-19)
- ~~`ecore/Everything/Delegation/document.pm:22688` - ajax_update vote mode~~ ✅ **COMPLETED** (2025-11-19)

### Block eval{} (Safe - Keep)
- `ecore/Everything/NodeBase.pm:924, 2639` - Error handling
- `ecore/Everything/Delegation/document.pm:19373, 19419, 19779, 19805, 20331` - SQL error handling
- `ecore/Everything/Delegation/htmlcode.pm:13512` - Try/catch

### JavaScript eval() (Separate Initiative)
- `ecore/Everything/Delegation/htmlcode.pm:611, 612` - Form JavaScript
- `ecore/Everything/Delegation/document.pm:12645` - Radio JavaScript

## evalCode() Usage Analysis

### Overview

`evalCode()` is the core eval() function in Everything2 that evaluates arbitrary Perl code strings. It's used as the underlying implementation for `parseCode()`, `embedCode()`, and several specialized systems.

**Location:** `ecore/Everything/HTML.pm:603-623`

**Function Signature:**
```perl
sub evalCode {
  my ($code, $CURRENTNODE) = @_;
  # Sets up context variables: $NODE, $GNODE, $USER, $VARS, etc.
  ## no critic (ProhibitStringyEval)
  my $str = eval $code;
  # Error handling and formatting
  return $str;
}
```

### evalCode() Call Sites (4 total)

#### 1. embedCode() Internal Use (2 calls) - Part of parseCode System

**Locations:**
- `ecore/Everything/HTML.pm:702` - Variable resolution in htmlcode arguments
- `ecore/Everything/HTML.pm:707` - Perl code block execution

**Usage Pattern:**
```perl
# Line 702: Resolve variables in [{ htmlcode:args }]
$args = evalCode('"'.$args.'"');  # Interpolate variables

# Line 707: Execute [% perl code %] blocks
$block = evalCode($block, @_);
```

**Context:**
- Called by `embedCode()` function which processes `[{ }]` and `[% %]` tags
- Used by `parseCode()` which calls `embedCode()`
- Part of the legacy template system
- **Will be removed when parseCode/embedCode are removed**

**Security:**
- Same security profile as parseCode (processes admin-controlled content)
- No direct user input reaches these eval() calls

---

#### 2. jsonexport_display_page (1 call) - JSON Structure Generation

**Location:** `ecore/Everything/Delegation/htmlpage.pm:2512`

**Usage Pattern:**
```perl
sub jsonexport_display_page {
  my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;
  my $json_struct = evalCode($NODE->{code});
  return encode_json($json_struct);
}
```

**Context:**
- Evaluates the {code} field of jsonexport nodes
- The code field contains Perl code that returns a data structure
- That structure is then JSON-encoded and returned
- Only 1 jsonexport nodetype exists in the system
- Used for admin utility/debugging purposes

**Nodes Using This:**
- `jsonexport` nodetype (extends htmlcode type)
- `jsonexport display page` htmlpage

**Security Assessment:** ✅ **LOW RISK**
- Admin-controlled nodetype (no user access)
- Utility feature for debugging/exporting data structures
- Code field can only be edited by admins

**Removal Strategy:**
- **Option A:** Keep as admin debugging tool (low priority)
- **Option B:** Convert to delegation-based JSON builders
- **Recommended:** LOW PRIORITY - defer until Phases 1-3 complete

---

#### 3. Achievement Checking (1 call) - hasAchieved Function

**Location:** `ecore/Everything/Delegation/htmlcode.pm:9175`

**Usage Pattern:**
```perl
# Check for delegation function first
my $achtitle = $$ACH{title};
$achtitle =~ s/[\s-]/_/g;
$achtitle =~ s/[^A-Za-z0-9_]/_/g;
$achtitle = lc($achtitle);

my $result;
if(my $delegation = Everything::Delegation::achievement->can($achtitle)) {
  $APP->devLog("Using achievement delegation for '$$ACH{title}' as '$achtitle'");
  $result = $force || $delegation->($DB, $APP, $user_id);
} else {
  # Fall back to eval of {code} field for unmigrated achievements
  $result = $force || evalCode("my \$user_id = $user_id;\n$$ACH{code}", $NODE);
}
```

**Context:**
- Checks if a user has earned a specific achievement
- 45 achievement nodes exist in `nodepack/achievement/`
- 45 delegation functions already exist in `Everything::Delegation::achievement`
- evalCode is now the **fallback** for unmigrated achievements
- System already checks for delegation first

**Achievement Architecture:**
- **Old system:** Achievement {code} field contains Perl condition
- **New system:** Static delegation function in `Everything::Delegation::achievement`
- **Examples:**
  ```perl
  # Old: achievement XML <code> field
  <code>return 1 if $$USER{karma} >= 20;
  return 0;</code>

  # New: delegation function
  sub karma20 {
    my ($DB, $APP, $user_id) = @_;
    my $USER = getNodeById($user_id);
    return 1 if $$USER{karma} >= 20;
    return 0;
  }
  ```

**Migration Status:**
- ✅ 45 achievement delegations created
- ⬜ Need to verify all achievements have delegations
- ⬜ Remove evalCode fallback after verification

**Security Assessment:** ✅ **NO RISK**
- Achievement nodes are admin-controlled
- Code field can only be edited by admins
- No user input reaches evalCode

**Removal Strategy:**
1. ⬜ Audit all 45 achievements to verify delegation exists
2. ⬜ Migrate any remaining achievements without delegations
3. ⬜ Test achievement checking with delegation-only code
4. ⬜ Remove evalCode fallback from htmlcode.pm:9175
5. ⬜ Empty all achievement {code} fields in XML

**Estimated Effort:** 1-2 days

---

#### 4. Notification Rendering (1 call) - get_notification Function

**Location:** `ecore/Everything/Delegation/htmlcode.pm:11327`

**Usage Pattern:**
```perl
my $invalidCheckCode = $notification->{invalid_check};
my $argJSON = $$notify{args};
my $args = &$safe_JSON_decode($argJSON);

my $evalNotify = sub {
  my $notifyCode = shift;
  my $wrappedNotifyCode = "sub { my \$args = shift; 0; $notifyCode };";
  my $wrappedSub = evalCode($wrappedNotifyCode);
  return &$wrappedSub($args);
};

# Don't return an invalid notification and remove it from the notified table
if ($invalidCheckCode ne '' && &$evalNotify($invalidCheckCode)) {
  $DB->sqlDelete('notified', 'notified_id = ' . int($$notify{notified_id}));
  next;
}

# Render notification message
$notificationCode = $notification->{code};
$html .= '<li>'.$type.': '.&$evalNotify($notificationCode).'</li>';
```

**Context:**
- Renders notification messages for users
- 23 notification types exist in `nodepack/notification/`
- Each notification has two code fields:
  - `{code}`: Generates the notification message text
  - `{invalid_check}`: Validates if notification should still be shown
- Creates dynamic subroutines from code strings at runtime
- Arguments passed as JSON, decoded and passed to generated sub

**Notification Fields:**
```xml
<!-- Example: voting notification -->
<code>my $str;
if ($$args{weight} > 0) {
  $str .= "Someone upvoted ";
} else {
  $str .= "Someone downvoted ";
}
if ($$args{node_id}) {
  $str .= linkNode($$args{node_id});
}
return $str;</code>
<invalid_check></invalid_check>
```

**Notification Types (23 total):**
- voting, newcomment, newdiscussion, nodenote, socialbookmark
- weblog, writeupedit, achievement, message, etc.

**Security Assessment:** ✅ **NO RISK**
- Notification nodes are admin-controlled
- Code fields can only be edited by admins
- User args are JSON-decoded (not eval'd)
- No user input reaches evalCode

**Architectural Issues:**
- Dynamic subroutine creation at runtime is inefficient
- Creates a new anonymous sub for EVERY notification rendered
- Makes profiling difficult
- Adds unnecessary complexity

**Removal Strategy:**

**Option A: Delegation Functions (Recommended)**
```perl
# Create Everything::Delegation::notification module
package Everything::Delegation::notification;

sub voting {
  my ($args) = @_;
  my $str;
  if ($$args{weight} > 0) {
    $str .= "Someone upvoted ";
  } else {
    $str .= "Someone downvoted ";
  }
  if ($$args{node_id}) {
    $str .= linkNode($$args{node_id});
  }
  return $str;
}

sub voting_invalid_check {
  my ($args) = @_;
  # Return 1 if notification should be hidden
  return 0;
}
```

**Option B: Template-Based**
- Use simple string templates with variable substitution
- Would work for simple notifications
- Complex logic would still need delegation functions

**Recommended Approach:**
1. ⬜ Create `Everything::Delegation::notification` module
2. ⬜ Migrate each of 23 notifications to delegation functions
3. ⬜ Update `get_notification` to use delegation lookup
4. ⬜ Test notification rendering
5. ⬜ Remove evalCode calls
6. ⬜ Empty notification {code} and {invalid_check} fields

**Performance Benefits:**
- Static functions vs runtime subroutine generation
- Better profiling support
- Clearer code path for debugging
- Follows established delegation pattern

**Estimated Effort:** 2-3 days

---

### evalCode() Removal Summary

**Total Call Sites:** 4

**Removal Priority:**

1. **HIGHEST:** embedCode calls (lines 702, 707)
   - ✅ Will be removed automatically when parseCode/embedCode removed (Phase 1)
   - No separate work required

2. **HIGH:** Achievement checking (line 9175)
   - ⏱️ 1-2 days effort
   - 45 delegations already exist
   - Just needs verification and fallback removal

3. **MEDIUM:** Notification rendering (line 11327)
   - ⏱️ 2-3 days effort
   - 23 notifications to migrate
   - Architectural improvement + eval removal

4. **LOW:** jsonexport (line 2512)
   - ⏱️ DEFER to later phase
   - Admin debugging tool
   - Low risk, low priority

**Total Estimated Effort:** 3-5 days (after parseCode removal)

---

## Appendix B: parseCode Usage Sites

All parseCode() call sites documented for Phase 1:

1. `ecore/Everything/HTML.pm:828` - Legacy displayPage path
2. `ecore/Everything/Delegation/htmlpage.pm:1819` - Document display
3. `ecore/Everything/Delegation/htmlpage.pm:3758` - Fullpage display
4. `ecore/Everything/Delegation/htmlcode.pm:904` - Text processing
5. `ecore/Everything/Delegation/htmlcode.pm:1355` - Superdoc processing
6. `ecore/Everything/Delegation/htmlcode.pm:8049` - Content processing
7. `ecore/Everything/Delegation/htmlcode.pm:8196` - Node doctext
8. `ecore/Everything/Delegation/htmlcode.pm:12333` - Page display
9. `ecore/Everything/Delegation/htmlcode.pm:12715` - Inline code
10. `ecore/Everything/Delegation/document.pm:2724` - Document doctext
11. `ecore/Everything/Delegation/document.pm:19845` - User nlcode

Plus 4 locations importing/aliasing parseCode function.

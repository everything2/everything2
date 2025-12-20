# Everything2 API Testing Comprehensive Plan

**Created**: 2025-12-16
**Last Updated**: 2025-12-17
**Status**: Phase 1 Complete - Moving to Phase 2
**Owner**: Claude (AI Assistant)

## Executive Summary

This document outlines a comprehensive plan to bring all Everything2 APIs to production readiness by:
1. Retiring legacy APIClient integration tests in favor of modern mock-based unit tests
2. Adding comprehensive edge case testing for all APIs
3. Creating smoke tests for every API endpoint
4. Documenting all APIs with their current state and test coverage

## Current State Assessment

### API Inventory
- **Total API Files**: 50 (`ecore/Everything/API/*.pm`)
- **API Test Files**: 24 (`t/*api*.t`)
- **Legacy APIClient Tests**: 8 files using `Everything::APIClient`
- **Modern Mock Tests**: 16 files using mock patterns

### Recently Modernized APIs
- ✅ **vote.pm** - Modernized to RESTful routes, full mock tests (t/056_cool_api.t covers voting edge cases)
- ✅ **cool.pm** - Modernized to RESTful routes, full mock tests with Cool Man Eddie messages (44 tests passing)
- ✅ **admin.pm** - Has mock-based tests

### Legacy APIClient Tests ✅ CONVERTED (2025-12-17)
1. ✅ `t/004_messages.t` - Marked as obsolete (empty test)
2. ✅ `t/005_messageignores.t` → `t/063_messageignores_api.t` (62 tests)
3. 🔲 `t/006_usergroups.t` - **DEFERRED** - Has commented-out tests due to nodegroup/cache issues
4. ✅ `t/007_systemutilities.t` → `t/064_systemutilities_api.t` (11 tests)
5. ✅ `t/008_e2nodes.t` → `t/065_e2nodes_api.t` (23 tests)
6. ✅ `t/009_writeups.t` → `t/060_writeups_api.t` (33 tests)
7. ✅ `t/010_preferences.t` → `t/061_preferences_api.t` (32 tests)
8. ✅ `t/011_developervars.t` → `t/062_developervars_api.t` (11 tests)

**Total**: 6 new test files created with 172 passing tests

### Known Issues
- **Nodegroup API** (`t/006_usergroups.t`): insertIntoNodegroup has race condition/cache issues in development
  - Tests commented out at line 60 with note: "There's a problem with insertIntoNodegroup where it doesn't always land in development consistently"
  - Root cause: Deeper problem with nodegroup inserts, not API-specific

## Phase 1: Retire APIClient & Convert to Mock Tests ✅ COMPLETE

### Completion Summary (2025-12-17)

**Status**: ✅ **COMPLETE** - All 7 convertible tests migrated to mock-based pattern

**New Test Files Created**:
- [t/060_writeups_api.t](../t/060_writeups_api.t) - 33 tests (writeup CRUD, permissions)
- [t/061_preferences_api.t](../t/061_preferences_api.t) - 32 tests (get/set preferences, validation)
- [t/062_developervars_api.t](../t/062_developervars_api.t) - 11 tests (developer VARS access)
- [t/063_messageignores_api.t](../t/063_messageignores_api.t) - 62 tests (ignore/unignore operations)
- [t/064_systemutilities_api.t](../t/064_systemutilities_api.t) - 11 tests (room purge)
- [t/065_e2nodes_api.t](../t/065_e2nodes_api.t) - 23 tests (e2node creation/deletion)

**Shared Mock Infrastructure Created**:
- [t/lib/MockUser.pm](../t/lib/MockUser.pm) - Comprehensive mock user class (250+ lines, full POD)
- [t/lib/MockRequest.pm](../t/lib/MockRequest.pm) - Mock request wrapper (220+ lines, full POD)
- All 6 test files refactored to use shared classes
- Eliminated ~900 lines of duplicate mock code

**Test Results**: ✅ All 172 tests passing in ~10 seconds

**Deferred**: t/006_usergroups.t - Nodegroup cache issue requires deeper investigation

**Documentation**:
- [api-test-conversion-summary.md](api-test-conversion-summary.md) - Detailed conversion report
- [SHARED-MOCKS-REFACTORING.md](SHARED-MOCKS-REFACTORING.md) - Shared mock classes summary
- [NIGHT-WORK-SUMMARY-2025-12-17.md](NIGHT-WORK-SUMMARY-2025-12-17.md) - Overnight work summary

### Original Priority Order (Now Complete)
1. ✅ **High Priority**: `t/009_writeups.t` → Converted
2. ✅ **Medium Priority**: `t/010_preferences.t`, `t/011_developervars.t` → Converted
3. ✅ **Low Priority**: `t/004_messages.t`, `t/005_messageignores.t`, `t/007_systemutilities.t`, `t/008_e2nodes.t` → Converted
4. 🔲 **Deferred**: `t/006_usergroups.t` - Requires nodegroup cache fix

### Conversion Strategy ✅ COMPLETED

All steps completed successfully. Pattern now established for future API tests.

#### ✅ Step 1: Analyze Existing Coverage - COMPLETE
- All 7 legacy tests analyzed
- Test coverage documented in [api-test-conversion-summary.md](api-test-conversion-summary.md)
- API gaps identified and tracked in [api-improvements-needed.md](api-improvements-needed.md)

#### ✅ Step 2: Create Mock-Based Tests - COMPLETE
Created shared mock infrastructure in [t/lib/](../t/lib/):

```perl
use lib "$FindBin::Bin/lib";
use MockRequest;

# Usage:
my $request = MockRequest->new(
    node_id => 123,
    title => 'testuser',
    is_guest_flag => 0,
    is_admin_flag => 1,
    postdata => { key => 'value' }
);

my $result = $api->method($request);
```

See [MockUser.pm](../t/lib/MockUser.pm) and [MockRequest.pm](../t/lib/MockRequest.pm) for full documentation.

#### ✅ Step 3: Preserve Coverage - COMPLETE
All existing test assertions migrated:
- ✅ Permission checks (guest, non-owner, owner, admin)
- ✅ Input validation (missing fields, invalid types)
- ✅ Business logic validation
- ✅ Error conditions
- ✅ Success paths

Coverage improvements documented in conversion summary.

#### 🔲 Step 4: Remove APIClient - PENDING USER APPROVAL
Ready to delete once user confirms:
- `ecore/Everything/APIClient.pm`
- All references to `Everything::APIClient`
- Legacy test files (t/004-011)

## Phase 2: Comprehensive Edge Case Testing

### Edge Case Categories

#### 1. Authentication & Authorization
- Guest user attempts
- Wrong user type attempts
- Missing authentication
- Expired sessions
- Suspended users
- Banned users

#### 2. Input Validation
- Missing required fields
- Invalid data types
- Out-of-range values
- SQL injection attempts
- XSS attempts
- Null/undefined values
- Empty strings vs null
- Unicode/special characters

#### 3. Resource Limits
- No votes/cools remaining
- Rate limiting
- Quota exhaustion
- Maximum field lengths
- Too many items in arrays

#### 4. Race Conditions & Concurrency
- Double voting/cooling
- Concurrent updates
- Stale data scenarios

#### 5. Data Integrity
- Non-existent resources
- Deleted resources
- Orphaned relationships
- Circular references

#### 6. Business Logic Edge Cases
- Self-referential operations (vote own writeup)
- Duplicate operations
- State transitions
- Cascade effects

### API-Specific Edge Cases

#### vote.pm
- ✅ Already covered: guest, no votes left, already voted, own writeup, invalid weight
- 🔲 TODO: Suspended user, invalid writeup ID, negative votes_left

#### cool.pm
- ✅ Already covered: guest, no cools left, already cooled, own writeup
- ✅ Cool Man Eddie messages
- 🔲 TODO: Suspended user, bookmarking disabled, editor cool on wrong node type

#### admin.pm
- ✅ Return to drafts functionality
- 🔲 TODO: Non-editor attempts, invalid publication status, missing writeup

### Testing Matrix Template

For each API endpoint, verify:
```
┌─────────────────┬──────┬─────────┬───────────┬────────┐
│ Test Scenario   │Guest │Regular  │ Editor    │ Admin  │
├─────────────────┼──────┼─────────┼───────────┼────────┤
│ Valid Request   │      │         │           │        │
│ Missing Field   │      │         │           │        │
│ Invalid Type    │      │         │           │        │
│ Not Found       │      │         │           │        │
│ Duplicate       │      │         │           │        │
│ Quota Exceeded  │      │         │           │        │
└─────────────────┴──────┴─────────┴───────────┴────────┘
```

## Phase 3: Smoke Tests for All API Endpoints

### Smoke Test Strategy

Add smoke tests to `tools/smoke-test.rb` for every API route, including error paths.

#### Current Smoke Test Pattern
```ruby
{
  name: 'API Endpoint Name',
  url: '/api/endpoint/path',
  type: :api,
  method: :post,
  body: { param: 'value' },
  expected_status: 200,
  expected_json: { success: 1 }
}
```

#### New Requirements
1. Test every route in every API's `routes()` method
2. Include both success and failure scenarios
3. Test all HTTP methods (GET, POST, PUT, DELETE)
4. Verify proper error codes (400, 403, 404, 500)

### API Endpoints Requiring Smoke Tests

#### High Priority (User-Facing)
- vote.pm: POST /api/vote/writeup/:id
- cool.pm: POST /api/cool/writeup/:id, POST /api/cool/writeup/:id/edcool, POST /api/cool/writeup/:id/bookmark
- messages.pm: All message operations
- sessions.pm: Login/logout
- drafts.pm: Draft management

#### Medium Priority (Editor/Admin)
- admin.pm: Return to drafts, moderation
- user.pm: User management
- writeups.pm: Writeup operations

#### Low Priority (Background/Utilities)
- systemutilities.pm
- developervars.pm
- tests.pm

## Phase 4: API Documentation (API.md)

Update `docs/API.md` with comprehensive documentation for each API.

### Documentation Template

```markdown
### API Name

**File**: `ecore/Everything/API/name.pm`
**Routes**:
- `POST /api/route/path` - Description

**Parameters**:
- `param_name` (type, required/optional) - Description

**Returns**:
```json
{
  "success": 1,
  "data": {}
}
```

**Error Codes**:
- 400: Missing required field
- 403: Permission denied
- 404: Resource not found

**Test Coverage**:
- Unit Tests: `t/XXX_name_api.t` (NN tests)
- Smoke Tests: ✅ Yes / ❌ No
- Edge Cases: Guest ✅, Quota ✅, Invalid Input ✅

**Production Status**: ✅ Ready / ⚠️ Needs Work / ❌ Not Ready

**Notes**: Any special considerations
```

## Special Investigation: Nodegroup Cache Issue

### Problem Statement
From `t/006_usergroups.t` line 57-60:
```perl
# There's a problem with insertIntoNodegroup where it doesn't always land
# in development consistently. It's not the API's fault, it is a deeper
# problem with nodegroup inserts
```

### Investigation Steps

1. **Examine insertIntoNodegroup Implementation**
   - File: `ecore/Everything/NodeBase.pm` or `ecore/Everything/Application.pm`
   - Look for cache invalidation issues
   - Check for race conditions

2. **Check Cache Mechanisms**
   - `getCache()` calls
   - `purgeCache()` calls
   - Group cache vs node cache

3. **Review usergroups API**
   - File: `ecore/Everything/API/usergroups.pm`
   - Check for proper cache handling after inserts

4. **Test Scenarios**
   - Sequential adds (works)
   - Rapid sequential adds (fails?)
   - Add with duplicates (fails?)
   - Concurrent adds (fails?)

5. **Potential Solutions**
   - Add cache purge after nodegroup operations
   - Use transactions for nodegroup updates
   - Add synchronization/locking
   - Force cache refresh before returning data

### Debug Approach
```perl
# Add to usergroup_add in API
$DB->getCache->purgeCache($nodegroup_node);  # Force refresh
$DB->getCache->purgeNodegroupCache($nodegroup_id);  # If exists
```

## Implementation Roadmap

### Week 1: Foundation ✅ COMPLETE (2025-12-16 to 2025-12-17)
- ✅ Day 1: Modernize vote & cool APIs (COMPLETED)
- ✅ Day 1: Fix EKN, Perl::Critic issues (COMPLETED)
- ✅ Day 2: Create this plan document (COMPLETED)
- ✅ Day 2-3: Convert all 7 APIClient tests to mock-based (COMPLETED)
- ✅ Day 3: Create shared MockUser/MockRequest infrastructure (COMPLETED)
- ✅ Day 3: Refactor all 6 tests to use shared mocks (COMPLETED)
- 🔲 Future: Investigate nodegroup cache issue

### Week 2: Comprehensive Testing (NEXT PHASE)
- 🔲 Add edge case tests for vote, cool, admin APIs
- 🔲 Add edge case tests for messages, sessions, drafts
- 🔲 Add edge case tests for remaining user-facing APIs
- 🔲 Add edge case tests for writeups, preferences, e2nodes

### Week 3: Smoke Tests & Documentation
- 🔲 Create smoke tests for all API endpoints
- 🔲 Document all APIs in API.md
- 🔲 Final review and validation

## Success Criteria

- [x] All APIClient tests converted to mock-based ✅ (2025-12-17)
- [x] Shared mock infrastructure created ✅ (2025-12-17)
- [ ] Everything::APIClient.pm deleted (pending user approval)
- [ ] 100% of API endpoints have smoke tests
- [ ] All user-facing APIs have comprehensive edge case coverage
- [ ] API.md documents all 50 APIs with test coverage metrics
- [ ] All tests passing (Perl + React)
- [ ] All smoke tests passing
- [ ] Nodegroup cache issue investigated and documented (LOW PRIORITY - deferred)

## Metrics

### Current (2025-12-17) - Updated after Phase 1 completion
- Mock-based API tests: 22/24 (92%) - 6 new tests added, 1 deferred (usergroups)
- Test files using shared mocks: 6/6 (100%) - All new tests use t/lib/MockUser.pm and MockRequest.pm
- Total API test coverage: 172 tests across new mock-based files
- APIs with comprehensive edge cases: 2/50 (4%) - vote, cool
- APIs with smoke tests: ~15/50 (30%) - estimated from current smoke-test.rb
- Documented APIs: 0/50 (0%)

### Phase 1 Completion Metrics
- APIClient tests converted: 6/7 (86%) - 1 deferred due to nodegroup cache issues
- New test files created: 6
- Lines of duplicate code eliminated: ~900
- Shared mock classes created: 2 (MockUser.pm, MockRequest.pm)
- Documentation files created/updated: 4

### Target (End of Plan)
- Mock-based API tests: 24/24 (100%)
- APIs with comprehensive edge cases: 50/50 (100%)
- APIs with smoke tests: 50/50 (100%)
- Documented APIs: 50/50 (100%)

## Notes

- **Phase 1 Complete**: All convertible APIClient tests migrated to mock-based pattern
- Prioritize user-facing APIs (vote, cool, messages, sessions, drafts) for Phase 2
- Editor/admin APIs are medium priority
- Utility/background APIs are lower priority but still need coverage
- Shared mock infrastructure ready for future test development
- **Nodegroup cache issue**: LOW PRIORITY - deferred to future investigation
- Document any APIs that cannot be fully tested with mocks

## Next Steps (After Phase 1 Completion)

1. **Review and Approve APIClient Deletion** (User Decision Required)
   - Confirm all converted tests provide equivalent coverage
   - Delete `ecore/Everything/APIClient.pm` and legacy test files (t/004-011)
   - Update any remaining references

2. **Begin Phase 2: Comprehensive Edge Case Testing**
   - Start with newly converted APIs (writeups, preferences, e2nodes, etc.)
   - Add SQL injection, XSS, boundary value tests
   - Test Unicode, special characters, edge cases

3. **Continue with Smoke Tests (Phase 3)**
   - Add smoke tests for all 6 newly tested APIs
   - Expand smoke test coverage across all 50 APIs

4. **API Documentation (Phase 4)**
   - Document all APIs in API.md with parameters, returns, error codes
   - Include test coverage metrics for each API

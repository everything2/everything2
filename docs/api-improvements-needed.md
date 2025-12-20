# API Implementation Gaps & Improvements Needed

**Created**: 2025-12-16
**Last Updated**: 2025-12-17
**Status**: Living Document - Updated with test conversion results
**Purpose**: Track missing implementations, inconsistencies, and needed improvements across E2 APIs

## 🎉 Recent Accomplishments (2025-12-17)

- ✅ **All 7 legacy APIClient tests converted to mock-based tests**
- ✅ **172 new tests passing** (See [api-test-conversion-summary.md](api-test-conversion-summary.md))
- ✅ **Shared MockUser/MockRequest classes created** in [t/lib/](../t/lib/)
- ✅ **All 6 test files refactored to use shared mocks** - Eliminated ~900 lines of duplication
- ✅ **8 APIs verified as using modern routes**
- ✅ **Multiple API gaps documented during testing**

## Critical Missing Implementations

### 1. Generic Node Retrieval (Everything::API::nodes)

**Issue**: The `get()` method in nodes.pm returns HTTP_UNIMPLEMENTED (405)

**Location**: [ecore/Everything/API/nodes.pm:26-31](ecore/Everything/API/nodes.pm#L26-L31)

**Current Code**:
```perl
sub get
{
  my ($self, $REQUEST, $id) = @_;

  return [$self->HTTP_UNIMPLEMENTED];
}
```

**Impact**:
- Cannot retrieve nodes by ID generically via API
- Each node type requires its own specialized retrieval endpoint
- Inconsistent with RESTful conventions

**Recommended Fix**:
Implement a generic get-by-id that:
1. Retrieves the node from database
2. Calls `json_display($user)` on the node
3. Returns proper permissions-aware JSON
4. Returns 404 for non-existent nodes
5. Returns 405 for node types that don't support display

**Example Implementation**:
```perl
sub get
{
  my ($self, $REQUEST, $id) = @_;

  my $node = $self->APP->node_by_id($id);
  unless ($node) {
    return [$self->HTTP_NOT_FOUND, { error => 'Node not found' }];
  }

  # Check if node type supports JSON display
  unless ($node->can('json_display')) {
    return [$self->HTTP_UNIMPLEMENTED, { error => 'Node type does not support display' }];
  }

  my $display_data = $node->json_display($REQUEST->user);
  return [$self->HTTP_OK, $display_data];
}
```

---

## API Response Inconsistencies

### 2. Writeup API Missing Fields

**Issue**: Writeup creation response doesn't include all expected fields

**Missing Fields in JSON Response**:
- `author_user` - Author's node_id
- `parent_e2node` - Parent e2node reference
- `wrtype_writeuptype` - Writeup type
- `notnew` - Flag for established writeups
- `reputation` - Writeup reputation score

**Current Behavior**: Only returns:
- `node_id`
- `title`
- `doctext`
- `createtime`

**Impact**:
- Frontend cannot display author information without additional API call
- Cannot show writeup type or parent node
- Owner cannot see their own reputation/notnew status

**Recommended Fix**:
Update `Everything::Node::writeup::json_display()` to include these fields for the owner.

**Location**: [ecore/Everything/Node/writeup.pm](ecore/Everything/Node/writeup.pm)

---

## Testing Gaps Discovered

### 3. MockUser/MockRequest Infrastructure ✅ COMPLETE

**Status**: ✅ **COMPLETED** (2025-12-17)

**Implementation**:
- Created [t/lib/MockUser.pm](../t/lib/MockUser.pm) - Comprehensive mock user class
- Created [t/lib/MockRequest.pm](../t/lib/MockRequest.pm) - Mock request wrapper
- Updated all 6 test files to use shared classes
- All 172 tests passing

**MockUser Methods Implemented**:
- Permission checks: `is_admin()`, `is_editor()`, `is_guest()`, `is_developer()`
- Core accessors: `node_id()`, `title()`, `NODEDATA()`
- Settings: `VARS()`, `set_vars()`
- Voting/Cool: `coolsleft()`, `votesleft()`
- Message ignores: `message_ignores()`, `set_message_ignore()`, `is_ignoring_messages()`

**Benefits**:
- Eliminated ~900 lines of duplicate code across 6 test files
- Consistent mock behavior for all API tests
- Easy to extend with new methods as needed
- Comprehensive POD documentation for both classes

---

## API Modernization Tracking

### 4. Completed Modernizations

✅ **vote.pm** - Converted to RESTful routes (2025-12-16)
- Old: `POST /api/vote` with writeup_id in body
- New: `POST /api/vote/writeup/:id` with weight in body
- All responses return HTTP 200 with success flag

✅ **cool.pm** - Converted to RESTful routes (2025-12-16)
- Old: `POST /api/cool` with command_post
- New: `POST /api/cool/writeup/:id`
- New: `POST /api/cool/writeup/:id/edcool`
- New: `POST /api/cool/writeup/:id/bookmark`
- Cool Man Eddie messages restored

✅ **preferences.pm** - Already using RESTful routes (verified 2025-12-16)
- Routes: `POST /api/preferences/set`, `GET /api/preferences/get`
- `POST /api/preferences/notifications`, `POST /api/preferences/admin`
- Validation via whitelist pattern

### 5. APIs Still Using command_post Pattern

Need to audit remaining APIs for old command_post pattern and modernize to routes:

**Priority List**:
1. Check all files in `ecore/Everything/API/*.pm`
2. Search for `command_post` usage
3. Convert to `routes()` method with RESTful paths
4. Update corresponding tests

---

## Response Format Standardization

### 6. HTTP Status Code Usage

**Current State**: Mixed usage of HTTP status codes

**Issues Found**:
- Some APIs return actual HTTP error codes (403, 404, 405)
- mod_perl appends HTML to non-200 responses
- Inconsistent error response format

**Standard Established** (vote.pm, cool.pm):
```perl
# Always return HTTP 200
return [$self->HTTP_OK, {
  success => 1,  # or 0 for errors
  message => 'Operation succeeded',
  data => { ... }
}];

# For errors:
return [$self->HTTP_OK, {
  success => 0,
  error => 'Detailed error message'
}];
```

**Recommendation**:
1. Audit all APIs for non-200 responses
2. Convert to success/error JSON pattern
3. Document the standard in API.md
4. Update all tests to check `success` field instead of HTTP status

**Exception**: The base nodes API delete/update methods still use real HTTP codes (403, 404, etc.) and may need to remain for backwards compatibility.

---

## Future Improvements

### 7. API Consolidation Opportunities

**Potential Consolidations**:
1. **Node Operations**: Create a unified node CRUD API instead of type-specific APIs
2. **Voting/Cooling**: Both follow similar patterns, could share common code
3. **User Management**: Scattered across multiple APIs

### 8. Missing API Functionality

**Needed APIs** (from frontend perspective):
1. **Writeup Editing**: No update endpoint exists
2. **Draft Management**: Create, update, delete drafts
3. **User Profile**: Get/update user settings
4. **Search**: Full-text search API
5. **Node History**: View node edit history

---

---

## Test Conversions Completed (2025-12-17)

All legacy APIClient tests have been successfully converted to modern mock-based tests:

### ✅ Completed Conversions

| Old Test | New Test | Tests | Status | Notes |
|----------|----------|-------|--------|-------|
| t/009_writeups.t | t/060_writeups_api.t | 33 | ✅ Pass | Writeup CRUD, permissions, validation |
| t/010_preferences.t | t/061_preferences_api.t | 32 | ✅ Pass | Get/set preferences, string prefs |
| t/011_developervars.t | t/062_developervars_api.t | 11 | ✅ Pass | Developer-only VARS access |
| t/004_messages.t | N/A (obsolete) | 1 | ✅ Empty | Just created APIClient instance |
| t/005_messageignores.t | t/063_messageignores_api.t | 62 | ✅ Pass | Ignore/unignore, idempotent ops |
| t/007_systemutilities.t | t/064_systemutilities_api.t | 11 | ✅ Pass | Room purge, admin-only |
| t/008_e2nodes.t | t/065_e2nodes_api.t | 23 | ✅ Pass | E2node create/delete, author fields |

**Total**: 7 files converted, 172 new tests, all passing

### Mock Infrastructure Established

Created consistent MockUser/MockRequest pattern across all tests:

**MockUser Methods Required**:
- `is_guest()`, `is_admin()`, `is_editor()`, `is_developer()`
- `node_id()`, `title()`, `NODEDATA()`, `VARS()`
- `coolsleft()`, `votesleft()` (for voting/cool APIs)
- `message_ignores()`, `set_message_ignore()`, `is_ignoring_messages()` (for message ignores)

**MockRequest Methods Required**:
- `user()` - Returns MockUser instance
- `is_guest()` - Delegates to user
- `JSON_POSTDATA()` - Returns postdata hashref

### APIs Verified During Conversion

All tested APIs confirmed to use modern routes:

- ✅ **preferences.pm** - RESTful routes, whitelist validation
- ✅ **developervars.pm** - Developer-only authorization
- ✅ **messageignores.pm** - RESTful CRUD operations
- ✅ **systemutilities.pm** - Admin-only utilities
- ✅ **e2nodes.pm** - Extends nodes API with CREATE_ALLOWED
- ✅ **vote.pm** - Modernized (previous work)
- ✅ **cool.pm** - Modernized (previous work)
- ✅ **writeups.pm** - Modern API

---

## Notes

- This document should be updated as new gaps are discovered
- Each entry should link to relevant code locations
- Mark items as resolved with ✅ and date completed
- Prioritize based on user impact and API modernization goals
- **Next Priority**: Create standardized MockUser/MockRequest base classes in t/lib/ to eliminate duplication

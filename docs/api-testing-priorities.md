# API Testing Priorities

**Created**: 2025-12-17
**Purpose**: Guide test development priorities based on security, user impact, and feature criticality

## Executive Summary

- **Total API Modules**: 50
- **Fully Tested**: 20 modules (40%)
- **Partially Tested**: 3 modules (6%)
- **No Tests**: 27 modules (54%)
- **Test Infrastructure**: Shared MockUser/MockRequest classes in [t/lib/](../t/lib/)

## Test Coverage Status

### ✅ Fully Tested (20 modules)

These APIs have comprehensive test coverage:

1. **sessions.pm** - [t/002_sessions_api.t](../t/002_sessions_api.t) (41 tests)
2. **nodenotes.pm** - [t/021_nodenotes_api.t](../t/021_nodenotes_api.t) (66 tests)
3. **hidewriteups.pm** - [t/028_hidewriteups_api.t](../t/028_hidewriteups_api.t) (32 tests)
4. **newwriteups.pm** - [t/030_newwriteups_api.t](../t/030_newwriteups_api.t) (33 tests)
5. **messages.pm** - [t/032_messages_api.t](../t/032_messages_api.t) + integration tests
6. **personallinks.pm** - [t/033_personallinks_api.t](../t/033_personallinks_api.t) (18 tests)
7. **poll.pm** - [t/034_poll_api.t](../t/034_poll_api.t) (62 tests)
8. **chatroom.pm** - [t/035_chatroom_api.t](../t/035_chatroom_api.t)
9. **chatter.pm** - [t/038_chatter_api.t](../t/038_chatter_api.t) + [t/027_chatterbox_cleanup.t](../t/027_chatterbox_cleanup.t)
10. **notifications.pm** - [t/040_notifications_api.t](../t/040_notifications_api.t) + integration tests
11. **wheel.pm** - [t/045_wheel_api.t](../t/045_wheel_api.t)
12. **admin.pm** - [t/051_admin_api.t](../t/051_admin_api.t)
13. **spamcannon.pm** - [t/052_spamcannon_api.t](../t/052_spamcannon_api.t)
14. **writeup_reparent.pm** - [t/053_writeup_reparent.t](../t/053_writeup_reparent_api.t)
15. **writeups.pm** - [t/056_writeups_api.t](../t/056_writeups_api.t) (33 tests, MockRequest) ✨
16. **messageignores.pm** - [t/059_messageignores_api.t](../t/059_messageignores_api.t) (62 tests, MockRequest) ✨
17. **systemutilities.pm** - [t/060_systemutilities_api.t](../t/060_systemutilities_api.t) (11 tests, MockRequest) ✨
18. **e2nodes.pm** - [t/061_e2nodes_api.t](../t/061_e2nodes_api.t) (23 tests, MockRequest) ✨
19. **cool.pm** - [t/062_cool_api.t](../t/062_cool_api.t) (MockRequest) ✨
20. **tests.pm** - [t/003_api_versions.t](../t/003_api_versions.t) (8 tests - version testing)

✨ = Uses shared MockRequest infrastructure (modern pattern)

### ⚠️ Partially Tested (3 modules)

These APIs have some coverage but missing critical endpoints:

1. **users.pm** - [t/048_user_api.t](../t/048_user_api.t) (14% coverage - 1/7 endpoints)
   - **Missing**: CRUD operations, user updates, user creation

2. **usergroups.pm** - [t/004_usergroups.t](../t/004_usergroups.t) (33% coverage - 3/9 endpoints)
   - **Covered**: create, add user, remove user
   - **Missing**: GET, DELETE, UPDATE, bulk operations

3. **nodes.pm** - [t/022_nodes_api_clone.t](../t/022_nodes_api_clone.t), [t/025_nodes_api_delete.t](../t/025_nodes_api_delete.t) (29% coverage - 2/7 endpoints)
   - **Covered**: clone, delete
   - **Missing**: GET, CREATE, UPDATE, lookup by type/title

### ⚠️ Duplicate Tests to Resolve (2 pairs)

1. **preferences.pm**:
   - t/029_preferences_api.t (50 tests, comprehensive, old style)
   - t/057_preferences_api.t (32 tests, MockRequest, modern) ✨
   - **Recommendation**: Merge best of both into t/057

2. **developervars.pm**:
   - t/024_developervars_api.t (23 tests, comprehensive, old style)
   - t/058_developervars_api.t (11 tests, MockRequest, modern) ✨
   - **Recommendation**: Merge best of both into t/058

---

## Priority 1: HIGH PRIORITY - Missing Tests (8 modules)

These APIs are security-critical, core features, or actively used in production. **Test these first.**

### 1. signup.pm - User Registration
- **Routes**: 1 route (POST /api/signup)
- **Authorization**: Public
- **Priority**: 🔴 **CRITICAL** - Security (reCAPTCHA, validation, email verification)
- **Test Focus**:
  - reCAPTCHA validation
  - Username/email validation
  - Password strength requirements
  - Email verification flow
  - Duplicate username/email prevention
  - SQL injection prevention

### 2. vote.pm - Writeup Voting
- **Routes**: 1 route (POST /api/vote/writeup/:id)
- **Authorization**: Logged-in users
- **Priority**: 🔴 **CRITICAL** - Core reputation system
- **Test Focus**:
  - Vote weight validation (-1, 0, +1)
  - Vote limit enforcement
  - Duplicate vote prevention
  - Vote reversal/change
  - Guest user blocking
  - Reputation calculation

### 3. reputation.pm - Vote Analysis
- **Routes**: 1 route (GET /api/reputation/:node_id)
- **Authorization**: Voted users, authors, admins
- **Priority**: 🔴 **CRITICAL** - Vote transparency
- **Test Focus**:
  - Authorization checks (only voters/authors/admins)
  - Monthly vote breakdown accuracy
  - Guest user blocking
  - Data privacy (users can't see others' reps)

### 4. suspension.pm - User Moderation
- **Routes**: 5 routes (suspend chat, room, topic, all types, unsuspend)
- **Authorization**: Chanop/Editor/Admin (varies by type)
- **Priority**: 🔴 **CRITICAL** - User safety, moderation
- **Test Focus**:
  - Authorization by suspension type
  - Suspension duration validation
  - Reason logging
  - Unsuspension
  - Cascade effects (chat → room → all)

### 5. userinteractions.pm - User Blocking
- **Routes**: 3 routes (block user, unblock, get block list)
- **Authorization**: Logged-in users
- **Priority**: 🔴 **CRITICAL** - Privacy, harassment prevention
- **Test Focus**:
  - Block/unblock operations
  - Message filtering
  - Favorite unfollowing
  - Guest user blocking
  - Self-blocking prevention

### 6. drafts.pm - Draft Management (E2 Editor Beta)
- **Routes**: 5 routes (GET all, GET one, POST create, PUT update, DELETE)
- **Authorization**: Logged-in users (own drafts only)
- **Priority**: 🔴 **CRITICAL** - E2 Editor Beta core feature
- **Test Focus**:
  - CRUD operations
  - Version history
  - Preview rendering
  - Permission checks (own drafts only)
  - Draft-to-writeup conversion
  - Max draft limits

### 7. autosave.pm - Editor Autosave (E2 Editor Beta)
- **Routes**: 5 routes (POST autosave, GET latest, GET history, POST restore, DELETE)
- **Authorization**: Logged-in users
- **Priority**: 🔴 **CRITICAL** - E2 Editor Beta data safety
- **Test Focus**:
  - Autosave frequency limits
  - Version history (20 versions max)
  - Manual restore
  - Old version pruning
  - Conflict resolution

### 8. Complete usergroups.pm Testing
- **Current**: 3/9 endpoints tested
- **Missing**: GET, DELETE, UPDATE operations
- **Priority**: 🔴 **HIGH** - Permissions system depends on it
- **Test Focus**:
  - GET usergroup details
  - DELETE usergroup
  - UPDATE usergroup metadata
  - Permission inheritance

---

## Priority 2: MEDIUM PRIORITY - Missing Tests (14 modules)

These APIs are actively used but have workarounds or lower risk profiles.

### Content Discovery

1. **user_search.pm** - Writeup Search
   - Routes: 1 route (GET /api/user_search/:username)
   - Purpose: Paginated, filtered, sorted writeup search
   - Test Focus: Pagination, filtering, sorting, permissions

2. **betweenthecracks.pm** - Neglected Writeups
   - Routes: 1 route (GET /api/betweenthecracks)
   - Purpose: Find low-vote writeups user hasn't voted on
   - Test Focus: Vote threshold, user exclusion, randomization

3. **trajectory.pm** - Site Statistics
   - Routes: 1 route (GET /api/trajectory)
   - Purpose: Monthly writeups/users/cools data
   - Test Focus: Date ranges, data accuracy, caching

4. **cool_archive.pm** - Cool Archive Browsing
   - Routes: 1 route (GET /api/cool_archive)
   - Purpose: Paginated cooled writeups with filtering
   - Test Focus: Pagination, date filtering, sorting

5. **page_of_cool.pm** - Page of Cool Data
   - Routes: 1 route (GET /api/page_of_cool)
   - Purpose: Recently cooled nodes, editor endorsements
   - Test Focus: Recency limits, endorsement tracking

6. **levels.pm** - User Level Info
   - Routes: 1 route (GET /api/levels)
   - Purpose: XP/writeup/vote/cool requirements per level
   - Test Focus: Level calculations, requirement accuracy

### Content Management

7. **weblog.pm** - Weblog Management
   - Routes: 1 route (POST /api/weblog/:id/remove)
   - Purpose: Remove entries from weblogs (soft delete)
   - Test Focus: Soft delete, permission checks, undo

8. **node_parameter.pm** - Node Parameter Editing
   - Routes: 3 routes (GET, SET, DELETE node parameters)
   - Authorization: Editor/Admin
   - Test Focus: Permission checks, parameter validation, deletion

9. **nodelets.pm** - Nodelet Management
   - Routes: 2 routes (GET order, POST update order)
   - Purpose: User UI customization
   - Test Focus: Order validation, collapsed state, preferences

### Polls

10. **poll_creator.pm** - Poll Creation
    - Routes: 1 route (POST /api/poll_creator)
    - Purpose: Create new e2poll nodes
    - Test Focus: Option validation, permissions, poll structure

11. **polls.pm** - Poll Management
    - Routes: 3 routes (GET list, POST set current, DELETE poll)
    - Authorization: Admin (set current, delete)
    - Test Focus: Admin permissions, current poll logic, deletion

### Completion Tasks

12. **Complete users.pm Testing**
    - Current: 1/7 endpoints tested (sanctity check only)
    - Missing: CRUD operations, user updates
    - Test Focus: User creation, updates, deletion, permission checks

13. **Complete nodes.pm Testing**
    - Current: 2/7 endpoints tested (clone, delete)
    - Missing: GET, CREATE, UPDATE, lookup
    - Test Focus: Generic node operations, type-specific behavior

14. **Resolve Duplicate Tests**
    - preferences.pm: Merge t/029 + t/057
    - developervars.pm: Merge t/024 + t/058

---

## Priority 3: LOW PRIORITY - Missing Tests (13 modules)

These APIs are admin-only tools, special features, or rarely used functionality.

### Admin Tools

1. **superbless.pm** - Admin Resource Grants (5 routes)
   - GP grants (editors), XP grants (admin), cool grants (admin), fiery hug (admin)

2. **easter_eggs.pm** - Bestow Easter Eggs (1 route)
   - Admin-only special event feature

3. **teddybear.pm** - Giant Teddy Bear Suit (1 route)
   - Admin-only fun feature (+2 GP hugs)

4. **list_nodes.pm** - List Nodes by Type (1 route)
   - Editor/Developer tool for paginated node listing

### Chat Tools

5. **bouncer.pm** - Bulk Room Management (1 route)
   - Chanop-only bulk user room moves

### Placeholder/Minimal

6. **catchall.pm** - Empty Placeholder (0 routes)
   - No functionality to test

---

## Testing Standards & Best Practices

### Use Shared Mock Infrastructure

All new API tests should use the shared mock classes:

```perl
use lib "$FindBin::Bin/lib";
use MockUser;
use MockRequest;

# Create mock users
my $guest = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  is_guest_flag => 1
);

my $user = MockRequest->new(
  node_id => $test_user->{node_id},
  title => $test_user->{title},
  nodedata => $test_user,
  is_guest_flag => 0
);

# Test API calls
my $result = $api->get_data($user);
is($result->[0], $api->HTTP_OK, "User get data returns 200 OK");
```

### Test Coverage Checklist

For each API endpoint, verify:

- ✅ **Authorization**: Guest, normal user, admin, editor (as appropriate)
- ✅ **Validation**: Invalid inputs, missing parameters, type mismatches
- ✅ **Permissions**: Own content, other users' content, admin override
- ✅ **Success Cases**: Happy path with valid data
- ✅ **Error Cases**: Missing data, invalid IDs, duplicate operations
- ✅ **Edge Cases**: Empty lists, max limits, boundary conditions
- ✅ **SQL Injection**: Verify parameterized queries (no string interpolation)
- ✅ **Response Format**: HTTP status codes, success/error JSON structure

### Modern Test Pattern (6 files, 172 tests)

See these files as examples:
- [t/056_writeups_api.t](../t/056_writeups_api.t) (33 tests)
- [t/057_preferences_api.t](../t/057_preferences_api.t) (32 tests)
- [t/058_developervars_api.t](../t/058_developervars_api.t) (11 tests)
- [t/059_messageignores_api.t](../t/059_messageignores_api.t) (62 tests)
- [t/060_systemutilities_api.t](../t/060_systemutilities_api.t) (11 tests)
- [t/061_e2nodes_api.t](../t/061_e2nodes_api.t) (23 tests)
- [t/062_cool_api.t](../t/062_cool_api.t)

---

## Next Steps

### Immediate Actions

1. **Resolve Duplicates**: Merge t/024→t/058 and t/029→t/057, keeping MockRequest versions
2. **Create Priority 1 Tests**: Start with signup.pm, vote.pm, reputation.pm
3. **Update Coverage**: Re-run tests and update coverage badges

### Short-term Goals (Q1 2026)

- Achieve 70% API module coverage (35 of 50 modules tested)
- Complete all Priority 1 tests (8 modules)
- Complete 50% of Priority 2 tests (7 modules)

### Long-term Goals (2026)

- Achieve 90% API module coverage (45 of 50 modules tested)
- Migrate all old-style tests to MockRequest pattern
- Comprehensive integration testing after PSGI migration

---

**Last Updated**: 2025-12-17
**See Also**: [API.md](API.md), [api-test-conversion-summary.md](api-test-conversion-summary.md), [code-coverage.md](code-coverage.md)

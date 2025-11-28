# Notification Legacy Code Removal Plan

**Status**: PLANNING - Do NOT execute yet
**Date**: 2025-11-27
**Context**: Legacy notification polling system was removed in commit e6c7fcc58, replaced by React Notifications nodelet

## Background

The legacy AJAX notification polling system has been replaced by a modern React implementation:

**Old System** (removed in e6c7fcc58):
```javascript
// www/js/legacy.js (removed)
e2.ajax.addList('notifications_list',{
    getJSON: "notificationsJSON",      // htmlcode function
    args: 'wrap',
    idGroup: "notified_",
    period: 45,                        // 45-second polling
    dismissItem: 'ajaxMarkNotificationSeen'  // htmlcode function
});
```

**New System** (current):
- React Notifications nodelet ([react/components/Nodelets/Notifications.js](../react/components/Nodelets/Notifications.js))
- REST API endpoint ([ecore/Everything/API/notifications.pm](../ecore/Everything/API/notifications.pm))
- Centralized rendering ([ecore/Everything/Application.pm::getRenderedNotifications()](../ecore/Everything/Application.pm#L7314))

## Orphaned Code Identified

### 1. ajax_update Document - mode=checkNotifications

**File**: [ecore/Everything/Delegation/document.pm](../ecore/Everything/Delegation/document.pm)
**Lines**: 22417-22419

```perl
if ($mode eq 'checkNotifications') {
    return to_json(htmlcode('notificationsJSON'));
}
```

**Status**: ORPHANED - No callers
**Evidence**: Legacy polling removed; grepped entire codebase - no JavaScript calls this mode

---

### 2. ajax_update Document - mode=markNotificationSeen

**File**: [ecore/Everything/Delegation/document.pm](../ecore/Everything/Delegation/document.pm)
**Lines**: 22413-22415

```perl
if ($mode eq 'markNotificationSeen') {
    htmlcode('ajaxNotificationSeen',$query->param("notified_id"));
}
```

**Status**: ORPHANED - No callers
**Evidence**: Legacy polling removed; replaced by `/api/notifications/dismiss` endpoint

**Bug Note**: Calls `ajaxNotificationSeen` which DOES NOT EXIST in htmlcode.pm
(Should be `ajaxMarkNotificationSeen` but irrelevant since orphaned)

---

### 3. htmlcode::notificationsJSON

**File**: [ecore/Everything/Delegation/htmlcode.pm](../ecore/Everything/Delegation/htmlcode.pm)
**Lines**: 11234-11358 (~125 lines)

**Function signature**:
```perl
sub notificationsJSON
{
  my $DB = shift;
  my $query = shift;
  # ... ~110 lines of notification rendering logic ...
  return $notification_list;
}
```

**Status**: ORPHANED - Only caller is mode=checkNotifications (also orphaned)
**Replacement**: Application.pm::getRenderedNotifications() (identical logic, refactored)

---

### 4. htmlcode::ajaxMarkNotificationSeen

**File**: [ecore/Everything/Delegation/htmlcode.pm](../ecore/Everything/Delegation/htmlcode.pm)
**Lines**: 12207-12237 (~31 lines)

**Function signature**:
```perl
sub ajaxMarkNotificationSeen
{
  my $DB = shift;
  # ... notification dismiss logic ...
}
```

**Status**: ORPHANED - Only caller is mode=markNotificationSeen (also orphaned)
**Replacement**: Everything::API::notifications::dismiss() (enhanced version with authorization)

---

### 5. nodepack XML Files

**File**: [nodepack/htmlcode/notificationsjson.xml](../nodepack/htmlcode/notificationsjson.xml)
**Status**: Empty nodepack stub (code lives in htmlcode.pm)
**Action**: Can be deleted from nodepack

**File**: [nodepack/htmlcode/ajaxmarknotificationseen.xml](../nodepack/htmlcode/ajaxmarknotificationseen.xml)
**Status**: Empty nodepack stub (code lives in htmlcode.pm)
**Action**: Can be deleted from nodepack

---

## Removal Plan

### Phase 1: Delete ajax_update Mode Handlers

**Files Modified**: 1
**Risk Level**: LOW (orphaned code)

Delete from [ecore/Everything/Delegation/document.pm](../ecore/Everything/Delegation/document.pm):

```perl
# REMOVE Lines 22413-22415:
if ($mode eq 'markNotificationSeen') {
    htmlcode('ajaxNotificationSeen',$query->param("notified_id"));
}

# REMOVE Lines 22417-22419:
if ($mode eq 'checkNotifications') {
    return to_json(htmlcode('notificationsJSON'));
}
```

**Total deletion**: 7 lines (including blank lines)

---

### Phase 2: Delete htmlcode Functions

**Files Modified**: 1
**Risk Level**: LOW (no callers after Phase 1)

Delete from [ecore/Everything/Delegation/htmlcode.pm](../ecore/Everything/Delegation/htmlcode.pm):

**Block 1 - notificationsJSON** (lines 11234-11358):
```perl
# REMOVE entire function (~125 lines)
sub notificationsJSON
{
  # ... entire function body ...
}
```

**Block 2 - ajaxMarkNotificationSeen** (lines 12207-12237):
```perl
# REMOVE entire function (~31 lines)
sub ajaxMarkNotificationSeen
{
  # ... entire function body ...
}
```

**Total deletion**: ~156 lines

---

### Phase 3: Delete Nodepack XML Files

**Files Deleted**: 2
**Risk Level**: VERY LOW (empty stubs)

```bash
rm nodepack/htmlcode/notificationsjson.xml
rm nodepack/htmlcode/ajaxmarknotificationseen.xml
```

---

### Phase 4: Update Documentation

**Files Modified**: Multiple docs

1. Remove references from [docs/ajax_update_system_analysis.md](../docs/ajax_update_system_analysis.md)
2. Update [docs/nodelet-periodic-updates.md](../docs/nodelet-periodic-updates.md) (if applicable)
3. Add removal notes to [docs/changelog-2025-11.md](../docs/changelog-2025-11.md)
4. Update [CLAUDE.md](../CLAUDE.md) Session 22 completion notes

---

## Testing Plan

### Pre-Removal Verification

1. **Confirm no JavaScript callers**:
   ```bash
   grep -r "checkNotifications" www/js/
   grep -r "markNotificationSeen" www/js/
   grep -r "notificationsJSON" www/js/
   # All should return NO matches (or only legacy.js comments)
   ```

2. **Confirm React system working**:
   ```bash
   # Test notification dismiss via React
   curl -X POST -b 'userpass=root%09blah' \
     -H 'Content-Type: application/json' \
     -d '{"notified_id":123}' \
     http://localhost:9080/api/notifications/dismiss
   ```

3. **Verify smoke tests pass**:
   ```bash
   ./tools/smoke-test.rb
   # Should pass 159/159
   ```

### Post-Removal Testing

1. **Application health test**:
   ```bash
   prove t/000_application_health.t
   # Should pass all Perl::Critic checks
   ```

2. **Notification API tests**:
   ```bash
   prove t/037_notifications_api.t
   # Should pass 8/8 subtests
   ```

3. **React tests**:
   ```bash
   npm test -- Notifications
   # Should pass all notification component tests
   ```

4. **Integration test - notification workflow**:
   - Create notification via admin action
   - Verify appears in React Notifications nodelet
   - Dismiss notification via X button
   - Verify disappears from list
   - Check database: is_seen=1

5. **Smoke test ajax_update document**:
   ```bash
   curl -s 'http://localhost:9080/title/ajax_update?mode=getlastmessage'
   # Should return number (still-active mode)

   curl -s 'http://localhost:9080/title/ajax_update?mode=checkNotifications'
   # Should return empty/error (deleted mode) - EXPECTED
   ```

---

## Rollback Plan

If issues discovered post-removal:

1. **Revert git commit**:
   ```bash
   git revert <commit-hash>
   ```

2. **Manual restoration** (if needed):
   - Restore deleted functions from git history
   - Code preserved in commit e6c7fcc58~1 (before React migration)

---

## Risk Assessment

| Component | Risk Level | Justification |
|-----------|-----------|---------------|
| mode=checkNotifications | VERY LOW | No callers found, replaced by React |
| mode=markNotificationSeen | VERY LOW | No callers found, replaced by API |
| notificationsJSON | VERY LOW | Only called by orphaned mode handler |
| ajaxMarkNotificationSeen | VERY LOW | Only called by orphaned mode handler |
| Nodepack XML files | VERY LOW | Empty stubs, no code |

**Overall Risk**: VERY LOW

**Justification**:
- Legacy polling removed 3+ sessions ago (commit e6c7fcc58)
- React Notifications nodelet production-ready with full test coverage
- Modern API endpoint handles all dismiss operations
- Application.pm::getRenderedNotifications() replaces htmlcode logic
- No external dependencies found
- Easy rollback via git revert if needed

---

## Code Replacement Mapping

| Old Code (to delete) | New Code (already active) | Location |
|---------------------|---------------------------|----------|
| notificationsJSON() | getRenderedNotifications() | Application.pm:7314 |
| ajaxMarkNotificationSeen() | /api/notifications/dismiss | API/notifications.pm:44 |
| mode=checkNotifications | React polling (usePolling hook) | hooks/usePolling.js |
| mode=markNotificationSeen | React dismiss handler | Notifications.js:45 |

---

## Estimated Impact

**Lines deleted**: ~170 lines
**Files modified**: 2
**Files deleted**: 2
**Test coverage**: 100% (all replacement code tested)
**Performance improvement**: Minimal (code already unused)
**Maintenance improvement**: Significant (less legacy code to maintain)

---

## Approval Checklist

Before executing removal:

- [ ] User confirms plan reviewed
- [ ] Pre-removal verification tests pass
- [ ] React Notifications nodelet confirmed working in production
- [ ] All API tests passing (t/037_notifications_api.t)
- [ ] Git commit ready for easy rollback
- [ ] Documentation updates prepared

---

## Execution Commands

**DO NOT RUN YET - PLANNING ONLY**

```bash
# Phase 1: Delete ajax_update mode handlers
# Edit document.pm manually - delete lines 22413-22415, 22417-22419

# Phase 2: Delete htmlcode functions
# Edit htmlcode.pm manually - delete lines 11234-11358, 12207-12237

# Phase 3: Delete nodepack files
rm nodepack/htmlcode/notificationsjson.xml
rm nodepack/htmlcode/ajaxmarknotificationseen.xml

# Phase 4: Test
./tools/smoke-test.rb
prove t/037_notifications_api.t
npm test -- Notifications

# Commit
git add -A
git commit -m "Remove orphaned notification legacy code

Removed legacy AJAX notification polling code that was replaced by
React Notifications nodelet in commit e6c7fcc58.

Deleted code:
- ajax_update modes: checkNotifications, markNotificationSeen
- htmlcode::notificationsJSON() - replaced by Application::getRenderedNotifications()
- htmlcode::ajaxMarkNotificationSeen() - replaced by API/notifications::dismiss()
- Empty nodepack XML stubs

All functionality now handled by:
- React Notifications nodelet (react/components/Nodelets/Notifications.js)
- REST API endpoint (/api/notifications)
- Centralized rendering (Application.pm::getRenderedNotifications())

Risk: VERY LOW - No active callers found
Tests: All passing (API tests, React tests, smoke tests)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Notes

- **Bug in markNotificationSeen mode**: Calls `ajaxNotificationSeen` which doesn't exist (should be `ajaxMarkNotificationSeen`). This bug never surfaced because the code path is never executed.

- **Code duplication eliminated**: notificationsJSON() had identical logic to Application.pm::getRenderedNotifications() - we successfully refactored into centralized location.

- **Authorization improvement**: Old ajaxMarkNotificationSeen() lacked proper authorization checks. New API endpoint has comprehensive security (guest blocking, subscription verification, 403 Forbidden for unauthorized access).

- **Performance**: Legacy polling hit server every 45 seconds. React implementation uses same interval but with cleaner architecture and better error handling.

---

**Status**: PHASE 1 & 2 COMPLETE - Stubs active, awaiting production push for full deletion

## Execution Log

### 2025-11-27: Phases 1 & 2 Completed

**Phase 1: Delete ajax_update Mode Handlers** ✅
- File: `ecore/Everything/Delegation/document.pm`
- Deleted lines 22413-22419 (7 lines total)
- Replaced with comment explaining removal
- Reference: Legacy polling removed in commit e6c7fcc58

**Phase 2: Stub htmlcode Functions** ✅
- File: `ecore/Everything/Delegation/htmlcode.pm`
- `notificationsJSON()`: Reduced from ~125 lines to 6-line stub returning `''`
- `ajaxMarkNotificationSeen()`: Reduced from ~31 lines to 6-line stub returning `''`
- Total reduction: ~150 lines of orphaned code replaced with deprecation stubs

**Testing Results**:
- ✅ Smoke tests: 159/159 passing
- ✅ Application health: 247/247 tests passing (Perl::Critic clean)
- ✅ Notifications API tests: 8/8 passing
- ✅ No errors in Apache logs
- ✅ React Notifications nodelet functioning correctly

**Lines Removed**: ~157 lines
**Stubs Remaining**: 2 functions (12 lines total)

### 2025-11-27: Pure React Notification Rendering

**Refactored notification system to pure React** ✅
- **Backend Changes**:
  - Modified `Application.pm::getRenderedNotifications()` to return structured data instead of HTML
  - Changed return format from `{notified_id, html}` to `{notified_id, text, timestamp}`
  - Removed HTML wrapping logic with `<li>`, `<a class="dismiss">` tags
  - Removed `parseLinks()` call from backend
  - Removed `wrap` parameter from function signature

- **React Component Changes** ([Notifications.js](../react/components/Nodelets/Notifications.js)):
  - Replaced `dangerouslySetInnerHTML` with `<ParseLinks text={notification.text} />`
  - Dismiss button rendered as React `<button>` instead of HTML string
  - Settings link generated purely in React (no server-rendered HTML)

- **Notification Delegation Updates** ([notification.pm](../ecore/Everything/Delegation/notification.pm)):
  - Converted all 14 notification functions from HTML links to bracket link syntax
  - Created `Application.pm::bracketLink()` helper method (not in Globals)
  - Functions now return plain text like `"Someone upvoted [Writeup Title]"`
  - ParseLinks component converts bracket links to HTML anchors in React

**Testing Results**:
- ✅ Smoke tests: 159/159 passing
- ✅ Notifications API tests: 8/8 passing
- ✅ No HTML escaping issues - bracket links render correctly

### Next Steps

**After production push** (when stubs confirmed unused in production logs):
- Phase 3: Delete nodepack XML files (2 files)
- Phase 4: Delete stub functions from htmlcode.pm (12 lines)
- Final deletion: ~169 lines total

**Status**: PURE REACT COMPLETE - Notifications fully refactored, awaiting production deployment

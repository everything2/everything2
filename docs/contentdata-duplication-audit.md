# contentData Duplication Audit

Analysis of Controllers and Page classes that duplicate data already available in the global `e2` state.

**Generated**: 2025-01-10
**Reference**: [spec/e2-global-state.md](../spec/e2-global-state.md)

---

## Executive Summary

Multiple Controllers and Page classes are passing user, node, and permission data in `contentData` that is already available globally via `e2.user`, `e2.node`, etc. This creates:

1. **Payload bloat** - Same data transmitted multiple times
2. **Inconsistent access patterns** - React components check different places for same data
3. **Maintenance burden** - Changes need to be made in multiple places

---

## Critical Issues

### Issue #1: debatecomment.pm - User Object Duplication (7 instances)

**File**: `ecore/Everything/Controller/debatecomment.pm`

**Problem**: Identical user object passed in 7 different code paths:

```perl
# Lines 119-124, 209-214, 312-317, 359-364, 417-422, 458-463, 525-530
user => {
    node_id => $user_id,
    title => $user->title,
    is_guest => $user->is_guest ? 1 : 0,
    is_admin => $user->is_admin ? 1 : 0
}
```

**Duplicates**:
- `e2.user.node_id`
- `e2.user.title`
- `e2.guest` / `e2.user.guest`
- `e2.user.admin`

**Fix**: Remove `user` from contentData. React component should use `user` prop (passed from DocumentComponent) or `e2.user`.

---

### ~~Issue #2: settings.pm - currentUser Duplication~~ (INTENTIONAL)

**File**: `ecore/Everything/Page/settings.pm`

**Code** (lines 348-351):
```perl
currentUser => {
    node_id => int($user->node_id),
    title => $user->title
}
```

**Why this is NOT a problem**: Administrators can edit other users' settings. In this case:
- `e2.user` = the logged-in administrator
- `contentData.currentUser` = the user whose settings are being edited (from URL)

This is an intentional admin override pattern, not duplication. The Settings.js component needs both to know who is editing vs whose settings are displayed.

**Status**: No fix needed.

---

### Issue #3: gnl.pm - Permission Flag Duplication

**File**: `ecore/Everything/Page/gnl.pm`

**Problem** (lines 58-60):
```perl
is_admin => 1,
is_editor => 1,
user_id => $USER->{node_id}
```

**Duplicates**:
- `e2.user.admin`
- `e2.user.editor`
- `e2.user.node_id`

**Fix**: Remove these flags. React component checks `user.admin`, `user.editor`.

---

### Issue #4: blind_voting_booth.pm - isEditor Duplication

**File**: `ecore/Everything/Page/blind_voting_booth.pm`

**Problem** (lines 66, 103, 127):
```perl
isEditor => $is_editor
```

**Duplicates**: `e2.user.editor`

**Fix**: React component checks `user.editor` directly.

---

## All Files with Duplication

### High Priority (Multiple Issues)

| File | Duplicated Properties | Lines |
|------|----------------------|-------|
| `Controller/debatecomment.pm` | user.node_id, user.title, is_guest, is_admin | 119-124, 209-214, 312-317, 359-364, 417-422, 458-463, 525-530 |
| `Page/gnl.pm` | is_admin, is_editor, user_id | 58-60 |

### Intentional (Not Duplication)

| File | Properties | Reason |
|------|-----------|--------|
| `Page/settings.pm` | currentUser.node_id, currentUser.title | Admin override - editing different user's settings |

### Medium Priority (Single Issue)

| File | Duplicated Properties | Lines |
|------|----------------------|-------|
| `Page/blind_voting_booth.pm` | isEditor | 66, 103, 127 |
| `Page/altar_of_sacrifice.pm` | node_id (current node) | 30, 43, 54, 79, 107 |
| `Page/super_mailbox.pm` | user_id | 57 |

### Low Priority (Acceptable Patterns)

These pass node_id for *referenced* nodes (not the current page node), which is acceptable:

| File | Pattern | Notes |
|------|---------|-------|
| `Page/findings.pm` | node_id in search results | Each result needs its own ID |
| `Page/node_row.pm` | node_id, node_type for subnode | Displaying different node than page |
| `Controller/e2node.pm` | writeup.author.node_id | Author is different from current user |

---

## Naming Inconsistencies

| Data | Standard (e2.*) | Variants Found | Files |
|------|-----------------|----------------|-------|
| User ID | `e2.user.node_id` | `user_id`, `userId`, `currentUser.node_id` | gnl.pm, super_mailbox.pm, settings.pm |
| Is Guest | `e2.guest` (0/1) | `is_guest` (boolean), `user.is_guest` | debatecomment.pm |
| Is Admin | `e2.user.admin` | `is_admin`, `user.is_admin` | debatecomment.pm, gnl.pm |
| Is Editor | `e2.user.editor` | `is_editor`, `isEditor` | gnl.pm, blind_voting_booth.pm |
| Votes Left | `e2.user.votesleft` | `votes_left`, `votesLeft` | blind_voting_booth.pm |

---

## Recommended Fixes

### Phase 1: Remove User Object from debatecomment.pm

**Before**:
```perl
my $content_data = {
    type => 'debatecomment',
    debatecomment => $comment_data,
    user => {
        node_id => $user_id,
        title => $user->title,
        is_guest => $user->is_guest ? 1 : 0,
        is_admin => $user->is_admin ? 1 : 0
    }
};
```

**After**:
```perl
my $content_data = {
    type => 'debatecomment',
    debatecomment => $comment_data
    # user removed - React uses props.user from DocumentComponent
};
```

**React side**:
```javascript
// DebateComment.js already receives user as prop
const DebateComment = ({ data, user }) => {
  // Use user.node_id, user.admin instead of data.user.*
}
```

---

### Phase 2: Remove Permission Flags

Files to update:
- `gnl.pm` - Remove `is_admin`, `is_editor`, `user_id`
- `blind_voting_booth.pm` - Remove `isEditor`

React components check `user.admin`, `user.editor` instead.

---

### Phase 3: Standardize Naming

When data must be passed (e.g., author of a writeup), use consistent naming:

```perl
# Preferred format for node references
author => {
    node_id => int($author->node_id),
    title => $author->title
}

# NOT
author_user => $author_id,
author_name => $author_title,
```

---

## Verification Checklist

After fixes, verify these React components work correctly:

- [ ] `DebateComment.js` - Uses `user` prop for permissions
- [ ] `GNL.js` - Uses `user` prop for admin/editor checks
- [ ] `BlindVotingBooth.js` - Uses `user` prop for editor check

Note: `Settings.js` intentionally needs `currentUser` for admin editing other users.

---

## Payload Size Impact

Estimated reduction per page type:

| Page Type | Properties Removed | Approx Bytes Saved |
|-----------|-------------------|-------------------|
| debatecomment | 4 props x 7 paths | ~400 bytes |
| settings | 2 props | ~50 bytes |
| gnl | 3 props | ~40 bytes |
| blind_voting_booth | 1 prop x 3 paths | ~30 bytes |

Total savings may seem small per page, but multiplied by thousands of page loads per day, this adds up.

---

## Future Prevention

1. **Code review checklist**: Check if data is already in `e2` before adding to contentData
2. **ESLint rule**: Warn when accessing `data.user` instead of `user` prop in Document components
3. **Documentation**: Reference spec/e2-global-state.md in controller templates

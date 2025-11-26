# Everything2 End-to-End Test Plan

**Last Updated:** 2025-11-25
**Status:** Phase 2 Complete - 10/16 tests passing (62.5%)
**Framework:** Playwright + Chromium

## Quick Links
- [Test Users & Credentials](#test-users--credentials)
- [Test Execution](#running-tests)
- [Current Coverage](#coverage-overview)
- [Failing Tests](#current-failures)
- [Priority Definitions](#priority-levels)

---

## Coverage Overview

| Feature Area | Priority | Tests | Passing | Coverage | Status |
|-------------|----------|-------|---------|----------|--------|
| [Authentication](#1-authentication--authorization) | P0 | 2 | 1 | 50% | ⚠️ Partial |
| [Chatterbox](#2-chatterbox--public-messaging) | P0 | 5 | 4 | 80% | ⚠️ Good |
| [Private Messaging](#3-private-messaging) | P0 | 2 | 2 | 100% | ✅ Complete |
| [Navigation](#4-navigation--basic-functionality) | P0 | 4 | 1 | 25% | ❌ Needs Work |
| [Wheel of Surprise](#5-wheel-of-surprise) | P1 | 3 | 2 | 67% | ⚠️ Partial |
| [Content Creation](#6-content-creation-writeups) | P0 | 0 | 0 | 0% | ❌ Not Started |
| [Voting System](#7-voting--experience) | P0 | 0 | 0 | 0% | ❌ Not Started |
| [User Settings](#8-user-settings--preferences) | P1 | 0 | 0 | 0% | ❌ Not Started |
| [Admin Functions](#9-admin-functions) | P2 | 1 | 1 | 100% | ✅ Complete |
| [Search](#10-search-functionality) | P1 | 0 | 0 | 0% | ❌ Not Started |
| [Notifications](#11-notifications) | P1 | 0 | 0 | 0% | ❌ Not Started |

**Overall:** 16 tests implemented, 10 passing (62.5%)

---

## Priority Levels

- **P0 (Critical):** Core functionality - must work for site to be usable
- **P1 (High):** Important features - significant user impact if broken
- **P2 (Medium):** Nice-to-have features - limited user impact
- **P3 (Low):** Edge cases and admin-only features

---

## Test Users & Credentials

All E2E test users are created by [tools/seeds.pl](../tools/seeds.pl) during development database initialization.

### Standard Test Users

| Username | Password | Permissions | GP | Use For |
|----------|----------|-------------|-----|---------|
| `root` | `blah` | Admin (e2gods) | Variable | Admin features, all permissions, legacy test compatibility |
| `genericdev` | `blah` | Developer (edev) | Variable | Developer nodelet, normal developer tests |
| `Cool Man Eddie` | `blah` | Regular user | Variable | Standard user tests, permission blocking |
| `c_e` | `blah` | Content editor | Variable | Message forwarding tests (forwards to Content Editors) |

### E2E Test Users (Recommended for New Tests)

These users are specifically designed for E2E testing with consistent credentials and clear permission boundaries.

| Username | Password | Permissions | GP | Use For |
|----------|----------|-------------|-----|---------|
| `e2e_admin` | `test123` | Admin (e2gods) | 500 | Admin features, god-mode testing |
| `e2e_editor` | `test123` | Editor (Content Editors) | 300 | Content editing, editor features |
| `e2e_developer` | `test123` | Developer (edev) | 200 | Developer features, chanop privileges |
| `e2e_chanop` | `test123` | Chanop (chanops) | 150 | Chatterbox moderation, room management |
| `e2e_user` | `test123` | Regular user (no groups) | 100 | Standard user functionality |
| `e2e user space` | `test123` | Regular user (no groups) | 75 | Username with space character testing |

**Note:** All E2E test users use password `test123` for consistency. Use these users for new tests to maintain clear permission boundaries and avoid conflicts with legacy tests.

### Authentication Pattern for Tests

E2 uses cookie-based authentication with hashed passwords. See [CLAUDE.md Cookie Authentication section](../CLAUDE.md#cookie-authentication) for details.

**Quick auth fixture usage:**
```javascript
const { test } = require('./fixtures/auth');

// Use pre-authenticated context
test('my test', async ({ authenticatedPage, authenticatedContext }) => {
  // Page is already logged in as 'root' user
  await authenticatedPage.goto('/');
  // ...
});

// Or login manually for specific user
test('editor test', async ({ page }) => {
  await page.goto('/');
  // Expand Sign In nodelet if needed
  const signInHeader = page.locator('h3:has-text("Sign In")');
  if (await signInHeader.getAttribute('aria-expanded') === 'false') {
    await signInHeader.click();
  }
  // Login
  await page.fill('#username', 'e2e_editor');
  await page.fill('#password', 'test123');
  await page.click('input[type="submit"]');
  // ...
});
```

---

## 1. Authentication & Authorization

**Priority:** P0 (Critical)
**Current Coverage:** 2/4 tests (50%)
**Test File:** [tests/e2e/navigation.spec.js](../tests/e2e/navigation.spec.js)

### Implemented Tests

#### ✅ Guest Access
- **Test:** `homepage loads for guests`
- **Status:** Passing
- **Validates:**
  - Homepage loads for unauthenticated users
  - Sign In nodelet is visible
  - Login fields are present

#### ⚠️ Login Flow
- **Test:** `login flow works`
- **Status:** Failing (too many "root" elements on page)
- **Validates:**
  - User can expand Sign In nodelet
  - User can fill login credentials
  - User can submit login form
  - User sees confirmation they're logged in
- **Issue:** Selector `text=root` matches 9 elements

### Planned Tests

#### ❌ Login via /title/login Page (P1)
- **Status:** Not implemented
- **Validates:**
  - Direct login page access works
  - Form submission redirects correctly
  - Error messages display for invalid credentials

#### ❌ Remember Me Functionality (P1)
- **Status:** Not implemented
- **Validates:**
  - Checkbox persists session across browser restarts
  - Cookie expiration works correctly

#### ❌ Logout (P0)
- **Status:** Not implemented
- **Validates:**
  - Logout button works
  - Session is cleared
  - User redirected to guest view

#### ❌ Session Timeout (P2)
- **Status:** Not implemented
- **Validates:**
  - Inactive sessions expire
  - User prompted to re-login
  - Unsaved data warnings

### Edge Cases to Test

- [ ] Login with special characters in username
- [ ] Login with very long password (>240 chars)
- [ ] Login with expired session cookie
- [ ] Login from multiple tabs simultaneously
- [ ] Login with incorrect credentials (error handling)
- [ ] Login when already logged in (redirect behavior)
- [ ] CSRF token validation
- [ ] SQL injection attempts in login fields

---

## 2. Chatterbox & Public Messaging

**Priority:** P0 (Critical)
**Current Coverage:** 5/8 tests (62.5%)
**Test File:** [tests/e2e/chatterbox.spec.js](../tests/e2e/chatterbox.spec.js)

### Implemented Tests

#### ⚠️ Send Message Without Layout Shift
- **Test:** `sends message without layout shift`
- **Status:** Failing (timeout waiting for #chatterbox)
- **Validates:**
  - Message input doesn't cause UI jump
  - Chatterbox height remains constant
- **Issue:** Chatterbox not visible after login

#### ✅ Error Message Display
- **Test:** `error message covers chat commands link`
- **Status:** Passing
- **Validates:**
  - API errors display to user
  - Error message positioned correctly
  - Error message fades in/out properly

#### ✅ Special Commands
- **Test:** `special commands render correctly`
- **Status:** Passing
- **Validates:**
  - `/me` command renders in italics
  - `/roll XdY` command displays dice results
  - Commands process correctly

#### ✅ Input Focus Retention
- **Test:** `input retains focus after sending`
- **Status:** Passing
- **Validates:**
  - Input field retains focus after message sent
  - User can type immediately without clicking

#### ✅ Character Counter
- **Test:** `character counter works`
- **Status:** Passing (placeholder)
- **Validates:**
  - Character count displays
  - Counter updates as user types
  - Visual warning at 90% (460 chars)
  - Visual error at 100% (512 chars)

### Planned Tests

#### ❌ Room Navigation (P0)
- **Status:** Not implemented
- **Validates:**
  - User can switch between rooms
  - Messages from current room only display
  - Room list updates correctly

#### ❌ Private Messages (/msg) (P0)
- **Status:** Not implemented
- **Validates:**
  - `/msg username message` sends private message
  - Success confirmation appears (no visual feedback in chatter)
  - Recipient receives message
  - Error handling for invalid recipients

#### ❌ Message Persistence (P1)
- **Status:** Not implemented
- **Validates:**
  - Messages persist across page reloads
  - Last 30 messages from last 5 minutes display
  - Older messages not shown

### Edge Cases to Test

- [ ] Rapid-fire messaging (rate limiting)
- [ ] Very long messages (>512 chars truncation)
- [ ] Unicode and emoji support
- [ ] XSS prevention: `<script>alert('xss')</script>`
- [ ] HTML injection: `<img src=x onerror=alert(1)>`
- [ ] Link parsing: `[Everything2]`, `[root[user]]`
- [ ] Command chaining: `/me /roll 1d20`
- [ ] Empty message submission
- [ ] Whitespace-only messages
- [ ] Borged user restrictions
- [ ] Admin-only commands: `/clearchatter`, `/borg`, `/drag`

---

## 3. Private Messaging

**Priority:** P0 (Critical)
**Current Coverage:** 2/6 tests (33%)
**Test File:** [tests/e2e/messages.spec.js](../tests/e2e/messages.spec.js)

### Implemented Tests

#### ✅ Initial Message Load
- **Test:** `loads initial messages on page load without API call`
- **Status:** Passing
- **Validates:**
  - Messages load from initial page data
  - No redundant API calls on mount
  - Performance optimization working

#### ✅ Mini Messages Visibility
- **Test:** `mini messages only show when Messages nodelet not in sidebar`
- **Status:** Passing
- **Validates:**
  - Logic prevents duplicate message displays
  - Mini messages hide when full Messages nodelet visible

### Planned Tests

#### ❌ Send Private Message (P0)
- **Status:** Not implemented
- **Validates:**
  - User can compose new message
  - Recipient lookup works
  - Message delivers successfully

#### ❌ Reply to Message (P0)
- **Status:** Not implemented
- **Validates:**
  - Reply button opens modal with pre-filled recipient
  - Reply-all includes all original recipients
  - Context preserved in reply

#### ❌ Archive Message (P1)
- **Status:** Not implemented
- **Validates:**
  - Archive button moves message to archive
  - Archived messages hidden from inbox
  - Can view archived messages separately

#### ❌ Delete Message (P1)
- **Status:** Not implemented
- **Validates:**
  - Delete confirmation modal appears
  - Message permanently deleted
  - Cannot be recovered after deletion

### Edge Cases to Test

- [ ] Message to non-existent user
- [ ] Message to usergroup
- [ ] Message to self
- [ ] Message with >512 characters
- [ ] Message forwarding (user with `message_forward_to`)
- [ ] Nested usergroup messaging (e2gods contains content_editors)
- [ ] Archive/unarchive toggle
- [ ] Delete own vs. admin delete
- [ ] Unicode in message content
- [ ] XSS prevention in messages

---

## 4. Navigation & Basic Functionality

**Priority:** P0 (Critical)
**Current Coverage:** 4/8 tests (50%)
**Test File:** [tests/e2e/navigation.spec.js](../tests/e2e/navigation.spec.js)

### Implemented Tests

#### ✅ Homepage for Guests
- **Test:** `homepage loads for guests`
- **Status:** Passing
- **Validates:**
  - Homepage accessible without login
  - Sign In nodelet visible

#### ⚠️ Login Flow
- **Test:** `login flow works`
- **Status:** Failing (covered in Authentication section)

#### ⚠️ Chatterbox After Login
- **Test:** `chatterbox appears on homepage for logged-in users`
- **Status:** Failing (timeout after login)
- **Validates:**
  - Chatterbox replaces Sign In nodelet
  - Message input available

#### ⚠️ React Page Content
- **Test:** `React page content loads`
- **Status:** Failing (login issue)
- **Validates:**
  - React pages render (Wheel of Surprise)
  - Interactive elements work

#### ⚠️ Mason2 Pages
- **Test:** `Mason2 pages still work`
- **Status:** Failing (login issue)
- **Validates:**
  - Legacy Mason2 pages still render
  - No regressions during React migration

#### ⚠️ Sidebar Nodelets
- **Test:** `sidebar nodelets render`
- **Status:** Failing (login issue)
- **Validates:**
  - Sidebar present
  - Nodelets load correctly

### Planned Tests

#### ❌ Guest Nodelet Consistency (P0) - **REGRESSION TEST**
- **Status:** Not implemented
- **Validates:**
  - Guest users see same nodelets on all pages
  - Nodelets consistent between homepage, "Guest Front Page", and other pages
  - No variation based on page type or navigation path
- **Bug Fixed:** 2025-11-25 - [user.pm:265](../ecore/Everything/Node/user.pm#L265)
  - **Root Cause:** `guest_front_page` document set `VARS->{nodelets}`, which persisted and overrode `guest_nodelets` config on other pages
  - **Fix:** Reordered checks in `nodelets()` method to check `is_guest` FIRST before checking `VARS->{nodelets}`
  - **Impact:** Ensures consistent guest experience regardless of which page they visit first
- **Test Strategy:**
  - Visit homepage as guest, capture nodelet list
  - Visit "Guest Front Page", capture nodelet list
  - Visit several other pages (search, node pages), capture nodelet lists
  - Assert all lists are identical

#### ❌ Direct Node Access (P0)
- **Status:** Not implemented
- **Validates:**
  - `/node/123` loads node by ID
  - `/user/username` loads user page
  - `/title/Node+Title` loads by title

#### ❌ 404 Handling (P1)
- **Status:** Not implemented
- **Validates:**
  - Non-existent nodes show 404
  - Friendly error message
  - Links to search/create

### Edge Cases to Test

- [ ] Guest nodelet consistency across page types (regression test - **CRITICAL**)
- [ ] URL encoding in titles (spaces, special chars)
- [ ] Very long URLs
- [ ] Malformed URLs
- [ ] Deep linking to specific sections
- [ ] Back/forward browser navigation
- [ ] Refresh behavior (state preservation)

---

## 5. Wheel of Surprise

**Priority:** P1 (High)
**Current Coverage:** 3/5 tests (60%)
**Test File:** [tests/e2e/wheel.spec.js](../tests/e2e/wheel.spec.js)

### Implemented Tests

#### ⚠️ Display Spin Result
- **Test:** `displays spin result`
- **Status:** Failing (timeout)
- **Validates:**
  - Wheel spin animation works
  - Result displays to user
  - GP deducted

#### ✅ Insufficient GP Block
- **Test:** `blocks spin when user has insufficient GP`
- **Status:** Passing
- **Validates:**
  - Users with <5 GP cannot spin
  - Error message displays
  - No GP deducted

#### ✅ Admin Self-Sanctify
- **Test:** `admin can sanctify themselves`
- **Status:** Passing
- **Validates:**
  - Admins bypass "cannot sanctify yourself" rule
  - GP transferred correctly
  - Success message displays

### Planned Tests

#### ❌ GP Optout Users (P1)
- **Status:** Not implemented
- **Validates:**
  - Users with GPoptout cannot spin
  - Appropriate message displays

#### ❌ Prize Distribution (P2)
- **Status:** Not implemented
- **Validates:**
  - All prize types work (GP, XP, items)
  - Probabilities correct
  - Halloween special prizes

### Edge Cases to Test

- [ ] Spin with exactly 5 GP (edge case)
- [ ] Multiple rapid spins (rate limiting)
- [ ] Spin during Halloween (special prizes)
- [ ] Admin spin restrictions vs. normal users

---

## 6. Content Creation (Writeups)

**Priority:** P0 (Critical)
**Current Coverage:** 0/10 tests (0%)
**Status:** ❌ Not Started

### Planned Tests

#### ❌ Create New Writeup (P0)
- **Validates:**
  - Navigation to create writeup form
  - Title and content input
  - Preview functionality
  - Successful submission
  - Writeup appears on e2node

#### ❌ Edit Existing Writeup (P0)
- **Validates:**
  - Edit button appears for own writeups
  - Changes save successfully
  - Edit history preserved

#### ❌ Delete Writeup (P1)
- **Validates:**
  - Delete confirmation modal
  - Writeup moved to tomb
  - Can be resurrected by editors

#### ❌ Link Parsing (P0)
- **Validates:**
  - `[node title]` creates link
  - `[title|display text]` works
  - `[title[nodetype]]` works
  - Invalid links show as plaintext

#### ❌ HTML Sanitization (P0)
- **Validates:**
  - XSS prevention
  - Allowed HTML tags work
  - Disallowed tags stripped

### Edge Cases to Test

- [ ] Very long writeups (>50k chars)
- [ ] Writeup with many links (>100)
- [ ] Duplicate writeup prevention
- [ ] Unicode and emoji support
- [ ] Image embedding
- [ ] Code blocks
- [ ] Tables
- [ ] Nested formatting

---

## 7. Voting & Experience

**Priority:** P0 (Critical)
**Current Coverage:** 0/8 tests (0%)
**Status:** ❌ Not Started

### Planned Tests

#### ❌ Cast Vote (P0)
- **Validates:**
  - Upvote button works
  - Downvote button works
  - Vote count updates
  - XP awarded to author
  - Voter XP deducted

#### ❌ Change Vote (P1)
- **Validates:**
  - Can change existing vote
  - XP adjustments correct
  - Vote count updates

#### ❌ Vote Restrictions (P0)
- **Validates:**
  - Cannot vote on own writeups
  - Guest users cannot vote
  - Insufficient XP blocks voting

#### ❌ Cool Vote (P1)
- **Validates:**
  - Editors can mark writeups cool
  - Cool list updates
  - Author receives notification

### Edge Cases to Test

- [ ] Vote on writeup with 0 votes
- [ ] Vote on very old writeup (>1 year)
- [ ] Vote during level-up
- [ ] Vote with exactly enough XP
- [ ] Multiple votes in rapid succession

---

## 8. User Settings & Preferences

**Priority:** P1 (High)
**Current Coverage:** 0/12 tests (0%)
**Status:** ❌ Not Started

### Planned Tests

#### ❌ Modify Display Settings (P1)
- **Validates:**
  - Change stylesheet
  - Toggle options (level display, etc.)
  - Settings persist across sessions

#### ❌ Nodelet Configuration (P1)
- **Validates:**
  - Add/remove nodelets from sidebar
  - Reorder nodelets
  - Collapse/expand nodelets
  - Settings saved

#### ❌ Privacy Settings (P1)
- **Validates:**
  - Message ignore list
  - Hide from Other Users
  - Email preferences

#### ❌ Password Change (P0)
- **Validates:**
  - Old password verification
  - New password validation
  - Success confirmation
  - Can login with new password

### Edge Cases to Test

- [ ] Invalid preference values
- [ ] Conflicting preference combinations
- [ ] Preference migration (old → new format)
- [ ] Default preferences for new users

---

## 9. Admin Functions

**Priority:** P2 (Medium)
**Current Coverage:** 1/10 tests (10%)
**Test File:** [tests/e2e/wheel.spec.js](../tests/e2e/wheel.spec.js)

### Implemented Tests

#### ✅ Admin Self-Sanctify
- **Test:** `admin can sanctify themselves`
- **Status:** Passing (covered in Wheel section)

### Planned Tests

#### ❌ User Management (P2)
- **Validates:**
  - View user details
  - Edit user settings
  - Ban/unban users
  - View user history

#### ❌ Content Moderation (P2)
- **Validates:**
  - Delete inappropriate content
  - Move to tomb
  - Resurrect deleted nodes

#### ❌ System Settings (P2)
- **Validates:**
  - Modify global settings
  - Clear caches
  - View system logs

### Edge Cases to Test

- [ ] Admin actions as non-admin (403)
- [ ] Admin actions on other admins
- [ ] Audit log for admin actions

---

## 10. Search Functionality

**Priority:** P1 (High)
**Current Coverage:** 0/6 tests (0%)
**Status:** ❌ Not Started

### Planned Tests

#### ❌ Basic Search (P1)
- **Validates:**
  - Search by title
  - Results display correctly
  - Pagination works

#### ❌ User Search (P1)
- **Validates:**
  - Find users by username
  - Partial matches work
  - Results link to user pages

#### ❌ Advanced Search (P2)
- **Validates:**
  - Filter by node type
  - Filter by date range
  - Filter by author

### Edge Cases to Test

- [ ] Empty search query
- [ ] Special characters in search
- [ ] Very long search queries
- [ ] No results found
- [ ] Thousands of results (performance)

---

## 11. Notifications

**Priority:** P1 (High)
**Current Coverage:** 0/5 tests (0%)
**Status:** ❌ Not Started

### Planned Tests

#### ❌ View Notifications (P1)
- **Validates:**
  - Notification list displays
  - Unread count correct
  - Notifications link to relevant content

#### ❌ Dismiss Notification (P1)
- **Validates:**
  - Dismiss button works
  - Notification removed from list
  - Count updates

#### ❌ Notification Settings (P2)
- **Validates:**
  - Enable/disable notification types
  - Settings save correctly

### Edge Cases to Test

- [ ] Dismiss already-dismissed notification
- [ ] Dismiss notification from another user (security)
- [ ] Notification for deleted content
- [ ] Large number of notifications (>100)

---

## Current Failures

### Immediate Issues to Fix

1. **Login assertion selector** (`navigation.spec.js:33`)
   - **Issue:** `text=root` matches 9 elements
   - **Fix:** Use more specific selector like `#username` or `data-testid`

2. **Chatterbox visibility after login** (multiple tests)
   - **Issue:** Tests timeout waiting for `#chatterbox`
   - **Debug:** Check if login actually succeeds, verify chatterbox renders for logged-in users

3. **Wheel spin result display** (`wheel.spec.js:5`)
   - **Issue:** Timeout waiting for spin result
   - **Debug:** Check if login works, verify wheel page loads

---

## Running Tests

```bash
# Run all E2E tests
npm run test:e2e

# Run specific test file
npx playwright test tests/e2e/chatterbox.spec.js

# Run in headed mode (see browser)
npm run test:e2e:headed

# Run in debug mode (step through)
npm run test:e2e:debug

# Run with UI (visual test runner)
npm run test:e2e:ui

# View test report
npx playwright show-report
```

---

## Test Maintenance

### When Adding New Tests

1. Update this document with test details
2. Add test to appropriate section
3. Update coverage percentages
4. Link to test file with line numbers
5. Document edge cases

### When Features Change

1. Review affected tests
2. Update test expectations
3. Update documentation
4. Re-run full test suite

### Regular Reviews

- **Weekly:** Review failing tests, update priorities
- **Monthly:** Coverage analysis, identify gaps
- **Quarterly:** Comprehensive test plan review

---

## Success Metrics

### Phase 2 Goals (Current)
- ✅ 16 tests implemented
- ⚠️ 10 tests passing (target: 16/16)
- ⚠️ 62.5% coverage (target: 100% of implemented)

### Phase 3 Goals (Next)
- [ ] Fix all failing tests (16/16 passing)
- [ ] Add content creation tests (10 tests)
- [ ] Add voting tests (8 tests)
- [ ] Target: 34 tests, 90%+ pass rate

### Phase 4 Goals (Future)
- [ ] Add user settings tests (12 tests)
- [ ] Add search tests (6 tests)
- [ ] Add notification tests (5 tests)
- [ ] Target: 57 tests, 95%+ pass rate

### Long-term Goals
- [ ] 100+ tests covering all features
- [ ] 95%+ pass rate sustained
- [ ] CI/CD integration
- [ ] Automated nightly runs
- [ ] Performance benchmarking

---

## Notes

- Tests use development environment (localhost:9080)
- Test user: `root` / `blah`
- Browser: Chromium (Chrome)
- Timeouts: 30 seconds per test
- Screenshots/videos saved on failure

**Last test run:** 2025-11-25
**Pass rate:** 10/16 (62.5%)
**Next review:** After fixing current failures

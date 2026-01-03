# Security Log Audit

This document tracks all `securityLog()` insertion points and their test coverage requirements.

## Overview

The `securityLog()` function is called from Pages, APIs, Delegation modules, and Application.pm. Each call requires a node_id as the first parameter, which is used by Security Monitor to categorize and sort entries.

**Current Test Coverage: PARTIAL** (Added 2026-01-01)

## securityLog Signature

```perl
$APP->securityLog($node_id_or_node, $user, $message)
```

- `$node_id_or_node` - Node ID or node hashref. Used for sorting in Security Monitor.
- `$user` - User performing the action (hashref)
- `$message` - Log message (supports e2 link syntax)

## All Security Log Insertion Points

### Page Classes (3 files, 7 calls)

| File | Line | Node Reference | Action |
|------|------|----------------|--------|
| `Page/mass_ip_blacklister.pm` | 184 | `Mass IP Blacklister` (restricted_superdoc) | IP block added |
| `Page/mass_ip_blacklister.pm` | 257 | `Mass IP Blacklister` (restricted_superdoc) | IP block removed |
| `Page/websterbless.pm` | 114 | `websterbless` (superdoc) | User websterblessed |
| `Page/ip_blacklist.pm` | 174 | `IP Blacklist` (restricted_superdoc) | IP added to blacklist |
| `Page/ip_blacklist.pm` | 220 | `IP Blacklist` (restricted_superdoc) | IP removed from blacklist |
| `Page/ip_blacklist.pm` | 287 | `IP Blacklist` (restricted_superdoc) | IP block edited |

### API Classes (14 files, 26 calls)

| File | Line | Node Reference | Action |
|------|------|----------------|--------|
| `API/signup.pm` | 89 | `Sign up` (superdoc) | User signup |
| `API/wheel.pm` | 210 | `Wheel of Surprise` (superdoc) | Wheel spin |
| `API/password.pm` | 97 | `Reset password` (superdoc) | Password reset |
| `API/xp.pm` | 110 | User node | XP recalculation |
| `API/admin.pm` | 267 | `Admin Settings` (superdoc) | Admin action |
| `API/admin.pm` | 362 | (varies) | Admin action |
| `API/admin.pm` | 390 | (varies) | Admin action |
| `API/admin.pm` | 601 | (varies) | Admin action |
| `API/admin.pm` | 822 | (varies) | Admin action |
| `API/admin.pm` | 906 | (varies) | Admin action |
| `API/superbless.pm` | 110 | `superbless` (superdoc) | XP superbless |
| `API/superbless.pm` | 207 | `superbless` (superdoc) | GP superbless |
| `API/superbless.pm` | 301 | `superbless` (superdoc) | Level adjustment |
| `API/superbless.pm` | 327 | `superbless` (superdoc) | Level adjustment |
| `API/superbless.pm` | 432 | `superbless` (superdoc) | Votes bestowed |
| `API/teddybear.pm` | 126 | `Giant Teddy Bear Suit` (superdoc) | Teddy bear action |
| `API/suspension.pm` | 203 | `Suspension Info` (superdoc) | User suspended |
| `API/suspension.pm` | 292 | `Suspension Info` (superdoc) | User unsuspended |
| `API/resurrect.pm` | 91 | `Dr. Nate's Secret Lab` (restricted_superdoc) | Node resurrected |
| `API/userimages.pm` | 36 | `New User Images` (superdoc) | Image approved |
| `API/userimages.pm` | 80 | `New User Images` (superdoc) | Image rejected |
| `API/node_parameter.pm` | 163 | `parameter` (opcode) | Parameter set |
| `API/node_parameter.pm` | 239 | `parameter` (opcode) | Parameter deleted |
| `API/giftshop.pm` | 207 | `E2 Gift Shop` (superdoc) | Star given |
| `API/giftshop.pm` | 266 | `E2 Gift Shop` (superdoc) | Votes purchased |
| `API/giftshop.pm` | 327 | `E2 Gift Shop` (superdoc) | Votes given |
| `API/giftshop.pm` | 396 | `E2 Gift Shop` (superdoc) | C! given |
| `API/giftshop.pm` | 466 | `E2 Gift Shop` (superdoc) | C! purchased |
| `API/giftshop.pm` | 576 | `E2 Gift Shop` (superdoc) | Topic changed |
| `API/giftshop.pm` | 687 | `E2 Gift Shop` (superdoc) | Easter egg given |
| `API/writeup_reparent.pm` | 265 | New e2node | Writeup reparented |
| `API/sanctify.pm` | 157 | `Sanctify user` (superdoc) | User sanctified |

### Delegation Modules (3 files, 17 calls)

| File | Line | Node Reference | Action |
|------|------|----------------|--------|
| `Delegation/opcode.pm` | 321 | `bless` (opcode) | User blessed 10GP |
| `Delegation/opcode.pm` | 371 | `bestow` (opcode) | 25 votes bestowed |
| `Delegation/opcode.pm` | 588 | `E2 Gift Shop` (superdoc) | Room topic changed |
| `Delegation/opcode.pm` | 1078 | `insure` (opcode) | Writeup uninsured |
| `Delegation/opcode.pm` | 1083 | `insure` (opcode) | Writeup insured |
| `Delegation/opcode.pm` | 1116 | `Recent Node Notes` (superdoc) | Note removed |
| `Delegation/opcode.pm` | 1162 | `unlockaccount` (opcode) | Account unlocked |
| `Delegation/opcode.pm` | 1332 | `flushcbox` (opcode) | Chat flushed |
| `Delegation/opcode.pm` | 1885 | `Sanctify user` (superdoc) | User sanctified |
| `Delegation/htmlcode.pm` | 10692 | `IP Blacklist` (restricted_superdoc) | IP blocked |
| `Delegation/htmlcode.pm` | 10786 | `lockaccount` (opcode) | Account locked |
| `Delegation/htmlcode.pm` | 12248 | `massacre` (opcode) | Node deleted |
| `Delegation/htmlcode.pm` | 13075 | `The Gift of Star` (node_forward) | Star given |
| `Delegation/htmlcode.pm` | 13163 | `Buy Votes` (node_forward) | Votes purchased |
| `Delegation/htmlcode.pm` | 13228 | `The Gift of Votes` (node_forward) | Votes given |
| `Delegation/htmlcode.pm` | 13297 | `The Gift of Ching` (node_forward) | C! given |
| `Delegation/htmlcode.pm` | 13390 | `Buy Chings` (node_forward) | C! purchased |
| `Delegation/htmlcode.pm` | 13479 | `$NODE` (current node) | Room topic changed |
| `Delegation/htmlcode.pm` | 13641 | `The Gift of Eggs` (node_forward) | Easter egg given |
| `Delegation/maintenance.pm` | 679 | `The Old Hooked Pole` (restricted_superdoc) | User deleted |

### Application.pm (3 calls)

| File | Line | Node Reference | Action |
|------|------|----------------|--------|
| `Application.pm` | 440 | `Sign up` or `Reset password` (superdoc) | Account activation |
| `Application.pm` | 1080 | `parameter` (opcode) | Parameter set |
| `Application.pm` | 1103 | `parameter` (opcode) | Parameter deleted |

## Node Types Used as Log Targets

These node types are referenced in security log calls. When migrating to new Page types, we must ensure these nodes exist and can be looked up:

| Node Title | Current Type | Used By |
|------------|--------------|---------|
| `bless` | opcode | opcode.pm |
| `bestow` | opcode | opcode.pm |
| `flushcbox` | opcode | opcode.pm |
| `insure` | opcode | opcode.pm |
| `lockaccount` | opcode | htmlcode.pm |
| `massacre` | opcode | htmlcode.pm |
| `parameter` | opcode | Application.pm, node_parameter.pm |
| `unlockaccount` | opcode | opcode.pm |
| `Admin Settings` | superdoc | admin.pm |
| `E2 Gift Shop` | superdoc | giftshop.pm, opcode.pm |
| `New User Images` | superdoc | userimages.pm |
| `Recent Node Notes` | superdoc | opcode.pm |
| `Reset password` | superdoc | password.pm, Application.pm |
| `Sanctify user` | superdoc | sanctify.pm, opcode.pm |
| `Sign up` | superdoc | signup.pm, Application.pm |
| `superbless` | superdoc | superbless.pm |
| `Suspension Info` | superdoc | suspension.pm |
| `websterbless` | superdoc | websterbless.pm |
| `Wheel of Surprise` | superdoc | wheel.pm |
| `Dr. Nate's Secret Lab` | restricted_superdoc | resurrect.pm |
| `Giant Teddy Bear Suit` | restricted_superdoc | teddybear.pm |
| `IP Blacklist` | restricted_superdoc | ip_blacklist.pm, htmlcode.pm |
| `Mass IP Blacklister` | restricted_superdoc | mass_ip_blacklister.pm |
| `The Old Hooked Pole` | restricted_superdoc | maintenance.pm |
| `Buy Chings` | node_forward | htmlcode.pm |
| `Buy Votes` | node_forward | htmlcode.pm |
| `The Gift of Ching` | node_forward | htmlcode.pm |
| `The Gift of Eggs` | node_forward | htmlcode.pm |
| `The Gift of Star` | node_forward | htmlcode.pm |
| `The Gift of Votes` | node_forward | htmlcode.pm |

## Required Tests

### Test File: `t/security_log.t`

Each securityLog call should have a corresponding test that verifies:

1. The log entry is created in the `securitylog` table
2. The correct `securitylog_node` (node_id) is stored
3. The correct `securitylog_user` is stored
4. The message contains expected content

### Test Categories

#### 1. API Security Log Tests

```perl
# For each API with securityLog:
# - Mock the action
# - Verify securityLog was called with correct node_id
# - Verify entry exists in securitylog table
```

| API | Method | Test Name |
|-----|--------|-----------|
| signup | create_account | `test_signup_security_log` |
| password | reset | `test_password_reset_security_log` |
| xp | recalculate | `test_xp_recalc_security_log` |
| superbless | xp/gp/level/votes | `test_superbless_*_security_log` |
| suspension | suspend/unsuspend | `test_suspension_*_security_log` |
| resurrect | resurrect_node | `test_resurrect_security_log` |
| userimages | approve/reject | `test_userimages_*_security_log` |
| node_parameter | set/delete | `test_parameter_*_security_log` |
| giftshop | (7 actions) | `test_giftshop_*_security_log` |
| writeup_reparent | reparent | `test_reparent_security_log` |
| sanctify | sanctify | `test_sanctify_security_log` |
| teddybear | action | `test_teddybear_security_log` |
| wheel | spin | `test_wheel_security_log` |
| admin | (6 actions) | `test_admin_*_security_log` |

#### 2. Page Security Log Tests

| Page | Action | Test Name |
|------|--------|-----------|
| mass_ip_blacklister | add/remove | `test_mass_ip_*_security_log` |
| ip_blacklist | add/remove/edit | `test_ip_blacklist_*_security_log` |
| websterbless | bless | `test_websterbless_security_log` |

#### 3. Opcode Security Log Tests

| Opcode | Test Name |
|--------|-----------|
| bless | `test_bless_security_log` |
| bestow | `test_bestow_security_log` |
| insure/uninsure | `test_insure_*_security_log` |
| lockaccount/unlockaccount | `test_lock_*_security_log` |
| flushcbox | `test_flush_security_log` |
| massacre | `test_massacre_security_log` |

## Migration Risks

When changing node types (e.g., superdoc → page), ensure:

1. **Node lookup still works**: `$DB->getNode("Node Title", 'new_type')`
2. **Node IDs are stable**: Don't change node_id values
3. **Security Monitor categories**: The node_id determines which category in Security Monitor

### Safe Migration Pattern

```perl
# Instead of hardcoding type:
my $node = $DB->getNode("Sign up", 'superdoc');

# Use type-agnostic lookup (if node_id is known):
my $node = $DB->getNodeById($KNOWN_NODE_ID);

# Or look up by title only:
my $node = $DB->getNode("Sign up");
```

## Test Coverage Status

Security log assertions are integrated into existing API test files rather than a standalone test.

| API/Module | Test File | Coverage Status |
|------------|-----------|-----------------|
| `API/sanctify.pm` | `t/050_sanctify_api.t` | ✓ Covered |
| `API/giftshop.pm` | `t/049_giftshop_api.t` | ✓ Covered (give_ching) |
| `API/suspension.pm` | `t/071_suspension_api.t` | ✓ Covered (suspend/unsuspend) |
| `API/wheel.pm` | `t/045_wheel_api.t` | ✓ Covered |
| `API/admin.pm` | `t/051_admin_api.t` | ✓ Covered (insure) |
| `API/signup.pm` | `t/063_signup_api.t` | ⚠ Not covered (no actual user creation) |
| `API/resurrect.pm` | `t/015_node_resurrection.t` | ⚠ Not covered (uses low-level $DB->resurrectNode) |
| `API/superbless.pm` | - | ⚠ No test file |
| `API/teddybear.pm` | - | ⚠ No test file |
| `API/userimages.pm` | - | ⚠ No test file |
| `API/password.pm` | - | ⚠ No test file |
| `API/xp.pm` | - | ⚠ No test file |
| `API/node_parameter.pm` | `t/081_node_parameter_api.t` | ⚠ Needs security log check |
| `API/writeup_reparent.pm` | `t/053_writeup_reparent_api.t` | ⚠ Needs security log check |
| Page classes | - | ⚠ Not covered |
| Delegation modules | - | ⚠ Not covered |
| Application.pm | - | ⚠ Not covered |

## Action Items

1. [x] Add security log assertions to sanctify API test
2. [x] Add security log assertions to giftshop API test
3. [x] Add security log assertions to suspension API test
4. [x] Add security log assertions to wheel API test
5. [ ] Create tests for superbless, teddybear, userimages, password, xp APIs
6. [ ] Add security log checks to node_parameter and writeup_reparent tests
7. [ ] Add integration test that verifies Security Monitor displays entries
8. [ ] Document node_id requirements for each security category
9. [ ] Consider adding a helper method: `$APP->securityLogByTitle($title, $user, $message)`

---

Last Updated: 2026-01-01

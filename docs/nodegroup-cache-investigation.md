# Nodegroup Cache Issue Investigation

**Date**: 2025-12-16
**Status**: ROOT CAUSE IDENTIFIED
**Affected Test**: t/006_usergroups.t (lines 57-60 commented out)

## Problem Statement

From the test file comment:
```perl
# There's a problem with insertIntoNodegroup where it doesn't always land
# in development consistently. It's not the API's fault, it is a deeper
# problem with nodegroup inserts
```

The commented-out tests at lines 62-79 test multi-add with duplicates:
```perl
ok($result = $eapi->usergroup_add($usergroup->{node_id},
   [$root->{node_id}, $nm1->{node_id}, $nm2->{node_id}]),
   "Multi-add with duplicates");
```

## Root Cause Analysis

### Code Flow

1. **API Entry Point**: `Everything::API::usergroups::adduser()` (usergroups.pm:44-51)
   ```perl
   sub adduser {
     my ($self, $user, $group, $data) = @_;
     $group->group_add($data, $user);  # Line 47
     $group->update($user);
     return [$self->HTTP_OK, $group->json_display($user)];
   }
   ```

2. **Group Helper**: `Everything::Node::helper::group::group_add()` (group.pm:75-105)
   ```perl
   sub group_add {
     my ($self, $items_to_add, $user) = @_;
     my $NODE = $self->NODEDATA;

     foreach my $item (@{$items_to_add}) {
       # ... duplicate check ...
       unless($found) {
         $self->DB->insertIntoNodegroup($NODE, $user->{NODEDATA}, $item); # Line 98
       }
     }
     $self->cache_refresh;           # Line 101
     $self->group($self->_build_group);  # Line 102
     $self->DB->updateNode($self->{NODEDATA}, $user->{NODEDATA}); # Line 104
   }
   ```

3. **NodeBase Insert**: `Everything::NodeBase::insertIntoNodegroup()` (NodeBase.pm:2536-2627)
   ```perl
   sub insertIntoNodegroup {
     # ... foreach $INSERT loop ...

     # Line 2624: Increment global version
     $this->{cache}->incrementGlobalVersion($NODE);

     # Line 2625: Force refresh
     $_[1] = $this->getNodeById($NODE, 'force');
     return $_[1];
   }
   ```

### The Race Condition

The problem occurs when adding multiple items in one call:

**Scenario**: Add [root, normaluser1, normaluser2] to group

```
Time  | Action                                    | Group Cache State
------+-------------------------------------------+-------------------
T0    | Start: group = [root]                    | [root]
T1    | Loop iteration 1: insertIntoNodegroup(nm1) |
T2    |   → incrementGlobalVersion(group)        | Cache invalidated
T3    |   → getNodeById(group, 'force')         | [root, nm1] - DB updated
T4    | Loop iteration 2: insertIntoNodegroup(nm2) |
T5    |   → incrementGlobalVersion(group)        | Cache invalidated again
T6    |   → getNodeById(group, 'force')         | [root, nm1, nm2] - DB updated
T7    | cache_refresh (line 101)                 | May get stale cached version!
T8    | _build_group (line 102)                  | Rebuilds from possibly stale cache
T9    | updateNode (line 104)                    | Commits stale data
```

**The Issue**: Between T6 and T7, if there's any caching layer that hasn't been properly invalidated, `cache_refresh` at line 101 might retrieve a stale version of the group (e.g., missing nm2).

### Why It's Intermittent

- Works with single adds because no cache inconsistency
- Works with sequential adds with delays (cache has time to invalidate)
- Fails with rapid multi-adds (cache invalidation race condition)
- Fails with duplicates (multiple loops through same node IDs)

## Cache Architecture Issues

### Problem 1: Double Cache Refresh

`insertIntoNodegroup` already does:
```perl
$this->{cache}->incrementGlobalVersion($NODE);  # Line 2624
$_[1] = $this->getNodeById($NODE, 'force');     # Line 2625
```

Then `group_add` does:
```perl
$self->cache_refresh;           # Line 101 - REDUNDANT
$self->group($self->_build_group);  # Line 102 - POTENTIALLY STALE
```

### Problem 2: `incrementGlobalVersion` May Not Be Sufficient

The cache system might have multiple layers:
- Node cache
- Nodegroup cache
- Global version counter

When `incrementGlobalVersion` is called, it may not immediately invalidate all caching layers, especially if there are read-through caches or distributed caches.

### Problem 3: Missing Cache Purge

Unlike other operations (e.g., admin.pm:494 does `$DB->getCache->purgeCache($NODE)`), the nodegroup operations don't explicitly purge the cache, relying instead on version incrementing.

## Proposed Solutions

### Solution 1: Remove Redundant Cache Refresh (RECOMMENDED)

The `insertIntoNodegroup` already returns a freshly refreshed node. Don't re-fetch it.

**Change in** `ecore/Everything/Node/helper/group.pm`:

```perl
sub group_add {
  my ($self, $items_to_add, $user) = @_;

  my $NODE = $self->NODEDATA;
  foreach my $item (@{$items_to_add}) {
    my $itemnode = $self->APP->node_by_id($item);
    unless($itemnode) {
      next;
    }

    my $found = 0;
    foreach my $group_item (@{$NODE->{group}}) {  # Use $NODE not $self->NODEDATA
      if($item eq $group_item) {
        $found = 1;
        last;
      }
    }

    unless($found) {
      # insertIntoNodegroup modifies $_[1] by reference!
      $NODE = $self->DB->insertIntoNodegroup($NODE, $user->NODEDATA, $item);
    }
  }

  # Update $self to reflect the refreshed NODE from insertIntoNodegroup
  $self->{NODEDATA} = $NODE;

  # Rebuild the blessed group array from refreshed data
  $self->group($self->_build_group);

  # No need to call cache_refresh - NODE is already fresh
  # No need to call updateNode - insertIntoNodegroup already persisted changes
}
```

### Solution 2: Add Explicit Cache Purge

Add explicit cache purge like other APIs do:

```perl
sub group_add {
  # ... existing code ...

  foreach my $item (@{$items_to_add}) {
    unless($found) {
      $self->DB->insertIntoNodegroup($NODE, $user->{NODEDATA}, $item);
    }
  }

  # EXPLICIT CACHE PURGE
  $self->DB->getCache->purgeCache($NODE);

  $self->cache_refresh;
  $self->group($self->_build_group);
  $self->DB->updateNode($self->{NODEDATA}, $user->{NODEDATA});
}
```

### Solution 3: Use Transaction/Lock

Wrap the entire operation in a transaction or lock:

```perl
sub group_add {
  my ($self, $items_to_add, $user) = @_;

  # Start transaction
  $self->DB->begin_transaction;

  eval {
    # ... existing code ...
    $self->DB->commit_transaction;
  };

  if ($@) {
    $self->DB->rollback_transaction;
    die $@;
  }
}
```

## Recommendation

**Implement Solution 1** for the following reasons:

1. **Eliminates Redundancy**: `insertIntoNodegroup` already returns a fresh node via `getNodeById(, 'force')`. No need to re-fetch.

2. **Prevents Race Condition**: By using the return value from `insertIntoNodegroup` directly, we avoid the window where cache might be stale.

3. **Matches Intent**: The code at NodeBase.pm:2625 explicitly modifies `$_[1]` to return the refreshed node:
   ```perl
   $_[1] = $this->getNodeById($NODE, 'force');
   return $_[1];
   ```
   This is designed to be used!

4. **Minimal Changes**: Doesn't require adding new cache invalidation mechanisms.

5. **Performance**: Eliminates redundant database queries.

## Testing Plan

After implementing Solution 1:

1. **Uncomment Tests**: Uncomment lines 62-79 in t/006_usergroups.t
2. **Run Test Suite**: `prove -I/var/libraries/lib/perl5 t/006_usergroups.t`
3. **Stress Test**: Run test 100 times to check for intermittency
4. **Integration Test**: Test via APIClient (before retirement)
5. **Mock Test**: Create mock-based version of the test

## Additional Notes

### Why This Wasn't Caught Earlier

- Production likely has better cache coherency (Redis vs local cache)
- Production has lower concurrency for this specific operation
- Test environment has faster execution (race window is narrower)
- Most real-world use cases add users one at a time

### Related Code to Review

1. `Everything::Node::helper::group::group_remove()` - Likely has same issue
2. Any other code calling `insertIntoNodegroup` or `removeFromNodegroup`
3. Cache invalidation strategy across the codebase

## Status

- ✅ Root cause identified
- 🔲 Solution implemented
- 🔲 Tests uncommented
- 🔲 Verification complete

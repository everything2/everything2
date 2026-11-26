# Everything2 Node Cache Architecture

**Author**: Claude Code / Jay Bonci
**Date**: December 2025
**Status**: Technical Analysis
**Last verified: 2026-11-22** (stamp ordering, #4735) against `ecore/Everything/NodeCache.pm`, `NodeBase.pm`, `Configuration.pm`, `app.psgi`.

> **Changes since Dec 2025 (summary):** `incrementGlobalVersion` is now an atomic upsert
> (`INSERT ... ON DUPLICATE KEY UPDATE version=version+1`); `getGlobalVersion`'s first-version insert
> is idempotent. A per-worker **hydration bundle** (#4423) preloads core nodes as permanent,
> version-exempt residents. `static_cache` dropped `htmlpage`/`opcode` (types removed) and gained
> `stylesheet` (#4419); `permanent_cache` gained `room`; `nodecache_size` default is 1300.
> `NodeBase::cached_stash` adds a per-worker TTL cache for decoded datastash payloads. Per-type cache
> stats (`getStats`) are exposed on the `cache_dump` page. `typeversion_controls` no longer exists.

## Overview

Everything2 uses a multi-layered caching system to reduce database load in a multi-process **PSGI/Starman** environment (Apache is a pure reverse proxy; the application runs in preforked Starman worker processes — mod_perl is gone). The key challenge is **cache coherency** - since each Starman worker process runs in its own memory space, changes made by one worker must be visible to all others.

The solution employs **version-based invalidation**: nodes are tagged with version numbers stored in shared database tables. When any process modifies a node, it increments the global version number, causing other processes to detect stale cached data on their next access.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Starman Worker Process                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    NodeCache (per-process)                       │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │   │
│  │  │  typeCache   │  │   idCache    │  │  CacheQueue (LRU)    │   │   │
│  │  │ {type}{title}│  │  {node_id}   │  │  Doubly-linked list  │   │   │
│  │  │   → data ref │  │   → data ref │  │  permanent + regular │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘   │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │   │
│  │  │   version    │  │  verified    │  │    typeVerified      │   │   │
│  │  │ {node_id}    │  │ {node_id}    │  │   {nodetype_id}      │   │   │
│  │  │ local ver #  │  │ per-pageload │  │   per-pageload       │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────────┘   │   │
│  │                                                                   │   │
│  │  ┌──────────────┐  ┌──────────────┐                             │   │
│  │  │  paramcache  │  │  groupCache  │                             │   │
│  │  │ {nid}{param} │  │ {nid}{memid} │                             │   │
│  │  └──────────────┘  └──────────────┘                             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         MySQL Database (shared)                          │
│  ┌──────────────────────────┐  ┌────────────────────────────────────┐   │
│  │      version table       │  │        typeversion table           │   │
│  │  version_id │ version    │  │  typeversion_id │ version          │   │
│  │  (node_id)  │ (counter)  │  │  (nodetype_id)  │ (counter)        │   │
│  │  ────────── │ ─────────  │  │  ────────────── │ ─────────        │   │
│  │  12345      │ 47         │  │  3 (htmlcode)   │ 892              │   │
│  │  12346      │ 3          │  │  15 (setting)   │ 156              │   │
│  └──────────────────────────┘  └────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Cache Layers

### Layer 1: In-Process Node Cache (NodeCache.pm)

The primary cache, storing complete node hashrefs in process memory.

**Key Components:**

| Hash | Purpose | Lifetime |
|------|---------|----------|
| `typeCache` | Name+type → queue data ref | Persistent (across pageloads) |
| `idCache` | node_id → queue data ref | Persistent |
| `version` | node_id → local version number | Persistent |
| `verified` | node_id → 1 if checked this pageload | Per-pageload (cleared in resetCache) |
| `typeVerified` | nodetype_id → 1 if type verified | Per-pageload |
| `typeVersion` | nodetype_id → version number | Rebuilt each pageload |
| `paramcache` | {node_id}{param_name} → value | Per-pageload |
| `groupCache` | {group_id}{member_id} → 1 | Persistent (until group modified) |

Also: `hydrationExempt` (node_id → 1 for hydration-bundle residents; persistent) and `stats`
(hits/misses/evictions/stale by type; persistent per worker, `getStats`/`resetStats`).

**Cache Size:** Controlled by `nodecache_size` in Configuration.pm (default: 1300 nodes)

**Permanent flag:** `NodeBase::getNodeById` caches a node as permanent if its type is in
`static_cache` **or** `permanent_cache`.

### Layer 1b: Hydration Bundle (#4423)

On each Starman worker's first request, `app.psgi` calls `NodeCache::loadHydrationCache`, which reads
a JSON bundle of core nodes (default `/var/everything/hydration/hydration_cache.json`, override
`E2_HYDRATION_CACHE_PATH`; built by `ecoretool hydrate` in `jobs/job_nodepack_builder.pl`). Each node is
inserted via `hydrateNode` as **permanent and version-exempt** (`hydrationExempt`), so it is served
without touching the DB. Nodetypes in the bundle have their derived inheritance fields stripped so
`getType` re-derives them (#4444/#4446). Best-effort: a missing/malformed bundle logs and falls back
to the normal DB path. Dev-only drift check: `E2_HYDRATION_VERIFY=1`.

### Layer 2: Static Cache (No Version Checks)

**NEW (December 2025)**: The `static_cache` is a performance optimization for "code nodes" - database rows that simply identify which Perl module to run. These nodes NEVER change at runtime; they only change via deployment (code changes require ECS task restart).

For static_cache types, `isSameVersion()` returns true immediately without querying the version table. This eliminates ~30 million version table queries per day at 600K pageloads.

```perl
has 'static_cache' => (isa => 'HashRef', is => 'ro', default => sub { {
  # Core type definitions
  "nodetype" => 1,
  "writeuptype" => 1,
  "linktype" => 1,
  "sustype" => 1,

  # Structural/template types
  "nodelet" => 1,
  "container" => 1,
  "theme" => 1,
  "stylesheet" => 1,   # deploy-managed, file-backed CSS (#4419)

  # Code-backed types (delegation modules)
  "htmlcode" => 1,
  "maintenance" => 1,

  # Code-backed document types (Page/Controller classes)
  "fullpage" => 1,
  "superdoc" => 1,
  "superdocnolinks" => 1,
  "restricted_superdoc" => 1,
  "oppressor_superdoc" => 1,
  "ticker" => 1,
  "jsonexport" => 1,

  # Other code-controlled types
  "achievement" => 1,
} });
```

**Properties of static_cache types:**
1. Never evicted from cache (permanent)
2. **No version table queries** - `isSameVersion()` returns 1 immediately
3. Changes only take effect after ECS task restart
4. Covers the 18 types listed above (`htmlpage` and `opcode` were dropped when those nodetypes were removed)

### Layer 3: Permanent Cache (With Version Checks)

Certain nodetypes are cached permanently (never evicted by LRU) but still require version checks because they can change at runtime via the web UI.

```perl
has 'permanent_cache' => (isa => 'HashRef', is => 'ro', default => sub { {
  "usergroup" => 1,
  "setting" => 1,
  "datastash" => 1,
  "room" => 1,
} });
```

**Properties of permanent_cache types:**
1. Never evicted from cache (permanent)
2. **Still require version checks** - can be modified at runtime
3. Changes take effect immediately across all processes
4. Examples: usergroup membership changes, site settings updates

### Layer 4: Global Version Table

The `version` table tracks individual node versions for cross-process invalidation:

```sql
CREATE TABLE version (
  version_id INT(11) NOT NULL,  -- Same as node_id
  version INT(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (version_id)
);
```

**How it works:**
1. When a node is cached, its global version is stored locally as its stamp. A node loaded from the
   database is stamped with the version read **before** its rows (`peekGlobalVersion`, passed to
   `cacheNode`; by title, `getNode` looks up the id first so it can do the same). Reading it after
   the rows would let a change committed between the two reads stamp the old rows with the new
   version, and this worker would serve them as current (#4735). A node with no version row yet is
   stamped -1, so its first check reloads it (the check creates the row): code that creates a node
   and then fixes up its rows without a bump relies on that reload (#4747)
2. When retrieving a cached node, `isSameVersion()` compares local vs global (no row counts as 0)
3. If versions differ, the cached node is stale and re-fetched from database
4. When a node is updated, `incrementGlobalVersion()` bumps the global version via an atomic upsert:
   `INSERT INTO version (version_id, version) VALUES (N, 1) ON DUPLICATE KEY UPDATE version = version + 1`
   (replaced a check-then-insert that raced concurrent workers into duplicate-PK errors)
5. `getGlobalVersion()` inserts a missing row as version 1 with a no-op `ON DUPLICATE KEY UPDATE`, so
   first-version creation is also race-safe

**Current statistics (dev environment, 2026-11-16):**
- 14,204 rows in version table
- Version numbers range from 1 to 4,140

### Layer 5: Type Version Table (typeversion) - DISABLED

**DISABLED December 2025**: The typeversion bulk invalidation mechanism has been disabled. It added per-pageload database overhead (`SELECT * FROM typeversion`) for a feature rarely used in practice.

```sql
CREATE TABLE typeversion (
  typeversion_id INT(11) NOT NULL,  -- Same as nodetype node_id
  version INT(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (typeversion_id)
);
```

**Historical Purpose:** Provided bulk invalidation - when ANY node of a typeversioned type was modified, ALL cached nodes of that type were invalidated across all processes.

**Why Disabled:**
- Individual node versioning via the `version` table handles invalidation correctly
- The `static_cache` optimization already skips version checks for code-backed types
- Bulk invalidation is rarely needed; most changes are to individual nodes
- The per-pageload query added unnecessary overhead

**Code Location:** The disabled code remains in `NodeCache.pm::resetCache()` for potential future removal if no issues arise.

### Layer 6: Per-Pageload Caches

Several caches are cleared at the start of each pageload via `resetCache()` / `clearSessionCache()`:

- **verified**: Tracks which nodes have been version-checked this pageload
- **typeVerified**: Tracks which nodetypes have been type-version-checked
- **paramcache**: Node parameter values

This prevents redundant database queries within a single request while ensuring fresh data on each new request.

## Cache Lifecycle

### Node Retrieval Flow

```
getNodeById(id, selectop)
    │
    ├─ if selectop != 'nocache'
    │      │
    │      └─ getCachedNodeById(id)
    │              │
    │              ├─ Found in idCache?
    │              │      │
    │              │      └─ isSameVersion(NODE)?
    │              │              │
    │              │              ├─ Already verified this pageload? → Return cached
    │              │              │
    │              │              ├─ Type verified this pageload? → Return cached
    │              │              │
    │              │              └─ Check global version table
    │              │                      │
    │              │                      ├─ Same version → Mark verified, return cached
    │              │                      │
    │              │                      └─ Different → Return undef (cache miss)
    │              │
    │              └─ Not found → Return undef
    │
    ├─ if selectop == 'force' or cache miss
    │      │
    │      └─ Fetch from database
    │
    └─ if selectop != 'nocache' and node fetched
           │
           └─ cacheNode(NODE, permanent?)
                   │
                   ├─ If already cached → removeNode first (update case)
                   │
                   ├─ Add to CacheQueue
                   │
                   ├─ Update typeCache, idCache, version hashes
                   │
                   └─ purgeCache() if over maxSize
```

### Node Update Flow

```
updateNode(NODE)
    │
    ├─ Write to database
    │
    ├─ incrementGlobalVersion(NODE)
    │      │
    │      ├─ INSERT INTO version ... ON DUPLICATE KEY UPDATE version=version+1
    │      │
    │      └─ SELECT from typeversion for the type; if a row exists:
    │              UPDATE typeversion SET version=version+1 WHERE typeversion_id=type_id
    │         (typeversion is empty in dev, so this is a SELECT-only no-op per update)
    │
    └─ bumpVersionAndRecache(NODE)
           │
           ├─ incrementGlobalVersion(NODE) (as above)
           │
           ├─ Version now exactly this worker's stamp + 1? → cacheNode(NODE) with it
           │
           └─ Otherwise another process changed the node too → drop it; the next read reloads
```

The targeted user writers (`Everything::Request` recording `lasttime`, `Application::updatePassword`,
the password-reset migration) use `bumpVersionAndRecache` the same way. Re-stamping with whatever
version is current after the bump would mark a copy missing the other change as current (#4735).
Hydration-bundle residents are version-exempt and keep the plain bump + re-cache.

Everything else saves through `updateNode`, not raw SQL on a node table: a raw write leaves every
other worker's copy current until something bumps the version (#4749 tracks the remaining sites).
`updateNode` writes each field that differs from the stored row, so load the node fresh
(`getNodeById($id, 'force')`) when the save runs alongside other writers to the same node, as
draft saves do (#4750); a copy older than the request could otherwise put back a change made
meanwhile on another worker.

### Per-Pageload Reset Flow

At the start of each request, `Everything::initEverything()` (called from `HTML::mod_perlInit` and the API dispatch path in `app.psgi`) calls `clearSessionCache()`:

```
clearSessionCache() / resetCache()
    │
    └─ Clear paramcache, verified, typeVerified
```

**Note:** The typeversion query has been disabled (December 2025). See Layer 5 above.

## CacheQueue (LRU Eviction)

The `CacheQueue` implements a doubly-linked list for O(1) LRU operations:

```perl
# Structure
{
  queueHead => { item => "HEAD", prev => ..., next => ... },
  queueTail => { item => "TAIL", prev => ..., next => ... },
  queueSize => N,
  numPermanent => M
}
```

**Operations:**
- `queueItem(NODE, permanent)` - Add to end of queue. O(1)
- `getItem(data)` - Get node and move to end (MRU). O(1)
- `getNextItem()` - Remove oldest non-permanent node. O(1) amortized
- `removeItem(data)` - Remove specific node. O(1)

**Eviction:** When cache exceeds `maxSize`, oldest non-permanent nodes are removed until under limit.

## Identified Issues and Performance Concerns

### Issue 1: Version Table Growth

**Problem:** The version table grows unbounded. Every node that has ever been cached gets an entry, and entries are never removed.

**Current State:** 1,782 rows in dev, potentially much larger in production.

**Impact:** Each version check is O(log n) on the primary key. Not critical with current size, but could become problematic.

**Mitigation:** The code comments suggest periodically deleting rows with low version numbers:
```sql
DELETE FROM version WHERE version < 50;
```

### Issue 2: TypeVersion Table High Churn (RESOLVED - December 2025)

**Historical State:** The typeversion table was populated in production with high version counts for certain types, notably `fullpage` with 3.7M version increments.

**Root Cause:** This was a legacy artifact from an old caching mechanism where node content was rendered and stored as "fullpage" cached versions. The database accumulated these version increments over 20+ years.

**Resolution:** The `static_cache` optimization (December 2025) makes this a non-issue:
- All code-backed types (including `fullpage`, `superdoc`, etc.) are now in `static_cache`
- `isSameVersion()` returns true immediately for these types without querying typeversion
- The high historical counts remain in the table but are never queried
- Since fullpage is now fully code-backed (React/Page classes), content caching no longer occurs

### Issue 3: Database Query Per Version Check (RESOLVED - December 2025)

**Historical Problem:** Every cache hit required a database query to the version table (unless already verified this pageload).

**Resolution:** The `static_cache` configuration in Configuration.pm now skips version checks entirely for code-backed types:

```perl
sub isSameVersion {
    # NEW: Skip version check entirely for static_cache types
    return 1 if exists $Everything::CONF->static_cache->{$$NODE{type}{title}};

    return 1 if exists $this->{typeVerified}{$type_id};
    return 1 if exists $this->{verified}{$node_id};

    my $ver = $this->getGlobalVersion($NODE);  # Only for non-static types
    ...
}
```

**Impact:** Eliminates ~30 million version table queries per day at 600K pageloads. Code-backed types (18 types) have zero version table overhead; hydration-bundle residents are likewise exempt (`hydrationExempt` check, which also covers Guest User).

### Issue 4: No Group Cache Invalidation (RESOLVED - December 2025)

**Historical Problem:** The `groupCache` tracked usergroup membership but had no version invalidation mechanism. When group membership changed, the cache was only invalidated via `groupUncache()` call in the modifying process. Other Starman workers had stale group membership data until their cache entry was naturally evicted.

**Resolution:** Modified `isSameVersion()` to also invalidate the `groupCache` entry when a version mismatch is detected:

```perl
sub isSameVersion {
    ...
    if($ver == $this->{version}{$$NODE{node_id}}) {
        $$this{verified}{$$NODE{node_id}} = 1;
        return 1;
    }

    # Version mismatch - also invalidate groupCache for this node.
    # This ensures usergroup membership changes propagate correctly.
    delete $this->{groupCache}{$$NODE{node_id}};

    return 0;
}
```

**How it works:**
1. When a usergroup's membership changes, `incrementGlobalVersion()` bumps the version
2. Other Starman workers still have the old version cached
3. On next access (e.g., `isApproved()` → `isGod()` → `existsInGroupCache()`), the node is fetched first
4. `isSameVersion()` detects the version mismatch and clears the `groupCache` entry
5. The next `hasGroupCache()` check returns false, triggering a fresh `selectNodegroupFlat()` call
6. Fresh membership data is cached with the new version

**Impact:** Usergroup membership changes (add/remove user from gods, editors, chanops, etc.) now propagate correctly to all Starman workers on next access.

### Issue 5: Permanent Cache Can Grow Unbounded

**Problem:** Permanent nodes are never evicted from the LRU queue. If numPermanent >= maxSize, the cache auto-doubles to prevent infinite loops:

```perl
if($this->{nodeQueue}->{numPermanent} >= $this->{maxSize}) {
    $this->setCacheSize($this->{maxSize} * 2);  # Double the cache!
}
```

**Impact:** Memory usage can grow unexpectedly if many permanent-type nodes are cached.

### Issue 6: TypeVersion Admin Page (typeversion_controls) (RESOLVED — page removed)

`typeversion_controls` was removed along with `Everything::Delegation::document`; nothing in `ecore/`
or `react/` references it now. The dev `typeversion` table is empty. Historical description:

**Problem:** The typeversion_controls page is a legacy delegation function that directly manipulates database tables without audit logging. It's also not obvious what types should be typeversioned.

**Current Implementation:**
```perl
sub typeversion_controls {
    # Shows checkboxes for ALL nodetypes
    # Inserts/deletes typeversion rows on form submission
    # No validation, no audit trail, no guidance
}
```

**Recommendation:** Replace with static configuration in Everything::Configuration (see migration plan below).

## Proposed: Static TypeVersion Configuration

> **Status 2026-11-16: largely moot.** Bulk invalidation is disabled in `resetCache`, the admin page is
> gone, and the dev `typeversion` table is empty (prod not checked). The only live code path left is
> the per-update typeversion SELECT in `incrementGlobalVersion`. Kept below as historical analysis;
> type names like `htmlpage`/`opcode` no longer exist.

Instead of managing typeversion via a database-backed admin page, define it statically in Configuration.pm:

```perl
# Proposed addition to Everything::Configuration
# Based on analysis of production typeversion table
has 'typeversioned_types' => (isa => 'ArrayRef', is => 'ro', default => sub { [
    # Permanent cache types that SHOULD be typeversioned:
    'nodetype',       # Core structural (318 updates - low, keep)
    'container',      # Structural elements (1,293 updates)
    'htmlcode',       # Cached permanently (12,182 updates)
    'nodelet',        # Sidebar components (~0 updates - keep)
    'maintenance',    # Maintenance nodes (661 updates)
    'setting',        # Site-wide settings (75K updates - review necessity)
    'writeuptype',    # Writeup types (18 updates - keep)
    'linktype',       # Link types (5 updates - keep)
    'sustype',        # Suspension types (~0 - keep)
    'theme',          # Visual themes (NOT currently typeversioned - add)
    'datastash',      # Data stashes (NOT currently typeversioned - add)

    # Non-permanent types currently typeversioned (review necessity):
    # 'document',     # 4,358 updates - do documents need bulk invalidation?
    # 'htmlpage',     # 3,221 updates
    # 'nodegroup',    # 5,922 updates
    # 'superdoc',     # 48,578 updates - very high
    # 'fullpage',     # 3.7M updates - REMOVE, too expensive
    # 'usergroup',    # 49,481 updates - permanent but high churn
    # 'room',         # 23,325 updates
    # 'opcode',       # 1,825 updates
] });
```

**Key Decisions for Migration:**

1. **Remove `fullpage` from typeversion** - 3.7M version increments is a massive overhead
2. **Add `theme` and `datastash`** - They're permanent_cache but not typeversioned
3. **Review `setting` and `usergroup`** - High churn, but likely necessary for correctness
4. **Consider removing non-permanent types** - Types like `document`, `superdoc` may not need bulk invalidation

**Benefits:**
1. Version-controlled configuration (changes tracked in git)
2. No database dependency for cache configuration
3. Clearer documentation of what types are typeversioned and why
4. Removes legacy typeversion_controls page
5. Explicit visibility into the performance cost of each type

**Migration Steps:**
1. Add `typeversioned_types` to Configuration.pm
2. Modify `resetCache()` to use config instead of database query for membership
3. Modify `incrementGlobalVersion()` to check config instead of database for membership
4. Keep typeversion table for version numbers only (don't query for membership list)
5. Retire typeversion_controls document
6. **Critical:** Remove fullpage from typeversion table in production ASAP

## Short-Term Performance Improvements

### 1. Review TypeVersion Entries for High-Churn Types

The production data shows `fullpage` with 3.7M increments. Each increment invalidates ALL fullpage nodes in ALL processes. Consider:

1. **Is fullpage typeversioning necessary?** If fullpages rarely reference each other, individual node versioning might suffice
2. **What's causing the churn?** 3.7M updates over the site's lifetime suggests something is updating fullpage nodes frequently
3. **Remove high-churn types from typeversion** if bulk invalidation isn't needed:

```sql
-- Consider removing fullpage from typeversion if not needed
DELETE FROM typeversion WHERE typeversion_id = 451267;

-- Or at minimum, add 'theme' and 'datastash' which are permanent_cache but not typeversioned:
INSERT INTO typeversion (typeversion_id, version)
SELECT node_id, 1 FROM node WHERE type_nodetype = 1 AND title IN ('theme', 'datastash')
ON DUPLICATE KEY UPDATE version = version;
```

### 2. Batch Version Preloading

Add method to preload versions for commonly-accessed nodes:

```perl
sub preloadVersions {
    my ($this, @node_ids) = @_;
    return unless @node_ids;

    my $ids = join(',', map { int($_) } @node_ids);
    my $csr = $this->{nodeBase}->sqlSelectMany(
        'version_id, version', 'version', "version_id IN ($ids)"
    );

    while (my $row = $csr->fetchrow_hashref) {
        # Pre-verify these for this pageload if versions match
        if ($this->{version}{$row->{version_id}} == $row->{version}) {
            $this->{verified}{$row->{version_id}} = 1;
        }
    }
}
```

### 3. Version Table Cleanup Cron

Add periodic cleanup of stale version entries:

```perl
# In a cron job or maintenance task
sub cleanupVersionTable {
    my ($DB) = @_;

    # Remove version entries for deleted nodes
    $DB->{dbh}->do(q{
        DELETE v FROM version v
        LEFT JOIN node n ON v.version_id = n.node_id
        WHERE n.node_id IS NULL
    });

    # Optionally: Remove low-version entries (rarely modified nodes)
    # $DB->{dbh}->do("DELETE FROM version WHERE version < 10");
}
```

### 4. Cache Hit Rate Monitoring (BUILT, differently)

`NodeCache` now tracks per-type `hits`/`misses`/`evictions`/`stale` in `$this->{stats}`
(`getStats`/`resetStats`), and the `cache_dump` page (`Everything::Page::cache_dump`) shows them along
with `NodeBase::cached_stash_stats`. The original proposal was:

```perl
# Add to NodeCache
sub getCacheStats {
    my ($this) = @_;
    return {
        cache_size => $this->getCacheSize(),
        max_size => $this->{maxSize},
        permanent_count => $this->{nodeQueue}->{numPermanent},
        types_cached => scalar keys %{$this->{typeCache}},
        version_checks => $this->{stats}{version_checks} // 0,
        cache_hits => $this->{stats}{cache_hits} // 0,
        cache_misses => $this->{stats}{cache_misses} // 0,
    };
}
```

## Configuration Reference

| Setting | Location | Default | Purpose |
|---------|----------|---------|---------|
| `nodecache_size` | Configuration.pm | 1300 | Max non-permanent nodes |
| `static_cache` | Configuration.pm | 18 types | Never evicted, never version-checked |
| `permanent_cache` | Configuration.pm | 4 types | Never evicted, still version-checked |
| `E2_HYDRATION_CACHE_PATH` | env | `/var/everything/hydration/hydration_cache.json` | Hydration bundle location |
| `static_nodetypes` | Configuration.pm | varies | Whether nodetypes are cached permanently |

## Files Reference

| File | Purpose |
|------|---------|
| `ecore/Everything/NodeCache.pm` | Main cache implementation |
| `ecore/Everything/CacheQueue.pm` | LRU queue data structure |
| `ecore/Everything/NodeBase.pm` | Database layer, calls cache methods |
| `ecore/Everything/Configuration.pm` | Cache configuration |
| `app.psgi` | Loads the hydration bundle once per worker |
| `ecore/Everything/Page/cache_dump.pm` | Cache stats display |
| `jobs/job_nodepack_builder.pl` | Builds + uploads the hydration bundle |

## See Also

- [CLAUDE.md](../CLAUDE.md) - Development guidelines
- [NodeBase.pm](../ecore/Everything/NodeBase.pm) - Database layer documentation

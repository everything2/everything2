# Random Nodes Nodelet Specification

**Purpose**: Display a rotating selection of random e2nodes to encourage content discovery
**Status**: Implemented (React + DataStash)
**Last verified**: 2026-11-16

---

## Overview

The Random Nodes nodelet shows a list of random e2nodes that have at least one writeup. The list is pre-generated periodically via a DataStash and displayed to all users. Each page load shows the same cached list (not per-request random), with a playful random phrase above the list.

---

## Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| `RandomNodes.js` | `react/components/Nodelets/RandomNodes.js` | React UI component |
| `randomnodes.pm` | `ecore/Everything/DataStash/randomnodes.pm` | DataStash generator |
| `DataStash.pm` | `ecore/Everything/DataStash.pm` | Base class for cached data |
| `getRandomNodesMany()` | `ecore/Everything/Application.pm` | Random node selection algorithm |
| `cron_datastash.pl` | `cron/cron_datastash.pl` | Scheduled regeneration trigger |
| `Everything::Cron::Schedule` | `ecore/Everything/Cron/Schedule.pm` | In-webhead cron sidecar schedule (runs `datastash` every 120s) |
| `_build_stash()` / `cached_stash()` | `ecore/Everything/PageState.pm`, `ecore/Everything/NodeBase.pm` | Request-path read with per-worker decode cache |

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              Data Generation (cron sidecar, every 120s)         │
├─────────────────────────────────────────────────────────────────┤
│  cron_datastash.pl (leader webhead, Everything::Cron::Runner)   │
│       │                                                         │
│       ▼                                                         │
│  DataStash::randomnodes->generate_if_needed()                   │
│       │                                                         │
│       ▼                                                         │
│  Application->getRandomNodesMany(12)                            │
│       │                                                         │
│       ▼                                                         │
│  Query e2node table with random OFFSET                          │
│       │                                                         │
│       ▼                                                         │
│  Store JSON in datastash node (randomnodes)                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Data Display (Request)                      │
├─────────────────────────────────────────────────────────────────┤
│  Page Request                                                   │
│       │                                                         │
│       ▼                                                         │
│  Application->buildNodeInfoStructure() checks nodelet 457857    │
│       │                                                         │
│       ▼                                                         │
│  PageState->_build_stash → DB->cached_stash("randomnodes")      │
│       │                                                         │
│       ▼                                                         │
│  e2.randomNodes sent to frontend                                │
│       │                                                         │
│       ▼                                                         │
│  RandomNodes.js renders with random phrase                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## DataStash System

### Base Class (`Everything::DataStash`)

The DataStash system provides time-based caching for expensive queries:

| Property | Type | Default | Purpose |
|----------|------|---------|---------|
| `interval` | Int | 300 | Seconds between regenerations |
| `lengthy` | Int | 0 | If 1, only run with `--lengthy` flag |
| `manual` | Int | 0 | If 1, never auto-regenerate |

### Key Methods

| Method | Purpose |
|--------|---------|
| `generate()` | Create and store new data |
| `generate_if_needed($force)` | Regenerate if interval elapsed or forced |
| `current_data()` | Retrieve current cached data |
| `update_needed()` | Check if interval has elapsed |
| `stash_name()` | Derive name from package (e.g., "randomnodes") |

### Storage Mechanism

Data is stored in a `datastash` nodetype:
- **Node ID**: 2117544 (title: "randomnodes")
- **Storage Field**: `vars` (JSON-encoded)
- **Update Tracking**: `last_update` node parameter

```perl
# Write operation
$stashnode->{vars} = JSON->encode($data);
$this->updateNode($stashnode, -1);

# Read operation
return JSON->decode($stashnode->{vars});
```

---

## Random Node Generator

### Configuration

```perl
package Everything::DataStash::randomnodes;
extends 'Everything::DataStash';

has '+interval' => (default => 60);  # Regenerate every 60 seconds
```

### Generate Method

```perl
sub generate {
  my ($this) = @_;
  my $randomnodes = [];

  foreach my $N (@{$this->APP->getRandomNodesMany(12)}) {
    push @$randomnodes, {
      "node_id" => $N->{node_id},
      "title" => $N->{title}
    };
  }

  return $this->SUPER::generate($randomnodes);
}
```

---

## Random Selection Algorithm

### `getRandomNodesMany($count)` (Application.pm)

The algorithm selects truly random individual nodes by picking separate random offsets for each:

```perl
sub getRandomNodesMany {
  my ($this, $count) = @_;

  # Sanitize and limit count
  $count = 1 if not defined($count);
  $count = int($count);
  $count = 20 if ($count > 20);  # Max 20 nodes

  # Get total eligible node count (cached 5 minutes, when $this->{cache} exists)
  my $cache_key = 'random_nodes_total_count';
  my $total_count = $this->{cache} ? $this->{cache}->get($cache_key) : undef;

  unless (defined $total_count) {
    $total_count = $this->{db}->sqlSelect(
      "COUNT(*)",
      "e2node",
      "exists(select 1 from nodegroup where nodegroup_id=e2node_id)"
    );
    $this->{cache}->set($cache_key, $total_count, 300);
  }

  return [] if $total_count == 0;

  # Select truly random individual nodes by picking random offsets for each
  my $response = [];
  my %seen_ids;  # Track seen node IDs to avoid duplicates

  for (my $i = 0; $i < $count; $i++) {
    # Try up to 3 times to find a unique node
    for (my $attempt = 0; $attempt < 3; $attempt++) {
      my $offset = int(rand($total_count));

      my $node_id = $this->{db}->sqlSelect(
        "e2node_id",
        "e2node",
        "exists(select 1 from nodegroup where nodegroup_id=e2node_id)
         LIMIT 1 OFFSET $offset"
      );

      next unless $node_id;
      next if $seen_ids{$node_id};  # Skip if already selected

      my $n = $this->{db}->getNodeById($node_id);
      if (defined($n)) {
        push @$response, $n;
        $seen_ids{$node_id} = 1;
        last;  # Found a unique node, move to next
      }
    }
  }

  return $response;
}
```

### Selection Criteria

Only e2nodes with at least one writeup are eligible:
```sql
SELECT e2node_id FROM e2node
WHERE exists(SELECT 1 FROM nodegroup WHERE nodegroup_id=e2node_id)
```

This subquery ensures:
- Node is an e2node (title/topic node)
- Node has at least one writeup (exists in nodegroup = has children)
- Empty nodeshells are excluded

### Duplicate Prevention

The algorithm tracks already-selected node IDs and retries (up to 3 times) if a duplicate is selected. This ensures variety even when the random offset happens to land on the same position twice.

### Performance Optimization

| Approach | Problem | Solution |
|----------|---------|----------|
| `ORDER BY RAND()` | Creates temp table, sorts entire result set | Not used |
| Single random OFFSET | Fast but returns consecutive nodes | Not used |
| Multiple random OFFSETs | 12 queries but truly random | **Used** |
| Count caching | COUNT(*) is expensive | Cached 5 minutes |

**Trade-off**: Uses 12 separate queries instead of 1, but each query is simple (`LIMIT 1 OFFSET N`). This ensures truly scattered random nodes rather than consecutive entries that might be thematically related.

---

## Cron Job

Scheduled by the **in-webhead cron sidecar** (`Everything::Cron::Schedule`, leader-elected via `GET_LOCK`; see `docs/cron-sidecar-design.md`), not system crontab or EventBridge. The `datastash` entry runs `cron_datastash.pl` with `type => 'rate', interval => 120` (timeout 600s); `datastash-lengthy` runs `--lengthy` every 6h. Because the cron cadence (120s) is longer than this stash's 60s interval, randomnodes effectively regenerates on every datastash run (~every 2 minutes).

### `cron/cron_datastash.pl`

Regenerates all DataStash caches based on their intervals:

```bash
# Normal run (non-lengthy stashes only)
/var/everything/cron/cron_datastash.pl

# Force regeneration
/var/everything/cron/cron_datastash.pl --force

# Run only a specific stash
/var/everything/cron/cron_datastash.pl --only=randomnodes

# Run lengthy stashes only
/var/everything/cron/cron_datastash.pl --lengthy
```

### Schedule

```perl
# ecore/Everything/Cron/Schedule.pm
{ name => 'datastash', argv => _cron('cron_datastash.pl'),
  type => 'rate', interval => 120, timeout => 600, local => 1 },
```

---

## Frontend Integration

### Data Injection

In `Application.pm:buildNodeInfoStructure()`:

```perl
# Random Nodes (nodelet ID 457857)
if ($nodelets =~ /457857/) {
  $e2->{randomNodes} = Everything::PageState->_build_stash($this->{db}, "randomnodes");
}
```

`_build_stash` calls `NodeBase::cached_stash`, a per-worker decode cache keyed on the stash's `last_update` nodeparam (self-tuning window, 30s grace; #4385/#4392). `randomNodes` is part of the page-state chrome partition (`Everything::PageState`), so it is also eligible for guest chrome caching (#4257).

### React Component

```jsx
// react/components/Nodelets/RandomNodes.js
const RandomNodes = (props) => {
  return (
    <NodeletContainer id={props.id} title="Random Nodes" ...>
      <em>{props.randomNodesPhrase}</em>
      <ul className="linklist">
        {props.randomNodes.length === 0 ? (
          <em>Check again later!</em>
        ) : (
          props.randomNodes.map((entry, index) => (
            <li key={"rn_"+index}>
              <LinkNode id={entry.node_id} display={entry.title} />
            </li>
          ))
        )}
      </ul>
    </NodeletContainer>
  );
}
```

### Random Phrases

Generated client-side once per page load, in the `E2ReactRoot` constructor (`initialState.randomNodesPhrase = this.getRandomNodesPhrase()`):

```javascript
getRandomNodesPhrase = () => {
  let choices = ['cousin','sibling','grandpa','grandma'];
  let person = choices[Math.floor(Math.random()*choices.length)];
  let rn = Math.random();

  let phrases = [
    `Nodes your ${person} would have liked:`,
    'After stirring Everything, these nodes rose to the top:',
    'Look at this mess the Death Borg made!',
    'Just another sprinkling of '+(rn<0.5?'indeterminacy':'randomness'),
    'The '+(rn<0.5?'best':'worst')+' nodes of all time:',
    (rn<0.5?'Drink up!':'Food for thought:'),
    'Things you could have written:',
    'What you are reading:',
    'Read this. You know you want to:',
    'Nodes to '+(rn<0.5?'live by':'die for')+':',
  ];

  return phrases[Math.floor(Math.random()*phrases.length)];
}
```

---

## Data Structure

### Stored in DataStash

```json
[
  { "node_id": 123456, "title": "coffee" },
  { "node_id": 234567, "title": "existentialism" },
  { "node_id": 345678, "title": "rubber duck debugging" },
  ...
]
```

### Sent to Frontend (e2.randomNodes)

Same structure as stored - array of `{node_id, title}` objects.

---

## Database Schema

### datastash Node

| Field | Value |
|-------|-------|
| `node_id` | 2117544 |
| `title` | "randomnodes" |
| `type_nodetype` | 2117441 (datastash) |
| `vars` | JSON array of random nodes |

### Node Parameter

| Node | Key | Value |
|------|-----|-------|
| randomnodes | `last_update` | Unix timestamp of last generation |

---

## Configuration

| Setting | Value | Location |
|---------|-------|----------|
| Nodes per regeneration | 12 | `randomnodes.pm` (`generate`) |
| Stash interval | 60 seconds | `randomnodes.pm` (`+interval`) |
| Cron cadence (effective refresh) | 120 seconds | `Cron/Schedule.pm` (`datastash`) |
| Count cache TTL | 300 seconds | `Application::getRandomNodesMany` |
| Max nodes per request | 20 | `Application::getRandomNodesMany` |
| Nodelet ID | 457857 | `nodepack/nodelet/random_nodes.xml` |

---

## Related Files

| File | Purpose |
|------|---------|
| `react/components/Nodelets/RandomNodes.js` | React component |
| `react/components/E2ReactRoot.js` | Phrase generator, state management |
| `ecore/Everything/DataStash/randomnodes.pm` | Data generator |
| `ecore/Everything/DataStash.pm` | Base DataStash class |
| `ecore/Everything/Application.pm` | `getRandomNodesMany()`, `buildNodeInfoStructure()` |
| `ecore/Everything/PageState.pm` | `_build_stash()` |
| `ecore/Everything/NodeBase.pm` | `stashData()` storage, `cached_stash()` read cache |
| `cron/cron_datastash.pl` | Regeneration script |
| `ecore/Everything/Cron/Schedule.pm` | Sidecar schedule |
| `nodepack/nodelet/random_nodes.xml` | Nodelet definition |
| `nodepack/datastash/randomnodes.xml` | DataStash node definition |

---

*Last verified: 2026-11-16*

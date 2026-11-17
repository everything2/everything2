# Everything2 Node Object System

**Last Updated**: 2026-11-16
**Last verified: 2026-11-16** against `ecore/Everything/Node.pm`, `Node/*.pm`, `Request.pm`, `Application.pm`, [docs/orm-migration-plan.md](orm-migration-plan.md).
**Author**: Claude Code / Jay Bonci

## Overview

This document describes the Everything2 node object system, covering the transition from legacy HASHREF-based nodes to the modern `Everything::Node` blessed object system. **DBIx::Class is dead** (decision 2026-06-29, [docs/orm-migration-plan.md](orm-migration-plan.md)) — including the earlier "DBIC for new tables only" carve-out. The direction is to **finish `Everything::Node::*` as E2's ORM layer**, move from Moose to Object::Pad incrementally (Globals → controllers → Node classes), and keep `NodeBase` as the storage engine (modernized in place).

## Table of Contents

1. [Historical Context](#historical-context)
2. [Current State: Three Node Representations](#current-state-three-node-representations)
3. [Pattern Reference Guide](#pattern-reference-guide)
4. [API Context: Blessed Nodes](#api-context-blessed-nodes)
5. [Legacy Context: Hashrefs](#legacy-context-hashrefs)
6. [Migration Patterns](#migration-patterns)
7. [Test Coverage](#test-coverage)
8. [Future Direction: Node::* on Object::Pad](#future-direction-node-on-objectpad-dbixclass-rejected)
9. [Work Items](#work-items)

---

## Historical Context

Everything2's node system has evolved through three major phases:

### Phase 1: Pure Hashrefs (Legacy)
```perl
# Original pattern (circa 2000-2015)
my $node = $DB->getNode('root', 'user');
# $node is a plain HASHREF: { node_id => 113, title => 'root', ... }

# Access via hash dereference
my $title = $node->{title};
my $id = $node->{node_id};

# Pass to $APP methods
my $level = $APP->getLevel($node);
my $is_admin = $APP->isAdmin($node);
```

**Characteristics**:
- Nodes returned as plain Perl hashrefs
- No encapsulation - direct hash access
- Business logic in `$APP` (Application.pm) and `htmlcode` functions
- No type safety
- Difficult to refactor

### Phase 2: Everything::Node (Current - Partial Migration)
```perl
# Modern pattern (2020-present)
my $user = $APP->node_by_name('root', 'user');
# $user is blessed as Everything::Node::user

# Access via methods
my $title = $user->title;
my $level = $user->level;
my $is_admin = $user->is_admin;

# Get legacy hashref when needed
my $hashref = $user->NODEDATA;
$APP->legacyFunction($hashref);
```

**Characteristics**:
- Nodes blessed into type-specific classes (`Everything::Node::user`, `Everything::Node::writeup`, etc.)
- Business logic encapsulated in node methods
- Gradual migration - some code still uses hashrefs
- `NODEDATA` method bridges old and new worlds
- Type-safe method calls

### Phase 3: Finish Node::* on Object::Pad (decided 2026-06-29; DBIx::Class rejected)

DBIx::Class was evaluated (May–June 2026) and rejected outright: E2's domain is nodes
(multi-table inheritance via `sqltablelist` + VARS + group membership), which DBIC doesn't model.
`Everything::Node::*` already is the domain layer; the plan is to finish it (relationship helpers,
fewer raw `$APP`/hashref call sites) and migrate Moose → Object::Pad in the order
Globals/Configuration (#4178) → controllers (`Everything::API`, `Everything::Page`) → `Node::*` →
PluginFactory teardown. Object::Pad fields aren't hash-accessible, which is what eventually removes
the blessed-vs-hashref split. Schema migrations (sqitch) are a separate, parallel track. Details:
[docs/orm-migration-plan.md](orm-migration-plan.md).

---

## Current State: Three Node Representations

In the current E2 codebase, you may encounter nodes in three different forms:

### 1. Blessed Everything::Node Objects
**Where**: Modern APIs, Request objects, new code
**Example**: `Everything::Node::user`, `Everything::Node::writeup`

```perl
# Created by
my $user = $APP->node_by_name('username', 'user');
my $user = $REQUEST->user;  # In API context

# Identify via
ref($user) eq 'Everything::Node::user'  # true
blessed($user)  # returns 'Everything::Node::user'
```

### 2. Plain Hashrefs
**Where**: Legacy code, `$DB->getNode()`, `Everything::Application` (raw hashrefs by design), remaining `Everything::Delegation::*` modules (`achievement`, `htmlcode`, `maintenance`, `notification`, `room`)

```perl
# Created by
my $node = $DB->getNode('title', 'type');
my $node = $DB->getNodeById($id);

# Identify via
ref($node) eq 'HASH'  # true
!blessed($node)  # true
```

### 3. Mixed/Hybrid
**Where**: Transition code, nodes upgraded on-the-fly

```perl
# A hashref that gets blessed later
my $node = $DB->getNode('title', 'type');
# ... code that blesses it ...
bless $node, 'Everything::Node::user';
```

---

## Pattern Reference Guide

### Accessing Node Data

| Task | Legacy (Hashref) | Modern (Blessed) | Notes |
|------|------------------|------------------|-------|
| Get node ID | `$node->{node_id}` | `$node->node_id` | ✅ Both work on blessed nodes |
| Get title | `$node->{title}` | `$node->title` | ✅ Use method for blessed nodes |
| Get type | `$node->{type}{title}` | `$node->type->title` | Type is also a node |
| Get author | `$node->{author_user}` | `$node->author_user` (id) or `$node->author` (blessed node) | Defined on `Everything::Node` |
| Custom field | `$node->{custom_field}` | type-specific accessor, else `$node->NODEDATA->{custom_field}` | Varies by node type |
| Permissions on a node | `$DB->canReadNode($user, $node)` | `$node->can_read_node($user)` / `can_update_node` / `can_delete_node` | |

### Checking User Permissions

| Permission | Legacy Pattern | Modern Pattern | API Context |
|------------|----------------|----------------|-------------|
| Is Admin | `$APP->isAdmin($user_hashref)` | `$user->is_admin` | `$USER->is_admin` |
| Is Guest | `$APP->isGuest($user_hashref)` | `$user->is_guest` | `$USER->is_guest` |
| Is Chanop | `$APP->isChanop($user_hashref)` | `$user->is_chanop` | `$USER->is_chanop` |
| Is Editor | `$APP->isEditor($user_hashref)` | `$user->is_editor` | `$USER->is_editor` |
| Is Developer | `$APP->isDeveloper($user_hashref)` | `$user->is_developer` | `$USER->is_developer` |
| User Level | `$APP->getLevel($user_hashref)` | `$user->level` | `$USER->level` |

The `$APP->is*` / `getLevel` helpers take a **hashref** (or id). Pass `$user->NODEDATA`, or better,
use the blessed method. (`isGuest` additionally accepts a blessed `Everything::Node`; the others do not.)

### Converting Between Representations

```perl
# Blessed → Hashref (for legacy code)
my $blessed_user = $REQUEST->user;
my $hashref = $blessed_user->NODEDATA;
$APP->legacyFunction($hashref);

# Hashref → Blessed (manual upgrade)
my $hashref = $DB->getNode('root', 'user');
my $blessed = $APP->node_by_name('root', 'user');  # Fetch again as blessed

# Note: There's no automatic upgrade of existing hashrefs
# You must fetch the node again using a blessing method
```

---

## API Context: Blessed Nodes

In `Everything::API::*` modules (and `Everything::Page`/`Everything::Controller`), `$REQUEST->user` always returns a blessed `Everything::Node::user` object. Note: API handlers must always return HTTP 200 and signal errors in the body (`[$self->HTTP_OK, {success => 0, error => '...'}]`) — see CLAUDE.md.

### Correct API Patterns

```perl
package Everything::API::example;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub some_endpoint {
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user;  # Blessed Everything::Node::user
  my $APP = $self->APP;
  my $DB = $self->DB;
  my $CONF = $self->CONF;

  # ✅ CORRECT: Use blessed methods; errors go in a 200 body
  return [$self->HTTP_OK, { success => 0, error => 'Forbidden' }] if $USER->is_guest;
  return [$self->HTTP_OK, { success => 0, error => 'Admin only' }] unless $USER->is_admin;

  my $user_level = $USER->level;
  my $user_title = $USER->title;
  my $user_id = $USER->node_id;

  # ✅ CORRECT: If you need hashref for legacy APP methods
  my $user_hashref = $USER->NODEDATA;
  $APP->someLegacyMethod($user_hashref);

  # ❌ WRONG: APP helpers expect hashrefs, not blessed objects
  # my $level = $APP->getLevel($USER);  # pass $USER->NODEDATA or use $USER->level

  # ❌ WRONG: Don't use hashref access on blessed objects
  # my $title = $USER->{title};  # Works but wrong pattern
}
```

### Everything::Request User Delegation

The `Everything::Request` object delegates these methods to the user object (`handles` on the `user` attribute):

```perl
# These all work because Request delegates to user:
$REQUEST->is_guest
$REQUEST->is_admin
$REQUEST->is_editor
$REQUEST->is_chanop
$REQUEST->is_clientdev
$REQUEST->is_developer
$REQUEST->VARS

# Equivalent to:
$REQUEST->user->is_guest
$REQUEST->user->is_admin
# etc.
```

---

## Legacy Context: Hashrefs

In legacy code (`Everything::Application`, the remaining `Everything::Delegation::*` modules), nodes are often plain hashrefs. (`Delegation::document`, `htmlpage` and `opcode` no longer exist.)

### Legacy Patterns

```perl
# In Everything::Application or a remaining Delegation module

sub some_legacy_function {
  my $node = shift;
  my $USER = shift;

  # These are plain hashrefs, not blessed

  # ✅ CORRECT: Use hash dereference
  my $title = $node->{title};
  my $user_id = $USER->{user_id};

  # ✅ CORRECT: Use $APP/$DB methods
  my $level = $APP->getLevel($USER);
  my $is_admin = $APP->isAdmin($USER);

  # ❌ WRONG: Don't call methods on hashrefs
  # my $level = $USER->level;  # Dies: "Can't call method on unblessed reference"
}
```

---

## Migration Patterns

### When Migrating Code: Hashref → Blessed

**Before** (legacy delegation/htmlcode):
```perl
sub create_room {
  my $USER = shift;
  my $title = shift;

  # Hashref access
  if ($APP->isGuest($USER)) {
    return "Guests cannot create rooms";
  }

  my $level = $APP->getLevel($USER);
  if ($level < 5 && !$APP->isAdmin($USER)) {
    return "Too young, level 5 required";
  }

  # Create room
  my $room = $DB->insertNode({
    title => $title,
    type_nodetype => $room_type->{node_id},
    author_user => $USER->{node_id}
  });
}
```

**After** (modern API):
```perl
sub create_room {
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user;  # Blessed object
  my $data = $REQUEST->JSON_POSTDATA;
  my $title = $data->{room_title};

  # Blessed method access; errors returned as HTTP 200 + success => 0
  if ($USER->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Guests cannot create rooms' }];
  }

  my $level = $USER->level;
  if ($level < 5 && !$USER->is_admin) {
    return [$self->HTTP_OK, { success => 0, error => 'Too young, level 5 required' }];
  }

  # Create room (or use blessed methods with NODEDATA if needed)
  my $room = $DB->insertNode({
    title => $title,
    type_nodetype => $room_type->{node_id},
    author_user => $USER->node_id
  });
}
```

### Dealing with Mixed Contexts

When you have blessed nodes but need to pass to legacy code:

```perl
# In API
my $USER = $REQUEST->user;  # Blessed

# Need to call legacy function that expects hashref
my $user_hashref = $USER->NODEDATA;
$APP->legacy_suspension_check($user_hashref);

# Or wrap it
sub check_suspension {
  my ($self, $USER) = @_;
  my $hashref = ref($USER) && $USER->can('NODEDATA') ? $USER->NODEDATA : $USER;
  return $self->APP->isSuspended($hashref, 'room');
}
```

---

## Test Coverage

### Current Test Structure

`t/` holds ~222 numbered `.t` files (`t/NNN_topic.t`); numbering is roughly chronological, not
by category, so grep by topic (e.g. `ls t | grep node`). React has ~313 `*.test.js` files under
`react/`. The devbuild runs Perl tests via `t/run.pl` (handles serial tests).

### API Test Pattern (Blessed Nodes)

```perl
# t/035_chatroom_api.t
use strict;
use warnings;
use Test::More;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

# Get blessed user via modern method
my $root_user = $APP->node_by_name('root', 'user');

# Test blessed methods
ok($root_user->is_admin, 'Root user is admin');
is($root_user->level, 99, 'Root user has level 99');
ok(!$root_user->is_guest, 'Root user is not guest');

# Test API with blessed user
# (APIs internally use $REQUEST->user which is blessed)
```

### Legacy Test Pattern (Hashrefs)

```perl
# t/015_node_resurrection.t
use strict;
use warnings;
use Test::More tests => 5;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

# getNode returns hashref in test context
my $node = $DB->getNode('test node', 'document');

# Test with hashref
is($node->{title}, 'test node', 'Node title correct');
ok($DB->getNodeById($node->{node_id}), 'Node exists');
```

### What Needs Test Coverage

| Area | Current Coverage | Gaps | Priority |
|------|------------------|------|----------|
| Node CRUD (hashref) | ✅ Good (t/0*.t) | None | - |
| User permissions (hashref) | ⚠️ Partial | Need suspension tests | Medium |
| API endpoints (blessed) | ⚠️ Partial | chatroom, personallinks | High |
| Node methods (blessed) | ❌ Poor | Most node types untested | High |
| NODEDATA conversion | ❌ None | Need round-trip tests | Medium |
| Mixed contexts | ❌ None | Need hybrid tests | Low |

---

## Future Direction: Node::* on Object::Pad (DBIx::Class rejected)

> **Status (decided 2026-06-29):** DBIx::Class is **dead** — not full adoption, not the
> "new tables only" carve-out. See Phase 3 above and [docs/orm-migration-plan.md](orm-migration-plan.md).
> The DBIC material below is kept only as the historical design that was rejected; do not revive it.

### Goals of the rejected DBIC design (historical)

1. **Full ORM**: Replace custom NodeBase with DBIx::Class
2. **Relationships**: Define has_many, belongs_to, many_to_many
3. **Type System**: Proper table-per-type or single-table inheritance
4. **Transactions**: ACID guarantees for complex operations
5. **Query Builder**: Rich query interface

### Proposed Schema

```perl
# Schema::Result::Node (base class)
package Everything::Schema::Result::Node;
use base 'DBIx::Class::Core';

__PACKAGE__->table('node');
__PACKAGE__->add_columns(
  node_id => { data_type => 'integer', is_auto_increment => 1 },
  title => { data_type => 'varchar', size => 255 },
  type_nodetype => { data_type => 'integer', is_foreign_key => 1 },
  createtime => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key('node_id');

__PACKAGE__->belongs_to(
  type => 'Everything::Schema::Result::Node',
  'type_nodetype'
);

# Schema::Result::User (joined table)
package Everything::Schema::Result::User;
use base 'DBIx::Class::Core';

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
  user_id => { data_type => 'integer', is_foreign_key => 1 },
  passwd => { data_type => 'varchar', size => 127 },
  email => { data_type => 'varchar', size => 40 },
  experience => { data_type => 'integer', default_value => 0 },
  karma => { data_type => 'integer', default_value => 0 },
  # ...
);

__PACKAGE__->set_primary_key('user_id');

__PACKAGE__->belongs_to(
  node => 'Everything::Schema::Result::Node',
  'user_id'
);

__PACKAGE__->has_many(
  writeups => 'Everything::Schema::Result::Writeup',
  { 'foreign.author_user' => 'self.user_id' }
);

# Usage
my $user = $schema->resultset('User')->find({ user_id => 113 });
print $user->node->title;  # 'root'
print $user->experience;   # 12345

my $writeups = $user->writeups->search(
  { reputation => { '>' => 5 } },
  { order_by => { -desc => 'createtime' } }
);
```

### Migration Path (current)

1. `Everything::Globals` / Configuration off Moose roles (#4178)
2. Controllers (`Everything::API`, `Everything::Page`) to Object::Pad
3. `Everything::Node::*` to Object::Pad (long pole: hashref pokes in `Application.pm`)
4. Retire `PluginFactory` for a plain dispatch table

---

## Work Items

### High Priority

1. **Complete API Migration**
   - ✅ nodenotes, poll, chatroom, personallinks, chatter APIs exist (`ecore/Everything/API/`)
   - Ongoing: remaining Page/controller logic → APIs (see [spec/state-mutating-pages.md](spec/state-mutating-pages.md))

2. **Add Blessed Node Test Coverage**
   - ⬜ Test suite for `Everything::Node::user` methods
   - ⬜ Test suite for `Everything::Node::writeup` methods
   - ⬜ Test NODEDATA round-trip conversions
   - ⬜ Test mixed blessed/hashref contexts

3. **Document Node Type Methods**
   - ⬜ Catalog all methods in `Everything::Node::user`
   - ⬜ Catalog all methods in `Everything::Node::writeup`
   - ⬜ Document which $APP methods have blessed equivalents

### Medium Priority

4. **Migrate Business Logic to Node Methods**
   - ⬜ Move user permission checks from Application.pm to user.pm
   - ⬜ Move writeup operations from htmlcodes to writeup.pm
   - ⬜ Move room operations from Application.pm to room.pm
   - ⬜ Create node method equivalents for common $APP operations

5. **Retire Remaining Delegation Modules** (`achievement`, `htmlcode`, `maintenance`, `notification`, `room`; #4259)
   - Move logic into tested `Everything::Application` / `Node::*` methods rather than widening delegation signatures

   Also: `Everything::Node::htmlpage` and `Everything::Node::opcode` still exist although those nodetypes were removed — cleanup candidates.

6. **Create NODEDATA Tests**
   - ⬜ Test that NODEDATA returns correct hashref structure
   - ⬜ Test that modifications to NODEDATA hashref don't affect blessed object
   - ⬜ Test round-trip: blessed → NODEDATA → blessed

### Low Priority

7. **Object::Pad migration** (see [docs/orm-migration-plan.md](orm-migration-plan.md); DBIx::Class work items dropped)

8. **Refactoring**
   - ⬜ Remove redundant $APP methods that have blessed equivalents
   - ⬜ Consolidate htmlcode functions into node methods
   - ⬜ Create consistent API response patterns

---

## Quick Reference

### "I have a node, what can I do?"

```perl
# First, identify what you have:
use Scalar::Util qw(blessed);

if (blessed($node)) {
  # It's a blessed object
  print "Type: " . ref($node);  # e.g., 'Everything::Node::user'

  # Use methods
  $node->title
  $node->node_id
  $node->type_specific_method

  # Get hashref if needed for legacy code
  my $hashref = $node->NODEDATA;

} else {
  # It's a plain hashref
  print "Type: HASHREF";

  # Use hash access
  $node->{title}
  $node->{node_id}

  # Use $APP/$DB methods
  $APP->method($node)
  $DB->method($node)
}
```

### "I need to check if user is admin"

```perl
# In API context ($REQUEST->user is blessed):
if ($USER->is_admin) { ... }

# In legacy context ($USER is hashref):
if ($APP->isAdmin($USER)) { ... }

# Universal (works for both):
my $user_data = blessed($USER) && $USER->can('NODEDATA') ? $USER->NODEDATA : $USER;
if ($APP->isAdmin($user_data)) { ... }
```

### "I'm getting 'Can't call method on unblessed reference'"

You're trying to call a method on a plain hashref. Either:

1. Fetch it as a blessed object: `$APP->node_by_name()` instead of `$DB->getNode()`
2. Use the hashref pattern: `$USER->{field}` instead of `$USER->field`
3. Convert to blessed (if possible): `my $hashref = $USER->NODEDATA`

### "I'm getting 'Not a HASH reference'"

You're trying to use hash access on a blessed object. Either:

1. Use methods: `$USER->field` instead of `$USER->{field}`
2. Get the hashref: `my $hashref = $USER->NODEDATA; $hashref->{field}`

---

## Conclusion

The Everything2 node system is in transition from legacy hashrefs to blessed objects. Understanding the difference is crucial for writing correct code:

- **APIs use blessed objects** - call methods directly
- **Legacy code uses hashrefs** - use hash access and $APP methods
- **NODEDATA bridges the gap** - converts blessed → hashref when needed
- **DBIx::Class is rejected** - `Everything::Node::*` is the ORM layer going forward, moving to Object::Pad; NodeBase stays the storage engine (see [docs/orm-migration-plan.md](orm-migration-plan.md))

When in doubt, check `blessed($node)` to determine what you're working with.

---

**See Also**:
- [ecore/Everything/Node/user.pm](../ecore/Everything/Node/user.pm) - User node implementation
- [ecore/Everything/Request.pm](../ecore/Everything/Request.pm) - Request object with user delegation
- [ecore/Everything/API.pm](../ecore/Everything/API.pm) - Base API class
- [t/035_chatroom_api.t](../t/035_chatroom_api.t) - Example API test with blessed nodes

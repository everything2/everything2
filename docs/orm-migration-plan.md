# Everything2 ORM Migration Plan
## Modernizing Node Persistence Layer with DBIx::Class

**Document Version**: 1.0
**Author**: Analysis by Claude Code
**Date**: 2025-12-06
**Status**: DRAFT - For Review After React Migration

---

## Executive Summary

This document outlines a comprehensive plan to migrate Everything2's custom node persistence layer (Everything::NodeBase + Everything::Node) to a modern ORM framework. The recommended approach is to adopt **DBIx::Class** (DBIC) while maintaining backward compatibility during a phased migration.

**Key Benefits**:
- Type-safe database operations with compile-time checking
- Schema versioning and automated migrations
- Query optimization with prepared statements and prefetch
- Reduced SQL injection risk through query builder
- Better testability and maintainability
- Industry-standard patterns and documentation

**Timeline**: Estimated 6-12 months post-React migration
**Risk Level**: High (touches core infrastructure)
**Compatibility Strategy**: Dual-layer approach with compatibility shims

---

## Table of Contents

1. [Current Architecture Analysis](#current-architecture-analysis)
2. [Everything::Node Architecture Evaluation](#everythingnode-architec22ture-evaluation)
3. [ORM Evaluation](#orm-evaluation)
4. [Migration Strategy](#migration-strategy)
5. [Implementation Phases](#implementation-phases)
6. [Technical Design](#technical-design)
7. [Risk Mitigation](#risk-mitigation)
8. [Testing Strategy](#testing-strategy)
9. [Performance Considerations](#performance-considerations)
10. [Rollback Plan](#rollback-plan)

---

## Current Architecture Analysis

### Overview

Everything2 uses a sophisticated custom ORM built around three core components:

1. **Everything::NodeBase** (2,925 lines) - Database abstraction and persistence
2. **Everything::Node** (458 lines) - Moose-based object wrapper
3. **Everything::NodeCache** (795 lines) - Multi-process caching with version tracking

### Database Schema Pattern

Everything2 uses **multi-table inheritance** where nodes are stored across joined tables:

```
Base Table (node):
  node_id, title, type_nodetype, author_user, createtime, hits, reputation

Type-Specific Tables (joined on node_id):
  user: user_id, email, passwd, karma, experience, GP
  document: document_id, doctext
  writeup: writeup_id, parent_e2node, wrtype_writeuptype
  ... (50+ node types)
```

**Join Example**:
```sql
SELECT * FROM node
  LEFT OUTER JOIN document ON node_id=document_id
  LEFT OUTER JOIN writeup ON node_id=writeup_id
WHERE node_id=123
```

### Key Features Requiring Special Handling

1. **Dynamic Type System**
   - Nodetypes stored as database records (not hardcoded classes)
   - Runtime inheritance resolution via `extends_nodetype`
   - Type-specific table joins defined in `sqltablelist` field

2. **Group Nodes**
   - Recursive group membership (usergroups containing usergroups)
   - Flattened group cache for permission checks
   - Separate `nodegroup` table for membership

3. **Node Versioning**
   - Per-node version counter in `version` table
   - Multi-process cache invalidation
   - Version check on every cached node access

4. **Permission System**
   - Type-level permissions (readers_user, writers_user, deleters_user)
   - Usergroup-based authorization
   - "gods" superuser group

5. **Serialized Data**
   - `vars` field (TEXT) stores serialized Perl hashrefs
   - Used for user preferences, settings, metadata
   - Needs inflation/deflation in ORM

6. **Node Parameters**
   - `nodeparam` table: separate key-value storage
   - More structured than vars
   - Separately cached

### Current Limitations

**Performance Issues**:
- Multiple queries per node load (base + types + version)
- No prepared statement caching
- N+1 queries when loading node lists
- Manual query construction overhead

**Maintenance Burden**:
- SQL strings scattered throughout codebase
- No schema migration framework
- Hard to track schema changes
- Type-specific logic spread across multiple files

**Safety Concerns**:
- SQL injection risks in manual query construction
- No compile-time type checking
- Mixed hashref/blessed object usage
- Inconsistent error handling

---

## Everything::Node Architecture Evaluation
## Business Logic Encapsulation and ORM Integration Strategy

**Updated**: 2025-12-19
**Purpose**: Evaluate whether Everything::Node's OO design should be preserved in ORM migration
**Context**: Post-React migration application cleanup planning

### Executive Recommendation

**PRESERVE and ENHANCE** the Everything::Node object-oriented architecture when migrating to DBIx::Class.

**Key Decision**: Maintain two-layer architecture:
- **DBIx::Class** = Persistence layer (database access, relationships, queries)
- **Everything::Node** = Domain layer (business logic, permissions, type behavior)

**Critical Insight**: Everything::Node provides more than just data access - it encapsulates 60+ type-specific classes with business logic that would be lost if eliminated.

### What Everything::Node Provides

#### 1. Type-Specific Behavior Encapsulation

Everything::Node is **NOT** just a thin wrapper around database rows. It provides rich business logic:

**Example: Everything::Node::user** (680 lines)

```perl
package Everything::Node::user;
extends 'Everything::Node::document';

# Permission checking methods (NOT in database)
sub is_guest { ... }
sub is_editor { ... }
sub is_admin { ... }
sub is_chanop { ... }

# Complex business logic
sub deliver_message {
  # Handles message forwarding, recursion detection, ignore checks
  if (my $forward_to = $self->message_forward_to) {
    $messagedata->{recurse_counter}++;
    return $forward_to->deliver_message($messagedata);
  }

  # Check if recipient is ignoring sender
  my $ignoring = $self->DB->sqlSelect(...)
  return {"ignores" => 1} if $ignoring;

  # Insert message
  $self->DB->sqlInsert("message", {...});
}

# Calculated fields (not stored in database)
sub numcools {
  return $self->DB->sqlSelect("count(*)", "coolwriteups",
    "cooledby_user=".$self->node_id);
}

sub is_online {
  return $self->DB->sqlSelect("count(*)", "room",
    "member_user=".$self->node_id);
}

# Relationship navigation
sub usergroup_memberships { ... }  # Returns array of usergroup objects
sub editable_categories { ... }    # Permission-filtered categories
sub available_weblogs { ... }      # UI configuration
```

**Why This Matters**:
- Controller code: `$user->is_editor` (clean, readable)
- Without Node classes: `$APP->isEditor($USER)` or scattered SQL
- Type polymorphism: `$node->json_display` works for ANY node type

#### 2. Permission System Abstraction

**Base Class** (Everything::Node):

```perl
sub can_read_node {
  my ($self, $user) = @_;
  return $self->DB->canReadNode($user->NODEDATA, $self->NODEDATA);
}

sub can_update_node {
  my ($self, $user) = @_;
  return $self->DB->canUpdateNode($user->NODEDATA, $self->NODEDATA);
}
```

**Usage in Controllers**:
```perl
# Clean, self-documenting
return [403, {error => 'Forbidden'}] unless $node->can_update_node($user);
```

**Without Node Classes** (bad):
```perl
# Harder to read, permission logic exposed
return [403, {error => 'Forbidden'}]
  unless $DB->canUpdateNode($USER, $NODE);
```

#### 3. JSON Serialization for React

**Base Class**:

```perl
sub json_reference {
  return { node_id => ..., title => ..., type => ... };
}

sub json_display {
  my $values = $self->json_reference;
  $values->{author} = $self->author->json_reference;
  $values->{createtime} = $self->APP->iso_date_format($self->createtime);
  return $values;
}
```

**Type-Specific Overrides** (Everything::Node::writeup):

```perl
override 'json_display' => sub {
  my ($self, $user) = @_;
  my $values = super();

  # Type-specific data
  $values->{cools} = $self->cools;
  $values->{writeuptype} = $self->writeuptype;

  # Permission-filtered data (only show rep to voters/author)
  if ($vote || $self->author_user == $user->node_id) {
    $values->{reputation} = int($self->reputation);
    $values->{upvotes} = int($self->upvotes);
    $values->{downvotes} = int($self->downvotes);
  }

  # Relationship data
  $values->{parent} = $self->parent->json_reference;
  $values->{insured} = 1 if $is_insured;

  return $values;
};
```

**Why This Matters**:
- React components receive clean JSON via `$node->json_display($user)`
- Type polymorphism: writeup, e2node, user all implement custom serialization
- User-specific data filtering built-in

#### 4. Type Inheritance Hierarchy

**Example Chain**:

```
Everything::Node (base)
  ↓
Everything::Node::document (adds doctext)
  ↓ (two branches)
  ├─ Everything::Node::user
  └─ Everything::Node::writeup
```

**Benefits**:
- Method inheritance: writeup gets document's methods automatically
- Override points: `json_display` customized per type
- Shared behavior: all documents have `doctext` accessor

### Three-Layer Architecture (Current)

```
┌─────────────────────────────────────────────────────┐
│ Controllers / Page Classes / API Endpoints          │
│                                                      │
│ Uses: $user->title, $user->is_editor                │
│       $writeup->parent->firmlinks                   │
│       $node->can_update_node($user)                 │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ Everything::Node (Domain Layer - 60+ types)         │
│                                                      │
│ ├─ Everything::Node (base - 458 lines)              │
│ │  - Wraps NODEDATA hashref                         │
│ │  - OO interface: title, author, type              │
│ │  - Permissions: can_read, can_update, can_delete  │
│ │  - CRUD: insert, update, delete                   │
│ │  - JSON: json_reference, json_display             │
│ │                                                    │
│ ├─ Type-Specific Subclasses:                        │
│ │  - Everything::Node::user (680 lines)             │
│ │    * is_guest, is_editor, deliver_message         │
│ │    * experience, GP, karma, coolsleft             │
│ │  - Everything::Node::writeup (296 lines)          │
│ │    * parent, reputation, user_has_voted           │
│ │    * cools, writeuptype, is_junk                  │
│ │  - Everything::Node::e2node                       │
│ │    * firmlinks, softlinks, group                  │
│ │  - ... (50+ more types)                           │
│ │                                                    │
│ └─ Key Insight: BUSINESS LOGIC, not just accessors  │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ Everything::NodeBase (Persistence - 2,925 lines)    │
│                                                      │
│ - Database abstraction                              │
│ - getNode, getNodeById, insertNode, updateNode      │
│ - Multi-table joins for inheritance                 │
│ - SQL construction and execution                    │
│ - Returns: hashrefs (NODEDATA)                      │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ MySQL Database                                      │
└─────────────────────────────────────────────────────┘
```

### Recommended Post-Migration Architecture

```
┌─────────────────────────────────────────────────────┐
│ Controllers / Page Classes / API Endpoints          │
│                                                      │
│ UNCHANGED - still uses:                             │
│   $user->title, $user->is_editor                    │
│   $writeup->parent->firmlinks                       │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ Everything::Node Domain Layer (PRESERVED)           │
│                                                      │
│ Changes:                                             │
│ - NODEDATA now wraps DBIC Result instead of hashref │
│ - Delegates field access to DBIC                    │
│ - Business logic UNCHANGED                          │
│                                                      │
│ Example:                                             │
│   sub experience {                                  │
│     $self->NODEDATA->experience  # DBIC accessor    │
│   }                                                 │
│                                                      │
│   sub is_editor {                                   │
│     $self->APP->isEditor(...)  # Business logic     │
│   }                                                 │
└──────────────────────┬──────────────────────────────┘
                       │ (wraps)
                       ▼
┌─────────────────────────────────────────────────────┐
│ DBIx::Class Persistence Layer (NEW - REPLACES       │
│                                NodeBase)             │
│                                                      │
│ ├─ Everything::Schema::Result::User                 │
│ │  - Column accessors (auto-generated)              │
│ │  - Relationships (belongs_to, has_many)           │
│ │  - Multi-table inheritance (manual joins)         │
│ │  - NO business logic (pure data access)           │
│ │                                                    │
│ ├─ Everything::Schema::Result::Writeup              │
│ ├─ Everything::Schema::Result::E2node               │
│ └─ ... (50+ Result classes)                         │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ MySQL Database (unchanged)                          │
└─────────────────────────────────────────────────────┘
```

### Responsibility Split

| Layer | Responsibilities | Examples |
|-------|-----------------|----------|
| **Controllers** | HTTP, request/response, routing | API endpoints, Page classes |
| **Everything::Node** | Business logic, permissions, type behavior, JSON | `is_editor()`, `can_update_node()`, `json_display()` |
| **DBIx::Class** | Database access, relationships, queries | Column accessors, `belongs_to`, `has_many` |
| **MySQL** | Data storage | Tables, indexes |

**Key Principle**: Domain logic in Node classes, persistence logic in DBIC.

### Migration Strategy: Preserve Node Layer

#### Phase 1: Dual Hashref/DBIC Support

**Goal**: Make Node classes work with both hashrefs (legacy) and DBIC Results (new)

**Before** (hashref access):
```perl
sub experience {
  my $self = shift;
  return $self->NODEDATA->{experience} || 0;
}
```

**After** (dual support):
```perl
sub experience {
  my $self = shift;
  return $self->_get_field('experience') || 0;
}

sub _get_field {
  my ($self, $field) = @_;

  # DBIC Result object
  if (blessed($self->NODEDATA) && $self->NODEDATA->can($field)) {
    return $self->NODEDATA->$field;
  }
  # Legacy hashref
  else {
    return $self->NODEDATA->{$field};
  }
}
```

#### Phase 2: Update Factory Methods

**Before** (NodeBase returns hashref):
```perl
sub node_by_id {
  my ($self, $node_id) = @_;
  my $hashref = $self->DB->getNodeById($node_id);
  return $self->_bless_node($hashref);
}
```

**After** (DBIC returns Result):
```perl
sub node_by_id {
  my ($self, $node_id) = @_;

  if ($self->CONF->{use_dbic}) {
    my $result = $self->schema->resultset('Node')->find($node_id);
    return $self->_bless_node($result);  # Wraps DBIC Result
  } else {
    my $hashref = $self->DB->getNodeById($node_id);
    return $self->_bless_node($hashref);  # Legacy hashref
  }
}
```

**Feature Flag Rollout**:
```perl
# Start at 0%, gradually increase
$Everything::CONF->{use_dbic} = 0;  # NodeBase
$Everything::CONF->{use_dbic} = 1;  # DBIC
```

#### Phase 3: Migrate Business Logic to DBIC ResultSets

**Before** (SQL in Node class):
```perl
package Everything::Node::user;

sub numcools {
  my $self = shift;
  return $self->DB->sqlSelect(
    "count(*)",
    "coolwriteups",
    "cooledby_user=".$self->node_id
  );
}
```

**After** (delegate to DBIC relationship):
```perl
package Everything::Node::user;

sub numcools {
  my $self = shift;
  return $self->NODEDATA->coolwriteups->count;  # DBIC
}

# In Everything::Schema::Result::User:
__PACKAGE__->has_many(
  coolwriteups => 'Everything::Schema::Result::Coolwriteup',
  { 'foreign.cooledby_user' => 'self.user_id' }
);
```

**Benefits**:
- Cleaner separation: business logic delegates to persistence
- Better query optimization (DBIC prefetch)
- Easier to test (mock DBIC relationships)

### Code Example: User Node with DBIC Backend

```perl
package Everything::Node::user;
use Moose;
extends 'Everything::Node::document';

# NODEDATA is now Everything::Schema::Result::User (DBIC)
# Inherits: has 'NODEDATA' => (isa => "Object", ...);

# Simple field accessors (delegate to DBIC)
sub experience { shift->_get_field('experience') || 0 }
sub GP { shift->_get_field('GP') || 0 }
sub lasttime { shift->_get_field('lasttime') }

# VARS field (DBIC inflates from JSON automatically)
sub VARS {
  my $self = shift;
  return $self->NODEDATA->vars;  # DBIC inflation
}

# Business logic (UNCHANGED)
sub is_guest {
  my $self = shift;
  return $self->APP->isGuest($self->NODEDATA->as_hashref) || 0;
}

sub is_editor {
  my $self = shift;
  return $self->APP->isEditor($self->NODEDATA->as_hashref) || 0;
}

# Complex logic uses DBIC relationships
sub numcools {
  my $self = shift;
  return $self->NODEDATA->coolwriteups_rs->count;
}

sub usergroup_memberships {
  my $self = shift;
  my @groups;

  # DBIC relationship
  my $rs = $self->NODEDATA->member_of_groups;
  while (my $group_result = $rs->next) {
    # Wrap DBIC Result in domain object
    push @groups, Everything::Node::usergroup->new(
      NODEDATA => $group_result->group_node
    );
  }

  return \@groups;
}

# Helper for dual hashref/DBIC support
sub _get_field {
  my ($self, $field) = @_;

  if (blessed($self->NODEDATA) && $self->NODEDATA->can($field)) {
    return $self->NODEDATA->$field;  # DBIC
  } else {
    return $self->NODEDATA->{$field};  # hashref
  }
}

__PACKAGE__->meta->make_immutable;
1;
```

### Why Preserve Everything::Node?

#### 1. Existing Controller Code Unchanged

**Current** (thousands of lines across 93+ documents):
```perl
my $user = $REQUEST->user;
return [403, {error => 'Forbidden'}] unless $user->is_editor;
return [$self->HTTP_OK, { numcools => $user->numcools }];
```

**After DBIC Migration** (IDENTICAL):
```perl
my $user = $REQUEST->user;  # Still Everything::Node::user
return [403, {error => 'Forbidden'}] unless $user->is_editor;
return [$self->HTTP_OK, { numcools => $user->numcools }];
```

**If We Eliminated Node Classes** (MASSIVE REWRITE):
```perl
my $user = $schema->resultset('User')->find($user_id);
# is_editor doesn't exist on DBIC Result - where does it go?
# Option 1: Scatter in controllers (BAD)
return [403, {error => 'Forbidden'}]
  unless $APP->isEditor($user->as_hashref);

# Option 2: Add to Result class (mixes concerns)
# Option 3: Service objects (another layer anyway)
```

#### 2. Business Logic Has a Home

**With Node Classes** (GOOD):
```perl
package Everything::Node::user;

# Clear ownership: user-specific business logic lives here
sub deliver_message { ... }
sub usergroup_memberships { ... }
sub editable_categories { ... }
```

**Without Node Classes** (BAD):
```perl
# Where does this logic go?
# - Controllers? (duplicated, hard to test)
# - DBIC Results? (mixes persistence and business logic)
# - Service objects? (reinventing Everything::Node)
```

#### 3. Type Polymorphism

**With Node Classes** (GOOD):
```perl
sub buildReactData {
  my ($self, $REQUEST) = @_;

  # Works for user, writeup, e2node, document, etc.
  my $node = $REQUEST->node;
  return { node => $node->json_display($REQUEST->user) };
}
```

**Without Node Classes** (BAD):
```perl
sub buildReactData {
  # Need type checking everywhere
  if ($node->result_source->name eq 'User') {
    return { node => $self->_user_json_display($node, $user) };
  } elsif ($node->result_source->name eq 'Writeup') {
    return { node => $self->_writeup_json_display($node, $user) };
  }
  # ... 60+ more types
}
```

#### 4. Separation of Concerns

**Good Architecture**:
- **Domain Layer** (Everything::Node): Business logic, permissions, type behavior
- **Persistence Layer** (DBIx::Class): Database access, relationships, queries
- **Presentation Layer** (Controllers): HTTP, routing, request/response

**Bad Architecture** (mixing persistence and business logic):
- **DBIC Results**: Database access AND business logic (hard to test)
- **Controllers**: Presentation AND business logic (duplication)

### Trade-offs Analysis

#### Option A: Keep Everything::Node + DBIC (RECOMMENDED)

**Pros**:
- ✅ Existing controller code unchanged (1000s of lines)
- ✅ Business logic preserved in domain layer
- ✅ Type polymorphism intact
- ✅ Clean separation of concerns
- ✅ Gradual migration with feature flags
- ✅ Follows "Domain-Driven Design" principles

**Cons**:
- ⚠️ Two layers to maintain
- ⚠️ Small performance overhead (wrapper objects)
- ⚠️ Need to sync Node accessors with DBIC columns

**Verdict**: **Best for E2** - preserves architecture, minimal risk

#### Option B: Eliminate Everything::Node, Use DBIC Only

**Pros**:
- ✅ One less layer to maintain
- ✅ Direct DBIC usage (no wrapper overhead)

**Cons**:
- ❌ Breaks ALL controller code
- ❌ Loses 60+ type-specific classes
- ❌ Permission logic scattered
- ❌ JSON serialization duplicated
- ❌ No polymorphism
- ❌ Massive rewrite required

**Verdict**: **Too risky** - entire application rewrite

### Conclusion

**Recommendation**: **PRESERVE Everything::Node** as domain layer, migrate NODEDATA from hashrefs to DBIx::Class Results.

**Why This Works**:

1. **Separation of Concerns**:
   - DBIx::Class = Persistence (database, relationships, queries)
   - Everything::Node = Domain (business logic, permissions, types)

2. **Existing Pattern**:
   - Current: NodeBase (persistence) + Node (domain)
   - Future: DBIx::Class (persistence) + Node (domain)
   - Just **replacing** persistence, not redesigning domain

3. **Migration Safety**:
   - Controllers unchanged (massive de-risking)
   - Feature flag rollout
   - Dual hashref/DBIC during transition

4. **Industry Best Practices**:
   - Domain-Driven Design (domain separate from persistence)
   - Similar to Rails: ActiveRecord (persistence) + Service Objects (business logic)
   - Clean Architecture: Entities (Node) vs Data Access (DBIC)

**Implementation Roadmap**:

- **Phase 1** (2-3 months): Generate DBIC schema, add compatibility layer
- **Phase 2** (3-4 months): Migrate read operations to DBIC
- **Phase 3** (2-3 months): Migrate write operations to DBIC
- **Phase 4** (2-3 months): Move business logic SQL to DBIC ResultSets
- **Phase 5** (1-2 months): Remove NodeBase

**Total**: 10-15 months post-React migration

---

## DBIx::Class Integration Architecture

**Added**: 2025-12-19
**Purpose**: Define how Everything::Node integrates with DBIx::Class
**Context**: Two-layer architecture design decisions

### Schema Access Pattern

**Recommendation**: Use **dependency injection** via Everything::Application (NOT global)

#### Why Not Global?

```perl
# ❌ BAD - Global schema object
package Everything::Schema;
our $SCHEMA = Everything::Schema->connect(...);

package Everything::Node;
sub experience {
  # Tight coupling to global state
  return $Everything::Schema::SCHEMA->resultset('User')->find(...);
}
```

**Problems**:
- Tight coupling makes testing difficult
- Can't swap schema implementations
- Global state leads to action-at-a-distance bugs
- Multiple database connections problematic

#### Recommended Pattern: Dependency Injection

```perl
package Everything::Application;

has 'schema' => (
  is => 'ro',
  isa => 'Everything::Schema',
  lazy => 1,
  builder => '_build_schema'
);

sub _build_schema {
  my $self = shift;

  # Reuse existing database handle
  my $dbh = $self->DB->getDatabaseHandle;

  # Connect DBIC using existing handle
  return Everything::Schema->connect(sub { $dbh });
}

# Factory methods delegate to schema
sub node_by_id {
  my ($self, $node_id) = @_;

  if ($self->CONF->{use_dbic}) {
    # DBIC path
    my $result = $self->schema->resultset('Node')->find($node_id);
    return unless $result;

    # Determine subclass based on type
    my $type_name = $result->nodetype->title;
    my $class = "Everything::Node::$type_name";

    # Bless DBIC Result into domain object
    return $class->new(NODEDATA => $result);
  } else {
    # Legacy NodeBase path
    my $hashref = $self->DB->getNodeById($node_id);
    return $self->_bless_node($hashref);
  }
}
```

**Benefits**:
- Schema injected through Application object
- Easy to mock in tests
- Single connection shared with existing code
- Feature flag controls DBIC vs NodeBase

#### Node Classes Access Schema via APP

```perl
package Everything::Node::user;

# Access schema through $self->APP->schema
sub numcools {
  my $self = shift;

  if (blessed($self->NODEDATA) && $self->NODEDATA->isa('DBIx::Class::Row')) {
    # DBIC: Use relationship
    return $self->NODEDATA->coolwriteups->count;
  } else {
    # Legacy: Direct SQL
    return $self->DB->sqlSelect("count(*)", "coolwriteups",
      "cooledby_user=" . $self->node_id);
  }
}
```

### Lazy Loading Strategy

**Recommendation**: Let DBIx::Class handle lazy loading automatically. Don't pre-optimize.

#### How DBIC Lazy Loading Works

**Default Behavior**: Only load the primary table, lazy-load relationships on access.

```perl
# 1. Find writeup - only queries writeup table
my $writeup = $schema->resultset('Writeup')->find(12345);
# SQL: SELECT * FROM writeup WHERE writeup_id = 12345

# 2. Access node relationship - triggers lazy load
my $title = $writeup->node->title;
# SQL: SELECT * FROM node WHERE node_id = 12345

# 3. Access document relationship - another lazy load
my $doctext = $writeup->document->doctext;
# SQL: SELECT * FROM document WHERE document_id = 12345
```

**Total**: 3 queries (one per table)

#### When Lazy Loading Is Optimal

**Existence Checks**:
```perl
# Just need to know if writeup exists
my $writeup = $schema->resultset('Writeup')->find($id);
if ($writeup) {
  # Only 1 query - no joins needed
  return 1;
}
```

**Conditional Access**:
```perl
# May or may not need related data
my $writeup = $schema->resultset('Writeup')->find($id);

# Only query node if we need it
if ($user->is_guest) {
  # Guests don't see author info - skip the join
  return;
}

# Only executes if we get here
my $author = $writeup->node->author;
```

**Single Record Operations**:
- When displaying one writeup, 3 queries is negligible
- Overhead of JOIN > benefit for single records

#### When to Use Prefetch (Eager Loading)

**Display Operations** (know you'll need all data):
```perl
my $writeup = $schema->resultset('Writeup')->search(
  { writeup_id => $id },
  { prefetch => ['node', 'document'] }
)->single;

# Now these are free (no additional queries):
my $title = $writeup->node->title;
my $doctext = $writeup->document->doctext;
```

**Total**: 1 query with JOINs

**List Operations** (avoid N+1 queries):
```perl
# BAD: N+1 queries (lazy loading in loop)
my @writeups = $schema->resultset('Writeup')->search(
  { parent_e2node => $e2node_id }
)->all;

foreach my $wu (@writeups) {
  print $wu->node->title;  # Queries node table EVERY iteration
}
# Total: 1 + N queries (N = number of writeups)

# GOOD: Prefetch to load all at once
my @writeups = $schema->resultset('Writeup')->search(
  { parent_e2node => $e2node_id },
  { prefetch => 'node' }
)->all;

foreach my $wu (@writeups) {
  print $wu->node->title;  # No query, already loaded
}
# Total: 1 query with JOIN
```

**Hot Paths** (performance-critical code):
```perl
# API endpoints that must be fast
sub buildReactData {
  my ($self, $REQUEST) = @_;

  # Prefetch everything we know we'll serialize
  my $writeup = $self->APP->schema->resultset('Writeup')->search(
    { writeup_id => $id },
    { prefetch => ['node', 'document', 'e2node', 'writeuptype'] }
  )->single;

  return { writeup => $writeup->json_display($REQUEST->user) };
}
```

### Three-Tier Lazy Loading Architecture

**Layer 1: Everything::Node** (Domain) delegates to NODEDATA
**Layer 2: DBIx::Class Result** (Persistence) defines relationships
**Layer 3: Custom ResultSets** (Queries) encapsulate access patterns

#### Layer 1: Node Classes Delegate

```perl
package Everything::Node::writeup;

# Simple accessor - delegates to NODEDATA
sub title {
  my $self = shift;
  return $self->_get_field('title');  # Might be hashref or DBIC Result
}

# Complex accessor - uses DBIC relationship
sub parent {
  my $self = shift;

  if (blessed($self->NODEDATA) && $self->NODEDATA->isa('DBIx::Class::Row')) {
    # DBIC: Use relationship (lazy loads e2node)
    my $e2node_result = $self->NODEDATA->e2node;
    return Everything::Node::e2node->new(NODEDATA => $e2node_result);
  } else {
    # Legacy: Manual load
    return $self->APP->node_by_id($self->NODEDATA->{parent_e2node});
  }
}
```

#### Layer 2: DBIC Relationships (Lazy by Default)

```perl
package Everything::Schema::Result::Writeup;

# Define relationships - NOT loaded until accessed
__PACKAGE__->belongs_to(
  node => 'Everything::Schema::Result::Node',
  { 'foreign.node_id' => 'self.writeup_id' }
);

__PACKAGE__->belongs_to(
  document => 'Everything::Schema::Result::Document',
  { 'foreign.document_id' => 'self.writeup_id' }
);

__PACKAGE__->belongs_to(
  e2node => 'Everything::Schema::Result::E2node',
  { 'foreign.e2node_id' => 'self.parent_e2node' },
  { join_type => 'left' }
);

__PACKAGE__->belongs_to(
  writeuptype => 'Everything::Schema::Result::Writeuptype',
  { 'foreign.writeuptype_id' => 'self.wrtype_writeuptype' },
  { join_type => 'left' }
);
```

#### Layer 3: Custom ResultSets (Access Pattern Optimization)

```perl
package Everything::Schema::ResultSet::Writeup;
use base 'DBIx::Class::ResultSet';

# Light load: Just writeup table
sub find_light {
  my ($self, $id) = @_;
  return $self->find($id);
  # SQL: SELECT * FROM writeup WHERE writeup_id = ?
  # Use for: Existence checks, conditional access
}

# Standard load: Include node (most common case)
sub find_standard {
  my ($self, $id) = @_;
  return $self->search(
    { writeup_id => $id },
    { prefetch => 'node' }
  )->single;
  # SQL: SELECT * FROM writeup JOIN node WHERE writeup_id = ?
  # Use for: Displaying single writeup with title/author
}

# Full load: Everything (for editing/admin)
sub find_full {
  my ($self, $id) = @_;
  return $self->search(
    { writeup_id => $id },
    { prefetch => ['node', 'document', 'e2node', 'writeuptype'] }
  )->single;
  # SQL: SELECT * FROM writeup JOIN node JOIN document JOIN e2node JOIN writeuptype
  # Use for: Edit page, admin operations
}

# Batch load: For lists (N+1 prevention)
sub find_for_e2node {
  my ($self, $e2node_id) = @_;
  return $self->search(
    { parent_e2node => $e2node_id },
    {
      prefetch => 'node',
      order_by => { -desc => 'node.createtime' }
    }
  );
  # SQL: Single query with JOIN
  # Use for: E2node display with all writeups
}
```

#### Factory Method Determines Loading Strategy

```perl
package Everything::Application;

sub node_by_id {
  my ($self, $node_id, $load_mode) = @_;
  $load_mode ||= 'standard';  # Default

  if ($self->CONF->{use_dbic}) {
    # Determine type
    my $base_result = $self->schema->resultset('Node')->find($node_id);
    return unless $base_result;

    my $type_name = $base_result->nodetype->title;
    my $rs = $self->schema->resultset(ucfirst($type_name));

    # Use appropriate finder based on load mode
    my $result;
    if ($load_mode eq 'light') {
      $result = $rs->find_light($node_id);
    } elsif ($load_mode eq 'full') {
      $result = $rs->find_full($node_id);
    } else {
      $result = $rs->find_standard($node_id);
    }

    # Wrap in domain object
    my $class = "Everything::Node::$type_name";
    return $class->new(NODEDATA => $result);
  }

  # Legacy path
  return $self->_bless_node($self->DB->getNodeById($node_id));
}
```

#### Usage Examples

```perl
# Controller code stays clean
package Everything::Page::writeup;

sub buildReactData {
  my ($self, $REQUEST) = @_;

  # Standard load: title, author, createtime (prefetches node)
  my $writeup = $REQUEST->node;  # Uses 'standard' mode

  # Full load: Editing requires all fields
  if ($REQUEST->param('mode') eq 'edit') {
    $writeup = $self->APP->node_by_id($writeup->node_id, 'full');
  }

  return { writeup => $writeup->json_display($REQUEST->user) };
}
```

### Performance Comparison

| Operation | NodeBase | DBIC Lazy | DBIC Prefetch | Winner |
|-----------|----------|-----------|---------------|--------|
| Existence check | 1 query (multi-join) | 1 query (single table) | 1 query (multi-join) | 🏆 DBIC Lazy |
| Display single writeup | 1 query (multi-join) | 3 queries (lazy load) | 1 query (multi-join) | 🏆 DBIC Prefetch |
| Display 100 writeups | 1 query (multi-join) | 300 queries (N+1!) | 1 query (multi-join) | 🏆 DBIC Prefetch |
| Conditional access | 1 query (wasted join) | 1-3 queries (on-demand) | 3 queries (wasted joins) | 🏆 DBIC Lazy |
| Memory usage | Low (hashref) | Low (single Result) | High (all Results) | 🏆 DBIC Lazy |

### Integration Example: Complete Flow

```perl
# 1. User requests writeup page
GET /node/writeup/My+Title

# 2. Controller loads writeup
package Everything::Page::writeup;

sub buildReactData {
  my ($self, $REQUEST) = @_;

  # Factory method determines loading strategy
  my $writeup = $REQUEST->node;  # Uses 'standard' mode

  # 3. Node class delegates to DBIC Result
  return {
    writeup => $writeup->json_display($REQUEST->user),
    e2node => $writeup->parent->json_reference,  # Lazy loads e2node
  };
}

# 4. DBIC Result lazy-loads relationships as needed
package Everything::Node::writeup;

sub json_display {
  my ($self, $user) = @_;

  my $values = $self->SUPER::json_display($user);

  # These trigger lazy loads only if NODEDATA is DBIC Result
  $values->{cools} = $self->cools;  # Query coolwriteups table
  $values->{writeuptype} = $self->writeuptype;  # Query writeuptype table

  return $values;
}

# 5. DBIC relationships load on-demand
package Everything::Schema::Result::Writeup;

__PACKAGE__->has_many(
  coolwriteups => 'Everything::Schema::Result::Coolwriteup',
  { 'foreign.coolwriteups_id' => 'self.writeup_id' }
);
# Only queries when $writeup->NODEDATA->coolwriteups->count is called
```

### Migration Strategy: Gradual Optimization

**Phase 1**: Use lazy loading everywhere (simplest, safest)
- Let DBIC load relationships on-demand
- No N+1 queries yet (NodeBase does multi-joins anyway)
- Focus on correctness, not optimization

**Phase 2**: Identify N+1 queries via logging
```perl
# Enable query logging in development
$schema->storage->debug(1);

# Or use DBIx::Class::QueryLog
use DBIx::Class::QueryLog;
my $ql = DBIx::Class::QueryLog->new;
$schema->storage->debugobj($ql);
$schema->storage->debug(1);

# After request, check for N+1
my $query_count = $ql->count;
warn "Executed $query_count queries" if $query_count > 5;
```

**Phase 3**: Add prefetch where needed
- List pages: Prefetch to avoid N+1
- Hot paths: Prefetch for performance
- Single records: Keep lazy loading

**Phase 4**: Create custom ResultSet finders
- Encapsulate common patterns (find_light, find_standard, find_full)
- Let factory method choose appropriate finder
- Gradually optimize based on real usage

### Key Takeaways

1. **Schema Access**: Inject via `$self->APP->schema`, NOT global
2. **Lazy Loading**: Let DBIC handle it, don't pre-optimize
3. **Prefetch**: Only use when you KNOW you'll need the data
4. **Custom ResultSets**: Encapsulate common access patterns
5. **Factory Pattern**: Let `node_by_id` choose appropriate loading strategy
6. **Measure First**: Add query logging, optimize based on data

---

## Eliminating NODEDATA: Direct DBIC Integration

**Added**: 2025-12-19
**Purpose**: Define end-state architecture eliminating NODEDATA compatibility layer
**Key Insight**: NODEDATA exists only to wrap raw hashrefs from NodeBase. Once DBIC provides proper objects, NODEDATA becomes unnecessary overhead.

### Current Problem: NODEDATA Is a Compatibility Shim

**Current Architecture** (NODEDATA wraps raw data):
```perl
package Everything::Node::user;
has 'NODEDATA' => (isa => 'HashRef');  # Raw hashref from NodeBase

sub experience {
  my $self = shift;
  return $self->NODEDATA->{experience};  # Hashref access
}

sub is_editor {
  my $self = shift;
  return $self->APP->isEditor($self->NODEDATA);  # Pass hashref
}
```

**Problem**: NODEDATA exists solely because NodeBase returns raw hashrefs without methods. Once we have DBIC Results (which ARE objects), this wrapper layer is unnecessary overhead.

### End-State Architecture: Everything::Node Extends DBIC Result

**Goal**: Everything::Node classes directly extend DBIC Result classes, adding business logic methods.

```perl
package Everything::Node::user;
use Moose;
extends 'Everything::Schema::Result::User';  # Direct inheritance

# DBIC provides data accessors automatically:
#   $user->experience (from user table)
#   $user->GP
#   $user->lasttime
#   $user->node->title (via relationship)

# Business logic methods added to Result class
sub is_editor {
  my $self = shift;
  return $self->APP->isEditor($self);
}

sub deliver_message {
  my ($self, $messagedata) = @_;
  # Business logic implementation...
}

sub numcools {
  my $self = shift;
  return $self->coolwriteups->count;  # DBIC relationship
}

__PACKAGE__->meta->make_immutable;
1;
```

**Controller usage (no NODEDATA)**:
```perl
my $user = Everything::Node::user->find($id);

return {
  experience => $user->experience,   # DBIC accessor
  GP => $user->GP,                   # DBIC accessor
  numcools => $user->numcools,       # Business logic
  is_editor => $user->is_editor,     # Business logic
};
```

### Migration Path to Eliminate NODEDATA

#### Phase 1: NODEDATA Wraps Hashrefs (Current)
```perl
package Everything::Node::user;
has 'NODEDATA' => (isa => 'HashRef');

sub experience {
  return shift->NODEDATA->{experience};
}
```

#### Phase 2: NODEDATA Wraps DBIC Results (Dual Support)
```perl
package Everything::Node::user;
has 'NODEDATA' => (isa => 'HashRef|DBIx::Class::Row');

sub experience {
  my $self = shift;

  # Check if DBIC Result
  if (blessed($self->NODEDATA) && $self->NODEDATA->isa('DBIx::Class::Row')) {
    return $self->NODEDATA->experience;  # DBIC method
  } else {
    return $self->NODEDATA->{experience};  # Hashref
  }
}
```

#### Phase 3: Everything::Node Delegates to DBIC Result
```perl
package Everything::Node::user;
extends 'Everything::Schema::Result::User';

# Thin wrapper - just adds business logic
sub is_editor {
  my $self = shift;
  return $self->APP->isEditor($self);
}

# Data accessors inherited from DBIC Result
# No NODEDATA needed!
```

#### Phase 4: Eliminate NODEDATA Entirely
- Remove NODEDATA attribute from Everything::Node
- Everything::Node classes ARE DBIC Results with business logic
- Controllers work unchanged (same method calls)

### Updated Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│ Controllers / API Endpoints                         │
│                                                      │
│ my $user = Everything::Node::user->find($id);      │
│ return { coolsleft => $user->coolsleft };          │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ Everything::Node::user                              │
│ extends Everything::Schema::Result::User            │
│                                                      │
│ ┌─────────────────────────────────────────────────┐ │
│ │ Business Logic Layer (added methods)            │ │
│ │ - is_editor()                                   │ │
│ │ - deliver_message()                             │ │
│ │ - numcools()                                    │ │
│ │ - coolsleft()                                   │ │
│ └─────────────────────────────────────────────────┘ │
│                                                      │
│ ┌─────────────────────────────────────────────────┐ │
│ │ DBIC Result Layer (inherited from parent)       │ │
│ │ - experience() [column accessor]                │ │
│ │ - GP() [column accessor]                        │ │
│ │ - lasttime() [column accessor]                  │ │
│ │ - node() [belongs_to relationship]              │ │
│ │ - coolwriteups() [has_many relationship]        │ │
│ └─────────────────────────────────────────────────┘ │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ Everything::Schema::Result::User (pure DBIC)       │
│ - Column definitions                                │
│ - Relationships                                     │
│ - No business logic                                 │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│ MySQL Database                                      │
└─────────────────────────────────────────────────────┘
```

### Factory Methods: Everything::Node->find()

Replace `$APP->node_by_id()` with class-level factory:

```perl
package Everything::Node;
use Moose::Role;  # Base is now a role, not a class

# Class method factory
sub find {
  my ($class, $id, $schema) = @_;

  # If called on base class, determine type from database
  if ($class eq 'Everything::Node') {
    my $node_result = $schema->resultset('Node')->find($id);
    return unless $node_result;

    my $type_name = $node_result->nodetype->title;
    my $node_class = "Everything::Node::$type_name";

    # Load type-specific result
    my $result = $schema->resultset(ucfirst($type_name))
      ->find_standard($id);

    return $result;  # Already blessed as Everything::Node::$type_name
  }
  # If called on subclass (Everything::Node::user->find($id))
  else {
    my $type = $class;
    $type =~ s/^Everything::Node:://;

    return $schema->resultset(ucfirst($type))->find_standard($id);
  }
}

sub find_by_name {
  my ($class, $title, $schema) = @_;

  if ($class eq 'Everything::Node') {
    # Need type parameter
    die "Cannot find_by_name on base class without type";
  }

  my $type = $class;
  $type =~ s/^Everything::Node:://;

  return $schema->resultset(ucfirst($type))->search(
    { 'node.title' => $title },
    { prefetch => 'node' }
  )->single;
}
```

**Usage**:
```perl
# Generic find (determines type from database)
my $node = Everything::Node->find(12345, $schema);

# Type-specific find (more efficient)
my $user = Everything::Node::user->find(12345, $schema);
my $root = Everything::Node::user->find_by_name('root', $schema);

# Old factory pattern (keep during migration for compatibility)
my $user = $APP->node_by_id(12345);  # Delegates to Everything::Node->find
```

### VARS Field: MySQL JSON Column Type

**Recommendation**: Migrate `vars` from TEXT (Storable/base64) to MySQL JSON column type.

**Why MySQL JSON is Superior**:

1. **Queryable**: Filter/search by JSON fields with `JSON_EXTRACT()`
2. **Indexed**: Add generated columns + indexes on JSON paths
3. **Type Validation**: MySQL validates JSON structure on INSERT/UPDATE
4. **Efficient Storage**: Binary format, not base64-encoded text
5. **Atomic Updates**: Update individual JSON keys without deserializing entire field
6. **Native Support**: DBIC has built-in JSON inflation/deflation

#### VARS in DBIC Result Class (Persistence Layer)

```perl
package Everything::Schema::Result::User;
use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/InflateColumn::Serializer/);

__PACKAGE__->add_columns(
  user_id => { data_type => 'integer' },
  experience => { data_type => 'integer' },
  GP => { data_type => 'integer' },
  lasttime => { data_type => 'datetime', is_nullable => 1 },

  # VARS as MySQL JSON column
  vars => {
    data_type => 'json',  # MySQL JSON column type (not TEXT)
    is_nullable => 1,
    serializer_class => 'JSON',
    default_value => '{}',
    # DBIC automatically:
    # - Inflates: MySQL JSON → Perl hashref when read
    # - Deflates: Perl hashref → MySQL JSON when written
  },
);

# Relationships
__PACKAGE__->belongs_to(
  node => 'Everything::Schema::Result::Node',
  { 'foreign.node_id' => 'self.user_id' }
);

__PACKAGE__->has_many(
  coolwriteups => 'Everything::Schema::Result::Coolwriteup',
  { 'foreign.cooledby_user' => 'self.user_id' }
);
```

**Database migration**:
```sql
-- Convert TEXT column to JSON
ALTER TABLE user MODIFY COLUMN vars JSON;

-- Migrate existing data (if currently Storable base64)
-- First, convert Storable to JSON using Perl script
-- Then update column type
```

#### Everything::Node::user (Business Logic Layer)

```perl
package Everything::Node::user;
use Moose;
extends 'Everything::Schema::Result::User';

with 'Everything::Globals';  # For APP, DB, CONF access

# VARS accessor (delegates to DBIC)
sub VARS {
  my $self = shift;
  return $self->vars || {};  # DBIC automatically inflates JSON → hashref
}

# Convenience accessors (business logic)
sub hidelastseen {
  my $self = shift;
  return $self->VARS->{hidelastseen} || 0;
}

sub nosocialbookmarking {
  my $self = shift;
  return $self->VARS->{nosocialbookmarking} || 0;
}

sub set_var {
  my ($self, $key, $value) = @_;
  my $vars = $self->VARS;
  $vars->{$key} = $value;
  $self->vars($vars);  # DBIC automatically deflates hashref → JSON
}

sub available_weblogs {
  my $self = shift;
  my $weblog_ids = $self->VARS->{weblogs} || [];

  # Load weblog nodes
  return [
    map { Everything::Node::weblog->find($_, $self->result_source->schema) }
    @$weblog_ids
  ];
}

# Other business logic...
sub is_editor {
  my $self = shift;
  return $self->APP->isEditor($self);
}

sub numcools {
  my $self = shift;
  return $self->coolwriteups->count;
}

__PACKAGE__->meta->make_immutable;
1;
```

**Controller usage** (unchanged):
```perl
my $user = Everything::Node::user->find($id, $schema);

# Read vars (DBIC inflates JSON automatically)
my $hidelastseen = $user->hidelastseen;
my $weblogs = $user->available_weblogs;

# Write vars (DBIC deflates to JSON automatically)
$user->set_var('hidelastseen', 1);
$user->update;  # MySQL stores as JSON
```

#### Querying JSON Fields

**Basic JSON queries**:
```perl
# Find users who hide their last seen
my @private_users = $schema->resultset('User')->search(
  \[ "JSON_EXTRACT(vars, '$.hidelastseen') = ?", 1 ]
)->all;

# Find users with specific weblog
my @weblog_users = $schema->resultset('User')->search(
  \[ "JSON_CONTAINS(vars, ?, '$.weblogs')", $weblog_id ]
)->all;
```

**Optimized with generated columns** (for frequently-queried fields):
```sql
-- Add generated column for hidelastseen
ALTER TABLE user ADD COLUMN hidelastseen_computed TINYINT
  GENERATED ALWAYS AS (COALESCE(JSON_EXTRACT(vars, '$.hidelastseen'), 0)) STORED;

-- Index it for fast queries
CREATE INDEX idx_hidelastseen ON user(hidelastseen_computed);
```

```perl
# Update DBIC Result to include generated column
package Everything::Schema::Result::User;

__PACKAGE__->add_columns(
  hidelastseen_computed => {
    data_type => 'tinyint',
    is_nullable => 0,
    # Mark as generated (read-only)
    is_auto_increment => 0,
    extra => { generated => 1 },
  },
);

# Now query like a normal indexed column (fast!)
my @private_users = $schema->resultset('User')->search(
  { hidelastseen_computed => 1 }
)->all;
```

#### Migration Strategy for VARS

**Phase 1**: Convert TEXT to JSON column type
```sql
-- Backup first!
CREATE TABLE user_backup AS SELECT * FROM user;

-- Convert column type
ALTER TABLE user MODIFY COLUMN vars JSON;
```

**Phase 2**: DBIC inflation/deflation (automatic)
```perl
# DBIC Result class handles JSON automatically
vars => {
  data_type => 'json',
  serializer_class => 'JSON',
}
```

**Phase 3**: Add generated columns for hot fields
```sql
-- For frequently-queried vars
ALTER TABLE user ADD COLUMN hidelastseen_computed TINYINT
  GENERATED ALWAYS AS (COALESCE(JSON_EXTRACT(vars, '$.hidelastseen'), 0)) STORED;

CREATE INDEX idx_hidelastseen ON user(hidelastseen_computed);
```

**Phase 4**: Business logic unchanged
```perl
# Everything::Node::user methods work exactly the same
my $hidelastseen = $user->hidelastseen;  # Reads from JSON
$user->set_var('hidelastseen', 1);       # Writes to JSON
```

### Complete Example: User Node Without NODEDATA

```perl
package Everything::Node::user;
use Moose;
extends 'Everything::Schema::Result::User';

with 'Everything::Globals';  # For APP, DB, CONF access

# Class-level factory
sub find {
  my ($class, $id, $schema) = @_;
  $schema ||= Everything::Application->instance->schema;
  return $schema->resultset('User')->find_standard($id);
}

sub find_by_name {
  my ($class, $title, $schema) = @_;
  $schema ||= Everything::Application->instance->schema;
  return $schema->resultset('User')->search(
    { 'node.title' => $title },
    { prefetch => 'node' }
  )->single;
}

# Data accessors inherited from DBIC Result:
#   $user->experience
#   $user->GP
#   $user->lasttime
#   $user->vars (auto-inflated JSON hashref)
#   $user->node (belongs_to relationship)
#   $user->coolwriteups (has_many relationship)

# Business logic methods

sub is_guest {
  my $self = shift;
  return $self->node->title eq 'Guest User';
}

sub is_editor {
  my $self = shift;
  return $self->APP->isEditor($self);
}

sub is_admin {
  my $self = shift;
  return $self->in_usergroup('gods');
}

sub in_usergroup {
  my ($self, $group_name) = @_;
  my $group = Everything::Node::usergroup->find_by_name(
    $group_name,
    $self->result_source->schema
  );
  return 0 unless $group;
  return $group->has_member($self);
}

sub numcools {
  my $self = shift;
  return $self->coolwriteups->count;
}

sub coolsleft {
  my $self = shift;
  my $total_cools = int($self->experience / 100);
  my $used_cools = $self->numcools;
  return $total_cools - $used_cools;
}

sub deliver_message {
  my ($self, $messagedata) = @_;

  # Forward if configured
  if (my $forward_to_id = $self->VARS->{message_forward_user}) {
    $messagedata->{recurse_counter} ||= 0;
    return { error => 'Forward loop' } if $messagedata->{recurse_counter} > 5;

    $messagedata->{recurse_counter}++;
    my $forward_user = Everything::Node::user->find(
      $forward_to_id,
      $self->result_source->schema
    );
    return $forward_user->deliver_message($messagedata);
  }

  # Check ignore list (DBIC query)
  my $ignoring = $self->result_source->schema
    ->resultset('MessageIgnore')
    ->search({
      ignorer => $self->user_id,
      ignoree => $messagedata->{sender_id}
    })->count;

  return { ignores => 1 } if $ignoring;

  # Insert message (DBIC create)
  $self->result_source->schema->resultset('Message')->create({
    message_to => $self->user_id,
    message_from => $messagedata->{sender_id},
    msgtext => $messagedata->{msgtext},
    tstamp => \'NOW()',
  });

  return { success => 1 };
}

# VARS accessor (delegates to DBIC JSON inflation)
sub VARS {
  my $self = shift;
  return $self->vars || {};
}

sub hidelastseen {
  my $self = shift;
  return $self->VARS->{hidelastseen} || 0;
}

sub set_var {
  my ($self, $key, $value) = @_;
  my $vars = $self->VARS;
  $vars->{$key} = $value;
  $self->vars($vars);
}

sub json_display {
  my ($self, $requesting_user) = @_;

  return {
    node_id => $self->node->node_id,
    title => $self->node->title,
    type => 'user',
    experience => $self->experience,
    GP => $self->GP,
    numcools => $self->numcools,
    coolsleft => $self->coolsleft,
    is_editor => $self->is_editor ? 1 : 0,
    is_admin => $self->is_admin ? 1 : 0,
    # Privacy: Only show lasttime if user hasn't hidden it
    ($self->hidelastseen ? () : (
      lasttime => $self->APP->iso_date_format($self->lasttime)
    )),
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**Controller usage**:
```perl
package Everything::API::user;

sub show {
  my ($self, $REQUEST, $user_id) = @_;

  my $user = Everything::Node::user->find($user_id);
  return [404, { error => 'User not found' }] unless $user;

  return [$self->HTTP_OK, {
    user => $user->json_display($REQUEST->user)
  }];
}

sub update_settings {
  my ($self, $REQUEST, $user_id) = @_;

  my $user = Everything::Node::user->find($user_id);
  return [404, { error => 'User not found' }] unless $user;

  # Update VARS (stored as JSON)
  $user->set_var('hidelastseen', $REQUEST->param('hidelastseen'));
  $user->set_var('nosocialbookmarking', $REQUEST->param('nosocialbookmarking'));
  $user->update;

  return [$self->HTTP_OK, { success => 1 }];
}
```

### Benefits of Eliminating NODEDATA

1. **Simpler Architecture**: One less layer of abstraction
2. **Better Performance**: No wrapper object overhead
3. **Direct DBIC Access**: Controllers can use DBIC features directly
4. **Cleaner Code**: `$user->experience` instead of `$user->NODEDATA->{experience}`
5. **Type Safety**: DBIC column definitions provide type hints
6. **Easier Testing**: Mock DBIC Results instead of hashrefs
7. **JSON Queries**: Can filter/search VARS fields directly in SQL
8. **Better IDE Support**: Method completion works with DBIC accessors

### Migration Checklist

- [ ] **Phase 1**: Add DBIC Result classes with JSON column for vars
- [ ] **Phase 2**: Make NODEDATA accept both HashRef and DBIC Result
- [ ] **Phase 3**: Update Everything::Node to extend DBIC Results
- [ ] **Phase 4**: Add `Everything::Node->find()` factory methods
- [ ] **Phase 5**: Migrate vars column from TEXT to JSON
- [ ] **Phase 6**: Remove NODEDATA attribute entirely
- [ ] **Phase 7**: Update all controllers to use new syntax
- [ ] **Phase 8**: Deprecate `$APP->node_by_id()` (keep for compatibility)
- [ ] **Phase 9**: Add generated columns for frequently-queried VARS fields

---

## ORM Evaluation

### Candidates Considered

| ORM | Maturity | Multi-table Inheritance | Active Development | Perl 5 Support |
|-----|----------|-------------------------|-------------------|----------------|
| **DBIx::Class** | Excellent (17+ years) | ✅ Yes (single/multi) | ✅ Active | ✅ Primary |
| Rose::DB::Object | Good (15+ years) | ✅ Yes | ⚠️ Maintenance mode | ✅ Yes |
| Fey::ORM | Fair (10+ years) | ⚠️ Limited | ❌ Inactive (archived) | ✅ Yes |
| Teng | Good (10+ years) | ❌ No | ✅ Active | ✅ Yes |
| DBIx::Lite | Fair (8+ years) | ❌ No | ⚠️ Minimal | ✅ Yes |

### Recommendation: DBIx::Class (DBIC)

**Rationale**:

✅ **Industry Standard**: Most widely-used Perl ORM, extensive documentation
✅ **Multi-table Inheritance**: Native support for single and multi-table inheritance
✅ **Active Development**: Regular releases, security fixes, community support
✅ **Feature Complete**: Relationships, prefetch, caching, transactions, migrations
✅ **Schema Management**: DBIx::Class::Schema::Loader for existing databases
✅ **Migration Tools**: DBIx::Class::Migration for version control
✅ **Performance**: Prepared statements, query optimization, prefetching
✅ **Extensible**: Custom inflation/deflation, method injection, hooks
✅ **Testing**: DBIx::Class::Fixtures for test data

**Key DBIC Features for E2**:

1. **Relationships**: Define FK relationships, prefetch related data
2. **Inheritance**: `add_columns()` + manual joins for multi-table types
3. **Inflation/Deflation**: Convert vars (serialized) ↔ Perl structures
4. **Custom Methods**: Add E2-specific methods to Result classes
5. **Hooks**: `insert()`, `update()`, `delete()` hooks for maintenance
6. **Transactions**: ACID compliance for complex operations
7. **Schema Versioning**: Track schema evolution with migrations

---

## Migration Strategy

### Guiding Principles

1. **Backward Compatibility**: Existing code must continue working during migration
2. **Incremental Approach**: Migrate one subsystem at a time
3. **Dual-Layer Operation**: DBIC and NodeBase coexist during transition
4. **Read-First Migration**: Convert reads before writes to validate safely
5. **Comprehensive Testing**: Test every migration phase thoroughly
6. **Performance Monitoring**: Track query performance throughout migration
7. **Rollback Capability**: Maintain ability to revert at each phase

### High-Level Approach

```
Phase 0: Preparation (2-3 months)
  └─> Schema analysis, DBIC setup, compatibility layer

Phase 1: Read Operations (3-4 months)
  └─> Migrate getNode*, query operations to DBIC

Phase 2: Write Operations (2-3 months)
  └─> Migrate insertNode, updateNode, nukeNode to DBIC

Phase 3: Specialized Features (2-3 months)
  └─> Groups, permissions, versioning, caching integration

Phase 4: Cleanup (1-2 months)
  └─> Remove NodeBase, update documentation, optimize
```

### Dual-Layer Architecture

During migration, maintain both systems:

```perl
# Compatibility layer in Everything::DB
package Everything::DB;

sub getNode {
    my ($self, $title, $type) = @_;

    # Use DBIC if type is migrated
    if ($self->_is_migrated_type($type)) {
        my $result = $self->dbic_schema->resultset($type)->find({title => $title});
        return $self->_result_to_hashref($result);  # Convert for legacy code
    }

    # Fall back to NodeBase
    return $self->nodebase->getNode($title, $type);
}
```

This allows gradual migration without breaking existing code.

---

## Implementation Phases

### Phase 0: Preparation (2-3 months)

#### 0.1 Schema Generation

**Goal**: Generate initial DBIC schema from existing database

**Tasks**:
- [ ] Install DBIx::Class::Schema::Loader
- [ ] Generate base schema classes from production database
- [ ] Review and clean up auto-generated code
- [ ] Add POD documentation to Result classes
- [ ] Set up DBIx::Class::Migration framework

**Tools**:
```bash
# Generate schema
dbicdump -o dump_directory=./lib \
         -o components='["InflateColumn::DateTime"]' \
         Everything::Schema \
         'dbi:mysql:database=everything' \
         username password

# Creates:
lib/Everything/Schema.pm
lib/Everything/Schema/Result/Node.pm
lib/Everything/Schema/Result/User.pm
lib/Everything/Schema/Result/Document.pm
... (one per table)
```

**Deliverables**:
- `lib/Everything/Schema.pm` - Main schema class
- `lib/Everything/Schema/Result/*.pm` - Result classes (one per table)
- `share/migrations/` - Migration directory structure
- Initial migration capturing current schema

#### 0.2 Compatibility Layer

**Goal**: Build abstraction layer allowing DBIC/NodeBase coexistence

**Tasks**:
- [ ] Create `Everything::DB::Compatibility` module
- [ ] Implement hashref conversion methods (Result ↔ hashref)
- [ ] Add type registry for migration tracking
- [ ] Build DBIC query → NodeBase fallback mechanism
- [ ] Create unified transaction interface

**Key Methods**:
```perl
package Everything::DB::Compatibility;

# Convert DBIC Result to legacy hashref format
sub result_to_hashref($result) {
    my $hash = { $result->get_columns };
    $hash->{type} = $result->nodetype->NODEDATA if $result->can('nodetype');
    return $hash;
}

# Convert hashref to DBIC update data
sub hashref_to_update_data($hashref) {
    my %data = %$hashref;
    delete $data{type};  # Can't update type via hash
    delete $data{node_id};  # Can't update PK
    return \%data;
}

# Check if type is migrated to DBIC
sub is_migrated($type_name) {
    return exists $MIGRATED_TYPES{$type_name};
}
```

**Deliverables**:
- `lib/Everything/DB/Compatibility.pm`
- `t/db/compatibility.t` - Comprehensive conversion tests
- Documentation on using compatibility layer

#### 0.3 Core Types Migration Design

**Goal**: Design DBIC schema for core node types

**Focus Types** (migrate first):
1. `node` - Base type (all nodes)
2. `nodetype` - Type definitions
3. `user` - User accounts
4. `document` - Content documents
5. `writeup` - E2-specific writeups

**Design Decisions**:

**Multi-table Inheritance Approach**:
```perl
# Option A: Manual Join (Recommended for E2)
package Everything::Schema::Result::Writeup;
use base 'DBIx::Class::Core';

__PACKAGE__->table('writeup');
__PACKAGE__->add_columns(
    writeup_id => { data_type => 'integer', is_foreign_key => 1 },
    parent_e2node => { data_type => 'integer', is_nullable => 1 },
    # ... writeup-specific fields
);

# Relationship to base node
__PACKAGE__->belongs_to(
    node => 'Everything::Schema::Result::Node',
    { 'foreign.node_id' => 'self.writeup_id' }
);

# Relationship to document (writeup extends document)
__PACKAGE__->belongs_to(
    document => 'Everything::Schema::Result::Document',
    { 'foreign.document_id' => 'self.writeup_id' }
);

# Proxy node fields for convenience
__PACKAGE__->add_columns(
    '+writeup_id' => { is_auto_increment => 1 }  # Actually from node.node_id
);

sub title { shift->node->title }
sub author_user { shift->node->author_user }
sub createtime { shift->node->createtime }
```

**Vars Inflation**:
```perl
# Serialize/deserialize vars field
use Storable qw(freeze thaw);
use MIME::Base64;

__PACKAGE__->inflate_column('vars', {
    inflate => sub {
        my $frozen = shift;
        return {} unless $frozen;
        return thaw(decode_base64($frozen));
    },
    deflate => sub {
        my $hashref = shift;
        return encode_base64(freeze($hashref));
    }
});
```

**Tasks**:
- [ ] Design Result classes for core types
- [ ] Define relationships (belongs_to, has_many, might_have)
- [ ] Implement vars inflation/deflation
- [ ] Create custom accessor methods
- [ ] Design type inheritance chain

**Deliverables**:
- `lib/Everything/Schema/Result/Node.pm`
- `lib/Everything/Schema/Result/Nodetype.pm`
- `lib/Everything/Schema/Result/User.pm`
- `lib/Everything/Schema/Result/Document.pm`
- `lib/Everything/Schema/Result/Writeup.pm`
- Design documentation for inheritance patterns

#### 0.4 Test Infrastructure

**Goal**: Establish comprehensive test suite for migration validation

**Tasks**:
- [ ] Create test database with realistic data
- [ ] Build DBIx::Class::Fixtures for common scenarios
- [ ] Write comparison tests (DBIC result == NodeBase result)
- [ ] Set up performance benchmarks
- [ ] Create integration tests for dual-layer operation

**Test Categories**:

1. **Unit Tests**: Individual Result class methods
2. **Integration Tests**: DBIC + NodeBase coexistence
3. **Comparison Tests**: Verify DBIC matches NodeBase behavior
4. **Performance Tests**: Query timing, memory usage
5. **Regression Tests**: Prevent breaking existing features

**Example Comparison Test**:
```perl
# t/db/compare_getnode.t
use Test::More;
use Everything::DB;
use Everything::NodeBase;

my $db = Everything::DB->new;
my $nb = Everything::NodeBase->new;

# Test user node retrieval
my $dbic_user = $db->getNode('root', 'user');
my $nb_user = $nb->getNode('root', 'user');

is_deeply($dbic_user, $nb_user, 'DBIC user matches NodeBase user');

# Test writeup with all joins
my $dbic_wu = $db->getNodeById(12345);
my $nb_wu = $nb->getNodeById(12345);

is($dbic_wu->{title}, $nb_wu->{title}, 'Titles match');
is($dbic_wu->{doctext}, $nb_wu->{doctext}, 'Document text matches');
is($dbic_wu->{parent_e2node}, $nb_wu->{parent_e2node}, 'Writeup parent matches');
```

**Deliverables**:
- `t/db/fixtures/` - Test data fixtures
- `t/db/compare/*.t` - DBIC vs NodeBase comparison tests
- `t/db/performance/*.t` - Performance benchmarks
- `t/db/integration/*.t` - Dual-layer tests
- Test documentation and running instructions

---

### Phase 1: Read Operations (3-4 months)

#### 1.1 Basic Node Retrieval

**Goal**: Migrate `getNode()` and `getNodeById()` to DBIC

**Migration Pattern**:
```perl
# Before (NodeBase):
my $node = $DB->getNode('root', 'user');

# After (DBIC):
my $user = $schema->resultset('User')->search(
    { 'node.title' => 'root' },
    { prefetch => 'node' }
)->single;

# Compatibility (during migration):
sub getNode {
    my ($self, $title, $type) = @_;

    if ($self->_is_migrated($type)) {
        my $rs = $self->schema->resultset($type);
        my $result = $rs->search(
            { 'node.title' => $title },
            { prefetch => 'node' }
        )->single;

        return $self->_result_to_hashref($result);
    }

    return $self->nodebase->getNode($title, $type);
}
```

**Tasks**:
- [ ] Implement `getNode()` for core types
- [ ] Implement `getNodeById()` for core types
- [ ] Add prefetch for related data (author, type)
- [ ] Handle cache integration
- [ ] Migrate `getNodeWhere()` for simple queries

**Deliverables**:
- Updated `Everything::DB` with DBIC read methods
- Passing comparison tests for all core types
- Performance benchmarks showing comparable or better speed

#### 1.2 Type System Migration

**Goal**: Migrate nodetype loading and inheritance resolution

**Challenges**:
- Nodetypes are dynamically loaded from database
- Inheritance chains resolved at runtime
- Need to cache derived types

**Approach**:
```perl
package Everything::Schema::Result::Nodetype;

# Cache derived types
our %DERIVED_CACHE;

sub derive {
    my $self = shift;
    return $DERIVED_CACHE{$self->node_id} if exists $DERIVED_CACHE{$self->node_id};

    my $derived = { $self->get_columns };

    # Resolve inheritance
    if (my $extends = $self->extends_nodetype) {
        my $parent = $self->result_source->schema
                          ->resultset('Nodetype')
                          ->find($extends)
                          ->derive;

        # Inherit fields with value -1
        for my $field (keys %$derived) {
            $derived->{$field} = $parent->{$field}
                if $derived->{$field} == -1 && exists $parent->{$field};
        }

        # Merge table lists
        my @parent_tables = split /,/, ($parent->{sqltablelist} || '');
        my @my_tables = split /,/, ($self->sqltable || '');
        $derived->{sqltablelist} = join(',', @my_tables, @parent_tables);
    }

    $derived->{resolvedInheritance} = 1;
    $DERIVED_CACHE{$self->node_id} = $derived;
    return $derived;
}
```

**Tasks**:
- [ ] Implement `Nodetype->derive()` method
- [ ] Cache derived nodetypes
- [ ] Test inheritance chains (writeup → document)
- [ ] Verify table join construction
- [ ] Handle restrictdupes field

**Deliverables**:
- `Everything::Schema::Result::Nodetype` with derive()
- Tests for complex inheritance chains
- Type cache integration

#### 1.3 Group Nodes

**Goal**: Migrate group node loading and flattening

**Current System**:
- Groups stored in `nodegroup` table
- Recursive resolution via `flattenNodegroup()`
- Used extensively in permissions

**DBIC Design**:
```perl
package Everything::Schema::Result::Nodegroup;

__PACKAGE__->table('nodegroup');
__PACKAGE__->add_columns(
    nodegroup_id => { data_type => 'integer', is_foreign_key => 1 },
    node_id => { data_type => 'integer', is_foreign_key => 1 },
    orderby => { data_type => 'integer', default_value => 0 },
);

# Belongs to parent group
__PACKAGE__->belongs_to(
    group_node => 'Everything::Schema::Result::Node',
    { 'foreign.node_id' => 'self.nodegroup_id' }
);

# Belongs to member node
__PACKAGE__->belongs_to(
    member_node => 'Everything::Schema::Result::Node',
    { 'foreign.node_id' => 'self.node_id' }
);

package Everything::Schema::Result::Node;

# Has many group members
__PACKAGE__->has_many(
    group_members => 'Everything::Schema::ResultSet::Nodegroup',
    { 'foreign.nodegroup_id' => 'self.node_id' }
);

# Is member of groups
__PACKAGE__->has_many(
    member_of => 'Everything::Schema::ResultSet::Nodegroup',
    { 'foreign.node_id' => 'self.node_id' }
);

sub flatten_group {
    my $self = shift;
    my %seen = (shift() || {});  # Prevent cycles

    return [] if $seen{$self->node_id}++;

    my @members = $self->group_members->all;
    my @flattened;

    for my $member (@members) {
        push @flattened, $member->member_node->node_id;

        # Recursively flatten nested groups
        if ($member->member_node->is_group) {
            push @flattened, $member->member_node->flatten_group(\%seen)->@*;
        }
    }

    return \@flattened;
}
```

**Tasks**:
- [ ] Create `Nodegroup` Result class
- [ ] Implement `flatten_group()` method
- [ ] Integrate with permission checks
- [ ] Test nested groups (usergroups in usergroups)
- [ ] Cache flattened results

**Deliverables**:
- `Everything::Schema::Result::Nodegroup`
- Group flattening implementation
- Tests for complex group hierarchies

#### 1.4 Query Migration

**Goal**: Convert complex queries to DBIC ResultSets

**Example Conversions**:

```perl
# Before: getNodeWhere with JOIN
my @nodes = $DB->getNodeWhere(
    "parent_e2node=123 AND reputation > 5",
    'writeup',
    'ORDER BY createtime DESC LIMIT 10'
);

# After: DBIC ResultSet
my @nodes = $schema->resultset('Writeup')->search(
    {
        parent_e2node => 123,
        'node.reputation' => { '>' => 5 }
    },
    {
        join => 'node',
        order_by => { -desc => 'node.createtime' },
        rows => 10
    }
)->all;
```

**Tasks**:
- [ ] Audit all NodeBase query methods
- [ ] Convert WHERE clauses to DBIC search specs
- [ ] Handle complex joins (multi-table types)
- [ ] Migrate ordering and pagination
- [ ] Test query result equivalence

**Deliverables**:
- `Everything::DB::QueryBuilder` helper
- Conversion guide for common query patterns
- Tests for complex queries

---

### Phase 2: Write Operations (2-3 months)

#### 2.1 Insert Operations

**Goal**: Migrate `insertNode()` to DBIC `insert()`

**Challenges**:
- Multi-table inserts (node + type-specific table)
- Automatic node_id generation
- Maintenance hooks (e.g., `user_create()`)
- Transaction safety

**DBIC Pattern**:
```perl
package Everything::Schema::Result::User;

around 'insert' => sub {
    my ($orig, $self, @args) = @_;

    # Start transaction
    $self->result_source->schema->txn_do(sub {

        # Insert base node first
        my $node = $self->result_source->schema->resultset('Node')->create({
            title => $self->title,
            type_nodetype => $self->_user_type_id,
            author_user => $self->author_user,
            createtime => \'NOW()',
        });

        # Set user_id to match node_id
        $self->user_id($node->node_id);

        # Insert user-specific data
        $self->$orig(@args);

        # Run maintenance hook
        $self->_run_maintenance_hook('user_create');

        # Invalidate cache
        $self->_increment_version;
    });

    return $self;
};

sub _run_maintenance_hook {
    my ($self, $hook) = @_;
    my $delegation = Everything::Delegation::maintenance->can($hook);
    $delegation->($self->_to_hashref) if $delegation;
}
```

**Tasks**:
- [ ] Implement `insert()` override for each type
- [ ] Add transaction wrappers
- [ ] Integrate maintenance hooks
- [ ] Handle node_id assignment
- [ ] Test complex multi-table inserts

**Deliverables**:
- Insert methods for core types
- Transaction integration
- Maintenance hook compatibility
- Tests verifying data integrity

#### 2.2 Update Operations

**Goal**: Migrate `updateNode()` to DBIC `update()`

**Challenges**:
- Updates span multiple tables
- Field whitelisting (security)
- Version increment for cache invalidation
- Maintenance hooks

**DBIC Pattern**:
```perl
package Everything::Schema::Result::User;

around 'update' => sub {
    my ($orig, $self, $updates) = @_;

    return $self->result_source->schema->txn_do(sub {
        # Apply whitelisted updates
        my $allowed = $self->field_whitelist;
        my %safe_updates = map { $_ => $updates->{$_} }
                           grep { exists $updates->{$_} }
                           @$allowed;

        # Update base node if needed
        if (my %node_updates = $self->_extract_node_fields(\%safe_updates)) {
            $self->node->update(\%node_updates);
        }

        # Update type-specific fields
        $self->$orig(\%safe_updates);

        # Run maintenance hook
        $self->_run_maintenance_hook('user_update');

        # Increment version
        $self->_increment_version;

        return $self;
    });
};

sub field_whitelist {
    my $self = shift;
    # Override in subclasses
    return [qw(title doctext)];  # Example
}
```

**Tasks**:
- [ ] Implement `update()` override for each type
- [ ] Add field whitelisting
- [ ] Version increment on update
- [ ] Test partial updates
- [ ] Verify maintenance hooks fire

**Deliverables**:
- Update methods for core types
- Field whitelist system
- Version tracking integration
- Update validation tests

#### 2.3 Delete Operations

**Goal**: Migrate `nukeNode()` to DBIC `delete()`

**Challenges**:
- Soft delete vs hard delete (tombstone table)
- CASCADE implications
- Permission checks
- Maintenance hooks

**DBIC Pattern**:
```perl
package Everything::Schema::Result::Node;

sub nuke {
    my ($self, $user) = @_;

    # Permission check
    die "Cannot delete node" unless $self->can_delete_node($user);

    return $self->result_source->schema->txn_do(sub {
        # Create tombstone
        $self->result_source->schema->resultset('Tombstone')->create({
            tombstone_id => $self->node_id,
            title => $self->title,
            type_nodetype => $self->type_nodetype,
            deletedby_user => $user->node_id,
            deletetime => \'NOW()',
        });

        # Run maintenance hook
        $self->_run_maintenance_hook($self->typename . '_delete');

        # Delete from type-specific tables (CASCADE handles joins)
        $self->delete;

        # Invalidate cache
        $self->_delete_version;
    });
}
```

**Tasks**:
- [ ] Implement `nuke()` method
- [ ] Add tombstone creation
- [ ] Test CASCADE behavior
- [ ] Verify orphan cleanup
- [ ] Permission integration

**Deliverables**:
- Delete implementation with tombstones
- Cascade testing
- Permission check integration

---

### Phase 3: Specialized Features (2-3 months)

#### 3.1 Cache Integration

**Goal**: Integrate DBIC with Everything::NodeCache

**Approach**:

```perl
package Everything::Schema;

use Everything::NodeCache;

has 'node_cache' => (
    is => 'ro',
    default => sub { Everything::NodeCache->new }
);

# Hook into DBIC storage to intercept queries
around 'resultset' => sub {
    my ($orig, $self, $source) = @_;

    # Get base resultset
    my $rs = $self->$orig($source);

    # Wrap with caching layer
    return Everything::Schema::CachedResultSet->new({
        resultset => $rs,
        cache => $self->node_cache
    });
};

package Everything::Schema::CachedResultSet;

sub find {
    my ($self, $id) = @_;

    # Check cache first
    if (my $cached = $self->cache->getCachedNodeById($id)) {
        # Verify version
        if ($self->cache->isSameVersion($cached)) {
            return $self->_hashref_to_result($cached);
        }
    }

    # Cache miss - query database
    my $result = $self->resultset->find($id);

    # Store in cache
    $self->cache->cacheNode($result->_to_hashref);

    return $result;
}
```

**Tasks**:
- [ ] Create `CachedResultSet` wrapper
- [ ] Integrate version checking
- [ ] Hook insert/update/delete to invalidate cache
- [ ] Test cache hit/miss behavior
- [ ] Benchmark cache performance

**Deliverables**:
- `Everything::Schema::CachedResultSet`
- Cache integration layer
- Performance tests showing cache benefit

#### 3.2 Permission System

**Goal**: Migrate permission checks to DBIC

**Current System**:
- `canReadNode()`, `canUpdateNode()`, `canDeleteNode()`
- Based on type-level usergroups
- Cached group membership

**DBIC Integration**:
```perl
package Everything::Schema::Result::Node;

sub can_read {
    my ($self, $user) = @_;

    my $type = $self->nodetype;
    return 1 unless $type->readers_user;  # No restrictions

    # Check if user is in authorized group
    my $group = $self->result_source->schema
                     ->resultset('Node')
                     ->find($type->readers_user);

    return $group->has_member($user);
}

sub can_update {
    my ($self, $user) = @_;

    # Gods can do anything
    return 1 if $user->is_god;

    # Author can update own content
    return 1 if $self->author_user == $user->node_id;

    # Check writers group
    my $type = $self->nodetype;
    return 1 unless $type->writers_user;

    my $group = $self->result_source->schema
                     ->resultset('Node')
                     ->find($type->writers_user);

    return $group->has_member($user);
}

# On Node (group type)
sub has_member {
    my ($self, $user) = @_;

    # Use cached flattened group
    my $flattened = $self->flatten_group;
    return grep { $_ == $user->node_id } @$flattened;
}
```

**Tasks**:
- [ ] Implement permission methods on Result classes
- [ ] Integrate with group flattening
- [ ] Cache permission checks
- [ ] Test edge cases (gods, content editors)
- [ ] Benchmark permission overhead

**Deliverables**:
- Permission methods on all Result classes
- Integration with group system
- Permission tests covering all scenarios

#### 3.3 Node Parameters

**Goal**: Migrate node parameter system to DBIC

**Current System**:
- `nodeparam` table: `(node_id, paramkey, paramvalue)`
- Methods: `getNodeParam()`, `setNodeParam()`, `deleteNodeParam()`

**DBIC Design**:
```perl
package Everything::Schema::Result::Nodeparam;

__PACKAGE__->table('nodeparam');
__PACKAGE__->add_columns(
    node_id => { data_type => 'integer', is_foreign_key => 1 },
    paramkey => { data_type => 'varchar', size => 255 },
    paramvalue => { data_type => 'text', is_nullable => 1 },
);

__PACKAGE__->set_primary_key('node_id', 'paramkey');

__PACKAGE__->belongs_to(
    node => 'Everything::Schema::Result::Node',
    'node_id'
);

package Everything::Schema::Result::Node;

__PACKAGE__->has_many(
    parameters => 'Everything::Schema::Result::Nodeparam',
    'node_id'
);

sub get_param {
    my ($self, $key) = @_;
    my $param = $self->parameters->find({ paramkey => $key });
    return $param ? $param->paramvalue : undef;
}

sub set_param {
    my ($self, $key, $value) = @_;
    $self->parameters->update_or_create({
        paramkey => $key,
        paramvalue => $value
    });
}

sub delete_param {
    my ($self, $key) = @_;
    $self->parameters->search({ paramkey => $key })->delete;
}
```

**Tasks**:
- [ ] Create `Nodeparam` Result class
- [ ] Add convenience methods to `Node`
- [ ] Test parameter CRUD operations
- [ ] Integrate with cache
- [ ] Migrate existing parameter usage

**Deliverables**:
- `Everything::Schema::Result::Nodeparam`
- Parameter accessor methods
- Tests for parameter operations

#### 3.4 Transactions

**Goal**: Ensure ACID compliance for complex operations

**Pattern**:
```perl
use Try::Tiny;

try {
    $schema->txn_do(sub {
        my $user = $schema->resultset('User')->create({
            title => 'newuser',
            email => 'user@example.com',
            # ...
        });

        my $doc = $schema->resultset('Document')->create({
            title => 'First Post',
            author_user => $user->user_id,
            doctext => 'Hello world',
        });

        # Both succeed or both rollback
    });
} catch {
    warn "Transaction failed: $_";
};
```

**Tasks**:
- [ ] Identify all complex operations needing transactions
- [ ] Wrap multi-step operations in `txn_do`
- [ ] Add rollback tests
- [ ] Handle deadlock scenarios
- [ ] Document transaction boundaries

**Deliverables**:
- Transaction wrappers for complex operations
- Rollback tests
- Transaction documentation

---

### Phase 4: Cleanup (1-2 months)

#### 4.1 NodeBase Deprecation

**Goal**: Remove Everything::NodeBase entirely

**Prerequisites**:
- All node operations migrated to DBIC
- All tests passing
- Performance acceptable
- No NodeBase references in active code

**Tasks**:
- [ ] Audit codebase for NodeBase usage
- [ ] Remove compatibility layer
- [ ] Delete `Everything::NodeBase.pm`
- [ ] Update documentation
- [ ] Celebrate! 🎉

#### 4.2 Performance Optimization

**Goal**: Optimize DBIC queries for production load

**Tasks**:
- [ ] Add missing indexes based on slow query log
- [ ] Optimize prefetch strategies
- [ ] Tune cache sizes
- [ ] Enable query logging in dev
- [ ] Profile common operations

**Tools**:
- `DBIx::Class::QueryLog` for query analysis
- `Devel::NYTProf` for profiling
- MySQL slow query log

#### 4.3 Documentation

**Goal**: Comprehensive documentation for DBIC schema

**Deliverables**:
- [ ] Schema overview documentation
- [ ] Result class reference
- [ ] Migration guide for developers
- [ ] Performance tuning guide
- [ ] Troubleshooting guide

---

## Technical Design

### Schema Organization

```
lib/Everything/Schema.pm              # Main schema class
lib/Everything/Schema/Result/         # Result classes (one per table)
    Node.pm                           # Base node
    Nodetype.pm                       # Type definitions
    User.pm                           # User accounts
    Document.pm                       # Documents
    Writeup.pm                        # Writeups
    Nodegroup.pm                      # Group membership
    Nodeparam.pm                      # Node parameters
    Version.pm                        # Cache versioning
    ...
lib/Everything/Schema/ResultSet/      # Custom ResultSet classes
    Node.pm                           # Node-specific queries
    User.pm                           # User searches
    ...
share/migrations/                     # Schema migrations
    _common/                          # Common migration code
    MySQL/                            # MySQL-specific migrations
        upgrade/                      # Version upgrades
        downgrade/                    # Version downgrades
```

### Result Class Example

```perl
package Everything::Schema::Result::Writeup;

use strict;
use warnings;
use base 'DBIx::Class::Core';

# Load components
__PACKAGE__->load_components(qw/
    InflateColumn::DateTime
    TimeStamp
/);

# Table name
__PACKAGE__->table('writeup');

# Columns
__PACKAGE__->add_columns(
    writeup_id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_foreign_key => 1,
    },
    parent_e2node => {
        data_type => 'integer',
        is_nullable => 1,
        is_foreign_key => 1,
    },
    wrtype_writeuptype => {
        data_type => 'integer',
        is_nullable => 1,
        is_foreign_key => 1,
    },
    notnew => {
        data_type => 'tinyint',
        default_value => 0,
    },
);

# Primary key
__PACKAGE__->set_primary_key('writeup_id');

# Relationships

# Belongs to base node (multi-table inheritance)
__PACKAGE__->belongs_to(
    node => 'Everything::Schema::Result::Node',
    { 'foreign.node_id' => 'self.writeup_id' }
);

# Belongs to document (writeup extends document)
__PACKAGE__->belongs_to(
    document => 'Everything::Schema::Result::Document',
    { 'foreign.document_id' => 'self.writeup_id' }
);

# Belongs to parent e2node
__PACKAGE__->belongs_to(
    e2node => 'Everything::Schema::Result::E2node',
    { 'foreign.e2node_id' => 'self.parent_e2node' },
    { join_type => 'left' }
);

# Belongs to writeup type
__PACKAGE__->belongs_to(
    writeuptype => 'Everything::Schema::Result::Writeuptype',
    { 'foreign.writeuptype_id' => 'self.wrtype_writeuptype' },
    { join_type => 'left' }
);

# Custom methods

sub title {
    my $self = shift;
    return $self->node->title;
}

sub author {
    my $self = shift;
    return $self->node->author;
}

sub doctext {
    my $self = shift;
    return $self->document->doctext;
}

# Permission checks
sub can_update {
    my ($self, $user) = @_;

    # Author can edit
    return 1 if $self->node->author_user == $user->node_id;

    # Content editors can edit
    return 1 if $user->is_content_editor;

    return 0;
}

# Maintenance hooks
around 'insert' => sub {
    my ($orig, $self, @args) = @_;

    $self->result_source->schema->txn_do(sub {
        $self->$orig(@args);
        $self->_run_maintenance('writeup_create');
    });
};

around 'update' => sub {
    my ($orig, $self, @args) = @_;

    $self->result_source->schema->txn_do(sub {
        $self->$orig(@args);
        $self->_run_maintenance('writeup_update');
        $self->_increment_version;
    });
};

sub _run_maintenance {
    my ($self, $hook) = @_;

    if (my $sub = Everything::Delegation::maintenance->can($hook)) {
        $sub->($self->as_hashref);
    }
}

# Convert to legacy hashref format
sub as_hashref {
    my $self = shift;

    return {
        $self->get_columns,
        # Include joined data
        title => $self->title,
        author_user => $self->node->author_user,
        doctext => $self->doctext,
        type => $self->node->nodetype->as_hashref,
    };
}

1;
```

### Caching Architecture

```
┌─────────────────────────────────────────────────┐
│          Application Layer                      │
│  (Controllers, APIs, Page classes)              │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│      Everything::Schema (DBIC)                  │
│  ┌───────────────────────────────────────────┐  │
│  │    CachedResultSet Wrapper                │  │
│  │  - Intercepts find() calls                │  │
│  │  - Checks NodeCache first                 │  │
│  │  - Verifies version on cache hit          │  │
│  └───────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
┌──────────────┐   ┌─────────────────┐
│ NodeCache    │   │ Database        │
│ (LRU cache)  │   │ (MySQL)         │
│              │   │                 │
│ - Per-process│   │ - version table │
│ - Version    │   │ - Global source │
│   checking   │   │   of truth      │
└──────────────┘   └─────────────────┘
```

### Migration Tracking

Use DBIx::Class::Migration for schema versioning:

```perl
# Create migration
$ dbic-migration prepare

# Generated files:
share/migrations/MySQL/deploy/1/001-auto.sql
share/migrations/MySQL/upgrade/1-2/001-auto.sql

# Apply migration
$ dbic-migration install    # Fresh install
$ dbic-migration upgrade    # Upgrade existing
$ dbic-migration downgrade  # Rollback

# Schema version tracked in:
dbix_class_schema_versions table
```

---

## Risk Mitigation

### High-Impact Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Performance regression** | Medium | Critical | Comprehensive benchmarking at each phase, rollback plan |
| **Data corruption** | Low | Critical | Transaction wrappers, extensive testing, database backups |
| **Cache invalidation bugs** | Medium | High | Version checking tests, comparison with NodeBase behavior |
| **Breaking existing features** | Medium | High | Comprehensive test suite, gradual rollout, feature flags |
| **Migration extends timeline** | High | Medium | Phased approach, clear milestones, early performance validation |
| **Team learning curve** | Medium | Medium | Documentation, training, pair programming during migration |
| **Incomplete type coverage** | Low | Medium | Audit all node types, prioritize by usage frequency |

### Rollback Strategy

At each phase, maintain ability to revert:

**Phase 0-1**: DBIC is read-only, NodeBase handles all writes
- Rollback: Remove DBIC reads, fall back to NodeBase
- Data loss: None (no writes)

**Phase 2**: DBIC handles writes for migrated types
- Rollback: Redirect writes back to NodeBase
- Data loss: None (both systems write same data)

**Phase 3**: Cache and permission integration
- Rollback: Disable DBIC cache layer, use NodeBase cache
- Data loss: None

**Phase 4**: NodeBase removed
- Rollback: Restore NodeBase from git history
- Data loss: Potential if schema diverged

**Emergency Rollback**:
```perl
# Feature flag for instant rollback
$Everything::CONF->{use_dbic} = 0;  # Falls back to NodeBase

# Or per-type:
$Everything::CONF->{dbic_types} = [];  # Disable DBIC for all types
```

---

## Testing Strategy

### Test Pyramid

```
        ┌──────────────┐
        │  E2E Tests   │  <- Full user workflows (10%)
        └──────────────┘
      ┌──────────────────┐
      │ Integration Tests│  <- DBIC + Cache + Permissions (30%)
      └──────────────────┘
    ┌──────────────────────┐
    │ Comparison Tests     │  <- DBIC == NodeBase results (40%)
    └──────────────────────┘
  ┌──────────────────────────┐
  │ Unit Tests               │  <- Individual methods (20%)
  └──────────────────────────┘
```

### Test Categories

**1. Unit Tests** (Result class methods)
```perl
# t/schema/result/user.t
my $user = $schema->resultset('User')->find(1);
is($user->title, 'root', 'User title correct');
ok($user->is_god, 'Root is god');
```

**2. Comparison Tests** (DBIC vs NodeBase)
```perl
# t/compare/node_retrieval.t
my $dbic_node = $db->getNode('root', 'user');
my $nb_node = $nodebase->getNode('root', 'user');
is_deeply($dbic_node, $nb_node, 'Results match');
```

**3. Integration Tests** (Multi-component)
```perl
# t/integration/writeup_create.t
my $wu = $schema->resultset('Writeup')->create({
    title => 'Test',
    doctext => 'Content',
    parent_e2node => 123,
});
ok($wu->node->exists, 'Node created');
ok($wu->document->exists, 'Document created');
ok($wu->exists, 'Writeup created');
```

**4. Performance Tests** (Benchmarks)
```perl
# t/performance/node_loading.t
use Benchmark qw(cmpthese);

cmpthese(1000, {
    'NodeBase' => sub { $nb->getNodeById(12345) },
    'DBIC'     => sub { $db->getNodeById(12345) },
});
```

**5. Regression Tests** (Prevent breakage)
```perl
# t/regression/permission_checks.t
# Verify specific permission edge cases don't regress
```

### Test Data

Use DBIx::Class::Fixtures for consistent test data:

```perl
# t/fixtures/users.pl
{
    User => [
        ['user_id', 'title', 'email'],
        [1, 'root', 'root@example.com'],
        [2, 'guest user', 'guest@example.com'],
    ],
    Node => [
        ['node_id', 'title', 'type_nodetype', 'author_user'],
        [1, 'root', 45, 1],
        [2, 'guest user', 45, 1],
    ],
}
```

### Coverage Targets

- **Unit tests**: 80% code coverage
- **Integration tests**: All major workflows
- **Comparison tests**: 100% coverage of migrated operations
- **Performance tests**: No regression > 10%

---

## Performance Considerations

### Expected Improvements

1. **Prepared Statements**: DBIC uses placeholders, reducing parsing overhead
2. **Query Optimization**: DBIC optimizes joins and column selection
3. **Connection Pooling**: Better connection reuse
4. **Prefetching**: Load related data in one query vs N+1

### Potential Regressions

1. **ORM Overhead**: DBIC object creation has cost (mitigated by caching)
2. **Learning Curve**: Inefficient queries during learning phase
3. **Complex Joins**: Multi-table inheritance may add query complexity

### Benchmarking Plan

Benchmark these operations before/after migration:

| Operation | Current (NodeBase) | Target (DBIC) | Test |
|-----------|-------------------|---------------|------|
| getNodeById | ~5ms | < 5ms | Load single node by ID |
| getNode (cached) | ~0.5ms | < 1ms | Cache hit |
| getNode (uncached) | ~8ms | < 8ms | Cache miss, single join |
| insertNode | ~15ms | < 15ms | Create with multi-table |
| updateNode | ~10ms | < 10ms | Update with version bump |
| Complex query | ~50ms | < 40ms | Multi-join with filtering |

### Optimization Techniques

**1. Lazy Loading (On-Demand Relationships)**

DBIC supports lazy loading by default - relationships are NOT joined unless explicitly requested. This is ideal for existence checks and light operations:

```perl
# Example: Just check if node exists (NO joins performed)
my $node = $schema->resultset('Node')->find($id);
if ($node) {
    # Only base node table queried - no document/writeup joins
    return 1;
}

# Lazy loading - joins happen on-demand when accessed
my $writeup = $schema->resultset('Writeup')->find($id);
# At this point: Only writeup table loaded

my $title = $writeup->node->title;
# NOW the node table is queried (lazy load triggered)

my $doctext = $writeup->document->doctext;
# NOW the document table is queried (second lazy load)
```

**When to use lazy loading** (default behavior):
- Existence checks: `if ($node) { ... }`
- Conditional access: May or may not need related data
- Single record operations: Overhead of join > benefit

**2. Prefetching (Eager Loading)**

Explicitly request joins when you KNOW you'll need the data:

```perl
# Load writeup WITH node and document in single query
my $writeup = $schema->resultset('Writeup')->search(
    { writeup_id => $id },
    { prefetch => ['node', 'document'] }
)->single;

# Now these are free (already loaded):
my $title = $writeup->node->title;      # No query
my $doctext = $writeup->document->doctext;  # No query
```

**When to use prefetch**:
- Displaying data: Know you'll render all fields
- List operations: Avoids N+1 queries
- Hot paths: Performance critical code

**3. Selective Column Loading**

Only load columns you actually need:

```perl
# Just need to check title, don't load heavy doctext
$rs->search({}, {
    columns => [qw/node_id title/],
    join => 'node'
});

# For existence check, just load PK
$rs->search({}, { columns => ['node_id'] });
```

**4. Join vs Prefetch**

```perl
# join: Use for filtering, doesn't load relationship data
my @writeups = $schema->resultset('Writeup')->search(
    { 'node.reputation' => { '>' => 10 } },
    { join => 'node' }  # Join for WHERE clause, but don't load node columns
)->all;
# Result: Only writeup columns loaded, but filtered by node.reputation

# prefetch: Use when you'll access relationship
my @writeups = $schema->resultset('Writeup')->search(
    { 'node.reputation' => { '>' => 10 } },
    { prefetch => 'node' }  # Join AND load node columns
)->all;
# Result: Both writeup and node columns loaded
```

**5. Everything2-Specific Pattern**

For E2's multi-table inheritance, create specialized methods:

```perl
package Everything::Schema::ResultSet::Writeup;

# Light load: Just writeup table (for existence checks)
sub find_light {
    my ($self, $id) = @_;
    return $self->find($id);  # Default lazy loading
}

# Standard load: Include node (for display)
sub find_standard {
    my ($self, $id) = @_;
    return $self->search(
        { writeup_id => $id },
        { prefetch => 'node' }
    )->single;
}

# Full load: Everything (for editing)
sub find_full {
    my ($self, $id) = @_;
    return $self->search(
        { writeup_id => $id },
        { prefetch => ['node', 'document', 'e2node', 'writeuptype'] }
    )->single;
}
```

**Usage in compatibility layer**:

```perl
sub getNodeById {
    my ($self, $id, $selectop) = @_;

    if ($self->_is_migrated_type($type)) {
        my $rs = $self->schema->resultset($type);

        # Light mode: Just check existence or get basic info
        if ($selectop eq 'light') {
            return $rs->find_light($id);
        }
        # Force mode: Full load with all relationships
        elsif ($selectop eq 'force') {
            return $rs->find_full($id);
        }
        # Default: Standard load (most common fields)
        else {
            return $rs->find_standard($id);
        }
    }

    return $self->nodebase->getNodeById($id, $selectop);
}
```

**6. Caching**
```perl
# Cache frequently-accessed nodes permanently
$schema->node_cache->cacheNode($node, 'permanent');
```

**7. Bulk Operations**
```perl
# Batch inserts
$rs->populate([
    { title => 'Node 1', ... },
    { title => 'Node 2', ... },
]);
```

**Performance Comparison**:

| Operation | Lazy (default) | Prefetch | Best For |
|-----------|---------------|----------|----------|
| Existence check | 1 query | 3 queries | ✅ Lazy |
| Display single writeup | 3 queries | 1 query | ✅ Prefetch |
| List 100 writeups | 300 queries (N+1) | 1 query | ✅ Prefetch |
| Conditional access | 1-3 queries | 3 queries | ✅ Lazy |

---

## Rollback Plan

### Phase-Specific Rollbacks

**Phase 0**: Preparation
- **Rollback**: Delete DBIC schema files, no production impact
- **Effort**: Minimal (1 hour)

**Phase 1**: Read operations
- **Rollback**: Set `$CONF->{use_dbic} = 0`, revert compatibility layer
- **Effort**: Low (1 day)
- **Risk**: None (NodeBase still handles writes)

**Phase 2**: Write operations
- **Rollback**: Disable DBIC writes, redirect to NodeBase
- **Effort**: Medium (2-3 days)
- **Risk**: Low (both systems write same schema)

**Phase 3**: Specialized features
- **Rollback**: Disable cache/permission integration
- **Effort**: High (1 week)
- **Risk**: Medium (cache invalidation issues possible)

**Phase 4**: NodeBase removal
- **Rollback**: Restore NodeBase from git, revert all DBIC
- **Effort**: Very High (2-3 weeks)
- **Risk**: High (schema may have diverged)

### Rollback Decision Criteria

Trigger rollback if:

1. **Performance**: > 20% regression in key operations
2. **Stability**: > 10 critical bugs in production
3. **Data Integrity**: Any data corruption detected
4. **Timeline**: Migration exceeds 150% of planned duration
5. **Team Consensus**: Engineering team agrees migration should pause

### Emergency Rollback Procedure

1. **Immediate**: Set feature flag `use_dbic = 0`
2. **Within 1 hour**: Deploy NodeBase fallback code
3. **Within 4 hours**: Verify all operations working
4. **Within 24 hours**: Post-mortem to understand failure
5. **Within 1 week**: Decision on retry vs abandon

---

## Alternative: Incremental Improvement

If full DBIC migration is deemed too risky, consider **incremental improvements** to existing NodeBase:

### Option A: Prepared Statements

Add prepared statement caching to NodeBase:

```perl
package Everything::NodeBase;

has 'statement_cache' => (
    is => 'ro',
    default => sub { {} }
);

sub sqlSelect {
    my ($self, $select, $from, $where, @bind) = @_;

    my $sql = "SELECT $select FROM $from WHERE $where";
    my $sth = $self->statement_cache->{$sql} ||= $self->{dbh}->prepare($sql);

    $sth->execute(@bind);
    return $sth;
}
```

**Benefit**: ~20% performance improvement
**Effort**: 1-2 weeks
**Risk**: Low

### Option B: Query Builder

Wrap SQL construction in query builder:

```perl
use SQL::Abstract;

my $sql = SQL::Abstract->new;
my ($stmt, @bind) = $sql->select('node', '*', { title => 'root', type => 45 });
```

**Benefit**: Safer SQL, easier to maintain
**Effort**: 1-2 months
**Risk**: Low-Medium

### Option C: Transaction Safety

Add transaction wrappers to complex operations:

```perl
sub insertNode {
    my ($self, ...) = @_;

    $self->{dbh}->begin_work;
    eval {
        # Insert operations
        $self->{dbh}->commit;
    };
    if ($@) {
        $self->{dbh}->rollback;
        die $@;
    }
}
```

**Benefit**: Data integrity improvements
**Effort**: 2-3 weeks
**Risk**: Low

---

## Conclusion

Migrating to DBIx::Class represents a significant investment in Everything2's technical infrastructure. The proposed phased approach minimizes risk while delivering incremental value.

### Key Success Factors

1. ✅ **Comprehensive Testing**: Comparison tests ensure DBIC matches NodeBase behavior
2. ✅ **Backward Compatibility**: Dual-layer approach maintains existing functionality
3. ✅ **Performance Monitoring**: Continuous benchmarking prevents regressions
4. ✅ **Incremental Migration**: Phased rollout allows early validation
5. ✅ **Rollback Capability**: Feature flags enable instant reversion
6. ✅ **Team Buy-In**: Training and documentation support adoption

### Recommended Next Steps

**After React Migration Completes**:

1. **Review this document** with engineering team
2. **Build consensus** on approach (full DBIC vs incremental improvements)
3. **Allocate resources** (1-2 senior engineers, 6-12 months)
4. **Start Phase 0**: Schema generation and compatibility layer
5. **Set success metrics**: Performance targets, test coverage goals
6. **Establish checkpoints**: Monthly reviews of progress

### Long-Term Vision

A successful DBIC migration positions Everything2 for:

- **Easier maintenance**: Standard ORM patterns vs custom code
- **Better performance**: Optimized queries, connection pooling
- **Safer operations**: Type checking, transaction safety
- **Team velocity**: Less time debugging SQL, more features
- **Modern standards**: Industry-standard patterns aid recruitment

This migration is not urgent, but it represents a strategic investment in technical debt reduction that will pay dividends for years to come.

---

## Appendix A: DBIC Resources

### Documentation
- [DBIx::Class Manual](https://metacpan.org/pod/DBIx::Class::Manual)
- [DBIx::Class Cookbook](https://metacpan.org/pod/DBIx::Class::Manual::Cookbook)
- [DBIx::Class::Schema::Loader](https://metacpan.org/pod/DBIx::Class::Schema::Loader)
- [DBIx::Class::Migration](https://metacpan.org/pod/DBIx::Class::Migration)

### Books
- *Programming Perl* (O'Reilly) - Chapters on DBI/DBIC
- *Perl Best Practices* (Conway) - ORM patterns

### Community
- IRC: #dbix-class on irc.perl.org
- Mailing list: dbix-class@lists.scsys.co.uk
- GitHub: https://github.com/Perl5-DBIx/DBIx-Class

---

## Appendix B: Migration Checklist

### Phase 0: Preparation
- [ ] Install DBIx::Class and dependencies
- [ ] Generate schema with dbicdump
- [ ] Review and clean generated Result classes
- [ ] Create compatibility layer
- [ ] Design core type Result classes
- [ ] Build test infrastructure
- [ ] Set up migration framework

### Phase 1: Read Operations
- [ ] Migrate getNode() for core types
- [ ] Migrate getNodeById() for core types
- [ ] Implement nodetype inheritance
- [ ] Migrate group node loading
- [ ] Convert complex queries to ResultSets
- [ ] All comparison tests passing

### Phase 2: Write Operations
- [ ] Migrate insertNode() for core types
- [ ] Migrate updateNode() for core types
- [ ] Migrate nukeNode() with tombstones
- [ ] Add transaction wrappers
- [ ] Integrate maintenance hooks
- [ ] Version increment on writes

### Phase 3: Specialized Features
- [ ] Integrate with NodeCache
- [ ] Migrate permission checks
- [ ] Node parameters system
- [ ] Transaction boundaries defined
- [ ] Performance acceptable

### Phase 4: Cleanup
- [ ] Remove NodeBase entirely
- [ ] Delete compatibility layer
- [ ] Optimize slow queries
- [ ] Complete documentation
- [ ] Production deployment

---

**END OF DOCUMENT**

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
2. [ORM Evaluation](#orm-evaluation)
3. [Migration Strategy](#migration-strategy)
4. [Implementation Phases](#implementation-phases)
5. [Technical Design](#technical-design)
6. [Risk Mitigation](#risk-mitigation)
7. [Testing Strategy](#testing-strategy)
8. [Performance Considerations](#performance-considerations)
9. [Rollback Plan](#rollback-plan)

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

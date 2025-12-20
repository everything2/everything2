# Everything2 Draft System Analysis

**Created**: 2025-12-19
**Purpose**: Comprehensive analysis of the draft system for publication workflow implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Draft Creation and Storage](#draft-creation-and-storage)
3. [Draft Visibility Rules](#draft-visibility-rules)
4. [Draft Searchability](#draft-searchability)
5. [E2node Attachment](#e2node-attachment)
6. [Publishing and Unpublishing Workflows](#publishing-and-unpublishing-workflows)
7. [Classic Interface Draft Management](#classic-interface-draft-management)
8. [System Inconsistencies](#system-inconsistencies)
9. [Key Files and Code Locations](#key-files-and-code-locations)

---

## Overview

The Everything2 draft system allows users to create, edit, and manage unpublished content before making it public. Drafts serve as:

1. **Pre-publication workspace**: New content being written
2. **Revision workspace**: Published writeups reverted to draft for major edits
3. **Collaboration workspace**: Shared drafts for peer review
4. **E2 Editor Beta workspace**: Modern React-based editor with autosave/versioning

**Node Type**: Draft (ID: 2035430)
**Canonical URL Format**: `/user/{author}/writeups/{title}`

---

## Draft Creation and Storage

### Database Schema

Drafts use THREE tables:

1. **`node` table**: Core node metadata
   - `node_id`: Unique identifier
   - `type_nodetype`: 2035430 (draft type)
   - `title`: Draft title
   - `author_user`: Creator user ID
   - `createtime`: Creation timestamp

2. **`draft` table**: Draft-specific metadata
   - `draft_id`: Links to node.node_id (primary key)
   - `publication_status`: Publication status node_id
   - `collaborators`: Comma-separated user IDs who can edit

3. **`writeup` table**: Content storage (SHARED with published writeups!)
   - `writeup_id`: Links to node.node_id
   - `doctext`: HTML content
   - `wrtype_writeuptype`: Writeup type (idea, person, thing, place, review)
   - `parent_e2node`: OPTIONAL parent e2node node_id

**Critical Note**: Both drafts AND published writeups can have entries in the `writeup` table. The `type_nodetype` field in the `node` table determines whether a piece of content is a draft (2035430) or writeup (117).

### Creation Methods

#### 1. E2 Editor Beta (Modern React-based)
**File**: `ecore/Everything/API/drafts.pm`
**Endpoint**: `POST /api/drafts`

```perl
sub create_draft {
  my ($self, $REQUEST) = @_;
  my $user = $REQUEST->user;
  my $data = $REQUEST->JSON_POSTDATA;

  # Create draft node with publication_status
  my $draft_id = $DB->insertNode($title, 'draft', $user, {
    doctext => $doctext || '',
    publication_status => $publication_status_id
  });

  # Insert writeup row for content storage
  $DB->sqlInsert('writeup', {
    writeup_id => $draft_id,
    doctext => $doctext || '',
    wrtype_writeuptype => $wrtype_id,
    parent_e2node => $parent_e2node_id || 0
  });
}
```

**Features**:
- JSON payload with title, doctext, wrtype, parent_e2node
- Publication status support (private, shared, public, findable, review)
- Autosave integration
- Version history tracking

#### 2. Classic Interface Draft Creation
**File**: `ecore/Everything/Delegation/htmlcode.pm`
**Function**: `htmlcode_writeupform`

Legacy HTML form submission - still functional but deprecated.

#### 3. Writeup Unpublishing (Reverting to Draft)
**File**: `ecore/Everything/API/admin.pm`
**Endpoint**: `POST /api/admin/:id/remove`

```perl
# Convert writeup to draft - combined update on node and draft tables
my $update_result = $DB->sqlUpdate('node, draft', {
  type_nodetype => $draft_type->{node_id},
  publication_status => $private_status->{node_id}
}, "node_id=$node_id AND draft_id=$node_id");

# Delete from writeup table
$DB->sqlDelete('writeup', "writeup_id=$node_id");

# Remove from parent e2node's nodegroup
$DB->removeFromNodegroup($E2NODE->NODEDATA, $NODE, -1);

# Cleanup: newwriteup, publish, category links
```

---

## Draft Visibility Rules

### Core Logic: `canSeeDraft()`
**File**: `ecore/Everything/Application.pm` (lines 1595-1667)

```perl
sub canSeeDraft {
  my ($self, $DRAFT, $USER, $disposition) = @_;
  # $disposition: 'edit' (modify) or 'find' (view)

  # 1. AUTHOR can always see their own drafts
  return 1 if $DRAFT->{author_user} == $USER->{node_id};

  # 2. GODS can see all drafts
  return 1 if $self->inUsergroup($USER, 'gods');

  # 3. COLLABORATORS (if listed in collaborators field)
  my $collaborators = $DRAFT->{collaborators} || '';
  return 1 if $collaborators =~ /\b$USER->{node_id}\b/;

  # 4. PUBLICATION STATUS based visibility
  my $pub_status = $self->node_by_id($DRAFT->{publication_status});
  return 0 unless $pub_status;

  my $status_title = $pub_status->{title};

  # Private: ONLY author/gods/collaborators
  return 0 if $status_title eq 'private';

  # Shared: Content Editors can see
  if ($status_title eq 'shared') {
    return 1 if $self->inUsergroup($USER, 'Content Editors');
    return 0;
  }

  # Public: All logged-in users can VIEW (but not edit)
  if ($status_title eq 'public') {
    return 1 if $disposition eq 'find';
    return 0; # Can't edit unless author/gods/collaborators
  }

  # Findable: Appears in searches for all users
  if ($status_title eq 'findable') {
    return 1 if $disposition eq 'find';
    return 0;
  }

  # Review: Content Editors can see
  if ($status_title eq 'review') {
    return 1 if $self->inUsergroup($USER, 'Content Editors');
    return 0;
  }

  return 0; # Default deny
}
```

### Visibility Matrix

| Publication Status | Author | Gods | Collaborators | Content Editors | Regular Users | Guest |
|-------------------|--------|------|---------------|-----------------|---------------|-------|
| **private** | ✅ Edit | ✅ Edit | ✅ Edit | ❌ | ❌ | ❌ |
| **shared** | ✅ Edit | ✅ Edit | ✅ Edit | ✅ View | ❌ | ❌ |
| **public** | ✅ Edit | ✅ Edit | ✅ Edit | ✅ View | ✅ View | ❌ |
| **findable** | ✅ Edit | ✅ Edit | ✅ Edit | ✅ View | ✅ View | ❌ |
| **review** | ✅ Edit | ✅ Edit | ✅ Edit | ✅ View | ❌ | ❌ |

**Guest users CANNOT see ANY drafts.**

---

## Draft Searchability

### Findings Page Integration
**File**: `ecore/Everything/Page/findings.pm`

```perl
sub buildReactData {
  my ($self, $REQUEST) = @_;
  my $user = $REQUEST->user;

  # Search drafts if user is logged in
  unless ($user->is_guest) {
    my @drafts = $DB->getNodeWhere({
      title => { -like => "%$search_term%" },
      type_nodetype => $draft_type_id
    });

    # Filter by canSeeDraft()
    @drafts = grep { $APP->canSeeDraft($_, $user->NODEDATA, 'find') } @drafts;
  }
}
```

**Behavior**:
- Drafts appear in `/findings` search results for logged-in users
- Filtered by `canSeeDraft()` with 'find' disposition
- Guest users NEVER see drafts in search results
- Drafts sorted by relevance (same as writeups)

### User Drafts Page
**URL**: `/user/{username}/writeups`
**File**: `ecore/Everything/Page/user.pm`

Shows user's own drafts and published writeups in reverse chronological order.

---

## E2node Attachment

### Parent E2node Field
**Database**: `writeup.parent_e2node` (integer, nullable)

**Purpose**: Associates a draft with a future e2node location. When published:
1. Create e2node if it doesn't exist
2. Add published writeup to e2node's nodegroup
3. Retain `parent_e2node` value in writeup table

**Critical Distinction**:
- **Drafts with parent_e2node**: "Attached draft" - knows where it will be published
- **Published writeup**: Member of e2node's nodegroup (many-to-one relationship via `nodegroup` table)

### Nodegroup Table (Published Writeups Only)
```sql
CREATE TABLE nodegroup (
  nodegroup_id INT PRIMARY KEY,
  node_id INT,            -- e2node node_id
  rank INT,               -- Display order
  orderby VARCHAR(255)    -- Sort key (rep, createtime, etc)
);
```

**Publishing Process**:
1. Convert draft node type from 2035430 → 117 (writeup)
2. Get or create parent e2node from `parent_e2node` field
3. Call `insertIntoNodegroup()` to add writeup to e2node's group
4. Update publication_status to appropriate published status

**Unpublishing Process** (writeup → draft):
1. Get parent e2node BEFORE modifications
2. Convert node type from 117 → 2035430
3. Delete from `writeup` table
4. Call `removeFromNodegroup()` to remove from e2node
5. Update publication_status to 'removed' (2043621)

---

## Publishing and Unpublishing Workflows

### Legacy Publishing: `publishdraft` htmlcode
**File**: `ecore/Everything/Delegation/htmlcode.pm` (lines 12303-12365)

```perl
sub publishdraft {
  my ($NODE, $noUpdate) = @_;

  # 1. Validate draft node
  return 0 unless $NODE->{type}{title} eq 'draft';

  # 2. Get or create parent e2node
  my $parent_id = $NODE->{parent_e2node};
  my $e2node;
  if ($parent_id) {
    $e2node = $APP->node_by_id($parent_id);
  } else {
    # Create new e2node with draft's title
    $e2node = $DB->getNode($NODE->{title}, 'e2node');
    unless ($e2node) {
      $e2node = $DB->insertNode($NODE->{title}, 'e2node', $NODE->{author_user});
    }
  }

  # 3. Convert draft to writeup type
  my $writeup_type = getType('writeup');
  $DB->sqlUpdate('node, draft', {
    type_nodetype => $writeup_type->{node_id}
  }, "node_id=".$NODE->{node_id}." AND draft_id=".$NODE->{node_id});

  # 4. Update parent_e2node in writeup table
  $DB->sqlUpdate('writeup', {
    parent_e2node => $e2node->{node_id}
  }, "writeup_id=".$NODE->{node_id});

  # 5. Add to e2node's nodegroup
  $DB->insertIntoNodegroup($e2node, $NODE, -1);

  # 6. Update newwriteups ticker
  unless ($noUpdate) {
    $APP->updateNewWriteups();
  }

  # 7. Cache management
  $DB->{cache}->incrementGlobalVersion($NODE);
  $DB->{cache}->removeNode($NODE);

  return 1;
}
```

### Modern Unpublishing: Admin API
**File**: `ecore/Everything/API/admin.pm`
**Endpoint**: `POST /api/admin/:id/remove`

See [Draft Creation](#draft-creation-and-storage) section for code details.

**Key Steps**:
1. Get parent e2node BEFORE type conversion
2. Combined update on node/draft tables
3. Delete from writeup table
4. Remove from nodegroup BEFORE cache operations
5. Cleanup: newwriteup, publish, category links
6. Explicit transaction commit

---

## Classic Interface Draft Management

### User Writeups Page
**URL**: `/user/{username}/writeups`

**Features**:
- Lists user's drafts and published writeups
- "Edit" link for drafts
- "Publish" link for drafts (if attached to e2node)
- "Unpublish" link for published writeups (reverts to draft)

### Legacy Writeup Form
**Function**: `htmlcode_writeupform` in `ecore/Everything/Delegation/htmlcode.pm`

**Unpublish Workflow**:
1. User clicks "Unpublish" link on their writeup
2. Calls `unpublishwriteup` htmlcode
3. Writeup converted to draft with publication_status='removed'
4. Removed from e2node nodegroup
5. User sees draft in "My Drafts" section

**Publish Workflow**:
1. User clicks "Publish" link on draft
2. Calls `publishdraft` htmlcode
3. Draft converted to writeup type
4. Added to parent e2node's nodegroup
5. Appears in New Writeups ticker

### No Direct "Revert to Draft" Button
**Finding**: Classic interface does NOT have a dedicated "Revert to Draft" button. Unpublishing is done via:
- Admin tools (editors only)
- Nuke/delete operations (converts to draft as intermediate step)
- Legacy "remove writeup" functionality

**User Confusion**: Regular users cannot easily revert their own published writeups to draft in the classic interface. This is a usability gap.

---

## System Inconsistencies

### 1. Publication Status Storage Confusion
**Problem**: Both drafts AND writeups use the `draft.publication_status` field.

**Example**:
```sql
-- Draft with private status
SELECT * FROM node n, draft d
WHERE n.node_id = d.draft_id
  AND n.type_nodetype = 2035430  -- draft type
  AND d.publication_status = 2043617;  -- 'private' status

-- Writeup with public status (ALSO uses draft table!)
SELECT * FROM node n, draft d
WHERE n.node_id = d.draft_id
  AND n.type_nodetype = 117  -- writeup type
  AND d.publication_status = 2043619;  -- 'public' status
```

**Confusion**: The `draft` table name implies it's only for drafts, but it's actually used for ALL content publication status tracking.

### 2. Type Conversion Fragility
**Problem**: Converting between draft (2035430) and writeup (117) requires updating multiple tables in precise order.

**Failure Modes**:
- Updating type BEFORE removing from nodegroup → null node errors
- Forgetting to update writeup table → orphaned content
- Not cleaning up newwriteup/publish tables → stale ticker data
- Missing transaction commit → partial state

### 3. Visibility Logic Complexity
**Problem**: `canSeeDraft()` has 6+ different code paths based on publication status.

**Maintenance Risk**:
- Adding new publication statuses requires updating visibility logic
- 'edit' vs 'find' disposition易混淆
- Collaborators field parsing is fragile (comma-separated string)

### 4. Search Behavior Inconsistency
**Problem**: Drafts appear in `/findings` for logged-in users but not for guests.

**User Confusion**:
- "Why can't I find my friend's public draft?"
- "I shared my draft but they can't search for it"

**AdSense Concern**: If drafts with profanity appear in search results, could violate content policy.

### 5. Attachment vs Parent Confusion
**Problem**: `parent_e2node` field serves dual purpose:
- For drafts: "Where will this be published?"
- For writeups: "Where is this published?" (redundant with nodegroup membership)

**Better Design**: Drafts should use `target_e2node` field, writeups should derive parent from nodegroup.

### 6. Classic vs React Interface Gaps
**Problem**: Classic interface lacks features present in E2 Editor Beta:
- No autosave
- No version history
- No easy "revert to draft" for regular users
- No publication status selection

### 7. Collaborators Field Issues
**Problem**: `draft.collaborators` is a comma-separated string of user IDs.

**Limitations**:
- No foreign key constraints
- No validation of user existence
- Regex parsing in `canSeeDraft()` is fragile
- No UI for managing collaborators in classic interface

### 8. Status Transition Restrictions
**Problem**: No validation of allowed publication status transitions.

**Example Invalid Transitions**:
- 'removed' → 'findable' (should require 'review' first)
- 'nuked' → 'public' (nuked content shouldn't be resurrected)
- 'insured' → 'private' (protected writeups shouldn't become drafts)

### 9. Version History and Autosave Confusion
**Problem**: E2 Editor Beta has `draft_versions` table for version history, but publishing doesn't preserve version history.

**Expected**: Publishing a draft should snapshot final version
**Actual**: Version history lost on publication

### 10. Neglected Drafts Logic
**Problem**: No automatic cleanup of old, abandoned drafts.

**Database Bloat**:
- Drafts from 2010+ still in database
- No "last modified" timestamp
- No "draft age" warnings

### 11. Publication_status=0 Ambiguity
**Problem**: `publication_status=0` can mean:
- Not set (NULL should be used)
- Legacy data before publication_status existed
- Deleted publication_status node

**Better**: Enforce NOT NULL constraint and default to 'private' (2043617).

### 12. Insured Writeups as "Drafts"
**Problem**: The 'insured' publication status (2043625) is meant for protected writeups that shouldn't be editable, but they still use the `draft` table.

**Confusion**: "Is an insured writeup a draft?"
**Answer**: No, it's a protected published writeup, but the schema suggests otherwise.

---

## Key Files and Code Locations

### Perl Backend

| File | Purpose | Key Functions |
|------|---------|---------------|
| `ecore/Everything/Node/draft.pm` | Draft node class | Extends writeup type, defines canonical URL |
| `ecore/Everything/Node/writeup.pm` | Writeup node class | `single_writeup_display()` for JSON serialization |
| `ecore/Everything/Application.pm` | Core app logic | `canSeeDraft()` (lines 1595-1667) |
| `ecore/Everything/API/drafts.pm` | E2 Editor Beta API | `create_draft()`, `update_draft()`, `delete_draft()` |
| `ecore/Everything/API/admin.pm` | Admin operations | `remove_writeup()` (lines 482-527) |
| `ecore/Everything/Delegation/htmlcode.pm` | Legacy htmlcode functions | `publishdraft()` (12303-12365), `unpublishwriteup()` (12367-12447) |
| `ecore/Everything/Page/findings.pm` | Search results page | Draft filtering in search |
| `ecore/Everything/Page/user.pm` | User profile page | Draft listing |

### React Frontend

| File | Purpose |
|------|---------|
| `react/components/Documents/Writeup.js` | Writeup page component |
| `react/components/WriteupDisplay.js` | Writeup rendering component |
| `react/components/E2NodeDisplay.js` | E2node page with writeup list |

### Database Tables

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `node` | Core node data | `node_id`, `type_nodetype`, `title`, `author_user`, `createtime` |
| `draft` | Draft metadata | `draft_id`, `publication_status`, `collaborators` |
| `writeup` | Content storage | `writeup_id`, `doctext`, `wrtype_writeuptype`, `parent_e2node` |
| `nodegroup` | E2node writeup membership | `nodegroup_id`, `node_id` (e2node), `rank`, `orderby` |
| `publication_status` | Status definitions | 'private', 'shared', 'public', 'findable', 'review', 'removed', 'nuked', 'insured' |
| `draft_versions` | E2 Editor Beta version history | `draft_id`, `version_number`, `content`, `created_at` |

---

## Recommendations for Publication Workflow Implementation

### 1. Migrate E2 Editor Beta Controller Code
**Source**: `ecore/Everything/API/drafts.pm`
**Target**: `ecore/Everything/Page/drafts.pm` (create new)

Extract React data building logic into `buildReactData()` method.

### 2. Create Unified Publish/Unpublish API
**Endpoint**: `POST /api/drafts/:id/publish`
**Endpoint**: `POST /api/writeups/:id/unpublish`

Consolidate legacy htmlcode logic into modern API endpoints.

### 3. Add Publication Status Validation
**Location**: `ecore/Everything/Node/draft.pm`

```perl
sub validate_status_transition {
  my ($self, $old_status, $new_status) = @_;

  # Define allowed transitions
  my %allowed = (
    private => ['shared', 'review'],
    shared => ['private', 'review', 'public'],
    review => ['shared', 'public', 'findable'],
    public => ['private', 'findable'],
    findable => ['private', 'public'],
    removed => ['review'],  # Must go through review first
  );

  return exists $allowed{$old_status}{$new_status};
}
```

### 4. Simplify Visibility Logic
**Location**: `ecore/Everything/Application.pm`

Extract visibility rules into separate `VisibilityPolicy` class for testability.

### 5. Add Draft Age Cleanup
**Location**: `ecore/Everything/Delegation/maintenance.pm`

```perl
# Delete drafts older than 1 year with publication_status='private'
# and no edits in last 365 days
```

### 6. Preserve Version History on Publish
**Location**: `ecore/Everything/API/drafts.pm`

```perl
sub publish_draft {
  # Before publishing, snapshot final version
  $DB->sqlInsert('draft_versions', {
    draft_id => $draft_id,
    version_number => $max_version + 1,
    content => $final_doctext,
    created_at => time(),
    note => 'Published version'
  });

  # Then proceed with publication
}
```

### 7. Add User-Facing "Revert to Draft" Button
**Location**: React component for writeup display

Allow regular users to unpublish their own writeups (not just editors).

---

## End of Document

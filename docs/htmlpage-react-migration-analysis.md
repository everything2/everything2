# HTMLPage System Analysis & React Migration Strategy

**Date**: 2025-11-26
**Status**: Analysis Complete
**Scope**: Understanding htmlpage delegation system for potential React migration

---

## Executive Summary

Everything2's htmlpage system is a **database-driven display layer** that provides view/edit forms for different node types. Currently implemented as:
- **100 delegated functions** in [Everything::Delegation::htmlpage](../ecore/Everything/Delegation/htmlpage.pm) (4668 lines)
- **99 htmlpage database records** mapping node types to display/edit functions
- **1 special Controller** ([Everything::Controller::maintenance](../ecore/Everything/Controller/maintenance.pm)) bypassing delegation for maintenance_display

This is fundamentally different from the superdoc/document system we've been migrating and requires a different approach.

---

## Current Architecture

### How HTMLPages Work

1. **Request arrives** for a node (e.g., `/node/123`)
2. **Controller** calls `Everything::HTML::getPage($NODE, $displaytype)`:
   - Looks up node's type (e.g., 'writeup', 'user', 'nodetype')
   - Queries database for htmlpage matching `(pagetype_nodetype, displaytype)`
   - Returns htmlpage node reference
3. **htmlpage node** contains:
   - `pagetype_nodetype`: Which node type this displays (e.g., writeup nodetype ID)
   - `displaytype`: 'display', 'edit', 'basicedit', 'xml', etc.
   - `page`: Function name in Everything::Delegation::htmlpage (e.g., 'writeup_display_page')
4. **Delegation function** called with signature:
   ```perl
   sub writeup_display_page {
     my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;
     # Build HTML string
     return $str;
   }
   ```
5. **HTML returned** as string, embedded in Mason2 template

### Database Schema

```sql
-- htmlpage table structure
htmlpage_id           INT PRIMARY KEY AUTO_INCREMENT
pagetype_nodetype     INT         -- References nodetype.node_id
displaytype           VARCHAR(20) -- 'display', 'edit', etc.
page                  MEDIUMTEXT  -- Function name in htmlpage.pm
parent_container      INT
mimetype              VARCHAR(50)
```

**Example records**:
```
htmlpage_id=59,  pagetype_nodetype=2 (container),   displaytype='display'
htmlpage_id=61,  pagetype_nodetype=3 (nodelet),     displaytype='display'
htmlpage_id=65,  pagetype_nodetype=5 (document),    displaytype='display'
htmlpage_id=75,  pagetype_nodetype=1 (node),        displaytype='display'
```

### 100 Delegation Functions

All in [Everything::Delegation::htmlpage.pm](../ecore/Everything/Delegation/htmlpage.pm):

**Display Pages** (read-only views):
- `container_display_page` - Container hierarchy viewer
- `nodelet_display_page` - Nodelet configuration viewer
- `document_display_page` - Document viewer (delegates to Everything::Delegation::document)
- `htmlcode_display_page` - Code viewer with syntax highlighting
- `htmlpage_display_page` - Meta - displays htmlpage definitions
- `node_display_page` - Generic node viewer (fallback)
- `nodegroup_display_page` - Node group membership viewer
- `nodetype_display_page` - Nodetype inheritance viewer
- `dbtable_display_page` - Database schema viewer
- `maintenance_display_page` - Cron job viewer
- `setting_display_page` - Configuration setting viewer
- `mail_display_page` - Email viewer
- `writeup_xml_page` - XML export for writeups
- `e2node_xml_page` - XML export for e2nodes
- `superdoc_display_page` - Superdoc viewer (delegates to Everything::Delegation::document)
- ...and ~85 more

**Edit Pages** (forms):
- `container_edit_page`, `nodelet_edit_page`, `document_edit_page`, etc.
- `writeup_edit_page` - Writeup editor
- `classic_user_edit_page` - User settings editor
- `nodegroup_editor_page` - Usergroup management
- `node_basicedit_page` - Generic node field editor
- ...and many more

**Patterns**:
- `{type}_display_page` - View node of type
- `{type}_edit_page` - Edit node of type
- `{type}_basicedit_page` - Simple form editor
- `{type}_xml_page` - XML export

---

## Key Differences from Superdoc/Document System

| Aspect | Superdoc/Document | HTMLPage |
|--------|-------------------|----------|
| **Purpose** | Content pages | Admin/node viewing/editing |
| **Routing** | URL-based (`/title/page_name`) | Node type + displaytype |
| **Storage** | Node content in `doctext` field | Function name in `page` field |
| **Implementation** | Mason2 templates OR React components | Delegation functions |
| **Migration Path** | Everything::Page::X → React | Delegation function → ??? |
| **Count** | ~159 special documents | ~100 delegation functions |
| **User-Facing** | Yes (public content) | Mixed (admin tools + editing) |

**Critical Insight**: Superdocs are **content** (pages users visit), htmlpages are **infrastructure** (how nodes are displayed/edited). They serve entirely different purposes.

---

## Maintenance Display Special Case

### Current Implementation

**Controller** ([Everything::Controller::maintenance.pm](../ecore/Everything/Controller/maintenance.pm)):
```perl
sub display {
  my ($self, $REQUEST, $node) = @_;
  my $html = $self->layout('/maintenance_display', REQUEST => $REQUEST, node => $node);
  return [$self->HTTP_OK, $html];
}
```

**Mason Template** ([templates/maintenance_display.mc](../templates/maintenance_display.mc)):
```mason
<%flags>
    extends => '/zen.mc'
</%flags>
Maintains: <& 'linknode', 'node' => $.node->maintains &><br>
<p>
Maintenance operation: <% $.node->maintaintype %>
<p><pre><% $.node->code_text %></pre>
```

**Why Special?**
- Only htmlpage with dedicated Controller + Mason template
- Bypasses delegation entirely
- Likely because maintenance nodes need special routing/handling

---

## React Migration Options

### Option 1: Keep HTMLPages as Delegation (Recommended for Now)

**Approach**: Don't migrate htmlpages to React immediately
- Focus on superdoc/document content migration (Phase 4a)
- Leave admin/editing infrastructure in Perl
- Migrate only when Mason2 elimination is complete

**Pros**:
- ✅ No risk to critical admin functionality
- ✅ Allows continued work on user-facing content
- ✅ Delegation functions work fine without Mason2
- ✅ Can revisit after Phase 4 complete

**Cons**:
- ❌ Admin UI remains in Perl-generated HTML
- ❌ Doesn't contribute to Mason2 elimination goal

**Timeline**: Post-Phase 4

### Option 2: Controller-Based React Routing (Like Maintenance)

**Approach**: Create Everything::Controller::X classes for each node type
- Each Controller has `display()` and `edit()` methods
- Controllers call Mason templates OR React components
- Gradual migration: Controller → Mason → Controller → React

**Example**:
```perl
# Everything::Controller::writeup
sub display {
  my ($self, $REQUEST, $node) = @_;

  # Check if React migration exists
  if ($self->can('buildReactData')) {
    return $self->render_react($REQUEST, $node);
  }

  # Fall back to Mason template
  my $html = $self->layout('/writeup_display', REQUEST => $REQUEST, node => $node);
  return [$self->HTTP_OK, $html];
}
```

**Pros**:
- ✅ Clean separation of concerns
- ✅ Gradual migration path
- ✅ Follows existing maintenance_display pattern
- ✅ Can coexist with delegation during transition

**Cons**:
- ❌ Requires creating ~100 Controller classes
- ❌ Duplicates work (delegation → Controller → React)
- ❌ Complex migration coordination

**Timeline**: 6-9 months

### Option 3: Direct Delegation → React (Aggressive)

**Approach**: Replace delegation functions with React components directly
- Create React components for each htmlpage type
- Modify Everything::HTML::getPage() to detect React availability
- Return React data instead of HTML string

**Example**:
```perl
# In Everything::HTML or Application.pm
sub renderHtmlPage {
  my ($self, $NODE, $displaytype) = @_;

  my $type_name = $NODE->{type}->{title};  # e.g., 'writeup'
  my $component_name = "${type_name}_${displaytype}";  # e.g., 'writeup_display'

  # Check for React component
  if (exists $REACT_COMPONENTS{$component_name}) {
    return $self->buildReactData($NODE, $component_name);
  }

  # Fall back to delegation
  return Everything::Delegation::htmlpage->$function($DB, $query, $NODE, ...);
}
```

**Pros**:
- ✅ Fastest path to React-based admin UI
- ✅ Eliminates delegation functions directly
- ✅ No intermediate Controller step

**Cons**:
- ❌ High risk - admin tools are critical
- ❌ All-or-nothing per node type
- ❌ Difficult to test incrementally
- ❌ Breaks existing htmlpage database records

**Timeline**: 9-12 months

### Option 4: Hybrid - Delegation Stays, Add React Admin Components (Pragmatic)

**Approach**: Keep delegation for now, create parallel React admin UI
- Delegation functions continue to work
- New React components for admin features
- Route based on preference/feature flags
- Gradual transition without breaking existing functionality

**Example**:
```perl
# User visits /node/123
# Controller checks: user has "use_react_admin" preference?
if ($USER->{react_admin_enabled}) {
  # Route to React admin component
  return $self->render_react_admin($NODE);
} else {
  # Use existing delegation
  return $self->render_delegated($NODE);
}
```

**Pros**:
- ✅ Zero risk to existing functionality
- ✅ Can test React admin with select users
- ✅ Gradual rollout with fallback
- ✅ Parallel development doesn't block other work

**Cons**:
- ❌ Maintains two code paths temporarily
- ❌ Requires feature flag infrastructure
- ❌ Slower overall migration

**Timeline**: 12-18 months

---

## Recommended Strategy

### Phase 4a (Current): Complete Superdoc/Document Migration
- ✅ Finish remaining 21 superdoc templates → React
- ✅ Establish content-only page optimization pattern
- ✅ Document migration patterns in CLAUDE.md
- ❌ **Do NOT touch htmlpages yet**

### Phase 4b: Evaluate Mason2 Dependencies
- Audit remaining Mason2 usage after superdoc migration
- Identify which delegation functions truly need templates
- Determine if delegation can survive without Mason2

### Phase 5: HTMLPage Strategy Decision
**Decision Point**: After Phase 4a complete, evaluate:
1. Can delegation functions work without Mason2?
2. Which admin tools are highest priority for React?
3. Is Controller-based routing worth the effort?

**Likely Recommendation**:
- Keep delegation for low-priority admin tools
- Migrate high-traffic admin pages (writeup_edit, user settings) to React via Controller pattern
- Use Option 4 (Hybrid) for gradual transition

---

## Content vs Infrastructure

**Key Philosophical Question**: What should React own?

**Content (Migrate First)**:
- ✅ Superdocs - user-facing content pages
- ✅ Documents - writeups, e2nodes, user homenode content
- ✅ Tickers - JSON/XML API responses
- ✅ Fullpages - Standalone interface pages

**Infrastructure (Migrate Later)**:
- ⏸ HTMLPages - admin tools, node editing, database management
- ⏸ Opcodes - form submissions, actions
- ⏸ Maintenance - cron jobs, system management

**Rationale**: Users experience content, admins can tolerate Perl UI for infrastructure.

---

## Example: How to Migrate One HTMLPage to React

If we wanted to migrate `maintenance_display_page` fully to React:

### Step 1: Create Everything::Page::maintenance

```perl
package Everything::Page::maintenance;

use Moose;
extends 'Everything::Page';

sub buildReactData {
  my ($self, $REQUEST) = @_;

  my $node = $REQUEST->node;
  my $maintains = $self->APP->node_by_id($node->maintain_nodetype);

  return {
    type => 'maintenance',
    maintains => {
      node_id => $maintains->node_id,
      title => $maintains->title
    },
    maintaintype => $node->maintaintype,
    code => $node->code_text
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

### Step 2: Create React Component

```javascript
// react/components/Documents/Maintenance.js
const Maintenance = ({ data }) => {
  const { maintains, maintaintype, code } = data;

  return (
    <div className="maintenance-display">
      <p>
        Maintains: <LinkNode node={maintains} />
      </p>
      <p>Maintenance operation: {maintaintype}</p>
      <pre>{code}</pre>
    </div>
  );
};

export default Maintenance;
```

### Step 3: Update DocumentComponent Router

```javascript
const COMPONENT_MAP = {
  // ...existing
  maintenance: lazy(() => import('./Documents/Maintenance'))
};
```

### Step 4: Modify Controller

```perl
# Everything::Controller::maintenance
sub display {
  my ($self, $REQUEST, $node) = @_;

  # Check if Everything::Page::maintenance exists and has buildReactData
  my $page_class = "Everything::Page::maintenance";
  if ($page_class->can('buildReactData')) {
    # Use React rendering (already handled by parent Controller)
    return $self->SUPER::display($REQUEST, $node);
  }

  # Fall back to Mason template
  my $html = $self->layout('/maintenance_display', REQUEST => $REQUEST, node => $node);
  return [$self->HTTP_OK, $html];
}
```

### Step 5: Remove Delegation Function

Once React version is stable, remove [htmlpage.pm:551-571](../ecore/Everything/Delegation/htmlpage.pm#L551-L571)

---

## Questions for User

1. **Scope Priority**: Should we continue with superdoc/document migration (Phase 4a) and defer htmlpages?
2. **Admin UI Value**: How important is modernizing admin tools vs user-facing content?
3. **Risk Tolerance**: Comfortable with aggressive React migration or prefer gradual hybrid approach?
4. **Timeline**: What's the target for Mason2 elimination? (Affects strategy choice)

---

## Recommendations

### Immediate (Phase 4a)
- ✅ **Focus on remaining 21 superdoc/document pages**
- ✅ Complete content-only optimization patterns
- ❌ **Do NOT migrate htmlpages yet**

### Short-Term (Phase 4b)
- Audit Mason2 dependencies in delegation functions
- Identify critical vs nice-to-have admin tools
- Test if delegation can survive post-Mason2

### Long-Term (Phase 5+)
- **If delegation works without Mason2**: Leave htmlpages as-is
- **If critical admin tools need React**: Use Controller pattern for high-priority pages
- **If full modernization desired**: Hybrid approach with feature flags

**Conservative Estimate**: HTMLPage migration is 12-18 month effort requiring careful planning. Superdoc/document migration is 2-3 month effort with clear patterns established.

---

## Appendix: Function Catalog

### Critical Admin Functions (High Priority for React)
- `writeup_edit_page` - Content editing (high traffic)
- `classic_user_edit_page` - User settings (high traffic)
- `nodegroup_editor_page` - Group management (admin feature)

### Infrastructure Functions (Low Priority)
- `dbtable_display_page` - Schema viewer (dev tool)
- `nodetype_display_page` - Type inspector (dev tool)
- `maintenance_display_page` - Cron viewer (ops tool)

### Viewer Functions (Medium Priority)
- `writeup_xml_page` - API endpoint
- `node_display_page` - Generic fallback
- `container_display_page` - Content organization

Full list: 100 functions in [htmlpage.pm](../ecore/Everything/Delegation/htmlpage.pm)

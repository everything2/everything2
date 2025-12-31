# Categories System Specification

**Purpose**: Allow users to create curated lists of related nodes
**Status**: Implemented (Legacy + React hybrid)

---

## Overview

Categories are special nodes that group related e2nodes and writeups into curated lists. Users create and maintain categories, which appear in a sidebar nodelet on the homepage.

---

## Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| `Categories.js` | `react/components/Nodelets/Categories.js` | Sidebar nodelet UI |
| `CreateCategory.js` | `react/components/Documents/CreateCategory.js` | Category creation form |
| `create_category.pm` | `ecore/Everything/Page/create_category.pm` | Creation page data |
| `categoryform` | `ecore/Everything/Delegation/htmlcode.pm:11179` | Add-to-category widget |
| `listnodecategories` | `ecore/Everything/Delegation/htmlcode.pm:10476` | Show node's categories |

### Data Flow

1. **Nodelet display**: `buildE2PageData()` queries editable categories → passes to React
2. **Adding to category**: `categoryform` htmlcode renders dropdown → form POSTs with `op=category`
3. **Creating category**: React form → POSTs with `op=new`, `type=1522375`

---

## Database Schema

### Node Type

```xml
<!-- nodepack/nodetype/category.xml -->
<node>
  <node_id>1522375</node_id>
  <title>category</title>
  <extends_nodetype>8</extends_nodetype>  <!-- document -->
  <sqltable>document</sqltable>
  <grouptable>nodegroup</grouptable>
  <restrictdupes>1</restrictdupes>
</node>
```

Categories extend the `document` node type, so they have:
- `doctext`: Category description (HTML)
- `author_user`: The maintainer (user, usergroup, or Guest User for public)

### Link Type

```xml
<!-- nodepack/linktype/category.xml -->
<node>
  <node_id>1935395</node_id>
  <title>category</title>
</node>
```

Category membership is stored as links:
```
links table:
  from_node = category_node_id
  to_node = member_node_id (e2node or writeup)
  linktype = 1935395 (category linktype)
```

---

## Maintainer Types

Categories can be maintained by:

| Maintainer | Description |
|------------|-------------|
| User (self) | Only the creating user can add/remove nodes |
| Guest User | Any logged-in user can edit (public category) |
| Usergroup | Any member of the usergroup can edit |

The `author_user` field stores the maintainer's node_id:
- Personal: user's node_id
- Public: Guest User node_id (from `$Everything::CONF->guest_user`)
- Usergroup: usergroup's node_id

---

## Categories Nodelet

### Data Structure

```javascript
// Passed via e2.categories
{
  categories: [
    {
      node_id: 123456,
      title: "Best Science Fiction",
      author_user: 789,
      author_username: "coolnoder"
    }
  ],
  currentNodeId: 999999  // Current page's node_id
}
```

### Query (Application.pm:6915)

```sql
SELECT n.node_id, n.title, n.author_user, u.title AS author_username
FROM node n
LEFT JOIN node u ON n.author_user = u.node_id
WHERE n.author_user IN ($userOrGroupIds)
  AND n.type_nodetype = 1522375
  AND n.node_id NOT IN (SELECT to_node FROM links WHERE from_node = n.node_id)
ORDER BY n.title
```

This returns categories the user can edit, excluding categories the current node is already in.

### UI

- Shows category title linked to category page
- Shows "by [author]" attribution
- "(add)" link to add current node to that category
- Footer: "Add a new Category" link to create_category superdoc

---

## Adding Nodes to Categories

### Widget (categoryform htmlcode)

The `categoryform` htmlcode renders an add-to-category dropdown:

```html
<fieldset id="categoryform{node_id}">
  <legend>Add this [type] to a category:</legend>
  <select name="cid{node_id}">
    <option value="">Choose...</option>
    <option value="123">My Category</option>
    <option value="new">New category...</option>
  </select>
  <button name="op" value="category">Add</button>
</fieldset>
```

### AJAX Updates

Uses the legacy AJAX system with class:
```
ajax categoryform{nid}:categoryform?op=category&nid=/nid&cid=/cid
```

On success, displays "Added" notification and updates the categories display.

### Permission Check

```perl
# Application.pm
sub can_category_add {
  my ($this, $node) = @_;
  return $this->can_action($node, "category");
}
```

Checks `disable_category` node param on node or node type.

### Level Restriction

Level 1 users can only add their own writeups to categories. Level 2+ users can add others' writeups.

---

## Creating Categories

### Page: create_category.pm

Returns form data:
```perl
{
  type              => 'create_category',
  user_id           => $user_id,
  user_title        => $USER->title,
  usergroups        => \@usergroups,  # Groups user belongs to
  category_type_id  => 1522375,
  guest_user_id     => $guest_user_id,
  low_level_warning => 1  # If level <= 1
}
```

### React Form: CreateCategory.js

Form fields:
- **Category Name**: Text input (max 255 chars)
- **Maintainer**: Dropdown (Me / Any Noder / Usergroups)
- **Description**: Textarea with `class="formattable"` (TinyMCE-enabled)

Submit creates form with:
```javascript
{
  node: categoryName,
  maintainer: maintainerId,
  category_doctext: description,
  op: 'new',
  type: category_type_id
}
```

### TinyMCE Integration

The description textarea has `class="formattable"`, which triggers TinyMCE initialization if the user has it enabled in settings (`settings_useTinyMCE`).

**Note**: This is one of the last remaining TinyMCE use cases in E2.

---

## Displaying Category Contents

### listnodecategories htmlcode

Shows which categories contain a given node:

```perl
sub listnodecategories {
  my $nodeid = shift || $$NODE{node_id};
  # Query links where to_node = $nodeid AND linktype = category_linktype
  # Return linked list of category titles
}
```

Output:
```html
<div class="categories" id="categories{node_id}">
  Categories: <a href="/node/123">Best Fiction</a>, <a href="/node/456">User's Favorites</a>
</div>
```

---

## User Profile Integration

### showUserCategories htmlcode

Lists categories maintained by a user:

```perl
sub showUserCategories {
  my $U = shift || $$USER{node_id};
  # Query: author_user = $U AND type_nodetype = category_type_id
  # Return comma-separated linked titles
}
```

Used on user profile pages to show categories they maintain.

### Node class: editable_categories

`Everything::Node::user::editable_categories()` returns categories a user can edit:
- Categories where user is author
- Categories where a usergroup they belong to is author
- Public categories (author = Guest User)

---

## Related Files

| File | Purpose |
|------|---------|
| `react/components/Nodelets/Categories.js` | Sidebar nodelet |
| `react/components/Documents/CreateCategory.js` | Creation form |
| `ecore/Everything/Page/create_category.pm` | Creation page data |
| `ecore/Everything/Delegation/htmlcode.pm` | categoryform, listnodecategories, showUserCategories |
| `ecore/Everything/Node/user.pm` | editable_categories method |
| `ecore/Everything/Application.pm:6915` | Categories nodelet data |
| `nodepack/nodetype/category.xml` | Node type definition |
| `nodepack/linktype/category.xml` | Link type definition |
| `nodepack/opcode/category.xml` | Operation code |

---

## Future Considerations

1. **TinyMCE replacement**: The category description editor is one of the last TinyMCE users. Could migrate to TipTap.

2. **React migration**: The categoryform widget is legacy htmlcode. Could be converted to React component.

3. **API endpoint**: Currently uses form POSTs. Could add `/api/categories/` for modern integration.

---

*Last updated: December 2025*

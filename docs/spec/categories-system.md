# Categories System Specification

**Purpose**: Allow users to create curated lists of related nodes
**Status**: Implemented (React UI + `Everything::API::category` backend)

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
| `AddToCategoryModal.js` | `react/components/AddToCategoryModal.js` | Add-to-category React modal |
| `Everything::API::category` | `ecore/Everything/API/category.pm` | Category REST backend (add/remove/list/reorder) |

### Data Flow

1. **Nodelet display**: `buildE2PageData()` queries editable categories → passes to React
2. **Adding to category**: React `AddToCategoryModal` calls `GET /api/category/list` to populate choices, then `POST /api/category/add_member`
3. **Creating category**: React form → POSTs with `op=new`, `type=1522375`

> **Backend note (current):** The legacy `categoryform` / `listnodecategories` / `showUserCategories` htmlcodes and the `op=category` opcode were **removed**. All category membership operations now go through `Everything::API::category` (`add_member`, `remove_member`, `reorder_members`, `list`, `node_categories`, `update`, `update_meta`, `lookup_owner`), driven from React.

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

### Widget (AddToCategoryModal React component)

`react/components/AddToCategoryModal.js` renders the add-to-category UI. It populates its choices from `GET /api/category/list?node_id=X` (which returns `your_categories`, `public_categories`, and — for editors — `other_categories`, already excluding categories the node is in) and submits via `POST /api/category/add_member`:

```javascript
// POST /api/category/add_member
{ category_id: 123, node_id: 999999 }
```

On success the API returns `{ success: 1, category_title }` and the React UI updates.

### Permission Check

Permission lives in the API (`add_member` in `ecore/Everything/API/category.pm`). A user can add to a category if any of: they are an editor; the category is public (owned by Guest User); they own the category; or they belong to the usergroup that maintains it.

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

### `GET /api/category/node_categories?node_id=X`

Returns the categories that contain a given node, each with `can_remove` permission info and prev/next navigation within the category (`_get_category_navigation`). React renders this list; the legacy `listnodecategories` htmlcode no longer exists.

---

## User Profile Integration

Categories a user maintains are surfaced through `Everything::Node::user::editable_categories()` and the category API (`/api/category/list`). The legacy `showUserCategories` htmlcode no longer exists.

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
| `react/components/AddToCategoryModal.js` | Add-to-category React modal |
| `ecore/Everything/Page/create_category.pm` | Creation page data |
| `ecore/Everything/API/category.pm` | Category REST backend (add/remove/list/reorder/meta) |
| `ecore/Everything/Node/user.pm` | editable_categories method |
| `ecore/Everything/Application.pm:6915` | Categories nodelet data |
| `nodepack/nodetype/category.xml` | Node type definition |
| `nodepack/linktype/category.xml` | Link type definition |

---

## Future Considerations

1. **TinyMCE replacement**: The category description editor is one of the last TinyMCE users. Could migrate to TipTap.

---

*Last updated: June 2026 (backend now `Everything::API::category` + React `AddToCategoryModal`; legacy categoryform/listnodecategories/showUserCategories htmlcode and the `op=category` opcode removed)*

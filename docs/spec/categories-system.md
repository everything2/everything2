# Categories System Specification

**Purpose**: Allow users to create curated lists of related nodes
**Status**: Implemented (React UI + `Everything::API::category` backend)
**Last verified**: 2026-11-16

---

## Overview

Categories are special nodes that group related e2nodes and writeups into curated lists. Users create and maintain categories. The Categories sidebar nodelet shows which categories the current node belongs to and lets users add/remove it.

---

## Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| `Categories.js` | `react/components/Nodelets/Categories.js` | Sidebar nodelet UI (current memberships + built-in add modal) |
| `CreateCategory.js` | `react/components/Documents/CreateCategory.js` | Category creation form |
| `create_category.pm` | `ecore/Everything/Page/create_category.pm` | Creation page data |
| `AddToCategoryModal.js` | `react/components/AddToCategoryModal.js` | Add-to-category modal opened from `PageActions.js` |
| `Everything::API::category` | `ecore/Everything/API/category.pm` | Category REST backend (create/add/remove/list/reorder/update) |
| `Everything::Controller::category` | `ecore/Everything/Controller/category.pm` | Category page display/edit |

### Data Flow

1. **Nodelet display**: `buildNodeInfoStructure()` in `Application.pm` (gated on nodelet 1935779) queries the categories that *contain* the current node → `e2.nodeCategories` (+ `e2.currentNodeId`)
2. **Adding to category**: the nodelet's modal (or `AddToCategoryModal`) lazy-loads choices from `GET /api/category/list?node_id=X`, then `POST /api/category/add_member`
3. **Removing**: `POST /api/category/remove_member` (shown when `can_remove`)
4. **Creating category**: React form → `POST /api/category/create` (replaced `op=new`, #4340)

> **Backend note (current):** The legacy `categoryform` / `listnodecategories` / `showUserCategories` htmlcodes and the `op=category` opcode were **removed**. All category membership operations now go through `Everything::API::category` (`create`, `add_member`, `remove_member`, `reorder_members`, `list`, `node_categories`, `update`, `update_meta`, `lookup_owner`), driven from React.

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
// e2.nodeCategories (computed for all users, including guests)
[
  {
    node_id: 123456,
    title: "Best Science Fiction",
    author_user: 789,
    author_username: "coolnoder",
    is_public: 0,     // author_user == Guest User
    can_remove: 1     // editor, or owner/owning-usergroup member of a non-public category
  }
]
// e2.currentNodeId: current page's node_id
```

### Query (`Application::buildNodeInfoStructure`)

```sql
SELECT c.node_id, c.title, c.author_user, u.title AS author_username
FROM links l
JOIN node c ON l.from_node = c.node_id
LEFT JOIN node u ON c.author_user = u.node_id
WHERE l.to_node = $node_id AND l.linktype = <category linktype>
ORDER BY c.title
```

This returns the categories the current node is already in. Candidate categories to add to are *not* precomputed; they are lazy-loaded from `/api/category/list` when the add modal opens.

### UI

- Lists current categories, linked, with "by [author]" attribution and a remove button where `can_remove`
- "Add to category" opens a modal with search filter, grouped into your / public / (editors) other categories
- "Create new category" link to the create_category page

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

(The page also returns `error`/`mustLogin` for guests and `error`/`forbidden` for users with a `nodelock` row. It does not return `user_id`/`user_title`.)

### React Form: CreateCategory.js

Form fields:
- **Category Name**: Text input (max 255 chars)
- **Maintainer**: Dropdown (Me / Any Noder / Usergroups)
- **Description**: TipTap editor with Rich/HTML mode toggle (mode saved via `/api/preferences/set` `tiptap_editor_raw`)

Submit:
```javascript
// POST /api/category/create
{ title: categoryName, maintainer: maintainerId, doctext: description }
// → { success: 1, node_id, maintainer }  or  { success: 1, node_id, existing: 1 } if the title already exists
```

The API validates that the maintainer is the creator, Guest User ("Any Noder"), or a usergroup the creator belongs to, then redirects the browser to `/node/<node_id>`.

TinyMCE has been removed site-wide; `settings_useTinyMCE` is deprecated.

---

## Displaying Category Contents

### `GET /api/category/node_categories?node_id=X`

Returns the categories that contain a given node, each with `can_remove` permission info and prev/next navigation within the category (`_get_category_navigation`). React renders this list; the legacy `listnodecategories` htmlcode no longer exists.

---

## User Profile Integration

The user profile (`Everything::Controller::user`) lists categories from `Everything::Node::user::maintained_categories()` (own + usergroup categories, excluding public ones). The legacy `showUserCategories` htmlcode no longer exists.

### Node class: editable_categories

`Everything::Node::user::editable_categories()` returns categories a user can edit (currently has no callers outside `user.pm`; `/api/category/list` does its own query):
- Categories where user is author
- Categories where a usergroup they belong to is author
- Public categories (author = Guest User)

---

## Related Files

| File | Purpose |
|------|---------|
| `react/components/Nodelets/Categories.js` | Sidebar nodelet |
| `react/components/Documents/CreateCategory.js` | Creation form |
| `react/components/AddToCategoryModal.js` | Add-to-category modal (from `PageActions.js`) |
| `ecore/Everything/Controller/category.pm` | Category page display/edit |
| `ecore/Everything/Page/create_category.pm` | Creation page data |
| `ecore/Everything/API/category.pm` | Category REST backend (add/remove/list/reorder/meta) |
| `ecore/Everything/Node/user.pm` | `editable_categories` / `maintained_categories` |
| `ecore/Everything/Application.pm` (`buildNodeInfoStructure`) | Categories nodelet data |
| `nodepack/nodetype/category.xml` | Node type definition |
| `nodepack/linktype/category.xml` | Link type definition |

---

*Last verified: 2026-11-16 (nodelet now shows current memberships; creation via `/api/category/create`; description editor is TipTap — TinyMCE gone)*

# htmlpage.pm Burndown Plan

This document tracks the migration of functions from `Everything::Delegation::htmlpage` to proper Controller classes (and occasionally Page classes for special superdoc processing).

## Architecture Overview

### Controllers vs Pages

**Controllers** (`Everything::Controller::*`)
- Handle display/edit for node types (e.g., `writeup`, `e2node`, `nodetype`)
- Most htmlpage.pm functions become Controllers
- Populate `nodeinfo` (window.e2) with node-type-specific data
- React components render the data from `nodeinfo`
- Lightweight - just data preparation, no complex processing

**Pages** (`Everything::Page::*`)
- Only for superdoc-type nodes with special/complex processing
- Named after the specific superdoc (e.g., `settings`, `drafts`, `sign_up`)
- `buildReactData()` returns custom JSON for that specific page
- Used when the processing is page-specific, not type-generic

### Migration Target

`*_display_page` / `*_edit_page` functions → **Controller methods** (with React display components)
Special superdoc processing only → **Page classes**

### Data Flow

```
Controller → nodeinfo (window.e2) → React Component
   │
   └── Lightweight: extracts/formats node fields for display
```

## Categorization Criteria

1. **Target type** - Controller (most) vs Page (superdoc specials)
2. **Complexity** - Simple display vs complex edit workflows
3. **Usage** - Admin-only system nodes vs user-facing
4. **Elimination candidates** - Functions that can be refactored away entirely

## Categories

### Category 1: System Node Type Editors (Admin/Dev Only) → Controllers

These are display/edit pages for system node types. Admin-only, rarely change.
All become **Controller** methods that populate `nodeinfo`, with React components for display.

| Function | Node Type | React Component | Notes |
|----------|-----------|-----------------|-------|
| `container_display_page` | container | ContainerDisplay | Shows parent container + listcode |
| `container_edit_page` | container | ContainerEdit | Title, author, parent, context textarea |
| `document_display_page` | document | DocumentDisplay | Simple display with edit link |
| `document_edit_page` | document | DocumentEdit | Title, author, textarea |
| `htmlcode_display_page` | htmlcode | HtmlcodeDisplay | Shows code |
| `htmlcode_edit_page` | htmlcode | HtmlcodeEdit | Code editor |
| `htmlpage_display_page` | htmlpage | HtmlpageDisplay | Shows page content |
| `htmlpage_edit_page` | htmlpage | HtmlpageEdit | Page content editor |
| `nodetype_display_page` | nodetype | NodetypeDisplay | Complex - shows type settings |
| `nodetype_edit_page` | nodetype | NodetypeEdit | Type settings editor |
| `dbtable_display_page` | dbtable | DbtableDisplay | Shows table schema |
| `dbtable_edit_page` | dbtable | DbtableEdit | Table editor |
| `dbtable_index_page` | dbtable | DbtableIndex | Index view |
| `maintenance_display_page` | maintenance | MaintenanceDisplay | Maintenance node display |
| `maintenance_edit_page` | maintenance | MaintenanceEdit | Maintenance node editor |
| `setting_display_page` | setting | SettingDisplay | Settings display |
| `setting_edit_page` | setting | SettingEdit | Settings editor |
| `mail_display_page` | mail | MailDisplay | Mail display |
| `mail_edit_page` | mail | MailEdit | Mail editor |
| `nodelet_edit_page` | nodelet | NodeletEdit | Nodelet editor |
| `nodelet_viewcode_page` | nodelet | NodeletViewcode | View nodelet code |
| `nodegroup_display_page` | nodegroup | NodegroupDisplay | Nodegroup display |
| `nodegroup_edit_page` | nodegroup | NodegroupEdit | Nodegroup editor |
| `nodegroup_editor_page` | nodegroup | NodegroupEditor | Editor interface |
| `schema_edit_page` | schema | SchemaEdit | Schema editor |
| `edevdoc_display_page` | edevdoc | EdevdocDisplay | Edev doc display |
| `edevdoc_edit_page` | edevdoc | EdevdocEdit | Edev doc editor |
| `document_viewcode_page` | document | DocumentViewcode | View document code |
| `superdoc_viewcode_page` | superdoc | SuperdocViewcode | View superdoc code |
| `achievement_display_page` | achievement | AchievementDisplay | Achievement display |
| `achievement_edit_page` | achievement | AchievementEdit | Achievement editor |
| `notification_display_page` | notification | NotificationDisplay | Notification display |
| `notification_edit_page` | notification | NotificationEdit | Notification editor |
| `stylesheet_display_page` | stylesheet | StylesheetDisplay | CSS display |
| `stylesheet_view_page` | stylesheet | StylesheetView | View stylesheet |
| `stylesheet_serve_page` | stylesheet | (raw CSS) | Serve CSS file - no React |
| `e2client_display_page` | e2client | E2clientDisplay | Client display |
| `e2client_edit_page` | e2client | E2clientEdit | Client editor |
| `datastash_display_page` | datastash | DatastashDisplay | Datastash display |
| `datastash_edit_page` | datastash | DatastashEdit | Datastash editor |

### Category 2: Elimination Candidates (Refactor Away)

These functions can potentially be eliminated by refactoring the underlying systems.

| Function | Reason for Elimination |
|----------|----------------------|
| `mysqlproc_display_page` | Stored procedures are hard to maintain; refactor to Perl code |
| `mysqlproc_edit_page` | Same as above |

### Category 3: Core Node Operations (Generic)

Generic display/edit pages for base node functionality.

| Function | Notes |
|----------|-------|
| `node_display_page` | Generic node display |
| `node_edit_page` | Generic node edit |
| `node_basicedit_page` | Basic edit form |
| `node_editvars_page` | Wraps htmlcode("editvars") |
| `node_listnodelets_page` | Lists user's nodelets |
| `node_xml_page` | XML export |
| `node_xmltrue_page` | True XML export |
| `node_help_display_page` | Help display |
| `node_forward_display_page` | Node forward display |
| `node_forward_edit_page` | Node forward edit |

### Category 4: User-Facing Content Types → Controllers

These are visible to regular users. Higher priority. All become **Controller** methods.

| Function | Node Type | React Component | Priority | Notes |
|----------|-----------|-----------------|----------|-------|
| `superdoc_display_page` | superdoc | SuperdocDisplay | HIGH | Main superdoc renderer - dispatches to named superdocs |
| `superdoc_edit_page` | superdoc | SuperdocEdit | MED | Superdoc editor |
| `superdocnolinks_display_page` | superdocnolinks | SuperdocnolinksDisplay | HIGH | No-links variant |
| `fullpage_display_page` | fullpage | FullpageDisplay | HIGH | Full page display |
| `e2node_edit_page` | e2node | E2nodeEdit | MED | E2node editor |
| `e2node_xml_page` | e2node | (XML) | LOW | XML export - no React |
| `e2node_chaos_page` | e2node | E2nodeChaos | LOW | Chaos mode |
| `e2node_softlinks_page` | e2node | E2nodeSoftlinks | LOW | Softlinks view |
| `writeup_edit_page` | writeup | WriteupEdit | HIGH | Writeup editor - critical path |
| `writeup_xml_page` | writeup | (XML) | LOW | XML export - no React |
| `e2poll_display_page` | e2poll | E2pollDisplay | MED | Poll display |
| `e2poll_edit_page` | e2poll | E2pollEdit | MED | Poll editor |
| `usergroup_display_page` | usergroup | Usergroup | HIGH | Already has React component |
| `usergroup_edit_page` | usergroup | UsergroupEdit | MED | Usergroup editor |
| `room_display_page` | room | RoomDisplay | MED | Chat room display |
| `room_edit_page` | room | RoomEdit | LOW | Room editor |
| `registry_display_page` | registry | RegistryDisplay | MED | Registry display |
| `registry_edit_page` | registry | RegistryEdit | MED | Registry editor |
| `ticker_display_page` | ticker | TickerDisplay | LOW | Ticker display - already Controller |
| `plaindoc_display_page` | plaindoc | PlaindocDisplay | LOW | Plain doc display |

### Category 5: Collaboration/Debate System → Controllers

| Function | Node Type | React Component | Notes |
|----------|-----------|-----------------|-------|
| `collaboration_display_page` | collaboration | CollaborationDisplay | Complex - ~130 lines |
| `collaboration_useredit_page` | collaboration | CollaborationUseredit | User edit mode |
| `debatecomment_display_page` | debatecomment | DebatecommentDisplay | Comment display |
| `debatecomment_edit_page` | debatecomment | DebatecommentEdit | Comment editor |
| `debatecomment_replyto_page` | debatecomment | DebatecommentReply | Reply interface |
| `debatecomment_compact_page` | debatecomment | DebatecommentCompact | Compact view |
| `debatecomment_atom_page` | debatecomment | (Atom XML) | Atom feed - no React |

### Category 6: Media Types → Controllers

| Function | Node Type | React Component | Notes |
|----------|-----------|-----------------|-------|
| `podcast_display_page` | podcast | PodcastDisplay | Podcast display |
| `podcast_edit_page` | podcast | PodcastEdit | Podcast editor |
| `recording_display_page` | recording | RecordingDisplay | Recording display |
| `recording_edit_page` | recording | RecordingEdit | Recording editor |

### Category 7: Draft System → Controller (Exists)

| Function | Status | Notes |
|----------|--------|-------|
| `draft_edit_page` | ACTIVE | Draft editor - needs migration |
| `draft_restore_page` | ACTIVE | Restore deleted draft |
| `draft_linkview_page` | MIGRATED | Now in Controller::draft |

### Category 8: Special Display Modes

| Function | Target | Notes |
|----------|--------|-------|
| `ajax_update_page` | Keep in delegation | AJAX update handler - special case |
| `choose_theme_view_page` | Controller | Theme chooser - ~240 lines, complex |
| `document_linkview_page` | Controller | Link view mode |

## Migration Order Recommendation

### Phase 1: User-Facing Content Types (High Impact)

These are the most visible to users. Each gets a Controller + React component.

1. `superdoc_display_page` → Controller::superdoc + SuperdocDisplay.js
2. `fullpage_display_page` → Controller::fullpage + FullpageDisplay.js
3. `writeup_edit_page` → Controller::writeup + WriteupEdit.js
4. `usergroup_display_page` → Already has Controller, wire to existing Usergroup.js

### Phase 2: Content Editors
1. `e2node_edit_page` → Controller::e2node + E2nodeEdit.js
2. `e2poll_display_page` / `e2poll_edit_page` → Controller::e2poll + components
3. `room_display_page` → Controller::room + RoomDisplay.js
4. `registry_display_page` / `registry_edit_page` → Controller::registry + components

### Phase 3: Collaboration System
1. `collaboration_display_page` → Controller::collaboration + CollaborationDisplay.js
2. `debatecomment_*` functions → Controller::debatecomment + components

### Phase 4: System Node Type Editors (Admin)

Bulk migrate admin-only node type editors. Pattern:
- Create Controller::nodetype with display()/edit() methods
- Create lightweight React components for form rendering
- Many are thin wrappers around htmlcode() calls

Priority order:
1. `nodetype_*` - Most complex, foundational
2. `dbtable_*` - Database schema editing
3. `htmlcode_*`, `htmlpage_*` - Code editing
4. Remaining admin types in any order

### Phase 5: Elimination

1. Audit stored procedures in `mysqlproc` nodes
2. Refactor business logic to Perl (Application.pm methods)
3. Remove `mysqlproc_display_page` / `mysqlproc_edit_page`
4. Delete the mysqlproc nodetype if no longer needed

### Phase 6: Cleanup
- Generic node operations (`node_*` functions)
- XML exports (may keep as-is or eliminate)
- Special display modes (`ajax_update_page` stays in delegation)

## Function Counts by Category

| Category | Count | Target |
|----------|-------|--------|
| System Node Types (Admin) | 40 | Controller |
| User-Facing Content | 20 | Controller |
| Collaboration/Debate | 7 | Controller |
| Media Types | 4 | Controller |
| Draft System | 3 | Controller (partial) |
| Generic Node Ops | 10 | Controller |
| Elimination | 2 | Remove |
| Special/Keep | 2 | As-is |
| **Total** | **88** | |

## Notes

- Many functions just wrap `htmlcode()` calls - thin wrappers become thin Controllers
- Some have complex logic (e.g., `usergroup_display_page` ~200 lines, `choose_theme_view_page` ~240 lines)
- `superdoc_display_page` dispatches to named superdoc Page classes (existing pattern)
- XML exports may be candidates for elimination (assess usage)
- `ajax_update_page` is a special AJAX handler, keep in delegation

## Existing Controllers

These Controllers already exist and can be extended:

```
Controller::draft
Controller::e2node
Controller::fullpage
Controller::jsonexport
Controller::node
Controller::page
Controller::restricted_superdoc
Controller::superdoc
Controller::superdocnolinks
Controller::ticker
Controller::user
Controller::writeup
```

## Progress Tracking

| Date | Function | Status | Notes |
|------|----------|--------|-------|
| | | | |

---

Last Updated: 2026-01-01

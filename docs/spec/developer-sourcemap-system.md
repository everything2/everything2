# Developer Source Map System

**Purpose**: Link E2 pages to their source code components on GitHub
**Status**: Implemented and active
**Last verified**: 2026-11-16

---

## Overview

The Source Map system helps developers understand what code renders each page on Everything2. When viewing any node, developers can open a modal that shows:

- React components used to render the page
- Perl Page classes that provide data
- Test files for the components
- Direct links to view and edit on GitHub

This replaces the legacy "view code" pages that showed raw Perl source in the browser.

---

## Architecture

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `buildSourceMap()` | `ecore/Everything/Application.pm` | Generates source map data |
| `Developer` nodelet | `react/components/Nodelets/Developer.js` | UI with "View Source Map" button |
| `SourceMapModal` | `react/components/Developer/SourceMapModal.js` | Modal wrapper |
| `SourceMapDisplay` | `react/components/Developer/SourceMapDisplay.js` | Shared list renderer (icons, GitHub links); also used inline by system-node Documents (`Htmlcode`, `Htmlpage`, `Maintenance`, `Nodelet`, `Nodetype`, `Notification`, `Schema`, `Stylesheet`) |
| Per-type controllers | `ecore/Everything/Controller/{achievement,container,htmlcode,maintenance,nodelet,nodetype,notification,schema,stylesheet}.pm` | Build their own `sourceMap` for the inline display |

### Data Flow

1. **Server**: `Everything::Controller` calls `buildSourceMap($node->NODEDATA, undef)` (the `$page` arg is unused since htmlpages were retired, #4361)
2. **Data**: Source map passed via `developerNodelet.sourceMap` in page data
3. **React**: Developer nodelet renders "View Source Map" button
4. **Modal**: SourceMapModal → SourceMapDisplay renders components with GitHub links

---

## Source Map Data Structure

```javascript
{
  githubRepo: 'https://github.com/everything2/everything2',
  branch: 'master',
  commitHash: 'abc1234',  // Current deployed commit
  components: [
    {
      type: 'react_component',    // Component type
      name: 'Epicenter',          // Display name
      path: 'react/components/Nodelets/Epicenter.js',  // File path
      description: 'React component'
    },
    {
      type: 'test',
      name: 'Epicenter.test.js',
      path: 'react/components/Nodelets/Epicenter.test.js',
      description: 'Component tests'
    }
  ]
}
```

### Component Types

| Type | Icon | Description |
|------|------|-------------|
| `react_component` | Code icon (cyan) | React component file |
| `react_document` | Code icon (cyan) | React document component |
| `test` | Vial icon (green) | Test file |
| `page_class` | File icon (purple) | Perl Page class |
| `delegation` | File icon (purple) | Legacy delegation module |
| `node_class` | Cogs icon | `Everything::Node::*` class (emitted by per-type controllers) |
| `controller` | File icon | Controller class |
| `database_table` | Database icon | Nodepack XML for DB table |

Unknown types (e.g. `css_file`, emitted by `Controller/stylesheet.pm`) fall back to a book icon. Icon CSS classes are `source-map__icon--{react,test,perl,node,controller,database,default}`.

---

## Node Type Detection

`buildSourceMap()` detects the node type and generates appropriate source links:

### Nodelets

For `nodelet` nodes:
- React component: `react/components/Nodelets/{ComponentName}.js`
- Test file: `react/components/Nodelets/{ComponentName}.test.js`

### React Documents (superdocs)

For `superdoc`, `superdocnolinks`, `restricted_superdoc`, `oppressor_superdoc` and `fullpage` nodes with a Page class that has `buildReactData`:
- Page class: `ecore/Everything/Page/{page_name}.pm`
- React component: `react/components/Documents/{ComponentName}.js`

### Legacy Documents

For superdoc-family nodes with no Page class / no `buildReactData`, `buildSourceMap()` still emits a `delegation` entry pointing at `ecore/Everything/Delegation/document.pm` — **that file no longer exists**, so this link 404s on GitHub. (The htmlpage entry was removed with #4361.)

### System Nodes

For `maintenance` and `htmlcode` nodes (the `nodelet` test in this branch is unreachable — nodelets match the first branch):
- Controller: `ecore/Everything/Controller/{nodetype}.pm`
- React component: `react/components/Documents/SystemNode.js`
- Database tables: `nodepack/dbtable/{table}.xml`

---

## User Interface

### Developer Nodelet

The Developer nodelet (visible to edev members) includes:
- GitHub repository link
- Current commit hash link
- Architecture info
- Current node_id and type
- **View Source Map** button
- **Your $VARS** button (shows user variables)

### Source Map Modal

The modal displays:
1. **Header**: Node title
2. **Component list**: Each source file with:
   - Icon indicating type
   - Name and description
   - File path (monospace)
   - "View on GitHub" button (links to commit)
   - "Edit on GitHub" button (links to branch for PRs)
3. **Contribute callout**: Link to `blob/master/CONTRIBUTING.md` — note no `CONTRIBUTING.md` exists in the repo today, so this link is dead
4. **Close button**

---

## Access Control

`Everything::Controller` builds `developerNodelet` (and thus the source map) only when the user has the `developer` flag (edev) **and** the Developer nodelet (node 836984) is in their `nodelets` var. The data is not a security boundary — it only contains public GitHub paths.

---

## GitHub Links

### View Links

Links to the specific commit currently deployed:
```
https://github.com/everything2/everything2/blob/{commitHash}/{path}
```

This ensures developers see exactly the code running in production.

### Edit Links

Links to the master branch for creating PRs:
```
https://github.com/everything2/everything2/edit/master/{path}
```

---

## Helper Functions

### `titleToComponentName($title)`

Converts node titles to PascalCase component names:
- `"chatterbox"` → `"Chatterbox"`
- `"other users"` → `"OtherUsers"`
- `"wheel of surprise"` → `"WheelOfSurprise"`

### `titleToPageFile($title)`

Converts node titles to snake_case Page file names:
- `"Cool Archive"` → `"cool_archive"`
- `"E2 Editor Beta"` → `"e2_editor_beta"`

---

## Related Files

| File | Purpose |
|------|---------|
| `ecore/Everything/Application.pm` | `buildSourceMap()`, `titleToComponentName()`, `titleToPageFile()` (~lines 8597-8750) |
| `react/components/Developer/SourceMapDisplay.js` | Shared renderer |
| `react/components/Nodelets/Developer.js` | Developer nodelet with Source Map button |
| `react/components/Developer/SourceMapModal.js` | Modal component |
| `react/components/Developer/SourceMapModal.test.js` | Modal tests |
| `ecore/Everything/Controller.pm` | Passes sourceMap to Developer nodelet (~line 245) |

---

## Benefits

1. **Modern workflow**: Click → GitHub → Edit → PR
2. **Context-aware**: Shows exactly what files implement current page
3. **Educational**: New developers learn codebase structure
4. **Non-intrusive**: Only visible to developers via nodelet
5. **Accurate**: Links to deployed commit, not just master

---

*Last updated: December 2025; verified against code 2026-11-16*

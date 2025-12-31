# Developer Source Map System

**Purpose**: Link E2 pages to their source code components on GitHub
**Status**: Implemented and active

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
| `SourceMapModal` | `react/components/Developer/SourceMapModal.js` | Modal displaying source links |

### Data Flow

1. **Server**: `buildSourceMap($NODE, $page)` analyzes the current node
2. **Data**: Source map passed via `developerNodelet.sourceMap` in page data
3. **React**: Developer nodelet renders "View Source Map" button
4. **Modal**: SourceMapModal displays components with GitHub links

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
| `controller` | File icon (purple) | Controller class |
| `database_table` | File icon | Nodepack XML for DB table |

---

## Node Type Detection

`buildSourceMap()` detects the node type and generates appropriate source links:

### Nodelets

For `nodelet` nodes:
- React component: `react/components/Nodelets/{ComponentName}.js`
- Test file: `react/components/Nodelets/{ComponentName}.test.js`

### React Documents (superdocs)

For superdocs with a Page class that has `buildReactData`:
- Page class: `ecore/Everything/Page/{page_name}.pm`
- React component: `react/components/Documents/{ComponentName}.js`

### Legacy Documents

For superdocs using delegation:
- Delegation: `ecore/Everything/Delegation/document.pm`
- HTMLPage (if applicable): `ecore/Everything/Delegation/htmlpage.pm`

### System Nodes

For maintenance, htmlcode, htmlpage nodes:
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
3. **Contribute callout**: Link to CONTRIBUTING.md
4. **Close button**

---

## Access Control

The Developer nodelet (and thus Source Map) is only visible to:
- Members of the `edev` usergroup
- Uses standard nodelet visibility rules

The source map data is generated server-side in `buildSourceMap()` and included in the page data only when the Developer nodelet is rendered.

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
| `ecore/Everything/Application.pm` | `buildSourceMap()` implementation |
| `react/components/Nodelets/Developer.js` | Developer nodelet with Source Map button |
| `react/components/Developer/SourceMapModal.js` | Modal component |
| `react/components/Developer/SourceMapModal.test.js` | Modal tests |
| `ecore/Everything/Controller.pm` | Passes sourceMap to Developer nodelet |

---

## Benefits

1. **Modern workflow**: Click → GitHub → Edit → PR
2. **Context-aware**: Shows exactly what files implement current page
3. **Educational**: New developers learn codebase structure
4. **Non-intrusive**: Only visible to developers via nodelet
5. **Accurate**: Links to deployed commit, not just master

---

*Last updated: December 2025*

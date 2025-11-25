# Unified Writeup Display Component

**Created**: 2025-11-24
**Purpose**: Standardize writeup/node display across multiple nodelets

## Overview

The `WriteupEntry` component provides a unified, consistent way to display writeups and nodes across all nodelets that show content listings. This eliminates code duplication and ensures a consistent look and feel throughout the application.

## Component Location

[react/components/WriteupEntry.js](../react/components/WriteupEntry.js)

## Display Modes

The component supports three display modes to accommodate different use cases:

### Full Mode (`mode="full"`)
**Used by**: NewWriteups, NewLogs

Shows complete information:
- Parent e2node title (if available)
- Writeup type (e.g., "idea", "person", "thing")
- Author byline
- Optional metadata
- Editor controls (hide/show writeup)
- Vote status indicator

**Example output:**
```
[Everything2] (idea) by username
```

### Standard Mode (`mode="standard"`)
**Used by**: NeglectedDrafts

Shows title, author, and metadata:
- Node title
- Author byline
- Custom metadata (e.g., "[3 days]")

**Example output:**
```
My Draft Title by username [3 days]
```

### Simple Mode (`mode="simple"`)
**Used by**: UsergroupWriteups, RecentNodes

Shows only the title:
- Node title (linked)
- No additional information

**Example output:**
```
My Node Title
```

## Usage Examples

### NewWriteups / NewLogs (Full Mode)
```jsx
<WriteupEntry
  entry={writeup}
  mode="full"
  editor={user.isEditor}
  editorHideWriteupChange={handleHide}
/>
```

### NeglectedDrafts (Standard Mode with Metadata)
```jsx
<WriteupEntry
  entry={draft}
  mode="standard"
  metadata={<span className="days"> [{draft.days} days]</span>}
/>
```

### UsergroupWriteups / RecentNodes (Simple Mode)
```jsx
<WriteupEntry
  entry={node}
  mode="simple"
  className=""
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `entry` | object | **required** | Node/writeup data object |
| `mode` | string | `'full'` | Display mode: `'full'`, `'standard'`, or `'simple'` |
| `showParent` | boolean | auto | Override: show parent e2node |
| `showAuthor` | boolean | auto | Override: show author byline |
| `showType` | boolean | auto | Override: show writeup type |
| `showMetadata` | boolean | auto | Override: show metadata |
| `metadata` | node | `null` | Custom metadata element/string |
| `editor` | boolean | `false` | Enable editor controls |
| `editorHideWriteupChange` | function | `null` | Handler for editor hide/show |
| `className` | string | `'contentinfo'` | CSS class for `<li>` element |
| `customContent` | node | `null` | Additional custom content |

## Entry Data Structure

The `entry` object should contain:

```javascript
{
  node_id: number,          // Required
  title: string,            // Required
  parent: {                 // Optional (for writeups)
    title: string,
    node_id: number
  },
  author: {                 // Optional
    title: string,
    node_id: number
  },
  writeuptype: string,      // Optional (e.g., "idea", "person")
  hasvoted: boolean,        // Optional (adds 'hasvoted' CSS class)
  // ... additional fields as needed
}
```

## Migration Summary

### Before (Multiple Components)
- `NewWriteupsEntry.js` - 32 lines, used by NewWriteups and NewLogs
- Inline `<li>` elements in UsergroupWriteups
- Inline `<li>` elements in RecentNodes
- Custom rendering in NeglectedDrafts

### After (Unified Component)
- `WriteupEntry.js` - 134 lines, used by all 5 nodelets
- Consistent styling and behavior
- Reduced code duplication
- Easier to maintain and enhance

## Benefits

1. **Consistency**: All nodelets display content in a predictable, uniform way
2. **Maintainability**: Single source of truth for writeup display logic
3. **Flexibility**: Three modes accommodate different use cases
4. **Extensibility**: Easy to add new features (e.g., metadata, custom content)
5. **Testing**: Easier to test a single component than multiple implementations

## CSS Classes

The component uses standard E2 CSS classes:
- `contentinfo` - Full writeup info display (default)
- `hasvoted` - Added when user has voted on the writeup
- `title` - Applied to title links
- `author` - Applied to author links
- `type` - Applied to writeup type display
- `metadata` - Applied to metadata display

## Nodelets Using WriteupEntry

| Nodelet | Mode | Features |
|---------|------|----------|
| **NewWriteups** | `full` | Editor controls, vote indicators, type |
| **NewLogs** | `full` | Vote indicators, type |
| **UsergroupWriteups** | `simple` | Title only |
| **RecentNodes** | `simple` | Title only, numbered list |
| **NeglectedDrafts** | `standard` | Title, author, days metadata |

## Future Enhancements

Potential improvements:
- Add timestamp display option
- Add vote count display
- Add reputation/XP indicators
- Add thumbnail images
- Add excerpt/preview text
- Implement React.memo for performance

## Related Components

- [LinkNode.js](../react/components/LinkNode.js) - Used for all links
- [EditorHideWriteup.js](../react/components/EditorHideWriteup.js) - Editor controls
- [NodeletContainer.js](../react/components/NodeletContainer.js) - Wrapper for nodelets

---

*For questions or updates, see [CLAUDE.md](../CLAUDE.md)*

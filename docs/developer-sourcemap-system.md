# Developer Source Map System

**Date**: 2025-11-26
**Purpose**: Replace legacy code viewing pages with modern GitHub-linked developer tooling
**Status**: Design Document

---

## Problem Statement

### Legacy Pattern (Obsolete)
- **Code viewing pages**: `*_viewcode`, `htmlcode_display_page`, etc.
- Display Perl source code through web UI
- Copy-paste to edit → GitHub PR workflow
- Out of place, confusing UX (viewing system node shows implementation)
- **Example**: Visit "Epicenter" display page → shows Perl code instead of nodelet

### Modern Pattern (Proposed)
- **Developer icon/modal**: Floating dev tools for authorized users
- Links to GitHub source files
- Shows component hierarchy
- Maps page → implementation components
- **Example**: Visit "Epicenter" display page → dev icon → modal with links to:
  - `react/components/Nodelets/Epicenter.js` (component)
  - `react/components/Nodelets/Epicenter.test.js` (tests)
  - `ecore/Everything/Controller.pm` (data loading)
  - GitHub PR link to edit

---

## Architecture

### Source Map Data Structure

Store mapping in `window.e2.sourceMap` (development only):

```javascript
{
  pageType: 'nodelet',           // 'nodelet', 'document', 'page', 'htmlpage'
  pageName: 'Epicenter',         // Human-readable name
  components: [
    {
      type: 'react',
      file: 'react/components/Nodelets/Epicenter.js',
      lines: null,              // Optional line range [start, end]
      description: 'Main React component'
    },
    {
      type: 'test',
      file: 'react/components/Nodelets/Epicenter.test.js',
      lines: null,
      description: 'Component tests'
    },
    {
      type: 'perl',
      file: 'ecore/Everything/Controller.pm',
      lines: [85, 95],          // Specific method location
      description: 'Data loading (epicenter method)'
    },
    {
      type: 'api',
      file: 'ecore/Everything/API/coolnodes.pm',
      lines: null,
      description: 'Cool nodes API endpoint'
    }
  ],
  githubRepo: 'everything2/everything2',
  githubBranch: 'master'
}
```

### Backend Integration

#### Controller.pm Addition

```perl
# In Everything::Controller::display
sub display {
  my ($self, $REQUEST, $node) = @_;

  # ... existing code ...

  # Add source map for developers (development mode only)
  if ($ENV{E2_ENV} eq 'development' && $REQUEST->user->is_developer) {
    $e2->{sourceMap} = $self->buildSourceMap($node, $REQUEST);
  }

  # ... rest of display logic ...
}

sub buildSourceMap {
  my ($self, $node, $REQUEST) = @_;

  my $type = $node->type->{title};
  my $name = $node->title;

  # Map node types to source files
  my $components = [];

  if ($type eq 'nodelet') {
    push @$components, {
      type => 'react',
      file => "react/components/Nodelets/${name}.js",
      description => 'React component'
    };
    push @$components, {
      type => 'test',
      file => "react/components/Nodelets/${name}.test.js",
      description => 'Component tests'
    };
    push @$components, {
      type => 'perl',
      file => 'ecore/Everything/Controller.pm',
      lines => $self->findMethodLines($name),  # Helper to locate method
      description => "Data loading (${name} method)"
    };
  } elsif ($type eq 'document' || $type eq 'superdoc') {
    my $page_class = "Everything::Page::" . $self->titleToClass($name);
    if ($page_class->can('buildReactData')) {
      # React-migrated document
      push @$components, {
        type => 'react',
        file => "react/components/Documents/" . $self->titleToComponent($name) . ".js",
        description => 'React document component'
      };
      push @$components, {
        type => 'perl',
        file => "ecore/Everything/Page/" . $self->titleToClass($name) . ".pm",
        description => 'Page class (data loading)'
      };
    } else {
      # Legacy Mason/delegation
      push @$components, {
        type => 'perl',
        file => 'ecore/Everything/Delegation/document.pm',
        lines => $self->findDelegationLines($name),
        description => 'Delegation function'
      };
    }
  }

  return {
    pageType => $type,
    pageName => $name,
    components => $components,
    githubRepo => 'everything2/everything2',
    githubBranch => 'master'
  };
}
```

### Frontend Component

#### DevTools.js - Floating Developer Icon

```javascript
// react/components/DevTools.js
import React, { useState } from 'react';
import SourceMapModal from './SourceMapModal';

const DevTools = ({ sourceMap, user }) => {
  const [showModal, setShowModal] = useState(false);

  // Only show for developers in development mode
  if (!sourceMap || !user?.developer) return null;

  return (
    <>
      {/* Floating dev icon - bottom right corner */}
      <div
        className="dev-tools-icon"
        onClick={() => setShowModal(true)}
        style={{
          position: 'fixed',
          bottom: '20px',
          right: '20px',
          width: '50px',
          height: '50px',
          backgroundColor: '#667eea',
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
          boxShadow: '0 4px 6px rgba(0,0,0,0.3)',
          zIndex: 9999,
          transition: 'transform 0.2s',
        }}
        onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.1)'}
        onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
        title="Developer Source Map"
      >
        <svg width="24" height="24" viewBox="0 0 24 24" fill="white">
          <path d="M8 3L4 7l4 4M16 3l4 4-4 4M12 3v18" stroke="currentColor" strokeWidth="2" />
        </svg>
      </div>

      {/* Modal */}
      {showModal && (
        <SourceMapModal
          sourceMap={sourceMap}
          onClose={() => setShowModal(false)}
        />
      )}
    </>
  );
};

export default DevTools;
```

#### SourceMapModal.js - Source Code Links

```javascript
// react/components/SourceMapModal.js
import React from 'react';

const SourceMapModal = ({ sourceMap, onClose }) => {
  const { pageType, pageName, components, githubRepo, githubBranch } = sourceMap;

  const getGitHubUrl = (component) => {
    const baseUrl = `https://github.com/${githubRepo}/blob/${githubBranch}`;

    if (component.lines) {
      // Link to specific line range
      const [start, end] = component.lines;
      return `${baseUrl}/${component.file}#L${start}-L${end}`;
    }

    return `${baseUrl}/${component.file}`;
  };

  const getIconForType = (type) => {
    switch (type) {
      case 'react': return '⚛️';
      case 'test': return '🧪';
      case 'perl': return '🐪';
      case 'api': return '🔌';
      default: return '📄';
    }
  };

  const getEditUrl = (component) => {
    // Direct GitHub edit link
    const baseUrl = `https://github.com/${githubRepo}/edit/${githubBranch}`;
    return `${baseUrl}/${component.file}`;
  };

  return (
    <div
      className="source-map-modal-overlay"
      onClick={onClose}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0,0,0,0.7)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 10000,
      }}
    >
      <div
        className="source-map-modal"
        onClick={(e) => e.stopPropagation()}
        style={{
          backgroundColor: 'white',
          borderRadius: '8px',
          padding: '24px',
          maxWidth: '600px',
          width: '90%',
          maxHeight: '80vh',
          overflow: 'auto',
          boxShadow: '0 10px 25px rgba(0,0,0,0.3)',
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '20px' }}>
          <div>
            <h2 style={{ margin: 0, marginBottom: '8px' }}>
              {pageName}
            </h2>
            <p style={{ margin: 0, color: '#666', fontSize: '14px' }}>
              {pageType} • {components.length} component{components.length !== 1 ? 's' : ''}
            </p>
          </div>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#999',
            }}
          >
            ×
          </button>
        </div>

        <div style={{ marginBottom: '24px' }}>
          <h3 style={{ fontSize: '14px', fontWeight: '600', marginBottom: '12px', color: '#666' }}>
            SOURCE FILES
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {components.map((component, index) => (
              <div
                key={index}
                style={{
                  border: '1px solid #e0e0e0',
                  borderRadius: '6px',
                  padding: '12px',
                  backgroundColor: '#f9f9f9',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', marginBottom: '8px' }}>
                  <span style={{ fontSize: '20px', marginRight: '8px' }}>
                    {getIconForType(component.type)}
                  </span>
                  <span style={{ fontSize: '14px', fontWeight: '600' }}>
                    {component.description}
                  </span>
                </div>
                <div style={{ fontSize: '12px', fontFamily: 'monospace', color: '#666', marginBottom: '8px' }}>
                  {component.file}
                  {component.lines && (
                    <span style={{ marginLeft: '8px', color: '#999' }}>
                      (lines {component.lines[0]}-{component.lines[1]})
                    </span>
                  )}
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <a
                    href={getGitHubUrl(component)}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      fontSize: '12px',
                      color: '#667eea',
                      textDecoration: 'none',
                      fontWeight: '500',
                    }}
                  >
                    View on GitHub →
                  </a>
                  <a
                    href={getEditUrl(component)}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      fontSize: '12px',
                      color: '#28a745',
                      textDecoration: 'none',
                      fontWeight: '500',
                    }}
                  >
                    Edit on GitHub →
                  </a>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ paddingTop: '16px', borderTop: '1px solid #e0e0e0' }}>
          <h3 style={{ fontSize: '14px', fontWeight: '600', marginBottom: '12px', color: '#666' }}>
            QUICK ACTIONS
          </h3>
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            <a
              href={`https://github.com/${githubRepo}/compare/${githubBranch}...${githubBranch}?expand=1`}
              target="_blank"
              rel="noopener noreferrer"
              style={{
                fontSize: '12px',
                padding: '8px 12px',
                backgroundColor: '#667eea',
                color: 'white',
                textDecoration: 'none',
                borderRadius: '4px',
                fontWeight: '500',
              }}
            >
              Create Pull Request
            </a>
            <a
              href={`https://github.com/${githubRepo}/issues/new`}
              target="_blank"
              rel="noopener noreferrer"
              style={{
                fontSize: '12px',
                padding: '8px 12px',
                backgroundColor: '#28a745',
                color: 'white',
                textDecoration: 'none',
                borderRadius: '4px',
                fontWeight: '500',
              }}
            >
              Report Issue
            </a>
            <a
              href={`https://github.com/${githubRepo}`}
              target="_blank"
              rel="noopener noreferrer"
              style={{
                fontSize: '12px',
                padding: '8px 12px',
                backgroundColor: '#6c757d',
                color: 'white',
                textDecoration: 'none',
                borderRadius: '4px',
                fontWeight: '500',
              }}
            >
              View Repository
            </a>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SourceMapModal;
```

#### Integration with E2ReactRoot

```javascript
// react/components/E2ReactRoot.js
import DevTools from './DevTools';

class E2ReactRoot extends React.Component {
  render() {
    const { sourceMap, user } = this.props.e2;

    return (
      <div>
        {/* Existing nodelet rendering */}
        {this.renderNodelets()}

        {/* Developer tools - only in development */}
        <DevTools sourceMap={sourceMap} user={user} />
      </div>
    );
  }
}
```

---

## Examples

### Example 1: Nodelet (Epicenter)

**User visits**: `/node/nodelet/Epicenter`

**Developer sees**:
- Floating 🔧 icon (bottom right)
- Click → Modal opens:

```
Epicenter
nodelet • 3 components

SOURCE FILES

⚛️ React component
   react/components/Nodelets/Epicenter.js
   View on GitHub → | Edit on GitHub →

🧪 Component tests
   react/components/Nodelets/Epicenter.test.js
   View on GitHub → | Edit on GitHub →

🐪 Data loading (epicenter method)
   ecore/Everything/Controller.pm (lines 85-95)
   View on GitHub → | Edit on GitHub →

QUICK ACTIONS
[Create Pull Request] [Report Issue] [View Repository]
```

### Example 2: React-Migrated Document (what_to_do_if_e2_goes_down)

**User visits**: `/title/what_to_do_if_e2_goes_down`

**Developer sees**:

```
what_to_do_if_e2_goes_down
superdoc • 3 components

SOURCE FILES

⚛️ React document component
   react/components/Documents/WhatToDoIfE2GoesDown.js
   View on GitHub → | Edit on GitHub →

🧪 Component tests
   react/components/Documents/WhatToDoIfE2GoesDown.test.js
   View on GitHub → | Edit on GitHub →

🐪 Page class (data loading)
   ecore/Everything/Page/what_to_do_if_e2_goes_down.pm
   View on GitHub → | Edit on GitHub →
```

### Example 3: Legacy Delegation Document

**User visits**: `/title/cool_archive`

**Developer sees**:

```
cool_archive
superdoc • 1 component

SOURCE FILES

🐪 Delegation function
   ecore/Everything/Delegation/document.pm (lines 1234-1456)
   View on GitHub → | Edit on GitHub →

⚠️ Note: This document uses legacy delegation.
Consider migrating to React (Everything::Page pattern).
```

---

## Implementation Plan

### Phase 1: Backend Source Map Generation (Week 1)
- ✅ Add `buildSourceMap()` to Controller.pm
- ✅ Add `titleToClass()` and `titleToComponent()` helpers
- ✅ Add `findMethodLines()` helper (parse source files for method locations)
- ✅ Wire into display() method (development mode only)
- ✅ Add to `window.e2.sourceMap` in zen.mc

### Phase 2: Frontend DevTools Component (Week 2)
- ✅ Create DevTools.js floating icon
- ✅ Create SourceMapModal.js
- ✅ Integrate with E2ReactRoot
- ✅ Add CSS for modal styling
- ✅ Test with various node types

### Phase 3: Enhanced Mapping (Week 3)
- ✅ Add API endpoint mapping
- ✅ Add test file detection
- ✅ Add documentation links
- ✅ Add "View in VS Code" links (for local dev)

### Phase 4: Delete Obsolete Code Viewing Pages (Week 4)
- ✅ Remove `*_viewcode` functions from htmlpage.pm
- ✅ Remove `htmlcode_display_page` code viewing
- ✅ Remove database htmlpage records
- ✅ Update routing to 404 on old URLs
- ✅ Add redirect to new dev tools

---

## Configuration

### Environment Variables

```bash
# .env (development)
E2_ENV=development
E2_GITHUB_REPO=everything2/everything2
E2_GITHUB_BRANCH=master

# .env (production)
E2_ENV=production
# Source map disabled in production
```

### User Permissions

```perl
# Only show dev tools to developers
sub shouldShowDevTools {
  my ($self, $USER) = @_;

  return 0 if $ENV{E2_ENV} ne 'development';
  return 0 if $self->isGuest($USER);
  return $USER->{developer} ? 1 : 0;
}
```

---

## Advanced Features (Future)

### Local Development Links

For developers running E2 locally, add "Open in VS Code" links:

```javascript
const getVSCodeUrl = (component) => {
  // vscode://file/path/to/file:line
  return `vscode://file/${process.env.E2_LOCAL_PATH}/${component.file}:${component.lines?.[0] || 1}`;
};
```

### Component Dependency Graph

Show what components depend on each other:

```javascript
dependencies: [
  {
    file: 'react/components/Nodelets/Epicenter.js',
    imports: [
      'react/components/LinkNode.js',
      'react/components/NodeletContainer.js',
      'react/hooks/usePolling.js'
    ]
  }
]
```

### Performance Metrics

Show component render times:

```javascript
performance: {
  serverTime: '45ms',     // buildReactData() execution
  renderTime: '12ms',     // React component render
  apiCalls: 2,            // Number of API endpoints hit
  cacheHits: 3            // DataStash cache hits
}
```

### Documentation Links

Auto-link to relevant documentation:

```javascript
documentation: [
  {
    title: 'Nodelet Migration Guide',
    url: '/docs/nodelet-migration-status.md'
  },
  {
    title: 'React Component Patterns',
    url: '/docs/react-migration-strategy.md'
  }
]
```

---

## Benefits

### Developer Experience
- ✅ **Modern workflow**: Click → GitHub → Edit → PR
- ✅ **Context-aware**: Shows exactly what files implement current page
- ✅ **Educational**: New developers learn codebase structure
- ✅ **Non-intrusive**: Floating icon, hidden for non-developers

### Codebase Cleanup
- ✅ **Delete ~20 obsolete code viewing functions**
- ✅ **Remove confusing "view source" UX**
- ✅ **Simplify htmlpage delegation**
- ✅ **Reduce database records**

### Maintainability
- ✅ **Single source of truth**: Source map in code, not database
- ✅ **Self-documenting**: Component hierarchy visible
- ✅ **Migration tracking**: Easy to see what's React vs legacy
- ✅ **Testing**: Links to test files encourage test writing

---

## Comparison: Old vs New

| Aspect | Old Pattern (Code Viewing) | New Pattern (Source Map) |
|--------|---------------------------|--------------------------|
| **Discovery** | Visit system node, see code dump | Click dev icon, see component list |
| **Editing** | Copy code, paste elsewhere, PR | Click "Edit on GitHub", PR directly |
| **Context** | Just see code, no structure | See component hierarchy |
| **Navigation** | Search through code dump | Direct links to files + line numbers |
| **Testing** | No link to tests | Direct link to test files |
| **Documentation** | No context | Can add doc links |
| **UX** | Confusing (shows code on page) | Clean (modal, opt-in) |
| **Access** | Anyone can view | Developers only |
| **Maintenance** | Perl delegation functions | React component + data |

---

## Migration from Old System

### Step 1: Identify Obsolete Functions

```bash
# Find all code viewing functions
grep -n "_viewcode\|_display_page.*code\|viewcode" ecore/Everything/Delegation/htmlpage.pm

# Expected ~20 functions to remove:
# - htmlcode_display_page
# - htmlcode_viewcode
# - container_viewcode
# - nodelet_viewcode
# - document_viewcode
# - etc.
```

### Step 2: Add Deprecation Warning

Before deleting, add warning to old pages:

```perl
sub htmlcode_display_page {
  my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

  return qq|
    <div style="padding: 20px; background: #fff3cd; border: 1px solid #ffc107;">
      <h3>⚠️ Deprecated: Code Viewing Pages</h3>
      <p>This page is obsolete. Code editing now happens via GitHub PRs.</p>
      <p>Developers: Use the dev tools icon (bottom right) to view source files.</p>
    </div>
  |;
}
```

### Step 3: Deploy Source Map System

- Deploy backend changes (Controller.pm)
- Deploy frontend changes (DevTools.js)
- Test with developers
- Collect feedback

### Step 4: Remove Old System

- Delete obsolete functions from htmlpage.pm
- Delete database htmlpage records
- Update routing (404 on old URLs)
- Document migration in changelog

---

## Success Metrics

### Adoption
- ✅ 80%+ of developers use dev tools in first month
- ✅ Feedback: "Easier to find code" rating > 4/5
- ✅ Reduced Slack questions: "Where is the code for X?"

### Code Quality
- ✅ 20+ obsolete functions deleted
- ✅ Codebase 5-10% smaller
- ✅ Zero functionality regressions

### Developer Velocity
- ✅ Reduced time to first edit: 10min → 2min
- ✅ Increased PR submissions from new contributors
- ✅ Faster onboarding for new developers

---

## Conclusion

The source map system replaces obsolete code viewing pages with a modern, GitHub-integrated developer experience. It:

1. **Eliminates ~20 obsolete htmlpage functions**
2. **Provides better developer UX** (modal with links vs code dump)
3. **Encourages GitHub workflow** (direct edit links)
4. **Self-documents codebase structure** (component hierarchy)
5. **Enables future enhancements** (dependency graphs, performance metrics)

**Estimated Effort**: 3-4 weeks
**Impact**: High (developer experience) + Medium (codebase cleanup)
**Risk**: Low (opt-in feature, doesn't affect users)

**Recommendation**: Implement after Phase 4a complete (document migrations), before Phase 4b (htmlcode extraction). This establishes the pattern for how developers discover and edit code going forward.

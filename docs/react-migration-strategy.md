# React Migration Strategy: Progressive React Adoption

**React Version**: 18.3.x (pinned until Mason2 elimination complete)
**Migration Status**: Phase 1 - Nodelet migration (9/~15 complete, expanding)
**Last Updated**: 2025-11-20
**Current Focus**: ReadThis nodelet → first new nodelet migration using established patterns

## Executive Summary

This document outlines Everything2's progressive strategy for adopting React across the application, starting with nodelets (sidebar components) and eventually expanding to page content where beneficial. The migration builds on existing React infrastructure.

**Important**: This migration will be completed on **React 18.3.x**. React 19 upgrade is deferred until Q3 2025 as a separate, focused task after Mason2 elimination is complete. See [react-19-migration.md](react-19-migration.md) for details.

**Key Insights**:
- **Not all pages use Mason2**: Some pages (JSON APIs, XML tickers, document functions) bypass Mason entirely
- **React adoption is selective**: Focus on components where React provides clear UX/maintainability benefits
- **Portal architecture works**: Current React nodelets use Portals to render into Mason-generated DOM
- **Progressive enhancement**: New React components added incrementally without disrupting existing functionality

## Current Architecture Analysis

### Existing Rendering Pipeline

**Mason2 Flow (Current):**
```
HTTP Request
  → Everything::HTML::displayPage()
  → Everything::HTMLRouter::route_node()
  → Everything::Controller::display()
  → Page Object display() returns HashRef
  → Everything::Controller::layout() spreads HashRef to Mason
  → Mason::run("/pages/template.mc", params)
  → HTML Output
```

**Key Files:**
- [ecore/Everything/Page.pm](ecore/Everything/Page.pm) - Base page class
- [ecore/Everything/Controller.pm:24-94](ecore/Everything/Controller.pm#L24-L94) - layout() method
- [ecore/Everything/Controller/superdoc.pm:6-24](ecore/Everything/Controller/superdoc.pm#L6-L24) - Page controller
- [templates/zen.mc](templates/zen.mc) - Main layout template
- [templates/pages/*.mc](templates/pages/) - Individual page templates

### Existing React Integration

**Current React Usage:**
- **Purpose**: Nodelets (sidebar components) only
- **Architecture**: React Portals rendering into Mason-generated DOM
- **Entry Point**: [react/index.js](react/index.js) → renders into `<div id='e2-react-root'>`
- **Data Flow**: Perl → JSON (nodeinfojson) → global `window.e2` object → React state
- **Components**: 27 React components in [react/components/](react/components/)

**Current Data Structure (window.e2):**
```javascript
{
  node: {node_id, title, type, createtime},
  user: {node_id, title, admin, editor, developer, guest},
  display_prefs: {vit_hidemaintenance, num_newwus, ...},
  newWriteups: [...],
  coolnodes: [...],
  staffpicks: [...],
  randomNodes: [...],
  developerNodelet: {page: {}, news: {}},
  collapsedNodelets: "...",
  lastCommit: "...",
  architecture: "..."
}
```

Built in [ecore/Everything/Application.pm:4628-4720](ecore/Everything/Application.pm#L4628-L4720) `buildNodeInfoStructure()`

### Current React Nodelets (Phase 1 - In Progress)

**Completed React Nodelets** (9 of ~15 total):

1. **Vitals** ([react/components/Nodelets/Vitals.js](../react/components/Nodelets/Vitals.js))
   - Node maintenance tools, XP display, level progress
   - Multiple collapsible sections (Maintenance, Node Info, Lists, Utilities, Misc)
   - Uses NodeletSection for section management

2. **Developer** ([react/components/Nodelets/Developer.js](../react/components/Nodelets/Developer.js))
   - Developer tools and news for contributors
   - Two sections: Utility and Everything Development
   - Conditional rendering based on user.developer flag

3. **NewWriteups** ([react/components/Nodelets/NewWriteups.js](../react/components/Nodelets/NewWriteups.js))
   - Real-time new writeups feed
   - Filtering controls (show/hide junk, count selection)
   - Uses NewWriteupsEntry and NewWriteupsFilter components
   - State management for filter preferences

4. **RecommendedReading** ([react/components/Nodelets/RecommendedReading.js](../react/components/Nodelets/RecommendedReading.js))
   - Cool Archive user picks
   - Page of Cool editor selections
   - Similar structure to what ReadThis should be

5. **NewLogs** ([react/components/Nodelets/NewLogs.js](../react/components/Nodelets/NewLogs.js))
   - System logs and admin messages
   - Conditional rendering based on log availability

6. **RandomNodes** ([react/components/Nodelets/RandomNodes.js](../react/components/Nodelets/RandomNodes.js))
   - Random node recommendations
   - Randomized phrase header for variety

7. **SignIn** ([react/components/Nodelets/SignIn.js](../react/components/Nodelets/SignIn.js))
   - Guest user sign-in form
   - Only shown when user.guest is true

8. **NeglectedDrafts** ([react/components/Nodelets/NeglectedDrafts.js](../react/components/Nodelets/NeglectedDrafts.js))
   - Draft management for writers
   - Conditional rendering based on draft availability

9. **QuickReference** ([react/components/Nodelets/QuickReference.js](../react/components/Nodelets/QuickReference.js))
   - Help links and quick access tools

**Nodelet Architecture Pattern**:

Each React nodelet follows this established pattern:

```javascript
// 1. Nodelet Component (react/components/Nodelets/Example.js)
import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'

const Example = (props) => {
  return (
    <NodeletContainer
      title="Example Nodelet"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {/* Nodelet content here */}
    </NodeletContainer>
  )
}

export default Example
```

```javascript
// 2. Portal Component (react/components/Portals/ExamplePortal.js)
import React from 'react'
import ReactDOM from 'react-dom'
import Example from '../Nodelets/Example'

const ExamplePortal = (props) => {
  const targetElement = document.getElementById('example')
  if (!targetElement) return null

  return ReactDOM.createPortal(
    <Example {...props} />,
    targetElement
  )
}

export default ExamplePortal
```

```javascript
// 3. Integration in E2ReactRoot (react/components/E2ReactRoot.js)
import ExamplePortal from './Portals/ExamplePortal'
import Example from './Nodelets/Example'

// In render():
<ExamplePortal
  showNodelet={(event) => this.showNodelet(event, 'example')}
  nodeletIsOpen={this.state.example_show}
  // ... pass data props
/>
```

**Next Nodelet to Migrate**: ReadThis ([ecore/Everything/Delegation/nodelet.pm:632-648](../ecore/Everything/Delegation/nodelet.pm#L632-L648))
- Currently renders three NodeletSections: Cool Writeups, Editor Selections, News
- Similar to RecommendedReading but with News section
- Good candidate for demonstrating the migration pattern

## Polling and Real-Time Updates

React nodelets implement intelligent polling to provide real-time updates while respecting server resources and user activity states. The polling system uses three-tier activity detection and page visibility management.

### Activity Detection System

**Three Activity States** ([react/hooks/useActivityDetection.js](../react/hooks/useActivityDetection.js)):

1. **Recently Active** (< 60 seconds since last activity)
   - User has interacted with page within last minute
   - Enables fastest polling rates
   - Triggered by mouse movement, clicks, keypresses, scrolling

2. **Idle** (60 seconds - 10 minutes since last activity)
   - User present but not actively interacting
   - Enables slower polling rates
   - Still updates content but less frequently

3. **Asleep** (10+ minutes since last activity)
   - User considered away from desk
   - Polling stops completely
   - Resumes immediately when activity detected

**Multi-Tab Detection**:
- Cookie-based active window tracking
- Only the focused browser tab polls the server
- Background tabs pause polling to avoid duplicate requests
- Uses `visibilitychange` event to detect tab switching

**Implementation Example**:
```javascript
import { useActivityDetection } from '../../hooks/useActivityDetection'

const MyNodelet = (props) => {
  const { isActive, isRecentlyActive, isMultiTabActive } = useActivityDetection(10)

  // isActive: false if 10+ minutes idle (asleep)
  // isRecentlyActive: false if 60+ seconds idle
  // isMultiTabActive: false if page not in focus
}
```

### Polling Patterns by Nodelet

**Chatterbox** - Adaptive Dual-Rate Polling ([react/hooks/useChatterPolling.js](../react/hooks/useChatterPolling.js)):
```javascript
// Polls at 45s when recently active, 2m when idle, stops when asleep/unfocused
export const useChatterPolling = (activeIntervalMs = 45000, idleIntervalMs = 120000) => {
  const { isActive, isRecentlyActive, isMultiTabActive } = useActivityDetection(10)

  useEffect(() => {
    const shouldPoll = isActive && isMultiTabActive && !loading

    if (shouldPoll) {
      // Use active interval (45s) if recently active, idle interval (2m) otherwise
      const currentInterval = isRecentlyActive ? activeIntervalMs : idleIntervalMs
      pollInterval.current = setInterval(() => fetchChatter(false), currentInterval)
    }
  }, [isActive, isRecentlyActive, isMultiTabActive, loading, activeIntervalMs, idleIntervalMs])
}
```

**Messages and NewWriteups** - Fixed 2-Minute Polling:
```javascript
const { isActive, isMultiTabActive } = useActivityDetection(10)
const pollInterval = React.useRef(null)

// Polling effect - refresh every 2 minutes when active
React.useEffect(() => {
  const shouldPoll = isActive && isMultiTabActive && !loading

  if (shouldPoll) {
    pollInterval.current = setInterval(() => {
      loadData()
    }, 120000) // 2 minutes
  } else {
    if (pollInterval.current) {
      clearInterval(pollInterval.current)
      pollInterval.current = null
    }
  }

  return () => {
    if (pollInterval.current) {
      clearInterval(pollInterval.current)
      pollInterval.current = null
    }
  }
}, [isActive, isMultiTabActive, loading, loadData])
```

### Focus Refresh Pattern

All polling nodelets implement **immediate refresh on page focus**:

```javascript
// Focus refresh: immediately refresh when page becomes visible
React.useEffect(() => {
  const handleVisibilityChange = () => {
    if (!document.hidden && isActive) {
      // Page just became visible and user is active - refresh immediately
      loadData()
    }
  }

  document.addEventListener('visibilitychange', handleVisibilityChange)

  return () => {
    document.removeEventListener('visibilitychange', handleVisibilityChange)
  }
}, [isActive, loadData])
```

**Benefits**:
- User returns from another tab/window → sees fresh data immediately
- No waiting for next polling interval
- Better perceived responsiveness

### Generic Polling Hook

For future nodelet migrations, use the reusable hook ([react/hooks/usePolling.js](../react/hooks/usePolling.js)):

```javascript
import { usePolling } from '../../hooks/usePolling'

const MyNodelet = (props) => {
  const fetchData = async () => {
    const response = await fetch('/api/my-data/', {
      credentials: 'include',
      headers: { 'X-Ajax-Idle': '1' }
    })
    return response.json()
  }

  const { data, loading, error, refresh } = usePolling(
    fetchData,
    120000,  // 2 minutes
    { refreshOnFocus: true }  // Enable focus refresh
  )

  return (
    <NodeletContainer>
      {loading && <div>Loading...</div>}
      {error && <div>Error: {error}</div>}
      {data && <div>{/* render data */}</div>}
    </NodeletContainer>
  )
}
```

### Server-Side Considerations

**X-Ajax-Idle Header**:
All polling requests include `X-Ajax-Idle: 1` header to indicate background refresh:
```javascript
fetch('/api/endpoint/', {
  credentials: 'include',
  headers: { 'X-Ajax-Idle': '1' }
})
```

This allows server-side logging and monitoring to distinguish:
- User-initiated requests (interactive)
- Background polling requests (automated)

**Polling Rate Guidelines**:
- **High-value real-time data** (chat): 45s active / 2m idle
- **Medium-value updates** (messages, writeups): 2m
- **Low-value updates** (rarely changing content): 5m+
- **Always stop when asleep** (10+ minutes idle)

### Incremental vs Full Updates

**Chatterbox** - Incremental Updates:
```javascript
// Use 'since' parameter for incremental updates
let url = '/api/chatter/'
if (!isInitial && lastTimestamp.current) {
  url += '?since=' + lastTimestamp.current
} else {
  url += '?limit=30'
}

// Prepend new messages, keep existing
if (data.length > 0) {
  setChatter((prev) => [...data, ...prev])
  lastTimestamp.current = data[0].timestamp
}
```

**Messages/NewWriteups** - Full Replace:
```javascript
// Replace entire list on each poll
const data = await response.json()
setMessages(data)
```

**Trade-offs**:
- Incremental: Lower bandwidth, preserves scroll position, more complex
- Full replace: Simpler code, always consistent, may reset UI state

### Testing Polling Behavior

**Simulate Activity States**:
```javascript
// In tests, mock useActivityDetection
jest.mock('../../hooks/useActivityDetection', () => ({
  useActivityDetection: jest.fn(() => ({
    isActive: true,
    isRecentlyActive: true,
    isMultiTabActive: true
  }))
}))

// Test idle state
useActivityDetection.mockReturnValue({
  isActive: true,
  isRecentlyActive: false,  // Idle for 60+ seconds
  isMultiTabActive: true
})

// Test asleep state
useActivityDetection.mockReturnValue({
  isActive: false,  // Asleep for 10+ minutes
  isRecentlyActive: false,
  isMultiTabActive: true
})
```

**Verify Polling Intervals**:
```javascript
jest.useFakeTimers()

// Fast-forward 45 seconds
jest.advanceTimersByTime(45000)
expect(fetchChatter).toHaveBeenCalledTimes(1)

// Fast-forward another 2 minutes (idle state)
jest.advanceTimersByTime(120000)
expect(fetchChatter).toHaveBeenCalledTimes(2)
```

### Best Practices for New Nodelets

1. **Always use activity detection** - Never poll unconditionally
2. **Always stop when asleep** - Respect user's away state
3. **Always implement focus refresh** - Better UX when returning to tab
4. **Use X-Ajax-Idle header** - Help server distinguish request types
5. **Clean up intervals** - Use `useEffect` cleanup to prevent memory leaks
6. **Consider incremental updates** - For high-frequency data (chat, notifications)
7. **Test all activity states** - Active, idle, asleep, focused, unfocused
8. **Document polling rate** - Make it clear why you chose specific interval

## Proposed Migration Architecture

### Phase 1: Hybrid Mode (Immediate)

**Goal**: Enable React components to render page content alongside Mason2 templates

**Architecture**:
```
HTTP Request
  → Everything::HTMLRouter::route_node()
  → Everything::Controller::display()
  ┌─ Page Object display() returns HashRef
  │
  ├─ Mason Mode (default, test_react not set):
  │    → layout() → Mason templates → Full HTML
  │
  └─ React Mode (test_react=1):
       → JSON response with:
          • pageData: HashRef from Page->display()
          • pageComponent: React component name
          • pageState: Additional metadata
       → Client-side React lazy loads component
       → Renders with pageData
```

**Implementation**:

1. **Enhance Page Base Class** ([ecore/Everything/Page.pm](ecore/Everything/Page.pm)):
```perl
package Everything::Page;

has 'react_component' => (is => 'ro', default => '');
has 'supports_react' => (is => 'ro', default => 0);

sub display {
  return {}  # Already returns HashRef - perfect!
}

sub page_metadata {
  my ($self, $REQUEST, $node) = @_;
  return {
    react_component => $self->react_component,
    page_type => ref($self),
    canonical_url => $node->canonical_url,
  };
}
```

2. **Add React Display Mode** to Controller ([ecore/Everything/Controller/superdoc.pm](ecore/Everything/Controller/superdoc.pm)):
```perl
sub display {
  my ($self, $REQUEST, $node) = @_;

  my $permission_result = $self->page_class($node)->check_permission($REQUEST, $node);

  if (!$permission_result->allowed) {
    return [$self->HTTP_FORBIDDEN];
  }

  my $page_object = $self->page_class($node);
  my $controller_output = $page_object->display($REQUEST, $node);

  # NEW: Check if React mode requested
  if ($REQUEST->param('test_react') && $page_object->supports_react) {
    return $self->render_react($REQUEST, $node, $page_object, $controller_output);
  }

  # Existing Mason rendering
  my $layout = $page_object->template || $self->title_to_page($node->title);
  my $html = $self->layout("/pages/$layout",
                          %$controller_output,
                          REQUEST => $REQUEST,
                          node => $node);

  return [$self->HTTP_OK, $html];
}

sub render_react {
  my ($self, $REQUEST, $node, $page_object, $data) = @_;

  my $response = {
    pageData => $data,
    pageComponent => $page_object->react_component,
    metadata => $page_object->page_metadata($REQUEST, $node),
    nodeinfojson => $self->build_node_info($REQUEST, $node),
  };

  return [$self->HTTP_OK, $response, {type => 'application/json'}];
}
```

3. **Create React Page Container** ([react/components/PageContainer.js](react/components/PageContainer.js)):
```javascript
import React, { Suspense, lazy } from 'react';

// Map page types to React components
const pageComponentMap = {
  'e2_staff': lazy(() => import('./Pages/E2Staff')),
  'e2n': lazy(() => import('./Pages/E2N')),
  'everything_new_nodes': lazy(() => import('./Pages/NewNodes')),
  // ... more mappings
};

const PageContainer = ({ pageComponent, pageData, metadata }) => {
  const Component = pageComponentMap[pageComponent];

  if (!Component) {
    return <div>Component {pageComponent} not yet migrated to React</div>;
  }

  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Component {...pageData} metadata={metadata} />
    </Suspense>
  );
};

export default PageContainer;
```

4. **Create Page Loader Utility** ([react/utils/pageLoader.js](react/utils/pageLoader.js)):
```javascript
export const loadPage = async (nodeId, useReact = true) => {
  const reactParam = useReact ? '?test_react=1' : '';
  const response = await fetch(
    `/api/nodes/${nodeId}${reactParam}`,
    { credentials: 'same-origin' }
  );

  if (!response.ok) {
    throw new Error(`Failed to load page: ${response.status}`);
  }

  return response.json();
};
```

### Phase 2: Incremental Page Migration

**Migration Priority Order:**
1. **Simple Read-Only Pages** (lowest risk)
   - [Everything::Page::e2_staff](ecore/Everything/Page/e2_staff.pm) - Static list display
   - [Everything::Page::golden_trinkets](ecore/Everything/Page/golden_trinkets.pm) - Node list
   - [Everything::Page::a_year_ago_today](ecore/Everything/Page/a_year_ago_today.pm) - Historical data

2. **Interactive Pages**
   - [Everything::Page::e2n](ecore/Everything/Page/e2n.pm) - New nodes (already has API)
   - [Everything::Page::sign_up](ecore/Everything/Page/sign_up.pm) - Form-based

3. **Complex Pages**
   - Node editing interfaces
   - Admin tools
   - Draft management

**Per-Page Migration Checklist:**
- [ ] Add `supports_react => 1` to Page class
- [ ] Add `react_component => 'component_name'` to Page class
- [ ] Ensure `display()` returns complete, well-structured HashRef
- [ ] Create React component in `react/components/Pages/`
- [ ] Add mapping to PageContainer
- [ ] Test with `?test_react=1` parameter
- [ ] Add fallback handling for missing data
- [ ] Verify API dependencies exist (or create them)

**Example Migration** - [Everything::Page::e2_staff](ecore/Everything/Page/e2_staff.pm):

**Before** (Page object stays same, just add attributes):
```perl
package Everything::Page::e2_staff;

use Moose;
extends 'Everything::Page';

has 'supports_react' => (is => 'ro', default => 1);
has 'react_component' => (is => 'ro', default => 'e2_staff');

sub display {
  my ($self, $REQUEST, $node) = @_;

  # Already returns perfect HashRef!
  return {
    editors => $ces,
    gods => $e2gods->group,
    inactive => $inactive,
    sigtitle => $sigtitle->group,
    chanops => $chanops->group
  };
}
```

**React Component** ([react/components/Pages/E2Staff.js](react/components/Pages/E2Staff.js)):
```javascript
import React from 'react';
import LinkNode from '../LinkNode';

const E2Staff = ({ editors, gods, inactive, sigtitle, chanops, metadata }) => {
  return (
    <div className="e2-staff-page">
      <h2>The Gods</h2>
      <ul>
        {gods.map(user => (
          <li key={user.node_id}>
            <LinkNode node={user} />
          </li>
        ))}
      </ul>

      <h2>Content Editors</h2>
      <ul>
        {editors.map(user => (
          <li key={user.node_id}>
            <LinkNode node={user} />
          </li>
        ))}
      </ul>

      {/* ... more sections */}
    </div>
  );
};

export default E2Staff;
```

### Phase 3: Full React Mode

**Goal**: Make React the default rendering engine

**Changes Required:**

1. **Main Layout Component** ([react/components/Layout.js](react/components/Layout.js)):
```javascript
const Layout = ({ children, nodelets, user, node }) => {
  return (
    <div id="wrapper">
      <Header user={user} />
      <div id="mainbody">
        <PageHeader node={node} user={user} />
        {children}
      </div>
      <Sidebar nodelets={nodelets} />
      <Footer />
    </div>
  );
};
```

2. **Router-Level Decision** ([ecore/Everything/HTMLRouter.pm](ecore/Everything/HTMLRouter.pm)):
```perl
sub route_node {
  my ($self, $NODE, $displaytype, $REQUEST) = @_;

  my $node = $self->APP->node_by_id($NODE->{node_id});
  my $controller = $self->CONTROLLER_TABLE->{$node->type->title};

  # Check if page supports React and user prefers it
  if ($self->should_use_react($REQUEST, $node)) {
    return $self->render_react_shell($REQUEST, $node, $controller);
  }

  # Fallback to Mason
  return $self->output($REQUEST, $controller->display($REQUEST, $node));
}

sub render_react_shell {
  my ($self, $REQUEST, $node, $controller) = @_;

  # Render minimal HTML shell with React mount point
  my $html = $self->react_shell_template($REQUEST, $node);
  return $self->output($REQUEST, [$self->HTTP_OK, $html]);
}
```

3. **React Shell Template** - Minimal HTML bootstrap:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title id="page-title">{title}</title>
  <link rel="stylesheet" href="{basesheet}">
  <meta name="robots" content="index,follow">
</head>
<body>
  <div id="e2-react-app"></div>
  <script id="nodeinfojson">window.e2 = {nodeinfojson}</script>
  <script src="/react/main.bundle.js"></script>
</body>
</html>
```

4. **Client-Side Routing** ([react/components/E2App.js](react/components/E2App.js)):
```javascript
const E2App = () => {
  const [pageData, setPageData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const nodeId = window.e2.node.node_id;
    loadPage(nodeId).then(data => {
      setPageData(data);
      setLoading(false);
    });
  }, []);

  if (loading) return <LoadingSpinner />;

  return (
    <Layout {...window.e2}>
      <PageContainer {...pageData} />
    </Layout>
  );
};
```

## Data Flow Patterns

### Current (Mason2):
```
Controller.layout()
  → buildNodeInfoStructure() → window.e2 (for React nodelets)
  → spread Page.display() HashRef → Mason template attributes
  → Mason renders HTML
```

### Proposed (Hybrid):
```
Controller.display()
  ├─ Mason Mode:
  │    → layout() → Mason templates → HTML
  │
  └─ React Mode:
       → JSON response {pageData, pageComponent, metadata}
       → Client React lazy loads component
       → Component renders with pageData
```

### Future (Full React):
```
HTMLRouter
  → Minimal HTML shell with window.e2
  → React App bootstraps
  → Loads page data via fetch
  → PageContainer lazy loads component
  → Renders with Layout
```

## Migration Benefits

### Technical Benefits
1. **Consistent Data Contract**: Page->display() already returns HashRef - perfect for JSON
2. **Progressive Enhancement**: Can migrate page-by-page with `?test_react=1`
3. **Code Reuse**: Existing Page objects need minimal changes
4. **API-First**: Forces better separation of data and presentation
5. **Performance**: Lazy loading, code splitting, client-side caching

### User Experience Benefits
1. **Faster Navigation**: Client-side routing, no full page reloads
2. **Better Interactivity**: React's declarative UI updates
3. **Mobile Friendly**: Single-page app architecture
4. **Offline Capable**: Service worker potential
5. **Modern UI Patterns**: Infinite scroll, optimistic updates, etc.

## Migration Risks & Mitigations

### Risk: Breaking Existing Functionality
**Mitigation**:
- Keep Mason as default until React mode is stable
- Use `?test_react=1` parameter for opt-in testing
- Comprehensive test coverage for each migrated page

### Risk: SEO Impact
**Mitigation**:
- Server-side rendering option via Node.js (future phase)
- Keep Mason templates for web crawlers
- Progressive enhancement approach

### Risk: Browser Compatibility
**Mitigation**:
- Babel transpilation already configured
- Polyfills for older browsers
- Graceful degradation to Mason for incompatible browsers

### Risk: Increased Complexity
**Mitigation**:
- Clear documentation and examples
- Consistent patterns enforced via PageContainer
- Developer training and onboarding docs

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Add `supports_react` and `react_component` to Page base class
- [ ] Implement `render_react()` in Controller
- [ ] Create PageContainer component
- [ ] Create pageLoader utility
- [ ] Document migration process

### Phase 2: Proof of Concept (Week 3-4)
- [ ] Migrate 3 simple pages (e2_staff, golden_trinkets, silver_trinkets)
- [ ] Test with `?test_react=1`
- [ ] Gather feedback
- [ ] Refine patterns

### Phase 3: Incremental Migration (Month 2-3)
- [ ] Migrate 5-10 pages per week
- [ ] Prioritize high-traffic pages
- [ ] Monitor performance metrics
- [ ] Fix bugs and edge cases

### Phase 4: Full React Mode (Month 4-6)
- [ ] Implement React shell template
- [ ] Add client-side routing
- [ ] Implement Layout component
- [ ] Migrate remaining pages
- [ ] Make React default for modern browsers

### Phase 5: Cleanup (Month 6+)
- [ ] Remove Mason templates for migrated pages
- [ ] Deprecate Mason rendering (keep for legacy support)
- [ ] Optimize bundle sizes
- [ ] Implement server-side rendering

## Code Examples

### Example Page Object (Minimal Changes)

```perl
package Everything::Page::new_example;

use Moose;
extends 'Everything::Page';

# NEW: Enable React rendering
has 'supports_react' => (is => 'ro', default => 1);
has 'react_component' => (is => 'ro', default => 'new_example');

# UNCHANGED: Already returns perfect HashRef
sub display {
  my ($self, $REQUEST, $node) = @_;

  return {
    items => $self->APP->get_items($REQUEST->user),
    categories => $self->APP->get_categories(),
    user_prefs => $REQUEST->user->VARS,
  };
}
```

### Example React Component

```javascript
// react/components/Pages/NewExample.js
import React, { useState } from 'react';
import LinkNode from '../LinkNode';

const NewExample = ({ items, categories, user_prefs, metadata }) => {
  const [filter, setFilter] = useState('all');

  const filteredItems = items.filter(item =>
    filter === 'all' || item.category === filter
  );

  return (
    <div className="new-example-page">
      <div className="filters">
        <button onClick={() => setFilter('all')}>All</button>
        {categories.map(cat => (
          <button key={cat} onClick={() => setFilter(cat)}>
            {cat}
          </button>
        ))}
      </div>

      <ul className="items">
        {filteredItems.map(item => (
          <li key={item.node_id}>
            <LinkNode node={item} />
            <span className="category">{item.category}</span>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default NewExample;
```

## Testing Strategy

### Unit Tests
- Jest for React components
- Test::More for Perl Page objects
- Verify data contract between Perl and React

### Integration Tests
- Selenium/Puppeteer for full page rendering
- Test both Mason and React modes
- Verify identical output where applicable

### Performance Tests
- Bundle size monitoring
- Load time comparisons (Mason vs React)
- Memory usage profiling

### User Acceptance Testing
- Beta testing with `?test_react=1` parameter
- Feedback collection
- A/B testing for performance metrics

## Conclusion

The proposed migration strategy leverages Everything2's existing architecture strengths:

1. **Page objects already return structured data** - minimal changes needed
2. **React infrastructure exists** - expand from nodelets to pages
3. **Progressive migration path** - low risk, high confidence
4. **Backward compatibility** - Mason remains available

The key insight is that `Everything::Page::display()` returning a HashRef is the **perfect data contract** for React. We simply need to:
- Route React mode requests to JSON responses
- Lazy load React components based on page type
- Render with the HashRef data

This approach provides a clear migration path from Mason2 to modern React without requiring a risky "big bang" rewrite.

# HTMLPage Cutover Plan

## Overview

This document outlines the multi-stage procedure to migrate away from the legacy `Everything::Delegation::htmlpage` system to the modern `Everything::Controller` architecture.

## Stage 1: Implement Default Controller Methods ✅ COMPLETE

Add fallback methods to the base `Everything::Controller` class that catch nodetypes without their own specific controllers. These mirror the legacy `node_*_page` functions.

**Completed: January 2026**

### Methods Implemented

| Method | Legacy Function | Status |
|--------|-----------------|--------|
| `display` | `node_display_page` | ✅ Implemented in base Controller |
| `edit` | `node_edit_page` | ✅ Implemented in base Controller |
| `xml` | `node_xml_page` | ✅ Already implemented |
| `xmltrue` | `node_xmltrue_page` | ✅ Already implemented |

### Implementation Notes

- `display`: The legacy `node_display_page` simply calls `htmlcode("displayNODE")`. For the controller, we need to either:
  - Port `displayNODE` htmlcode to a React component, or
  - Return a minimal display with node title, type, author, createtime

- `edit`: Legacy just returns a placeholder string. For controller, redirect to `basicedit` since that's the universal raw field editor.

- `xml` and `xmltrue`: Already implemented in `Everything::Controller`. Verify they work correctly for all nodetypes.

### Nodetype Inheritance Considerations

Some nodetypes may be better served by inheriting from existing controllers rather than the base fallback:

| Nodetype | Potential Parent Controller | Notes |
|----------|----------------------------|-------|
| (system types) | `Everything::Controller` | Use base fallback with basicedit |
| (document-like) | Consider per-case | May need specific handling |

## Stage 2: Force Controller Routing (Remove Fallback to htmlpage)

Once Stage 1 is complete (all default methods implemented), modify `HTMLRouter` to always route through controllers without checking for specific type support. This eliminates the fallback path to the legacy htmlpage system.

### Current Behavior

In `HTMLRouter::can_route()`:
1. Checks if displaytype is in allowed list
2. Checks if `CONTROLLER_TABLE->{$nodetype}` exists
3. Checks if controller `can($displaytype)`
4. Checks if controller `fully_supports($node_title)`
5. If any check fails, returns 0/undef and falls back to legacy htmlpage

### New Behavior

After Stage 1, the base `Everything::Controller` will have all required methods (`display`, `edit`, `xml`, `xmltrue`, `basicedit`, etc.). This means:

- Every nodetype will have a controller (either specific or base `Everything::Controller`)
- Every controller will respond to standard displaytypes
- No fallback to htmlpage is needed

### Changes Required

**`ecore/Everything/HTMLRouter.pm`**:
- Modify `can_route()` to always return true for valid displaytypes
- Or simplify to only check displaytype allowlist, skip controller capability checks
- Remove `fully_supports()` check (or make it always return 1 in base controller)

**`ecore/Everything/Controller.pm`**:
- Ensure `fully_supports()` returns 1 by default (already does)
- Ensure all standard displaytype methods exist with sensible defaults

### Known Breakage: AJAX Updates

**This stage will break AJAX updates.** The `ajax_update_page` htmlpage function handles dynamic partial page updates and does not have a controller equivalent yet.

However, this breakage can be **ignored for now** because the Mason container does not insert the ajax displaytypes into the routing path. The ajax updates flow through a different code path that bypasses the HTMLRouter entirely.

### Result: Dead Code

After this stage, the following modules become dead code (no longer called):
- `Everything::Delegation::htmlpage` - All `*_page` functions
- `Everything::Delegation::document` - All document display delegations

These can be removed in a subsequent cleanup stage.

### Risk Mitigation

Since all htmlpages have been implemented and all existing fallbacks are in place, this change should be **net-neutral** for standard page rendering - everything continues working as before, just routed through controllers instead of htmlpage delegation.

### Verification

After this change:
1. Test a sampling of nodetypes across all displaytypes
2. Verify no 500 errors or "unimplemented" responses
3. Check development.log for any unexpected fallback attempts

## Stage 3: Audit Page Actions (Category/Weblog Icons)

Analyze the `page actions` htmlcode to determine when category and weblog action icons are displayed, and ensure the corresponding React components include these icons.

### Analysis Required

1. **Read `page actions` htmlcode** in `Everything::Delegation::htmlcode`
   - Identify conditions for showing category action icon
   - Identify conditions for showing weblog action icon
   - Document any other action icons that may be conditionally displayed

2. **Map to React Components**
   - Determine which React document components need these icons
   - Identify where in the component the icons should appear (header, action bar, etc.)

### Expected Conditions (to verify)

| Icon | Likely Condition | React Component(s) |
|------|------------------|-------------------|
| Category | Node is categorizable (e2node, writeup?) | E2node, Writeup |
| Weblog | Node can be added to weblog | E2node, Writeup |

### Implementation

For each icon type:
1. Verify the condition logic from htmlcode
2. Ensure React component receives necessary data in `contentData`
3. Add icon/action to React component if missing

### Files to Analyze
- `ecore/Everything/Delegation/htmlcode.pm` - `page_actions` function
- `react/components/Documents/*.js` - Document display components

## Stage 4: Fix lastnode_id for Softlink Creation

Currently not generating enough softlinks because `lastnode_id` is not being passed from links in writeups, e2nodes, or softlinks. This parameter is critical for softlink creation but historically caused SEO issues when included in URLs.

### Background

- **What is lastnode_id**: The previous node visited, used to create softlinks between nodes
- **For writeups**: lastnode_id should be the parent e2node
- **Problem**: Including lastnode_id in URLs hurts SEO (creates duplicate content, pollutes crawl budget)
- **Current state**: Links don't include lastnode_id, so softlinks aren't being created

### Solution Options

#### Option A: Cookie-based (Recommended)

Store lastnode_id client-side in a cookie, read it server-side for softlink creation.

**Pros**:
- Clean URLs (no `?lastnode_id=` parameters)
- SEO-friendly
- Server-side processing remains unchanged

**Cons**:
- Requires React component changes to set cookie on navigation
- Cookie must be read server-side before softlink creation

**Implementation**:
1. React component sets `lastnode_id` cookie when rendering a node
2. On next page load, server reads cookie value
3. Server uses cookie value for softlink creation
4. Cookie is updated to current node_id after processing

#### Option B: URL Parameter (Not Recommended)

Include `lastnode_id` in link URLs rendered by React components.

**Pros**:
- Simple implementation
- No cookie management needed

**Cons**:
- SEO impact (duplicate URLs, crawl issues)
- Historical problems with this approach
- Pollutes browser history

### Recommended Approach: Cookie-based

**React Changes**:
- When rendering writeup/e2node/softlink components, set a cookie:
  ```javascript
  document.cookie = `lastnode_id=${nodeId}; path=/; SameSite=Lax`;
  ```
- Could be done in a shared hook or component that wraps node displays

**Server Changes**:
- In softlink creation code, read `lastnode_id` from cookie if not in query params
- Update cookie after softlink processing

### Files to Modify

**React**:
- `react/components/Documents/E2node.js` - Set lastnode_id cookie
- `react/components/Documents/Writeup.js` - Set lastnode_id cookie (to parent e2node)
- Possibly create shared hook: `react/hooks/useLastNode.js`

**Perl (server-side)**:
- Softlink creation code - Read from cookie as fallback
- `ecore/Everything/Application.pm` or relevant softlink function

## Stage 5: Expand React Root to Full Page

Move the React root to contain the entire page within the `<html>` tags. This is a foundational change that enables full React control over the page layout, including the search functionality.

### Current State

- Mason template renders the outer HTML structure (header, nav, search, etc.)
- React root only contains the main content area
- Search is handled by legacy JavaScript that modifies the search button
- Header/nav are rendered server-side via Mason

### Target State

- React root wraps the entire page content (inside `<html>` tags)
- React components handle:
  - Header/navigation
  - Search UI (integrated with live search API)
  - Main content area
  - Footer
- Mason template becomes minimal (just bootstraps React)

### Prerequisites

1. **React Search Component** - Must be created before this stage
   - Integrate with existing live search API
   - Restyle search input/button
   - Replace legacy JavaScript search handling

### CRITICAL: Preserving Ad Serving

**Ad revenue is critical to E2's operation. Extra care must be taken not to break ad serving during this migration.**

**Current ad implementation:**
- `templates/helpers/googleads.mi` - Mason component rendering AdSense
- Loaded in `templates/zen.mc` immediately after `<body>` tag
- Controlled by `no_ads` flag (disabled for logged-in users)
- AdSense script: `pagead2.googlesyndication.com/pagead/js/adsbygoogle.js`
- Ad client: `ca-pub-0613380022572506`
- Ad slot: `9636638260` (728x90 header banner)

**Migration requirements:**

1. **Preserve exact ad placement** - Ads must render in the same DOM position
2. **Keep script loading order** - AdSense script must load early
3. **Maintain ad container structure** - The `<ins class="adsbygoogle">` element must be present
4. **Test with real ads** - Verify ads actually render (not just DOM structure)
5. **Monitor ad metrics** - Watch AdSense dashboard for impression drops after deployment

**React ad component:**
```jsx
// react/components/Ads/HeaderAd.js
const HeaderAd = ({ showAds }) => {
  useEffect(() => {
    // Push ad after component mounts
    if (showAds && window.adsbygoogle) {
      try {
        (window.adsbygoogle = window.adsbygoogle || []).push({});
      } catch (e) {
        console.error('AdSense error:', e);
      }
    }
  }, [showAds]);

  if (!showAds) return null;

  return (
    <div className="headerads">
      <center>
        <ins
          className="adsbygoogle"
          style={{ display: 'inline-block', width: '728px', height: '90px' }}
          data-ad-client="ca-pub-0613380022572506"
          data-ad-slot="9636638260"
        />
      </center>
    </div>
  );
};
```

**AdSense script loading** - Must remain in `<head>` via Mason or be loaded synchronously:
```html
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-0613380022572506" crossorigin="anonymous"></script>
```

**Testing checklist:**
- [ ] Ads render for guest users
- [ ] Ads do NOT render for logged-in users
- [ ] Ad blocker detection still works (Stage 7 GA4 migration)
- [ ] No console errors related to AdSense
- [ ] AdSense dashboard shows normal impression counts post-deploy

### Implementation Steps

1. **Create React Search Component**
   - New component: `react/components/Search/SearchBar.js`
   - Use existing live search API endpoint
   - Style to match site design (Kernel Blue palette)
   - Handle keyboard navigation, suggestions, etc.

2. **Create React Header Component**
   - New component: `react/components/Layout/Header.js`
   - Include logo, navigation, search bar
   - User menu/login state

3. **Modify Mason Template**
   - Move React root to wrap entire body content
   - Reduce Mason template to minimal bootstrap:
     ```html
     <html>
       <head>...</head>
       <body>
         <div id="react-root"></div>
         <script>...</script>
       </body>
     </html>
     ```

4. **Remove Legacy JavaScript**
   - Remove search button modification code
   - Remove any other legacy JS that React now handles

5. **Create EpicenterZen Component**
   - For users without the Epicenter nodelet, a compact linkbar is shown in the header
   - Currently rendered via `htmlcode('epicenterZen')` in `templates/zen.mc`
   - Must be replaced with a React component when React owns the header

### EpicenterZen Replacement

**Current behavior** (from `Everything::Delegation::htmlcode::epicenterZen`):

For logged-in users without Epicenter nodelet, displays:
- **User links**: Username, Logout, Preferences, Drafts, Help, Random
- **Stats**: Votes left, Cools left, XP/GP changes
- **Quick actions**: Chat, Inbox

**Condition check** (from `templates/zen.mc`):
```perl
my $epicenter_nodelet = $DB->getNode('Epicenter', 'nodelet');
my $nodelets = $user->VARS->{nodelets} || '';
if ($nodelets !~ /\b$epid\b/) {
    # Show epicenterZen linkbar
}
```

**React implementation:**
```jsx
// react/components/Layout/EpicenterZen.js
const EpicenterZen = ({ user, hasEpicenterNodelet }) => {
  if (user.guest || hasEpicenterNodelet) return null;

  return (
    <div id="epicenter_zen">
      <span id="epicenter_zen_info">
        <Link to={`/user/${user.title}`}>{user.title}</Link>
        {' | '}<Link to="/?op=logout">Log Out</Link>
        {' | '}<Link to="/title/User+Settings">Preferences</Link>
        {' | '}<Link to="/title/Drafts">Drafts</Link>
        {' | '}<Link to="/title/Everything2+Help">Help</Link>
        {' | '}<RandomNodeLink />
      </span>
      {(user.votesleft > 0 || user.cools > 0) && (
        <span id="voteInfo">
          You have {user.cools > 0 && <><strong>{user.cools}</strong> C!{user.cools > 1 ? 's' : ''}</>}
          {user.cools > 0 && user.votesleft > 0 && ' and '}
          {user.votesleft > 0 && <><strong>{user.votesleft}</strong> vote{user.votesleft > 1 ? 's' : ''}</>}
          {' '}left today.
        </span>
      )}
      <XPDisplay user={user} />
      <span id="epicenter_zen_commands">
        <Link to="/title/chatterlight">chat</Link>
        {' | '}<Link to="/title/message+inbox">inbox</Link>
      </span>
    </div>
  );
};
```

**Data requirements** - Add to `e2` JSON:
- `hasEpicenterNodelet` - boolean flag
- User stats already available: `votesleft`, `cools`, XP/GP info

### Files to Create

- `react/components/Search/SearchBar.js` - Live search component
- `react/components/Layout/Header.js` - Full header with nav
- `react/components/Layout/Footer.js` - Footer component (if not exists)
- `react/components/Layout/PageLayout.js` - Root layout wrapper
- `react/components/Layout/EpicenterZen.js` - Compact user info bar
- `react/components/Ads/HeaderAd.js` - AdSense header banner (CRITICAL)

### Files to Modify

- `mason2/pages/react_page.mc` - Expand React root, simplify Mason (keep AdSense script in `<head>`)
- `react/App.js` or equivalent - Include new layout components
- `ecore/Everything/Application.pm` - Add `hasEpicenterNodelet` to e2 JSON
- Remove/deprecate legacy search JS

### Benefits

- Unified React rendering (no Mason/React boundary issues)
- Modern search UX with live suggestions
- Easier styling and theming
- Better code organization
- Removes legacy JavaScript dependencies

## Stage 6: Migrate Page Action Icons to React

Convert the bookmark and editor cool icons from legacy JavaScript `window` event handlers to proper React components with Font Awesome icons. This unifies the look and feel and removes dependencies on `legacy.js`.

### Current State

Page action icons (bookmark, editor cool) are rendered server-side via `page_actions` htmlcode with inline `onclick` handlers that call global `window` functions:

**`ecore/Everything/Delegation/htmlcode.pm` (page_actions):**
```perl
# Editor cool button - HTML entity star (&#9733;)
push @actions, qq{<button onclick="window.toggleEditorCool && window.toggleEditorCool($node_id, this)" ...>&#9733;</button>};

# Bookmark button - HTML entity bookmark (&#128278;/&#128279;)
$bookmark_add = qq{<button onclick="window.toggleBookmark && window.toggleBookmark($node_id, this)" ...>$bookmark_icon</button>};
```

**`www/js/legacy.js`:**
```javascript
window.toggleEditorCool = async function(nodeId, button) { ... }
window.toggleBookmark = async function(nodeId, button) { ... }
```

### Target State

- React components render icons using Font Awesome
- State management handled by React (no DOM manipulation)
- API calls made via React hooks/services
- Icons styled consistently with Kernel Blue palette
- No global `window` function dependencies

### Implementation

#### 1. Create React Icon Action Components

**New file: `react/components/Actions/BookmarkButton.js`**
```jsx
import { useState, useCallback } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faBookmark as faBookmarkSolid } from '@fortawesome/free-solid-svg-icons';
import { faBookmark as faBookmarkRegular } from '@fortawesome/free-regular-svg-icons';

const BookmarkButton = ({ nodeId, initialBookmarked }) => {
  const [isBookmarked, setIsBookmarked] = useState(initialBookmarked);
  const [isLoading, setIsLoading] = useState(false);

  const toggleBookmark = useCallback(async () => {
    const prevState = isBookmarked;
    setIsBookmarked(!prevState); // Optimistic update
    setIsLoading(true);

    try {
      const response = await fetch(`/api/cool/bookmark/${nodeId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      const data = await response.json();

      if (!data.success) throw new Error(data.error);
      setIsBookmarked(data.bookmarked);
    } catch (error) {
      setIsBookmarked(prevState); // Revert on error
      console.error('Bookmark error:', error);
    } finally {
      setIsLoading(false);
    }
  }, [nodeId, isBookmarked]);

  return (
    <button
      onClick={toggleBookmark}
      disabled={isLoading}
      title={isBookmarked ? 'Remove bookmark' : 'Bookmark this page'}
      className="action-icon-button"
      style={{ color: isBookmarked ? '#4060b0' : '#999' }}
    >
      <FontAwesomeIcon icon={isBookmarked ? faBookmarkSolid : faBookmarkRegular} />
    </button>
  );
};
```

**New file: `react/components/Actions/EditorCoolButton.js`**
```jsx
import { useState, useCallback } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faStar as faStarSolid } from '@fortawesome/free-solid-svg-icons';
import { faStar as faStarRegular } from '@fortawesome/free-regular-svg-icons';

const EditorCoolButton = ({ nodeId, initialCooled }) => {
  const [isCooled, setIsCooled] = useState(initialCooled);
  const [isLoading, setIsLoading] = useState(false);

  const toggleCool = useCallback(async () => {
    setIsLoading(true);
    try {
      const response = await fetch(`/api/cool/edcool/${nodeId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      const data = await response.json();

      if (!data.success) throw new Error(data.error);
      setIsCooled(data.edcooled);
    } catch (error) {
      console.error('Editor cool error:', error);
    } finally {
      setIsLoading(false);
    }
  }, [nodeId]);

  return (
    <button
      onClick={toggleCool}
      disabled={isLoading}
      title={isCooled ? 'Remove editor cool' : 'Add editor cool (endorsement)'}
      className="action-icon-button"
      style={{ color: isCooled ? '#f4d03f' : '#999' }}
    >
      <FontAwesomeIcon icon={isCooled ? faStarSolid : faStarRegular} />
    </button>
  );
};
```

#### 2. Add Data to contentData

Ensure controllers/pages pass bookmark and editor cool state to React:

```perl
# In buildReactData or controller display method:
$content_data->{can_bookmark} = $APP->can_bookmark($node->NODEDATA);
$content_data->{is_bookmarked} = $self->_check_bookmarked($user, $node);
$content_data->{can_edcool} = $APP->isEditor($user->NODEDATA);
$content_data->{is_edcooled} = $PAGELOAD->{edcoollink} ? 1 : 0;
```

#### 3. Integrate into Document Components

Add action buttons to relevant React document components (E2node, Writeup, Superdoc, etc.):

```jsx
// In E2node.js or similar
import BookmarkButton from '../Actions/BookmarkButton';
import EditorCoolButton from '../Actions/EditorCoolButton';

const E2node = ({ data }) => {
  const { node_id, can_bookmark, is_bookmarked, can_edcool, is_edcooled } = data;

  return (
    <div className="e2node">
      <div className="page-actions">
        {can_edcool && <EditorCoolButton nodeId={node_id} initialCooled={is_edcooled} />}
        {can_bookmark && <BookmarkButton nodeId={node_id} initialBookmarked={is_bookmarked} />}
      </div>
      {/* ... rest of component */}
    </div>
  );
};
```

#### 4. Remove Legacy Code

**From `www/js/legacy.js`:**
- Remove `window.toggleEditorCool` function (lines ~958-980)
- Remove `window.toggleBookmark` function (lines ~982-1020)
- Remove `bookmarkit` from warnings object (line ~879-880)

**From `ecore/Everything/Delegation/htmlcode.pm` (page_actions):**
- Remove editor cool button HTML generation
- Remove bookmark button HTML generation
- These will no longer be rendered server-side

### Font Awesome Icons

| Action | Icon (Active) | Icon (Inactive) | Color (Active) | Color (Inactive) |
|--------|--------------|-----------------|----------------|------------------|
| Bookmark | `faBookmarkSolid` | `faBookmarkRegular` | `#4060b0` (Link Blue) | `#999` |
| Editor Cool | `faStarSolid` | `faStarRegular` | `#f4d03f` (Gold) | `#999` |

### CSS for Action Buttons

```css
.action-icon-button {
  background: none;
  border: none;
  cursor: pointer;
  padding: 4px 8px;
  font-size: 16px;
  transition: color 0.2s ease;
}

.action-icon-button:hover {
  opacity: 0.8;
}

.action-icon-button:disabled {
  cursor: wait;
  opacity: 0.5;
}
```

### Files to Create

- `react/components/Actions/BookmarkButton.js`
- `react/components/Actions/EditorCoolButton.js`
- `react/components/Actions/index.js` (barrel export)

### Files to Modify

- `react/components/Documents/E2node.js` - Add action buttons
- `react/components/Documents/Writeup.js` - Add action buttons
- `react/components/Documents/Superdoc.js` - Add action buttons
- `ecore/Everything/Page/*.pm` - Add bookmark/edcool state to contentData
- `www/js/legacy.js` - Remove toggle functions
- `ecore/Everything/Delegation/htmlcode.pm` - Remove button generation from page_actions

### Notes

- Icon placement TBD - may need adjustment after Stage 5 (React full page)
- Category and weblog action icons (mentioned in Stage 3) can follow same pattern
- Consider creating shared `useToggleAction` hook for reusable optimistic update logic

## Stage 7: Full Burndown Audit of Legacy JavaScript

Complete audit and migration of all remaining functionality in `www/js/legacy.js`. After Stages 5 and 6, this file should be nearly empty. This stage ensures nothing is missed and allows complete removal of the file.

### Current Contents of legacy.js (~1020 lines)

| Section | Lines | Status | Migration Target |
|---------|-------|--------|------------------|
| **e2URL class** | 1-61 | Audit | React router/URL utils |
| **jQuery extensions (e2 object)** | 63-382 | Audit | React state management |
| **Full text search checkbox** | 79-129 | **Migrate Stage 5** | React SearchBar component |
| **e2.inclusiveSelect, e2.add, e2.activate** | 135-162 | Dead after React | Remove |
| **e2.periodical (timer)** | 215-257 | Audit | React useEffect + setInterval |
| **Cookie utilities** | 263-280 | Audit | React cookie hooks or native |
| **e2.setLastnode** | 334-352 | **Migrate Stage 4** | Cookie-based approach |
| **confirmop framework** | 354-379 | Audit | React confirm dialogs |
| **Message reply links** | 386-387 | Audit | React component |
| **Expandable textareas** | 392-458 | Audit | React auto-resize textarea |
| **Widgets (showhide)** | 460-515 | Audit | React modals/dropdowns |
| **Read-only textarea guard** | 517-530 | Audit | React component prop |
| **wuformaction** | 532-546 | Audit | React form handlers |
| **Lastnode link injection** | 548-574 | **Migrate Stage 4** | React softlink component |
| **beforeunload unsaved warning** | 576-613 | Audit | React form dirty state |
| **AJAX update system** | 615-916 | Dead after React | Remove |
| **Google Analytics 4** | 919-954 | **Migrate this stage** | React baseline/App.js |
| **toggleEditorCool** | 958-980 | **Migrate Stage 6** | React EditorCoolButton |
| **toggleBookmark** | 982-1020 | **Migrate Stage 6** | React BookmarkButton |

### Category 1: Already Migrated (Remove After Verification)

These are marked as removed/migrated in the code comments:

```javascript
// writeupmessage - REMOVED: React WriteupDisplay + MessageModal + /api/messages/create handles this
// coolit - REMOVED: page_actions uses window.toggleEditorCool + /api/cool/edcool handles this
// favorite_noder - REMOVED: React UserDisplay.js + /api/favorites/:id/action/:action handles this
```

### Category 2: Google Analytics & Ads (Migrate to React Baseline)

**Google Analytics 4 (lines 919-954):**
```javascript
window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', 'G-2GBBBF9ZDK', { 'user_login_status': userLoginStatus });

// Ad blocker detection event
window.addEventListener('load', function() { ... });
```

**Migration approach:**
1. Move GA4 initialization to React App.js or dedicated Analytics component
2. Use React context to access user login status
3. Ad blocker detection can be a React hook or component

**New file: `react/components/Analytics/GoogleAnalytics.js`**
```jsx
import { useEffect } from 'react';

const GoogleAnalytics = ({ user }) => {
  useEffect(() => {
    const userStatus = user?.guest === 0 ? 'logged_in' : 'guest';

    window.dataLayer = window.dataLayer || [];
    function gtag(...args) { window.dataLayer.push(args); }

    gtag('js', new Date());
    gtag('config', 'G-2GBBBF9ZDK', { user_login_status: userStatus });

    // Ad blocker detection (delayed)
    const timer = setTimeout(() => {
      let adStatus = 'no_ad_slot';
      const adElement = document.querySelector('.adsbygoogle');

      if (adElement) {
        if (adElement.offsetHeight > 0 && adElement.querySelector('iframe')) {
          adStatus = 'ad_shown';
        } else if (typeof window.adsbygoogle === 'undefined') {
          adStatus = 'blocked_script';
        } else {
          adStatus = 'blocked_render';
        }
      }

      gtag('event', 'ad_check', { ad_status: adStatus, user_type: userStatus });
    }, 3000);

    return () => clearTimeout(timer);
  }, [user]);

  return null;
};

export default GoogleAnalytics;
```

**Google Ads:** If ads code exists in legacy.js or elsewhere, it should also move to a React component or be loaded via the Mason template `<head>`.

### Category 3: AJAX Update System (Dead Code)

The entire `e2.ajax` system (lines 615-916) becomes dead code once React handles all page updates. This includes:
- `e2.ajax.htmlcode()` - Server-side htmlcode execution
- `e2.ajax.update()` - DOM replacement with server-rendered HTML
- `e2.ajax.pending` - Pending operation tracking
- `warnings` object - User warnings for pending operations

**Action:** Remove entirely after React handles all updates.

### Category 4: jQuery/DOM Utilities (Evaluate Each)

| Utility | Current Use | React Alternative |
|---------|------------|-------------------|
| `e2.getCookie` / `setCookie` / `deleteCookie` | Cookie management | `js-cookie` or native |
| `e2.getFocus` | Focus tracking | React refs |
| `e2.getSelectedText` | Text selection | Native API |
| `e2.vanish` | Fade/slide removal | CSS transitions or Framer Motion |
| `e2.heightToScrollHeight` | Auto-resize textarea | React `useAutoResize` hook |
| `e2.startText` | Message reply links | React component props |

### Category 5: Form Handling (Migrate Incrementally)

| Feature | Lines | React Migration |
|---------|-------|-----------------|
| Expandable textareas | 392-458 | `TextareaAutosize` component or hook |
| Read-only textarea guard | 517-530 | `readOnly` prop on textarea |
| `wuformaction` buttons | 532-546 | React form submission handlers |
| Unsaved changes warning | 576-613 | React form dirty state + `beforeunload` |

### Category 6: Widget System (Replace with React)

The widget show/hide system (lines 460-515) handles dropdown menus and forms. Replace with:
- React dropdown components
- React modal/dialog components
- CSS-only details/summary elements where appropriate

### Audit Checklist

For each function/section in legacy.js:

1. [ ] Identify all call sites (htmlcode, Mason templates, other JS)
2. [ ] Determine if functionality exists in React
3. [ ] If not, create React component/hook
4. [ ] Update server to not emit legacy JS calls
5. [ ] Remove from legacy.js
6. [ ] Test affected pages

### Final Goal: Delete legacy.js

After this stage:
1. `www/js/legacy.js` should be completely empty or deleted
2. Mason template removes `<script src="legacy.js">`
3. All functionality lives in React components

### Files to Create

- `react/components/Analytics/GoogleAnalytics.js`
- `react/components/Analytics/AdBlockerDetection.js` (or combined)
- `react/hooks/useCookie.js` (if needed)
- `react/hooks/useAutoResizeTextarea.js`
- `react/hooks/useUnsavedChangesWarning.js`

### Files to Modify

- `mason2/pages/react_page.mc` - Remove legacy.js script tag
- `react/App.js` - Add GoogleAnalytics component
- Various React components - Integrate migrated functionality

### Files to Remove

- `www/js/legacy.js` - After all migrations complete

## Stage 8: Audit Container Code and Ensure Mason Template Feature Parity

Ensure Mason templates (`templates/zen.mc` and related) are feature-complete with all functionality from `Everything::Delegation::container.pm` before the container code becomes dead.

### Container Functions to Audit

The container module has 4 functions that wrap page content:

| Function | Purpose | Mason Equivalent |
|----------|---------|------------------|
| `zen_stdcontainer` | Full HTML structure (head, body, scripts) | `templates/zen.mc` |
| `zen_container` | Header, sidebar, footer structure | Part of `zen.mc` |
| `formcontainer` | Wraps content in POST form for edit pages | Not currently in Mason |
| `atom_container` | Atom feed XML wrapper | Controllers handle directly |

### Feature Comparison: zen_stdcontainer vs zen.mc

#### Head Section

| Feature | Container | Mason | Status |
|---------|-----------|-------|--------|
| DOCTYPE, charset, lang | Yes | Yes | ✅ |
| Page title | `$APP->pagetitle($NODE)` | `$.pagetitle` | ✅ |
| Basesheet CSS | htmlcode("linkStylesheet") | `$.basesheet` | ✅ |
| Zensheet CSS | htmlcode for user style | `$.zensheet` | ✅ |
| Custom style | `$VARS{customstyle}` | `$.customstyle` | ✅ |
| Print stylesheet | htmlcode("linkStylesheet") | `$.printsheet` | ✅ |
| Base href (guests) | `$APP->basehref()` | `$.basehref` | ✅ |
| Canonical URL | Built from urlGenNoParams | `$.canonical_url` | ✅ |
| Robots meta | Conditional logic | `$.meta_robots_*` | ✅ |
| Meta description | htmlcode("metadescriptiontag") | `$.metadescription` | ✅ |
| Favicon | `$APP->asset_uri()` | `$.favicon` | ✅ |
| Atom feed link | Conditional (Cool Archive vs default) | `$.atom_feed` | ⚠️ Review |
| GA4 script | In head | In head | ✅ |
| Open Graph meta | No | Yes | ✅ Better |
| Twitter meta | No | Yes | ✅ Better |
| JSON-LD schema | No | Yes | ✅ Better |

#### Body Section

| Feature | Container | Mason | Status |
|---------|-----------|-------|--------|
| Body class | writeuppage + type | `$.body_class` | ✅ |
| Body id (superdocs) | From title | Not implemented | ⚠️ Add |
| Schema.org itemscope | Yes | Yes | ✅ |
| Static javascript | htmlcode("static javascript") | Direct script tags | ✅ |

### Feature Comparison: zen_container vs zen.mc body

| Feature | Container | Mason | Status |
|---------|-----------|-------|--------|
| Google ads header | htmlcode("zenadheader") | `<& 'googleads' &>` | ✅ |
| Header div | Yes | Yes | ✅ |
| epicenterZen | Conditional on nodelet | Conditional on nodelet | ✅ |
| Search form | htmlcode("zensearchform") | `<& 'searchform' &>` | ✅ |
| E2 logo | Yes | Yes | ✅ |
| Wrapper div | Yes | Yes | ✅ |
| Main body div | Yes | Yes | ✅ |
| Page header | htmlcode("page header") | Inline `<div id="pageheader">` | ✅ |
| Sidebar | Yes | Yes | ✅ |
| React root | `<div id='e2-react-root'>` | React handles | ✅ |
| Footer | htmlcode("zenFooter") | Via React | ✅ |

### Items Needing Review

#### 1. Atom Feed Link Conditional

Container has special logic for Cool Archive:
```perl
if ($$NODE{title} eq "Cool Archive") {
    # Use Cool Archive Atom Feed
} else {
    # Use New Writeups Atom Feed (with user param for user pages)
}
```

**Action:** Verify Mason template handles this via `$.atom_feed` prop passed from controller.

#### 2. Body ID for Superdocs

Container adds body id for superdocs:
```perl
if($$NODE{type}{title} =~ /superdoc/) {
    my $id = ( $$NODE{node_id} != 124 ? lc($$NODE{title}) : 'frontpage' );
    $id =~ s/\W//g;
    $str .= '" id="' . $id;
}
```

**Action:** Add body id generation to Mason template or ensure React doesn't need it.

#### 3. formcontainer

Used for edit pages wrapping content in a form:
```perl
$query->start_form(-method=>'POST', action=>$ENV{script_name}, name=>'pagebody', id=>'pagebody')
$query->hidden('displaytype')
$query->hidden('node_id', getId($NODE))
htmlcode('verifyRequestForm', "edit_$type")
```

**Action:** React edit components handle their own forms. Verify all edit displaytypes work without formcontainer.

#### 4. atom_container

Wraps Atom feed content:
```perl
<?xml version="1.0" encoding="UTF-8" ?>
<feed xmlns="http://www.w3.org/2005/Atom" ...>
```

**Action:** Controllers generate complete Atom XML directly (e.g., `debatecomment::atom`). Container not needed.

### Mason Template Enhancements (Already Better)

The Mason template `zen.mc` already includes features NOT in container:

1. **Open Graph meta tags** - Facebook/social sharing
2. **Twitter card meta tags** - Twitter sharing
3. **JSON-LD structured data** - SEO schema.org markup
4. **Viewport meta** - Mobile responsiveness
5. **Article published_time** - For writeups/e2nodes

### Verification Steps

1. **Visual diff test:**
   - Render same page via container (legacy path)
   - Render same page via Mason template (controller path)
   - Compare HTML output for missing elements

2. **Feature matrix:**
   - Create checklist of all container features
   - Verify each exists in Mason or is obsolete

3. **Edge cases:**
   - Cool Archive page (custom Atom feed)
   - Superdoc pages (body id)
   - User pages (Atom feed with user param)
   - Guest vs logged-in (base href, ads)

### Files to Audit

**Container code (becoming dead):**
- `ecore/Everything/Delegation/container.pm` - All 4 functions

**Mason templates (must be complete):**
- `templates/zen.mc` - Main page wrapper
- `templates/helpers/googleads.mi` - Ad insertion
- `templates/helpers/searchform.mi` - Search form
- `templates/helpers/createdby.mi` - Author byline
- `templates/pages/react_page.mc` - React page wrapper

**Htmlcodes called by container (may become dead):**
- `zenadheader` - Ad header
- `zensearchform` - Search form
- `page header` - Page title/byline area
- `zenFooter` - Footer content
- `static javascript` - JS includes
- `metadescriptiontag` - Meta description
- `linkStylesheet` - CSS links
- `epicenterZen` - User info bar

### Post-Audit Actions

1. Add any missing features to Mason templates
2. Document any intentionally removed features
3. Mark container.pm as deprecated
4. After Stage 2 (force controller routing), container becomes dead code
5. Remove container.pm in cleanup stage

## Files Affected

### To Modify
- `ecore/Everything/Controller.pm` - Add default display/edit methods
- `ecore/Everything/HTMLRouter.pm` - May need routing adjustments

### To Eventually Remove
- `ecore/Everything/Delegation/htmlpage.pm` - After all nodetypes migrated

## Testing Strategy

For each nodetype without a specific controller:
1. Test `?displaytype=display` renders correctly
2. Test `?displaytype=edit` redirects to basicedit (or shows appropriate message)
3. Test `?displaytype=xml` returns valid XML
4. Test `?displaytype=xmltrue` returns valid XML with form data

## Current Status

### Completed Migrations
- `debatecomment` - Full controller with display, edit, replyto, compact, atom
- `debate` - Inherits from debatecomment controller
- (93+ other document types migrated to React Page classes)

### Legacy htmlpage Functions Removed
- `debatecomment_display_page`
- `debatecomment_edit_page`
- `debatecomment_replyto_page`
- `debatecomment_compact_page`
- `debatecomment_atom_page`

### Remaining Legacy Functions in htmlpage.pm
- `node_display_page`
- `node_edit_page`
- `node_basicedit_page`
- `fullpage_display_page`
- `node_xml_page`
- `node_xmltrue_page`
- `ajax_update_page`
- (others to be inventoried)

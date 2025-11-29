# Legacy.js to React Migration Plan

**Created:** 2025-11-24
**Last Updated:** 2025-11-28
**Status:** ✅ AJAX POLLING ELIMINATED - Core Migration Complete
**Priority:** Medium (Remaining features are non-critical utilities)
**File Size:** 3,728 lines of jQuery-based JavaScript

## Executive Summary

[legacy.js](../www/js/legacy.js) is the primary JavaScript file for Everything2, containing ~3,700 lines of jQuery-based code that handles AJAX updates, form interactions, and UI enhancements. As part of the React migration, we're systematically moving functionality from legacy.js into React components with modern patterns (hooks, polling, state management).

## 🎉 Major Milestone Achieved (2025-11-28)

**ALL legacy AJAX polling has been eliminated!** The core periodic update system that powered Everything2's real-time features for years has been fully migrated to React.

**What This Means:**
- ✅ **Zero active AJAX polls** - No more `e2.ajax.addList()` calls
- ✅ **Zero periodical updaters** - No more `periodicalUpdater` instances
- ✅ **All nodelets use React** - Modern polling hooks with better performance
- ✅ **Cleaner code** - React hooks are simpler and more maintainable
- ✅ **Better UX** - Faster polling intervals, activity detection, multi-tab coordination

**Remaining Work:** legacy.js still contains ~3,550 lines of:
- Form utilities and enhancements
- Widget system (popups, expandable inputs)
- jQuery extensions and helpers
- Page-specific DOM manipulation
- **None of this is critical path** - Can be migrated incrementally as needed

**Key Insight:** We're using different idle detection methods to track migration progress:
- **Legacy AJAX:** Uses `ajaxIdle=1` query parameter (NO LONGER ACTIVE)
- **React Hooks:** Uses `X-Ajax-Idle: 1` header (ALL ACTIVE POLLING)
- This makes it easy to identify which system is making requests

## What's in Legacy.js

### Core Utilities (Lines 1-120)

**Status:** Mostly Keep (Low priority to migrate)

- `replyToCB()` - Chatterbox reply helper
- `e2URL` - URL parsing and manipulation (jQuery BBQ replacement)
- `e2.tinyMCESettings` - Rich text editor configuration
- `e2.linkparse()` - E2 bracket link parser

**Migration Priority:** Low - These are utilities used by other code

### jQuery Extensions & e2 Namespace (Lines 82-570)

**Status:** Mixed (Some candidates for React hooks)

#### Core e2 Object Extensions
- `e2.fxDuration` - Animation timing
- `e2.isChatterlight` - Chatterlight detection
- `e2.collapsedNodelets` - Nodelet collapse state
- `e2.timeout` - AJAX timeout setting
- `e2.defaultUpdatePeriod` - Polling interval (3.5 minutes)
- `e2.sleepAfter` - Idle timeout (17 minutes)

**Migration Path:** Some of these (collapse state, polling config) should move to React context/hooks

### Form Enhancements (Lines 123-707)

**Status:** Candidates for React components

#### Full Text Search Enhancement (Lines 124-150)
- Adds "Full Text" checkbox to search form
- Redirects to Google Custom Search
- **Migration:** Could be React component

#### Test Drive Link Fix (Lines 148-150)
- Removes `noscript` parameter on focus
- **Migration:** Low priority, simple jQuery

#### e2 Metafunction (Lines 151-570)
Complex selector and activation system:
- `e2(selector)` - jQuery wrapper
- `e2.inclusiveSelect()` - Element selection
- `e2.add()` - Deferred function application
- `e2.activate()` - Run instructions on elements
- `e2.getFocus()` - Focus detection

**Migration:** This is jQuery framework code - keep until all dependent code is migrated

### Widget System (Lines 580-707)

**Status:** Keep for now (Complex infrastructure, used throughout site)

The widget system provides two key UI enhancements used extensively across E2:

#### 1. Expandable Inputs/Textareas (Lines 580-646)

**What it does:** Automatically grows text inputs and textareas as users type

**Classes:**
- `.expandable` - Applied to `<input>` or `<textarea>` elements
- Inputs are replaced with single-row textareas that grow vertically
- Textareas get automatic height adjustment based on content

**Key Features:**
- **Auto-height:** `e2.heightToScrollHeight()` adjusts height to fit content
- **Maxlength enforcement:** Prevents typing beyond limit, handles paste overflow
- **Enter key handling:** For replaced inputs, Enter submits form instead of newline
- **Newline prevention:** In replaced inputs, pasted newlines become spaces
- **Style preservation:** Copies margins, padding, fonts from original input

**Code Location:**
```javascript
// Lines 580-646 in legacy.js
e2('textarea.expandable', expandableTextarea);  // Line 644
e2('input.expandable', expandableInput);        // Line 645
```

**Where Used:**
- **Document editing:** [document.pm](../ecore/Everything/Delegation/document.pm)
  - SQL query textarea
  - Node title inputs
  - Various admin forms

- **Writeup forms:** [htmlcode.pm](../ecore/Everything/Delegation/htmlcode.pm)
  - Message composition (`writeupmessage`)
  - Note text input (255 char limit)
  - Category creation
  - Node locking reason
  - Reply-to-message input (1234 char limit)

- **Chatterbox:** [htmlpage.pm](../ecore/Everything/Delegation/htmlpage.pm)
  - Message input (512 char limit with `onfocus` maxlength)

**Migration Strategy:**
- **Phase 1:** Create React `<AutoExpandTextarea>` component
- **Phase 2:** Migrate high-traffic areas (chatterbox, messages)
- **Phase 3:** Migrate admin forms
- **Phase 4:** Remove jQuery implementation

**React Equivalent:**
```javascript
// Future React component pattern
import { useRef, useEffect } from 'react'

const AutoExpandTextarea = ({ value, onChange, maxLength, ...props }) => {
  const textareaRef = useRef(null)

  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
      textareaRef.current.style.height = `${textareaRef.current.scrollHeight}px`
    }
  }, [value])

  const handleChange = (e) => {
    if (maxLength && e.target.value.length > maxLength) {
      e.target.value = e.target.value.substr(0, maxLength)
    }
    onChange(e)
  }

  return <textarea ref={textareaRef} value={value} onChange={handleChange} {...props} />
}
```

#### 2. Popup Widgets (Lines 648-703)

**What it does:** Creates collapsible popup panels that appear below trigger links

**Classes:**
- `.showwidget` - Applied to trigger links (opener)
- `.widget` - Applied to the popup content container
- `.open` / `.closed` - State classes added to opener

**How It Works:**
1. **Opener Link:** `<a class="showwidget">Show Options</a>`
2. **Widget Container:** `<div class="widget" style="visibility:hidden">...</div>`
3. **JavaScript:** Finds widget (sibling, parent sibling, or parent) and positions it
4. **Positioning:** Absolutely positioned below opener, aligned left or right to fit window
5. **Animation:** Slides open/closed (jQuery `slideToggle`, except IE8 which uses display toggle)

**Widget Creation (Perl):**
```perl
# ecore/Everything/Delegation/htmlcode.pm - sub widget (lines 12035-12090)

htmlcode('widget',
  $content,              # Widget content (HTML)
  $tagname,             # Container tag ('div', 'span', 'form')
  $linktext,            # Opener link text
  {
    showwidget => 'uniqueID',        # Required: unique identifier
    -title => 'Click to show',       # Opener title attribute
    -closetitle => 'hide',           # Close button title (default: 'hide')
    node => $NODE                     # Node for noscript fallback (default: current)
  }
);
```

**Where Used:**

##### Cool Writeup Details
```perl
# htmlcode.pm - showCs{node_id} widgets
htmlcode('widget', $coolers, 'span', $coolnum, {
  showwidget => 'showCs'.$$N{node_id},
  -title => 'show who gave the C!s',
  -closetitle => 'hide cools'
})
```
**Purpose:** Shows list of users who "cooled" a writeup
**Trigger:** Click cool count number
**Location:** Writeup display page

##### Add to Category/Usergroup
```perl
# htmlcode.pm - addto{node_id} widgets
htmlcode('widget', $form, 'form', 'add', {
  showwidget => 'addto'.$$WRITEUP{node_id},
  -title => 'add to category or usergroup page'
})
```
**Purpose:** Form to add writeup to category or usergroup
**Trigger:** Click "add" link
**Location:** Writeup actions

##### Category Form (in writeups)
```perl
# htmlcode.pm - category widgets
htmlcode('widget', $categoryform, 'form', 'add to category', {
  showwidget => 'category',
  -title => 'add to category'
})
```
**Purpose:** Category selection form
**Trigger:** Click "add to category"
**Location:** Writeup actions in main form

##### Weblog Form (in writeups)
```perl
# htmlcode.pm - weblog widgets
htmlcode('widget', $weblog_form, 'form', 'add to usergroup', {
  showwidget => 'weblog',
  -title => 'add to usergroup page'
})
```
**Purpose:** Usergroup page selection form
**Trigger:** Click "add to usergroup"
**Location:** Writeup actions in main form

##### Admin Options
```perl
# htmlcode.pm - admin widget
htmlcode('widget', join('<hr>', @admin_options), 'span', 'admin', {
  showwidget => 'admin',
  -title => 'Click here to show/hide admin options'
})
```
**Purpose:** Admin action forms
**Trigger:** Click "admin" link
**Location:** Various admin contexts

##### Message Actions
```perl
# htmlcode.pm - messageID widgets
# Two types: regular message widget + delete confirmation widget
{
  showwidget => $messageID,           # Show message details
  showwidget => "deletemsg_$messageID" # Delete confirmation
}
```
**Purpose:** Message reply/delete forms
**Trigger:** Click message action links
**Location:** Private messages

##### Document Options
```perl
# document.pm - optionsform widget
{ showwidget => 'optionsform' }
```
**Purpose:** Document settings form
**Trigger:** Click options link
**Location:** Special documents (superdocs, etc.)

**Technical Details:**

**Positioning Algorithm (lines 693-702):**
```javascript
function adjust(widget) {
  // Position directly under opener
  widget.style.top = widget.openedBy.offsetHeight + 'px'

  // Align left edge with opener
  var adjust = opener.offset().left - widget.offset().left
  widget.css('left', adjust)

  // If overflows right edge of window, shift left via margin
  adjust = $(window).width() - widget.offset().left - widget.outerWidth(true)
  if (adjust < 0) widget.css('margin-left', adjust)
}
```

**State Management:**
- `widget.openedBy` - Reference to opener link
- `widget.targetwidget` - Bidirectional reference from opener to widget
- `this.className` - Toggle 'open'/'closed' classes
- `widget.style.display` - Toggle 'block'/'none'

**URL Parameter Integration:**
- `?showwidget=uniqueID` opens widget on page load
- Used for noscript fallback and direct linking
- JavaScript removes parameter after opening

**Migration Strategy:**

**Phase 1: Analysis (Current)**
- [x] Document all widget locations
- [ ] Count widget instances across codebase
- [ ] Identify high-traffic vs low-traffic widgets

**Phase 2: High-Priority Widgets → React**
- [ ] Cool writeup details → React modal/dropdown
- [ ] Category/usergroup forms → React components
- [ ] Message actions → React components

**Phase 3: Medium-Priority Widgets**
- [ ] Admin options → React admin panel
- [ ] Document options → React settings

**Phase 4: Complete Removal**
- [ ] Remove widget htmlcode
- [ ] Remove jQuery widget system
- [ ] Update all widget callers

**React Patterns for Migration:**

**Pattern 1: Modal Dialog**
```javascript
// For complex forms (add to category, admin options)
const [showModal, setShowModal] = useState(false)
return (
  <>
    <button onClick={() => setShowModal(true)}>Options</button>
    <Modal open={showModal} onClose={() => setShowModal(false)}>
      {/* Widget content */}
    </Modal>
  </>
)
```

**Pattern 2: Dropdown/Popover**
```javascript
// For simple lists (cool details, quick actions)
const [anchorEl, setAnchorEl] = useState(null)
return (
  <>
    <button onClick={(e) => setAnchorEl(e.currentTarget)}>Show</button>
    <Popover
      open={Boolean(anchorEl)}
      anchorEl={anchorEl}
      onClose={() => setAnchorEl(null)}
    >
      {/* Widget content */}
    </Popover>
  </>
)
```

**Pattern 3: Accordion/Collapsible**
```javascript
// For in-page sections (document options)
const [expanded, setExpanded] = useState(false)
return (
  <div>
    <button onClick={() => setExpanded(!expanded)}>
      {expanded ? 'Hide' : 'Show'} Options
    </button>
    {expanded && <div>{/* Widget content */}</div>}
  </div>
)
```

**Migration Priority:** Medium
- Used extensively (20+ instances)
- But not user-facing critical path
- Good candidate for batch migration
- Modern UX patterns (modals, dropdowns) are better

**Migration Notes:**
- Widgets are server-side rendered with noscript fallback
- React migration will be client-side only initially
- Need API endpoints for widget content (some already exist)
- Consider modern UX alternatives (modals, dropdowns, slide-outs)

### Form Validation & Unload Warnings (Lines 707-850)

**Status:** Mixed

#### Edit Prevention (Lines 707-763)
- Prevents editing readonly textareas
- **Migration:** Could use React `readOnly` prop

#### Unload Warnings (Lines 764-850)
- `e2.beforeunload` system
- Warns users about unsaved changes
- **Migration:** React hook `useBeforeUnload()`

### AJAX System (Lines 851-1400)

**Status:** MIGRATING TO REACT ✓

This is the heart of legacy.js - the AJAX polling and update system.

#### Core AJAX Functions

##### `e2.ajax.htmlcode()` (Lines 897-951)
Calls htmlcodes via AJAX
- Handles query parameters and htmlcode args
- Sets `ajaxIdle` query parameter for idle requests *(Legacy method - intentionally kept)*
- **Status:** Keep for now (used by remaining legacy code)

##### `e2.ajax.set()` (Lines 953-982)
Sets variables via AJAX
- Calls `ajaxVar` htmlcode
- **Migration:** Most var setting moved to React state/API calls

##### `e2.ajax.pending` (Lines 910-911)
Tracks pending AJAX requests
- **Migration:** React hooks manage their own request state

#### List Management System (Lines 984-1157)

**What it does:** Periodic polling for dynamic content updates

##### `e2.ajax.addList()` (Lines 984-1036)
Registers lists for periodic updates
```javascript
e2.ajax.addList('chatterbox_messages', {
  getJSON: 'showmessages',
  period: 23,  // seconds
  ascending: true
})
```

##### `e2.ajax.lists` Object
Stores configuration for all AJAX-updated lists

##### `e2.ajax.updateList()` (Lines 1038-1095)
Fetches and updates list content
- Calls getJSON htmlcode
- Merges new items into existing list
- Handles item IDs and removal

##### `e2.ajax.removeListItem()` (Lines 1097-1107)
Marks items for removal

### Periodic Update System (Lines 1159-1290)

**Status:** MIGRATING TO REACT ✓

#### `e2.ajax.periodicalUpdater` Class (Lines 1159-1290)

**What it does:** Polls server for content updates, with sleep/wake behavior

**Key Features:**
- Polls every N seconds (configured per instance)
- Sleeps after 17 minutes of inactivity
- Wakes on user activity (mouse, keyboard, scroll, touch)
- Sets `ajaxIdle=1` for background requests *(Legacy method)*

**Migration Status:**
- ✅ **MIGRATED:** Chatterbox (replaced with `useChatterPolling` + `useActivityDetection`)
- ✅ **MIGRATED:** Other Users (replaced with `useOtherUsersPolling`)
- ❌ **PENDING:** Other periodic updaters (if any remain)

**React Replacement Pattern:**
```javascript
// Old (legacy.js)
new e2.ajax.periodicalUpdater('chatterbox:updateNodelet:chatterbox')

// New (React hooks)
import { useChatterPolling } from './hooks/useChatterPolling'
const { chatter, loading, error } = useChatterPolling(3000)
```

### Chatterbox AJAX (Lines 1291-1367)

**Status:** ✅ MIGRATED TO REACT (2025-11-24)

#### What Was Here:
- `e2.ajax.addList('chatterbox_messages')` - Message list polling
- `e2.ajax.addList('chatterbox_chatter')` - Chatter list polling
- Both used 23-second polling intervals

#### Migration:
- **React Component:** [react/components/Nodelets/Chatterbox.js](../react/components/Nodelets/Chatterbox.js)
- **Polling Hook:** [react/hooks/useChatterPolling.js](../react/hooks/useChatterPolling.js)
- **Activity Detection:** [react/hooks/useActivityDetection.js](../react/hooks/useActivityDetection.js)
- **API Endpoints:** `/api/chatter/` (GET), `/api/chatter/create` (POST)
- **Idle Detection:** Uses `X-Ajax-Idle: 1` header *(New React method)*

#### Benefits of Migration:
- 3-second polling (instead of 23 seconds)
- Incremental updates with `since` parameter
- Activity-based sleep/wake (10 minutes)
- Multi-tab coordination
- Clean separation of concerns

### Other Users AJAX (Lines 1368-1371)

**Status:** ✅ MIGRATED TO REACT (2025-11-24)

#### What Was Here:
```javascript
new e2.ajax.periodicalUpdater('otherusers:updateNodelet:Other+Users')
```

#### Migration:
- **React Component:** [react/components/Nodelets/OtherUsers.js](../react/components/Nodelets/OtherUsers.js)
- **Polling Hook:** [react/hooks/useOtherUsersPolling.js](../react/hooks/useOtherUsersPolling.js)
- **API Endpoint:** `/api/chatroom/` (GET)
- **Polling Interval:** 2 minutes (120 seconds)
- **Idle Detection:** Uses `X-Ajax-Idle: 1` header *(New React method)*

### Remaining Legacy.js Content (Lines 1372-3724)

**Status:** Not yet analyzed in detail

Estimated content based on file structure:
- Form helpers and utilities
- Page-specific enhancements
- DOM manipulation
- Event handlers
- Validation logic
- UI interactions

**Action Item:** Detailed analysis needed of remaining ~2,350 lines

## AJAX Htmlcodes Catalog

**Purpose:** This section catalogs all htmlcodes called via AJAX in the legacy system, helping identify what needs API endpoints during React migration.

**AJAX Pattern Format:**
```
class="ajax targetID:htmlcodeName?param1=/field1&param2=/field2:arg1,arg2"
```

- `targetID` - Element to update with response
- `htmlcodeName` - Perl htmlcode function to call
- `?params` - Query parameters (/ means read from form field)
- `:args` - Arguments passed to htmlcode

### Nodelet Updates

| Htmlcode | Purpose | Status | Migration Path |
|----------|---------|--------|----------------|
| `updateNodelet` | Refresh entire nodelet | ✅ **DEPRECATED** | Use React polling hooks |
| `chatterbox:updateNodelet` | Refresh chatterbox | ✅ **MIGRATED** | `useChatterPolling` hook + `/api/chatter/` |
| `chatterlight_rooms:updateNodelet` | Refresh chatterlight rooms | ❌ Pending | Create API endpoint |

**Note:** `updateNodelet` was the old way to refresh nodelets via AJAX. Being replaced by React polling hooks.

### Writeup Actions

| Htmlcode | Purpose | Status | Migration Path |
|----------|---------|--------|----------------|
| `writeupcools` | Show who cooled writeup | ❌ Pending | `/api/writeups/{id}/cools` GET |
| `ilikeit` | Like/unlike writeup | ❌ Pending | `/api/writeups/{id}/like` POST |
| `coolit` | Cool writeup (editors) | ❌ Pending | `/api/writeups/{id}/cool` POST |
| `bookmarkit` | Bookmark writeup | ❌ Pending | `/api/bookmarks/` POST/DELETE |
| `listnodecategories` | List categories for node | ❌ Pending | `/api/nodes/{id}/categories` GET |
| `categoryform` | Add to category form handler | ❌ Pending | `/api/categories/{id}/add` POST |
| `weblogform` | Add to usergroup form handler | ❌ Pending | `/api/usergroups/{id}/add` POST |

**Pattern Example:**
```perl
# Cool writeup details widget
class="ajax cools123456:writeupcools:123456"
# On click: calls writeupcools(node_id=123456), updates element with ID "cools123456"
```

### Draft Management

| Htmlcode | Purpose | Status | Migration Path |
|----------|---------|--------|----------------|
| `drafttools` | Draft action buttons | ❌ Pending | `/api/drafts/{id}/actions` |
| `setdraftstatus` | Change draft status | ❌ Pending | `/api/drafts/{id}/status` PATCH |
| `parentdraft` | Set parent e2node for draft | ❌ Pending | `/api/drafts/{id}/parent` PATCH |
| `ajax+publishhere` | Publish draft to current e2node | ❌ Pending | `/api/drafts/{id}/publish` POST |

**Usage Context:** Draft editor page, review queue, neglected drafts nodelet

**Pattern Example:**
```perl
# Set draft status
class="ajax draftstatus123:setdraftstatus?node_id=123&advanced=1:123"
# Changes draft status with advanced options
```

### Message System

| Htmlcode | Purpose | Status | Migration Path |
|----------|---------|--------|----------------|
| `messageBox` | Reply to message form | ❌ Pending | `/api/messages/` POST (create reply) |
| `confirmDeleteMessage` | Delete message confirmation | ❌ Pending | `/api/messages/{id}` DELETE |

**Usage Context:** Private messages page, message inbox

**Pattern Example:**
```perl
# Reply to message
class="ajax replyto456:messageBox:123,0,456,0"
# Args: user_id, show_cc, message_id, usergroup_id
```

### Admin/Editor Functions

| Htmlcode | Purpose | Status | Migration Path |
|----------|---------|--------|----------------|
| `nodenote` | Add/update node notes | ✅ **MIGRATED** | `/api/nodenotes/` POST/DELETE (exists) |
| `ordernode` | Lock/unlock node ordering | ❌ Pending | `/api/nodes/{id}/orderlock` POST |
| `ajaxEcho` | Generic confirmation echo | ❌ Pending | Handle in React (local feedback) |
| `homenodeinfectedinfo` | Cure borgification | ❌ Pending | `/api/users/{id}/cure` POST |
| `sanctify` | Mark user as not borged | ❌ Pending | `/api/users/{id}/sanctify` POST |
| `favorite_noder` | Add/remove favorite noder | ❌ Pending | `/api/favorites/noders` POST/DELETE |

**Usage Context:** Master Control nodelet, admin tools, editor functions

**Pattern Example:**
```perl
# Add node note
class="ajax nodenotes:nodenote:123"
# Calls nodenote htmlcode with node_id=123
```

### AJAX Htmlcode Implementation Patterns

**Server-Side (Perl):**
```perl
# ecore/Everything/Delegation/htmlcode.pm

sub myHtmlcode {
  my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

  # Process request
  my $result = doSomething();

  # Return HTML fragment
  return "<div>$result</div>";
}
```

**Client-Side (legacy.js):**
```javascript
// When element with class "ajax foo:myHtmlcode:arg" is clicked:
// 1. Extracts htmlcode name and args
// 2. Calls e2.ajax.htmlcode('myHtmlcode', {args: 'arg'})
// 3. Updates element with ID "foo" with response HTML
```

**React Migration Pattern:**
```javascript
// 1. Create API endpoint
// ecore/Everything/API/myfeature.pm
sub my_action {
  my ($self, $REQUEST) = @_;
  my $result = doSomething();
  return [$self->HTTP_OK, { result => $result }];
}

// 2. Create React component
const MyComponent = () => {
  const handleAction = async () => {
    const response = await fetch('/api/myfeature/my_action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: 'value' })
    })
    const result = await response.json()
    // Update state
  }
  return <button onClick={handleAction}>Do Something</button>
}
```

### AJAX Usage Statistics

**By Category:**
- Writeup Actions: 7 htmlcodes
- Draft Management: 4 htmlcodes
- Message System: 2 htmlcodes
- Admin/Editor: 6 htmlcodes
- Nodelet Updates: 3 htmlcodes (2 deprecated)

**Total: 22 unique AJAX htmlcodes** actively used

**Migration Status:**
- ✅ Migrated: 2 (9%)
- ✅ Deprecated: 2 (9%)
- ❌ Pending: 18 (82%)

### Discovery Commands

```bash
# Find all AJAX class usage
grep -rh "class.*ajax" ecore/Everything/Delegation/ --include="*.pm" | \
  grep -oP 'ajax [^"'\'':]+ :[^"'\'':]+' | sort -u

# Find specific htmlcode definition
grep -n "^sub myHtmlcode" ecore/Everything/Delegation/htmlcode.pm

# Find all callers of htmlcode
grep -r "myHtmlcode" ecore/ --include="*.pm"

# Find legacy.js AJAX handlers
grep -n "e2.ajax" www/js/legacy.js
```

## Migration Status Tracking

### ✅ Completed Migrations

| Feature | Lines Removed | Migration Date | New Location |
|---------|--------------|----------------|--------------|
| Chatterbox AJAX | ~170 | 2025-11-24 | `react/components/Nodelets/Chatterbox.js` |
| Chatterbox Polling | N/A | 2025-11-24 | `react/hooks/useChatterPolling.js` |
| Other Users Polling | ~4 | 2025-11-24 | `react/hooks/useOtherUsersPolling.js` |
| Activity Detection | N/A | 2025-11-24 | `react/hooks/useActivityDetection.js` |

**Total Lines Migrated:** ~174 lines
**Total Lines Remaining:** ~3,550 lines
**Progress:** 4.7% complete

### ❌ Pending Migrations

#### High Priority (Active/Visible Features)

1. **Message System** (Lines TBD)
   - Private messages
   - Message list updates
   - Message actions

2. **Form Enhancements** (Various)
   - Form validation
   - Unload warnings
   - Input widgets

3. **Search Enhancements** (Lines 124-150)
   - Full text search checkbox
   - Form manipulation

#### Medium Priority (Background Features)

4. **AJAX Infrastructure** (Lines 851-982)
   - `e2.ajax.htmlcode()` - Keep until all callers migrated
   - `e2.ajax.set()` - Migrate variable setting to API
   - `e2.ajax.pending` - Remove once no dependencies

5. **List Management** (Lines 984-1157)
   - Generic list updating system
   - May have remaining users

#### Low Priority (Utilities)

6. **URL Parsing** (Lines 21-78)
   - `e2URL` class
   - Replace with native `URL` API when needed

7. **Core Utilities** (Lines 1-120)
   - `replyToCB()` - Chatterbox helper
   - `e2.linkparse()` - Link parsing
   - Keep until all references removed

8. **jQuery Extensions** (Lines 151-570)
   - `e2()` metafunction
   - Keep as compatibility layer

## React Migration Patterns

### Pattern 1: Periodic Polling → React Hook

**When to use:** Content that updates periodically without user action

**Example:** Chatterbox, Other Users

**Steps:**
1. Create custom hook (e.g., `useFooPolling`)
2. Use `useEffect` with interval
3. Integrate `useActivityDetection` for sleep/wake
4. Use `X-Ajax-Idle: 1` header
5. Remove from legacy.js

**Template:**
```javascript
export const useFooPolling = (pollIntervalMs = 60000) => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const { isActive, isMultiTabActive } = useActivityDetection(10)

  const fetchData = async () => {
    try {
      const response = await fetch('/api/foo/', {
        headers: { 'X-Ajax-Idle': '1' },
        credentials: 'same-origin'
      })
      const data = await response.json()
      setData(data)
      setLoading(false)
    } catch (err) {
      setError(err.message)
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [])

  useEffect(() => {
    if (!isActive || !isMultiTabActive || loading) return

    const interval = setInterval(fetchData, pollIntervalMs)
    return () => clearInterval(interval)
  }, [isActive, isMultiTabActive, loading, pollIntervalMs])

  return { data, loading, error }
}
```

### Pattern 2: Form Enhancement → React Component

**When to use:** DOM manipulation for forms

**Steps:**
1. Create React component
2. Use controlled inputs
3. Handle events in React
4. Remove jQuery code

### Pattern 3: AJAX Call → API Endpoint + fetch

**When to use:** User-triggered AJAX requests

**Steps:**
1. Create REST API endpoint
2. Use `fetch()` in React
3. Handle response with state
4. Remove `e2.ajax.*` call

### Pattern 4: DOM Manipulation → React State

**When to use:** Dynamic UI updates

**Steps:**
1. Identify state being manipulated
2. Move to React `useState`
3. Render based on state
4. Remove jQuery selectors

## Idle Detection Strategy

**Current System (Intentional):**

We're using TWO different methods to track migration progress:

### Legacy AJAX (Query Parameter)
```javascript
ajax.data.ajaxIdle = 1  // Query parameter
// Request: /ajax?htmlcode=foo&ajaxIdle=1
```

### React Hooks (HTTP Header)
```javascript
headers: { 'X-Ajax-Idle': '1' }
// Request: /api/foo/ with header X-Ajax-Idle: 1
```

**Why Both?**

This dual system allows us to:
1. **Track migration progress** - See which requests are from legacy vs React
2. **Identify legacy code** - Any request with `ajaxIdle=1` query param is legacy
3. **Identify React code** - Any request with `X-Ajax-Idle: 1` header is modern
4. **No conflicts** - Both methods work simultaneously during migration

**Backend Support:**

[ecore/Everything/Request.pm](../ecore/Everything/Request.pm) lines 171-174:
```perl
# Skip lastseen update for background/idle requests
# Supports both query parameter (ajaxIdle=1) and header (X-Ajax-Idle: 1)
my $is_idle_request = $self->param('ajaxIdle') || $ENV{HTTP_X_AJAX_IDLE};
return $user if !$user || $user->is_guest || $is_idle_request;
```

## Burndown List

### Phase 1: Periodic Updates (CURRENT)
- [x] Chatterbox messages
- [x] Chatterbox chatter
- [x] Other Users
- [ ] Identify remaining periodicalUpdater instances
- [ ] Messages/notifications (if applicable)

**Target:** End of current sprint
**Lines Remaining:** ~170 in this category (estimate)

### Phase 2: User-Triggered AJAX
- [ ] Form submissions via AJAX
- [ ] Variable setting (`e2.ajax.set`)
- [ ] Htmlcode calls (`e2.ajax.htmlcode`)
- [ ] List operations

**Target:** Next 2-3 sprints
**Lines Remaining:** ~400 (estimate)

### Phase 3: Form Enhancements
- [ ] Full text search checkbox
- [ ] Form validation
- [ ] Unload warnings
- [ ] Input widgets
- [ ] Expandable fields

**Target:** Q1 2026
**Lines Remaining:** ~500 (estimate)

### Phase 4: Utilities & Core
- [ ] URL parsing (`e2URL`)
- [ ] Link parsing (`e2.linkparse`)
- [ ] jQuery extensions
- [ ] e2 metafunction
- [ ] Focus management
- [ ] Misc helpers

**Target:** Q2 2026
**Lines Remaining:** ~2,000+ (estimate)

### Phase 5: Complete Removal
- [ ] Remove legacy.js entirely
- [ ] Remove jQuery dependency
- [ ] Clean up asset pipeline
- [ ] Update documentation

**Target:** Q3 2026

## Performance Impact

### Current State
- **File Size:** ~120 KB unminified
- **Minified:** ~60 KB
- **Gzipped:** ~20 KB
- **Loaded:** Every page load
- **Execution:** jQuery + legacy code runs on every page

### Expected Final State
- **React Bundle:** Handles all UI
- **Legacy.js:** Removed entirely
- **Page Weight:** -20 KB gzipped per page
- **Execution:** Only React components needed for page
- **Benefits:**
  - Code splitting (load only what's needed)
  - Modern React patterns
  - Better developer experience
  - Easier testing

## Testing Strategy

### During Migration

1. **Parallel Operation**
   - Old and new code run side-by-side
   - Feature flags control which is active
   - Compare behavior

2. **Idle Detection Tracking**
   - Monitor `ajaxIdle=1` vs `X-Ajax-Idle: 1`
   - Identify remaining legacy requests
   - Measure migration progress

3. **React Testing**
   - Jest tests for all new components
   - Integration tests for API endpoints
   - Verify feature parity with old code

### After Complete Migration

1. **Remove legacy.js reference** from htmlcode.pm
2. **Remove from asset pipeline**
3. **Monitor error rates**
4. **Performance regression testing**

## Documentation

### Files to Create/Update

- [x] This document (legacy-js-to-react-migration.md)
- [ ] Individual migration docs for each major feature
- [ ] API endpoint documentation
- [ ] React hooks documentation
- [ ] Testing guide updates

### Files to Reference

- [docs/react-migration-strategy.md](react-migration-strategy.md) - Overall React migration
- [docs/nodelet-migration-status.md](nodelet-migration-status.md) - Nodelet-specific progress
- [docs/message-chatter-system.md](message-chatter-system.md) - Message/chatter architecture
- [docs/inline-javascript-modernization.md](inline-javascript-modernization.md) - Inline JS in Perl code

## Quick Reference

### Find Legacy AJAX Calls

```bash
# Find ajaxIdle query parameter (legacy method)
grep -n "ajaxIdle" www/js/legacy.js

# Find periodicalUpdater instances
grep -n "periodicalUpdater" www/js/legacy.js

# Find e2.ajax calls
grep -n "e2\.ajax\." www/js/legacy.js
```

### Find React Polling Hooks

```bash
# Find polling hooks
find react/hooks -name "*Polling.js"

# Find API endpoints
find ecore/Everything/API -name "*.pm"

# Find X-Ajax-Idle header usage
grep -r "X-Ajax-Idle" react/
```

### Monitor Migration Progress

```bash
# Count lines in legacy.js (track over time)
wc -l www/js/legacy.js

# Count React test files
find react -name "*.test.js" | wc -l

# See what's migrated
git log --oneline --grep="MIGRATED\|React\|polling" --since="2025-11-01"
```

## Next Steps

### Immediate (This Week)
1. ✅ Document legacy.js structure (this doc)
2. ✅ Create burndown list (this doc)
3. ✅ Commit Other Users migration
4. [ ] Search for remaining periodicalUpdater instances
5. [ ] Identify next highest-priority migration target

### Short Term (Next 2 Weeks)
1. [ ] Analyze lines 1372-3724 of legacy.js in detail
2. [ ] Create migration plan for form enhancements
3. [ ] Identify all e2.ajax.htmlcode() callers
4. [ ] Plan AJAX infrastructure migration
5. [ ] Create React component templates for common patterns

### Medium Term (Next Month)
1. [ ] Migrate 2-3 more major features to React
2. [ ] Reduce legacy.js by 500+ lines
3. [ ] Increase React test coverage
4. [ ] Document all new patterns
5. [ ] Update CLAUDE.md with progress

## Success Criteria

**Migration Complete When:**
- [ ] legacy.js is 0 lines (removed entirely)
- [ ] All periodic updates use React hooks
- [ ] All AJAX uses fetch() or React Query
- [ ] All forms are React components
- [ ] jQuery is removed from dependencies
- [ ] All tests passing (443+ React tests)
- [ ] No performance regressions
- [ ] Documentation complete

---

**Document Status:** Initial version
**Last Updated:** 2025-11-24
**Lines Migrated:** 174 / 3,724 (4.7%)
**Next Review:** 2025-12-01

# Everything2 AJAX Update System Analysis

**Status**: ✅ FULLY MIGRATED - All legacy polling eliminated
**Last Updated**: 2026-01-07

## Executive Summary

The ajaxUpdate system was a legacy AJAX framework that handled real-time updates for chatterbox messages, notifications, votes, and other dynamic content. **All functionality has been successfully migrated to React** as of November 2025.

**Completed Improvements**:
1. ✅ eval() calls replaced with direct delegation (message, vote opcodes)
2. ✅ Notifications migrated to React Notifications nodelet
3. ✅ Chatterbox messages migrated to React Chatterbox nodelet
4. ✅ Chatterbox chatter migrated to React Chatterbox nodelet
5. ✅ Messages migrated to React Messages nodelet
6. ✅ Other Users polling migrated to React OtherUsers nodelet
7. ✅ `notificationsJSON` htmlcode deleted
8. ✅ `ajaxMarkNotificationSeen` htmlcode deleted
9. ✅ `showmessages` htmlcode deleted
10. ✅ `showchatter` htmlcode deleted
11. ✅ `testshowmessages` htmlcode stubbed (deletion pending)
12. ✅ Removed 6 unused ajax_update modes: `update`, `getlastmessage`, `checkCools`, `checkMessages`, `checkFeedItems`, `deleteFeedItem` (2025-12-07)
13. ✅ `coolsJSON` htmlcode deleted (2026-01-07)
14. ✅ `ilikeit` migrated to React API endpoint `/api/ilikeit` (2026-01-07)

**Remaining Legacy AJAX**: NONE - All polling systems migrated to React

## ajax_update Mode Status

### Removed Modes (2025-12-07)

The following modes were removed as they had no frontend callers:

| Mode | Reason | Replacement |
|------|--------|-------------|
| `getlastmessage` | Not called by frontend | React Chatterbox manages message IDs internally |
| `update` | Already retired | Was returning error message |
| `checkCools` | Not called by frontend | React manages cool nodes via initial page data |
| `checkMessages` | Not called by frontend | React Messages nodelet uses /api/messages |
| `checkFeedItems` | Not called by frontend | User feed feature unused/deprecated |
| `deleteFeedItem` | Not called by frontend | User feed feature unused/deprecated |

### Previously Removed (2025-11-27)

| Mode | Replacement |
|------|-------------|
| `markNotificationSeen` | /api/notifications/dismiss |
| `checkNotifications` | React Notifications nodelet |

### Active Modes (Still In Use)

| Mode | Usage | Notes |
|------|-------|-------|
| `message` | Chatterbox message sending | Only remaining mode in ajax_update |

### Removed/Migrated Modes

| Mode | Replacement | Notes |
|------|-------------|-------|
| `vote` | `/api/vote/writeup/:id` | React WriteupDisplay handles voting |
| `getNodeInfo` | Removed | No longer called |
| `annotate` | Removed | No longer called |

### Future Cleanup

1. ✅ **DONE**: `coolsJSON` htmlcode removed (2026-01-07)
2. ✅ **DONE**: `vote` mode removed - React uses `/api/vote` instead
3. **Next**: Remove `userFeedJSON` htmlcode (no longer called)
4. **Next**: Remove `message` mode - React Chatterbox uses `/api/chatter/create`
5. **Future**: Remove ajax_update function entirely when message mode migrated

---

## System Architecture

### 1. Client-Side Layer (legacy.js)

**Location**: `www/js/legacy.js` (lines 891-1281)

The `e2.ajax` object provides the client-side AJAX interface:

#### Core Functions:

**`e2.ajax.htmlcode(htmlcode, params, callback, pendingId)`** (lines 897-933)
- Primary function for making AJAX requests
- Sets `displaytype: 'ajaxupdate'` to route to the ajax handler
- Sends requests to the server with htmlcode name and parameters
- Handles success/failure callbacks
- Looks for `<!-- AJAX OK` marker in response to validate success

**`e2.ajax.update(id, htmlcode, args, replaceID, callback)`** (lines 935-954)
- Updates a DOM element by ID with server-rendered content
- Calls `e2.ajax.htmlcode()` internally
- Can replace entire element or just inner HTML

**`e2.ajax.varChange(name, value, callback)`** (lines 956-960)
- Updates user variable on server
- Calls htmlcode 'ajaxVar' with name,value parameters

**`e2.ajax.starRateNode(node_rate, weight, seed, nonce)`** (lines 962-971)
- Handles star rating submissions
- Uses operation-based routing (op: "starRate")

#### List Management System (lines 1013-1090)

Manages dynamic lists of content (chatterbox, notifications, etc.):
- `e2.ajax.lists` - Registry of list specifications
- `e2.ajax.addList()` - Registers a list container
- `e2.ajax.listManager()` - Periodical updater for lists
- `e2.ajax.updateList()` - Fetches and updates list items
- `e2.ajax.insertListItem()` - Adds items to lists with timestamp sorting
- `e2.ajax.removeListItem()` - Removes list items with fade animation

#### Active Lists in Use (Current as of 2025-11-28):

1. ~~**notifications_list**~~ - **MIGRATED** to React Notifications nodelet ✅
2. ~~**chatterbox_messages**~~ - **MIGRATED** to React Chatterbox nodelet ✅
3. ~~**messages_messages**~~ - **MIGRATED** to React Messages nodelet ✅
4. ~~**chatterbox_chatter**~~ - **MIGRATED** to React Chatterbox nodelet ✅

**All legacy AJAX lists have been migrated to React!**

#### Periodical Updaters:

- ~~**Other Users**~~ - **MIGRATED** to React OtherUsers nodelet (2-minute polling) ✅

**All periodical updaters have been migrated to React!**

---

### 2. Routing Layer (Everything::HTML)

**Location**: `ecore/Everything/HTML.pm`

**Key Routing Logic** (line 802-813):
```perl
my $displaytype = $query->param('displaytype');
my $PAGE = getPage($NODE, $displaytype);

if($Everything::ROUTER->can_route($NODE, $displaytype)) {
    $Everything::ROUTER->route_node($NODE, $displaytype || 'display', $REQUEST);
}
```

When `displaytype=ajaxupdate`:
1. `getPage()` looks for an htmlpage with `displaytype='ajaxupdate'`
2. Finds "ajax update page" (node_id: 2009848)
3. Routes to the delegated fullpage function for that htmlpage

---

### 3. Server-Side Handler (ajax update page)

**Location**: `nodepack/htmlpage/ajax_update_page.xml`

```xml
<displaytype>ajaxupdate</displaytype>
<mimetype>application/json</mimetype>
<title>ajax update page</title>
```

This htmlpage delegates to the `ajax_update` function in `Everything::Delegation::document`.

---

### 4. Main Handler Function (ajax_update)

**Location**: `ecore/Everything/Delegation/document.pm` (lines 22670-22782)

The ajax_update function routes to different handlers based on the `mode` parameter.

---

## AJAX List Attachment Points

This section documents where each AJAX-enabled list and periodical updater is attached in the codebase, showing which nodelets and pages contain these dynamic elements.

### 1. ~~Notifications List~~ (`notifications_list`) - ✅ MIGRATED

**Status**: **COMPLETELY MIGRATED TO REACT** (2025-11-27)

**Old System** (REMOVED):
- Legacy AJAX polling every 45 seconds
- Used `notificationsJSON` htmlcode (DELETED)
- Used `ajaxMarkNotificationSeen` htmlcode (DELETED)

**New System** (ACTIVE):
- **Component**: `react/components/Nodelets/Notifications.js`
- **API**: `GET /api/notifications` (fetch new notifications)
- **API**: `POST /api/notifications/dismiss` (dismiss notifications)
- **Polling**: React hooks with idle detection
- **Rendering**: Application::getRenderedNotifications()

**Migration Complete**: All functionality replaced

---

### 2. ~~Chatterbox Messages List~~ (`chatterbox_messages`) - ✅ MIGRATED

**Status**: **COMPLETELY MIGRATED TO REACT** (2025-11-27)

**Old System** (REMOVED):
- Legacy AJAX polling every 23 seconds
- Used `showmessages` htmlcode
- Displayed in `<div id="chatterbox_messages">`

**New System** (ACTIVE):
- **Component**: `react/components/Nodelets/Chatterbox.js` → `MessageList.js`
- **API**: `GET /api/messages` (fetch messages)
- **API**: `POST /api/messages/archive` (archive messages)
- **Polling**: React hooks (useChatterPolling.js) with activity detection
- **Rendering**: Integrated into React Chatterbox component

**Migration Complete**: All functionality replaced, including archive/delete actions

---

### 3. ~~Messages List~~ (`messages_messages`) - ✅ MIGRATED

**Status**: **COMPLETELY MIGRATED TO REACT** (2025-11-28)

**Old System** (REMOVED):
- Legacy AJAX polling every 23 seconds
- Used `testshowmessages` htmlcode (now stubbed)
- Displayed in `<div id="messages_messages">`

**New System** (ACTIVE):
- **Component**: `react/components/Nodelets/Messages.js`
- **API**: `GET /api/messages` (fetch messages)
- **API**: `POST /api/messages/archive` (archive messages)
- **API**: `DELETE /api/messages/{id}` (delete messages)
- **Polling**: React hooks with activity detection
- **Rendering**: Full React component with message list and actions

**Migration Complete**: All functionality replaced, all users now have React Messages nodelet

---

### 4. ~~Chatterbox Chatter List~~ (`chatterbox_chatter`) - ✅ MIGRATED

**Status**: **COMPLETELY MIGRATED TO REACT** (2025-11-27)

**Old System** (REMOVED):
- Legacy AJAX polling every 11 seconds
- Used `showchatter` htmlcode
- Displayed in `<div id="chatterbox_chatter">`
- Had complex auto-scroll and unread count logic in legacy.js

**New System** (ACTIVE):
- **Component**: `react/components/Nodelets/Chatterbox.js`
- **API**: `GET /api/chatter` (fetch chatter messages)
- **API**: `POST /api/chatter/create` (send messages)
- **Polling**: React hooks (useChatterPolling.js) with activity detection
- **Features**:
  - Auto-scroll to new messages
  - Unread count in page title when inactive
  - Start/stop controls
  - /msg, /whisper, and all chatterbox commands
  - Message history with timestamp sorting

**Migration Complete**: All functionality replaced, including all special features

---

### 5. ~~Other Users Periodical Updater~~ - ✅ MIGRATED

**Status**: **COMPLETELY MIGRATED TO REACT** (2025)

**Old System** (REMOVED):
- Legacy AJAX polling via `e2.ajax.periodicalUpdater('otherusers:updateNodelet:Other+Users')`
- Used `updateNodelet` htmlcode to refresh nodelet content
- Triggered by room changes via `changeroom` htmlcode

**New System** (ACTIVE):
- **Component**: `react/components/Nodelets/OtherUsers.js`
- **Polling Hook**: `react/hooks/useOtherUsersPolling.js`
- **API**: `GET /api/chatroom/` (fetch other users data)
- **API**: `POST /api/chatroom/change_room` (change rooms)
- **API**: `POST /api/chatroom/set_cloaked` (toggle cloak)
- **API**: `POST /api/chatroom/create_room` (create new room)
- **Polling**: Every 2 minutes with activity detection
- **Features**:
  - Room selection and switching
  - Cloak toggle for eligible users
  - Create new room dialog
  - User flags (god, editor, chanop, borged, etc.)
  - Recent noding/action display

**Migration Complete**: All functionality replaced, legacy periodical updater removed from legacy.js

---

### 6. Dismiss Item Handler

**Initialization**: `/www/js/legacy.js:1361`
```javascript
e2('.dismiss', 'click', e2.ajax.dismissListItem);
```

**Purpose**: Handles dismiss/delete actions on list items

**Used By**:
- Notifications (dismiss notification)
- Messages (archive/delete message)

**Mechanism**:
- Binds click handler to all elements with class `dismiss`
- Traverses DOM to find parent list and item ID
- Calls appropriate dismiss htmlcode (e.g., `ajaxMarkNotificationSeen`)
- Removes item from DOM with fade animation

---

### Summary: AJAX Update Patterns

**Status**: ✅ All AJAX polling has been migrated to React

**Legacy Pattern (DEPRECATED)**:
AJAX lists were registered via `e2.ajax.addList()` and automatically detected when:
1. DOM element with matching ID is found (e.g., `<div id="chatterbox_chatter">`)
2. Element is passed through `e2()` function (E2's jQuery enhancement)
3. List manager is created and starts polling

**React Polling Frequencies** (Current):
- **Chatterbox chatter**: React polling with activity detection
- **Private messages**: React polling with activity detection
- **Notifications**: React polling with activity detection
- **Other Users**: 2-minute polling via `useOtherUsersPolling` hook
- **New Writeups**: 3-minute polling

**Guest User Behavior**:
Guest users see static content and the "I like it!" button (via `/api/ilikeit`).

**Page Availability**:
React nodelets are mounted on ALL pages where the respective nodelets are configured, typically:
- Main page (guest front page for logged-in users)
- All node display pages
- Search results
- User profiles
- Any page that includes the nodelets in sidebar

---

## React Integration

### Overview: Unified React System

Everything2 has **fully migrated** from the legacy AJAX polling system to React:

1. ~~**Legacy AJAX System** (legacy.js)~~ - **DEPRECATED** - Only action handlers remain (vote, message opcodes)
2. **Modern React System** (react/) - Uses `fetch()` API with `/api/` endpoints - **PRIMARY**

All polling-based features now use React components with dedicated API endpoints.

---

### React System Architecture

**Location**: `react/`

**Entry Point**: `react/index.js` - Mounts `E2ReactRoot` component to `#e2-react-root` element

**Root Component**: `react/components/E2ReactRoot.js`
- Central state management for all React nodelets
- Uses `fetch()` for all server communication
- Implements its own idle detection via `react-idle-timer`
- Manages preferences via `/api/preferences` endpoint
- Updates every 3 minutes (180 seconds) for NewWriteups

---

### React-Managed Nodelets

The following nodelets are fully React-based and do NOT use the legacy AJAX system:

1. **New Writeups** (`NewWriteups.js`)
   - API: `GET /api/newwriteups`
   - Updates: Every 180 seconds
   - State: `newWriteups` array in React state
   - Filter: NoJunk toggle, limit selector
   - Actions: Editor hide/show via `/api/hidewriteups/:id/action/:verb`

2. **Vitals** (`Vitals.js`)
   - API: Initial data from `window.e2` object
   - No polling - static after initial load
   - Sections: maintenance, nodeinfo, list, nodeutil, misc
   - Preferences: Saved via `/api/preferences/set`

3. **Developer** (`Developer.js`)
   - API: Initial data from `window.e2.developerNodelet`
   - No polling - static after initial load
   - Sections: util, edev
   - Displays: page info, news, last commit, architecture

4. **Recommended Reading** (`RecommendedReading.js`)
   - API: Initial data from `window.e2` (coolnodes, staffpicks)
   - No polling - static after initial load

5. **New Logs** (`NewLogs.js`)
   - API: Derives from `newWriteups` + `daylogLinks`
   - No separate API calls
   - Filters existing data for daylogs

6. **Random Nodes** (`RandomNodes.js`)
   - API: Initial data from `window.e2.randomNodes`
   - No polling - static after initial load
   - Random phrase generated client-side

7. **Neglected Drafts** (`NeglectedDrafts.js`)
   - API: Initial data from `window.e2.neglectedDrafts`
   - No polling - static after initial load

8. **Quick Reference** (`QuickReference.js`)
   - API: Initial data from `window.e2.quickRefSearchTerm`
   - No polling - static after initial load

9. **Sign In** (`SignIn.js`)
   - API: Form submits to traditional login endpoint
   - Only shown to guests
   - Not a dynamic updater

---

### Legacy AJAX-Managed Features

**All polling features have been migrated to React!**

1. ~~**Chatterbox** (`chatterbox_chatter`)~~ - ✅ MIGRATED to React Chatterbox nodelet
2. ~~**Chatterbox Messages** (`chatterbox_messages`)~~ - ✅ MIGRATED to React Chatterbox nodelet
3. ~~**Messages Nodelet** (`messages_messages`)~~ - ✅ MIGRATED to React Messages nodelet
4. ~~**Notifications** (`notifications_list`)~~ - ✅ MIGRATED to React Notifications nodelet
5. ~~**Other Users** (periodical updater)~~ - ✅ MIGRATED to React OtherUsers nodelet
6. ~~**Voting System**~~ - ✅ MIGRATED to React WriteupDisplay (`/api/vote/writeup/:id`)

**Only remaining ajax_update mode**:

7. **Message Sending** (via ajax_update)
   - Mode: `message`
   - Uses: Direct delegation to `Everything::Delegation::opcode::message()`
   - Note: React Chatterbox uses `/api/chatter/create` - this mode can likely be removed

---

### Data Flow Comparison

#### Legacy AJAX Flow
```
Client (legacy.js)
    ↓
e2.ajax.htmlcode('showchatter', 'json')
    ↓
POST /?displaytype=ajaxupdate&htmlcode=showchatter&args=json
    ↓
Everything::HTML (routing)
    ↓
ajax update page (htmlpage)
    ↓
ajax_update() function (document.pm)
    ↓
Returns: HTML or JSON string
    ↓
Client: Updates DOM via jQuery
```

#### React Flow
```
Client (React component)
    ↓
fetch('/api/newwriteups')
    ↓
GET /api/newwriteups
    ↓
Everything::Router (API routing)
    ↓
Everything::API::newwriteups->get()
    ↓
Returns: JSON object [HTTP_OK, data]
    ↓
Client: Updates React state → Re-renders
```

---

### Conflicts and Issues

#### 1. Duplicate Idle Detection

**Problem**: Two separate idle detection systems run simultaneously.

**Legacy System** (`legacy.js:975-1011`):
- Uses custom sleep/wake system
- Monitors: focusin, focus, mouseenter, mousemove, mousedown, keydown, keypress, scroll, click
- Sleeps after: `e2.sleepAfter` minutes
- Pauses all `e2.ajax` robots when idle

**React System** (`E2ReactRoot.js:166-176`):
- Uses `react-idle-timer` library
- Timeout: 5 minutes (300 seconds)
- Sends `?ajaxIdle=1` parameter to API calls
- Independent of legacy system

**Impact**:
- Both systems track activity separately
- No coordination between them
- React components may poll while legacy system is asleep
- Wasted resources when both are active

---

#### 2. Preference Management Conflicts

**Problem**: Preferences managed through different systems.

**Legacy System**:
- Uses `e2.ajax.varChange()` to call `ajaxVar` htmlcode
- Updates cookies directly
- Manages `collapsedNodelets` via string manipulation

**React System**:
- Uses `fetch('/api/preferences/set')` with JSON payload
- Validates preferences against whitelist
- Returns structured response

**Overlap**: `collapsedNodelets` preference

Both systems try to manage which nodelets are collapsed:
- React: Updates via `/api/preferences/set` (lines 252-288 in E2ReactRoot.js)
- Legacy: Updates via `e2.ajax.varChange()` and cookies (line 260-272)
- React explicitly syncs with cookies and `e2.collapsedNodelets` global (lines 260-272)

**Current Workaround**: React manually syncs cookies and global `e2` object to maintain compatibility

---

#### 3. State Synchronization Issues

**Problem**: No shared state between systems.

**Scenario**: User changes preference in React component
- React state updates immediately
- API call persists preference
- Legacy AJAX system unaware of change
- May display stale data until next page reload

**Example**:
- User collapses NewWriteups nodelet (React)
- React updates its state and sends preference to server
- Legacy chatterbox continues polling
- Both systems waste bandwidth

---

#### 4. Data Initialization Strategy

**Problem**: React components receive initial data via `window.e2` global object.

**Current Approach** (E2ReactRoot.js:116-118):
```javascript
toplevelkeys.forEach((key) => {
  initialState[key] = e2[key]
})
```

**Issues**:
- Tightly couples React to global scope
- Server must render `window.e2` object into page
- No type safety or validation
- Can't lazy-load React bundle

**Data Injected**:
- `e2.user` - Current user object
- `e2.node` - Current node being viewed
- `e2.newWriteups` - Initial writeups array
- `e2.developerNodelet` - Developer info
- `e2.coolnodes` - Cool nodes array
- `e2.staffpicks` - Staff picks array
- `e2.randomNodes` - Random nodes array
- `e2.neglectedDrafts` - Draft data
- `e2.display_prefs` - User preferences
- `e2.collapsedNodelets` - Nodelet state

---

#### 5. Update Frequency Mismatch

**Problem**: Different update intervals cause inconsistency.

| Feature | System | Frequency | Endpoint |
|---------|--------|-----------|----------|
| Chatterbox | Legacy | 11s | htmlcode via ajax_update |
| Messages | Legacy | 23s | htmlcode via ajax_update |
| Notifications | Legacy | 45s | htmlcode via ajax_update |
| New Writeups | React | 180s | /api/newwriteups |

**Impact**:
- User sees chat updating frequently (11s)
- But New Writeups updates slowly (180s)
- Creates perception of inconsistency
- Some features feel "live", others feel "stale"

---

#### 6. No Cross-System Communication

**Problem**: Systems cannot trigger updates in each other.

**Example Scenario**:
1. User sends a chatterbox message (legacy system)
2. Message appears in chatterbox immediately (legacy poll)
3. If message mentions a user, notification should appear
4. Notification nodelet won't update until next 45s poll
5. React components have no way to know about the event

**Current Reality**:
- No pub/sub mechanism
- No shared event bus
- No WebSocket for real-time coordination
- Each system operates in isolation

---

### Interoperability Mechanisms

Despite the conflicts, some mechanisms enable limited interoperability:

#### 1. Global `e2` Object

**Purpose**: Share data between systems

**Usage**:
- Legacy: `e2.collapsedNodelets` updated via cookies
- React: Reads initial state from `e2.*`
- React: Writes back to `e2.collapsedNodelets` for compatibility

**Location**: Set in page render, accessible to both systems

---

#### 2. Cookie Synchronization

**Purpose**: Persist preferences across page loads

**React Code** (E2ReactRoot.js:259-272):
```javascript
// Compatibility with JQuery versions
e2['collapsedNodelets'] = e2['collapsedNodelets'].replace(replacement,'')
let cookies = document.cookie.split(/;\s?/).map(v => v.split('='))
cookies.forEach((element,index) => {
  if(cookies[index][0] == 'collapsedNodelets') {
    cookies[index][1] = cookies[index][1].replace(replacement,'')
    if(!showme) {
      cookies[index][1] += prefname
    }
    document.cookie = 'collapsedNodelets='+cookies[index][1]
  }
})
```

**Legacy System**: Reads cookies directly, updates via `e2.setCookie()` and `e2.deleteCookie()`

---

#### 3. DOM Portal System

**Purpose**: Mount React components into existing page structure

**Implementation**: React Portals (`NodeletPortal.js`)
- Finds existing DOM element by ID
- Mounts React component into that element
- Allows React to coexist with server-rendered HTML

**Example** (NewWriteupsPortal.js):
```javascript
const NewWriteupsPortal = ({children}) => {
  const target = document.getElementById('newwriteups-react-portal')
  return target ? ReactDOM.createPortal(children, target) : null
}
```

---

### Migration Strategy Implications

#### Current Reality: Hybrid System

**Advantages**:
- Can migrate gradually, one nodelet at a time
- React components provide better UX for migrated features
- API endpoints are reusable for future mobile apps
- Modern tech stack for new development

**Disadvantages**:
- Two systems to maintain
- Duplicate idle detection logic
- No real-time coordination
- Increased complexity
- Potential for bugs at boundaries
- Higher bandwidth usage (double-polling some data)

---

#### Recommended Evolution Path

**Phase 1: Complete Current Migration** ✅ DONE
- [x] NewWriteups migrated to React
- [x] Vitals migrated to React
- [x] Developer migrated to React
- [x] API endpoints created for migrated features
- [x] Replace eval() calls in ajax_update (message, vote modes)

**Phase 2: Migrate Remaining Legacy AJAX Features** ✅ DONE
- [x] Create `/api/messages` endpoint (replace showchatter/showmessages htmlcodes)
- [x] Create `/api/notifications` endpoint (replace notificationsJSON htmlcode)
- [x] Create React Chatterbox component
- [x] Create React Messages component
- [x] Create React Notifications component
- [x] Create React "Other Users" component
- [x] Create `/api/ilikeit` endpoint (replace ilikeit htmlcode ajax pattern)

**Phase 3: Clean Up Legacy Code** (IN PROGRESS)
- [ ] Remove unused htmlcodes (userFeedJSON, etc.)
- [ ] Remove legacy polling code from legacy.js
- [ ] Remove unused ajax_update modes
- [ ] Consolidate idle detection into React system only

**Phase 4: Deprecate Legacy System** (FUTURE)
- [ ] Remove `e2.ajax` object from legacy.js
- [ ] Remove `ajax_update` function from document.pm
- [ ] Remove "ajax update page" htmlpage
- [ ] Remove displaytype=ajaxupdate routing
- [ ] Clean up htmlcode functions no longer needed

**Phase 5: Optimize** (FUTURE)
- [ ] Implement GraphQL for flexible data fetching
- [ ] Add client-side caching (React Query or SWR)
- [ ] Implement service worker for offline support
- [ ] Add code splitting for faster initial load
- [ ] Move to server-side rendering (SSR) with Next.js

---

### Developer Guidelines

#### When Building New Features

**Use React If**:
- Feature needs frequent UI updates
- Complex client-side state management
- Better UX is priority
- Feature will be used on mobile

**Use Legacy AJAX If**:
- Feature is temporary/experimental
- Quick prototype needed
- Minimal UI requirements
- Deprecated soon anyway

**Best Practices**:
1. **Always use `/api/` endpoints** for new features
2. **Never add new modes to ajax_update** - it's deprecated
3. **Document state management** clearly
4. **Test idle behavior** in both systems
5. **Coordinate with existing features** to avoid conflicts
6. **Update this document** when adding new components

---

### Testing Considerations

#### Test Both Systems

When testing changes that affect shared data:
1. Test with React components
2. Test with legacy AJAX features
3. Test preference synchronization
4. Test cookie handling
5. Test idle/active transitions
6. Test with network throttling

#### Common Test Scenarios

1. **Collapsed Nodelet State**
   - Collapse in React → Verify legacy respects it
   - Update via legacy cookie → Verify React sees it on reload

2. **Idle Detection**
   - Go idle for 6 minutes
   - Verify both systems stop polling
   - Return to active
   - Verify both systems resume

3. **Preference Changes**
   - Change preference in React
   - Verify persisted to database
   - Reload page
   - Verify preference retained

4. **Concurrent Updates**
   - Open two browser tabs
   - Change preference in tab 1
   - Verify tab 2 eventually reflects change (may require reload)

---

### Performance Impact

#### Current Bandwidth Usage (Logged-In User)

**Per Minute**:
- Chatterbox: 6 polls (every 11s if active)
- Messages: 3 polls (every 23s if active)
- Notifications: 1.33 polls (every 45s)
- New Writeups: 0.33 polls (every 180s)

**Total**: ~10-11 requests/minute when all features active

**Network Overhead**:
- Each legacy AJAX call: Full HTML response (~2-5KB)
- Each React API call: JSON only (~1-3KB)
- React more efficient for data transfer
- But longer intervals mean less real-time

---

### Conclusion

The current hybrid system works but creates technical debt. The React system is more modern and maintainable, but the legacy AJAX system still powers critical features like chat and notifications. Complete migration to React with WebSocket support would provide the best user experience and simplify the codebase.

**Priority**: Replace the two eval() calls in ajax_update immediately, then focus on migrating Chatterbox, Messages, and Notifications to React as these are the most active polling systems.

---

## Complete Mode Reference

### Mode: "message" (lines 22677-22685)
**Purpose**: Send chatterbox messages

**Parameters**:
- `msgtext`: Message text to send
- `deletelist`: Comma-separated list of parameters to delete

**Returns**: Value of `sentmessage` parameter

**Current Implementation**:
```perl
$query->param('message',$query->param("msgtext"));
my @deleteParams = split(',', $query->param("deletelist") || '');
foreach (@deleteParams) {
    $query->param($_,1);
}
Everything::Delegation::opcode::message($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
return $query->param('sentmessage');
```

**✅ IMPLEMENTATION**: Uses direct delegation to `Everything::Delegation::opcode::message()` (line 381)

---

### Mode: "vote" (lines 22687-22690)
**Purpose**: Cast votes on writeups

**Parameters**: Vote parameters (from query string)

**Returns**: 0

**Current Implementation**:
```perl
Everything::Delegation::opcode::vote($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
return 0;
```

**✅ IMPLEMENTATION**: Uses direct delegation to `Everything::Delegation::opcode::vote()` (line 225)

---

### Mode: "getNodeInfo" (lines 22694-22704)
**Purpose**: Retrieve a specific field from a node

**Parameters**:
- `type`: Node type
- `title`: Node title
- `field`: Field name to retrieve

**Returns**: The requested field value

**Implementation**: Direct getNode() lookup, no issues

---

### Mode: "annotate" (lines 22706-22739)
**Purpose**: Manage annotations on nodes

**Parameters**:
- `action`: "delete", "retrieve", or "add"
- `annotation_id`: Node being annotated
- `location`: Annotation location (for delete/add)
- `comment`: Annotation text (for add)

**Returns**: Status message or annotation data

**Implementation**: Direct SQL operations, no issues

---

### Mode: "update" (lines 22741-22744)
**Purpose**: DEPRECATED/RETIRED

**Returns**: Error message stating mode retired for security reasons

---

### Mode: "getlastmessage" (lines 22746-22748)
**Purpose**: Get ID of most recent chatterbox message

**Returns**: Maximum message_id

**Implementation**: Direct SQL SELECT, no issues

---

### Mode: "markNotificationSeen" (lines 22751-22753)
**Purpose**: Mark notification as read

**Parameters**:
- `notified_id`: Notification ID

**Implementation**: Calls htmlcode 'ajaxNotificationSeen'

---

### Mode: "checkNotifications" (lines 22755-22757)
**Purpose**: Get current notifications

**Returns**: JSON-encoded notification data

**Implementation**: Calls htmlcode 'notificationsJSON', converts to JSON

---

### Mode: "checkCools" (lines 22760-22762)
**Purpose**: Get current cool nodes

**Returns**: JSON-encoded cool nodes data

**Implementation**: Calls htmlcode 'coolsJSON', converts to JSON

---

### Mode: "checkMessages" (lines 22764-22766)
**Purpose**: Get chatterbox messages

**Returns**: JSON-encoded message data

**Implementation**: Calls htmlcode 'showchatterJSON', converts to JSON

---

### Mode: "checkFeedItems" (lines 22768-22770)
**Purpose**: Get user feed items

**Returns**: JSON-encoded feed data

**Implementation**: Calls htmlcode 'userFeedJSON', converts to JSON

---

### Mode: "deleteFeedItem" (lines 22772-22775)
**Purpose**: Delete a feed item

**Parameters**:
- `feeditem_nodeid`: Node ID to delete

**Implementation**: Calls nukeNode(), no issues

---

### Default Mode: "var" (line 22674)
**Purpose**: Fallback/default handler

**Returns**: Empty string

**Implementation**: Sets NODE to node_id 124, returns empty

---

## Identified Issues: eval() on Delegated Opcodes

### ~~Issue 1~~: Message Opcode Eval → **FIXED**

**Location**: `document.pm:22683`

**Previous Code (DEPRECATED)**:
```perl
if ($mode eq 'message') {
    my $op = getNode('message','opcode');
    $query->param('message',$query->param("msgtext"));
    my @deleteParams = split(',', $query->param("deletelist") || '');
    foreach (@deleteParams) {
        $query->param($_,1);
    }
    eval($$op{code}); ## no critic (ProhibitStringyEval, RequireCheckingReturnValueOfEval)
    return $query->param('sentmessage');
}
```

**Problem (RESOLVED)**:
- Previously loaded the 'message' opcode node from database
- Executed its code via `eval($$op{code})`
- The message opcode was already delegated, making eval() unnecessary

**Implemented Solution**:
- Module: `Everything::Delegation::opcode`
- Function: `message($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP)` (line 381)
- Direct delegation call replaces eval()

**Current Code (IMPLEMENTED)**:
```perl
if ($mode eq 'message') {
    $query->param('message',$query->param("msgtext"));
    my @deleteParams = split(',', $query->param("deletelist") || '');
    foreach (@deleteParams) {
        $query->param($_,1);
    }
    Everything::Delegation::opcode::message($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
    return $query->param('sentmessage');
}
```

**Benefits**:
- Eliminates eval() security risks
- Removes database query overhead (no getNode() call)
- Removes Perl::Critic violations
- Clearer code path for debugging

---

### ~~Issue 2~~: Vote Opcode Eval → **FIXED**

**Location**: `document.pm:22688`

**Previous Code (DEPRECATED)**:
```perl
if ($mode eq 'vote') {
    my $op = getNode('vote','opcode');
    eval($$op{code}); ## no critic (ProhibitStringyEval, RequireCheckingReturnValueOfEval)
    return 0;
}
```

**Problem (RESOLVED)**:
- Previously loaded the 'vote' opcode node from database
- Executed its code via `eval($$op{code})`
- The vote opcode was already delegated, making eval() unnecessary

**Implemented Solution**:
- Module: `Everything::Delegation::opcode`
- Function: `vote($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP)` (line 225)
- Direct delegation call replaces eval()

**Current Code (IMPLEMENTED)**:
```perl
if ($mode eq 'vote') {
    Everything::Delegation::opcode::vote($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
    return 0;
}
```

**Benefits**:
- Eliminates eval() security risks
- Removes database query overhead (no getNode() call)
- Removes Perl::Critic violations
- Clearer code path for debugging

---

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ CLIENT SIDE (legacy.js)                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User Action → e2.ajax.htmlcode('someHtmlCode', params)       │
│                     ↓                                           │
│                Sets: displaytype = 'ajaxupdate'                │
│                     ↓                                           │
│                jQuery.ajax() → POST to server                  │
│                                                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓ HTTP Request
                             │
┌────────────────────────────┴────────────────────────────────────┐
│ ROUTING LAYER (Everything::HTML)                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  getPage($NODE, 'ajaxupdate')                                  │
│         ↓                                                       │
│  Finds: "ajax update page" htmlpage                            │
│         ↓                                                       │
│  Router delegates to fullpage function                         │
│                                                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓ Function Call
                             │
┌────────────────────────────┴────────────────────────────────────┐
│ HANDLER LAYER (Everything::Delegation::document)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ajax_update($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP)│
│         ↓                                                       │
│  Checks: $query->param("mode")                                 │
│         ↓                                                       │
│  Routes to appropriate handler:                                │
│    • message   → ⚠️  eval(opcode) [SHOULD USE DELEGATION]     │
│    • vote      → ⚠️  eval(opcode) [SHOULD USE DELEGATION]     │
│    • getNodeInfo → Direct node lookup                         │
│    • annotate    → SQL operations                              │
│    • check*      → htmlcode delegation → JSON                 │
│    • etc.                                                      │
│         ↓                                                       │
│  Returns: String or JSON data                                  │
│                                                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ↓ HTTP Response
                             │
┌────────────────────────────┴────────────────────────────────────┐
│ CLIENT SIDE (legacy.js - callback)                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Validates response (checks for <!-- AJAX OK marker)           │
│         ↓                                                       │
│  Updates DOM or triggers callback                              │
│         ↓                                                       │
│  User sees updated content                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Usage Patterns in Codebase

### Chatterbox Integration
- **Send message**: `mode=message` with msgtext parameter
- **Get messages**: `mode=checkMessages` → calls 'showchatterJSON' htmlcode
- **Get last message ID**: `mode=getlastmessage`

### Voting System
- **Cast vote**: `mode=vote` with vote parameters

### Notifications
- **Check notifications**: `mode=checkNotifications` → calls 'notificationsJSON' htmlcode
- **Mark as seen**: `mode=markNotificationSeen` with notified_id

### Cool Nodes
- **Check cools**: `mode=checkCools` → calls 'coolsJSON' htmlcode

### Feed Items
- **Get feed**: `mode=checkFeedItems` → calls 'userFeedJSON' htmlcode
- **Delete item**: `mode=deleteFeedItem` with feeditem_nodeid

### Node Operations
- **Get node field**: `mode=getNodeInfo` with type, title, field

### Annotations
- **Add/retrieve/delete**: `mode=annotate` with action parameter

---

## React Migration Recommendations

### Phase 1: Replace eval() Calls (IMMEDIATE)

**Priority: HIGH - Can be done immediately**

Replace the two eval() calls with delegation:

1. **Message mode** (line 22684):
   - Replace `eval($$op{code})` with `Everything::Delegation::opcode::message(...)`
   - Test with chatterbox message sending
   - Verify /msg, /whisper, and other message commands work

2. **Vote mode** (line 22690):
   - Replace `eval($$op{code})` with `Everything::Delegation::opcode::vote(...)`
   - Test with writeup voting
   - Verify vote counting and XP changes work

**Testing Requirements**:
- Send chatterbox messages (public, /msg, /whisper)
- Cast votes on writeups (upvote/downvote)
- Verify proper error handling for suspended users
- Check that achievements trigger correctly

---

### Phase 2: API Modernization (SHORT TERM)

**Goal**: Create proper REST API endpoints to replace ajax_update modes

**Recommended Structure**:
```
POST /api/messages          → Replace mode=message
POST /api/votes             → Replace mode=vote
GET  /api/notifications     → Replace mode=checkNotifications
PUT  /api/notifications/:id → Replace mode=markNotificationSeen
GET  /api/cools             → Replace mode=checkCools
GET  /api/messages          → Replace mode=checkMessages
GET  /api/feed              → Replace mode=checkFeedItems
DELETE /api/feed/:id        → Replace mode=deleteFeedItem
GET  /api/nodes/:type/:title/:field → Replace mode=getNodeInfo
```

**Benefits**:
- RESTful design follows modern conventions
- Easier to document and test
- Better caching strategies
- Proper HTTP status codes
- Type-safe with JSON schemas

---

### Phase 3: React Component Integration (MEDIUM TERM)

**Recommended Approach**: Incremental replacement

1. **Chatterbox Component**
   - Replace `e2.ajax.updateList('chatterbox_chatter')` with React state management
   - Use WebSocket or polling for live updates
   - Convert legacy.js list management to React hooks

2. **Notifications Component**
   - Replace periodical updater with React query or SWR
   - Convert notification list to React components
   - Implement real-time updates via WebSocket

3. **Voting System**
   - Create React components for vote buttons
   - Use optimistic updates for better UX
   - Replace form-based voting with API calls

4. **Cool Nodes Widget**
   - Convert to React component
   - Use modern state management
   - Implement auto-refresh with React hooks

---

### Phase 4: Deprecate legacy.js (LONG TERM)

**Steps**:
1. Ensure all ajax_update modes have React equivalents
2. Create compatibility layer for gradual migration
3. Monitor usage of legacy endpoints
4. Remove e2.ajax object when no longer used
5. Delete legacy.js and ajax_update function

---

## Security Considerations

### Current Security Issues

1. **eval() Usage**: Using eval on database-stored code (being addressed)
2. **Mode parameter**: Client can specify any mode (needs validation)
3. **Direct SQL in annotate mode**: SQL injection risk if not parameterized
4. **No rate limiting**: AJAX endpoints can be hammered

### Recommendations for React Migration

1. **Authentication**: Use JWT or session tokens
2. **Authorization**: Verify permissions for each endpoint
3. **Input Validation**: Validate all parameters with schemas
4. **Rate Limiting**: Implement per-user rate limits
5. **CSRF Protection**: Use CSRF tokens or SameSite cookies
6. **Content Security Policy**: Restrict inline scripts

---

## Performance Considerations

### Current Bottlenecks

1. **Multiple Database Lookups**: Each ajax call may load multiple nodes
2. **No Caching**: Fresh data fetched every time
3. **Polling**: Periodical updaters create constant server load
4. **Large Responses**: Some JSON responses may be large

### Optimization Opportunities

1. **Caching Layer**: Redis/Memcached for frequently accessed data
2. **WebSocket**: Replace polling with push-based updates
3. **GraphQL**: Allow clients to request exactly what they need
4. **CDN**: Cache static/semi-static responses
5. **Database Indexing**: Ensure proper indexes on message/notification queries

---

## Testing Strategy

### Unit Tests Needed

1. **Opcode Delegation Tests**
   - Test `Everything::Delegation::opcode::message()` directly
   - Test `Everything::Delegation::opcode::vote()` directly
   - Mock database and query objects

2. **ajax_update Mode Tests**
   - Test each mode independently
   - Verify correct delegation calls
   - Test error conditions

### Integration Tests Needed

1. **End-to-End AJAX Tests**
   - Simulate client-side AJAX calls
   - Verify correct responses
   - Test authentication/authorization

2. **React Component Tests**
   - Test new React components
   - Mock API endpoints
   - Test real-time updates

---

## Implementation Checklist

### Immediate (eval() replacement)
- [ ] Replace message eval with `Everything::Delegation::opcode::message()`
- [ ] Replace vote eval with `Everything::Delegation::opcode::vote()`
- [ ] Remove `## no critic` annotations after replacement
- [ ] Run full test suite
- [ ] Test chatterbox messaging manually
- [ ] Test voting system manually
- [ ] Deploy to staging
- [ ] Deploy to production

### Short Term (API modernization)
- [ ] Design REST API structure
- [ ] Create API endpoint handlers
- [ ] Add authentication/authorization
- [ ] Add rate limiting
- [ ] Add input validation
- [ ] Write API documentation
- [ ] Create API tests
- [ ] Deploy API endpoints

### Medium Term (React components)
- [ ] Create Chatterbox React component
- [ ] Create Notifications React component
- [ ] Create Voting React component
- [ ] Create Cool Nodes React component
- [ ] Implement WebSocket for real-time updates
- [ ] Add state management (Redux/Context)
- [ ] Write component tests
- [ ] Gradual rollout with feature flags

### Long Term (deprecation)
- [ ] Monitor legacy endpoint usage
- [ ] Create migration guide for any third-party code
- [ ] Remove legacy.js e2.ajax object
- [ ] Remove ajax_update function
- [ ] Remove ajax update page htmlpage
- [ ] Clean up routing code
- [ ] Final verification and deployment

---

## Conclusion

The ajaxUpdate system is a functional legacy AJAX framework that can be incrementally modernized. The immediate priority is replacing the two eval() calls with delegation to improve code quality and eliminate Perl::Critic violations.

The path to React migration is clear: create REST API endpoints that mirror the existing modes, then build React components that consume these APIs. The system's modular design with discrete modes makes this transition straightforward.

**Next Steps**:
1. Review this analysis with the team
2. Replace eval() calls (can be done immediately)
3. Design REST API structure
4. Begin React component development

---

**Document Version**: 1.0
**Date**: 2025-11-19
**Author**: Claude (Everything2 Migration Analysis)
**Status**: Draft for Review

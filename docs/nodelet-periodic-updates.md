# Nodelet Periodic Update System

**Status**: Analysis complete, implementation pending
**Created**: 2025-11-24
**Related**: React migration, legacy.js removal

## Overview

The current system uses legacy.js AJAX polling to keep nodelets updated with fresh data. As we migrate nodelets to React, we need a replacement strategy for periodic updates that works in the hybrid migration state and can eventually replace all legacy polling.

## Current Legacy System

### Update Mechanisms

The legacy system uses two different patterns:

#### 1. List-based Updates (via `e2.ajax.addList`)

**Used by:**
- `chatterbox_messages` (private messages in chatterbox)
- `messages_messages` (private messages in separate nodelet)
- `chatterbox_chatter` (public chat)
- `notifications_list` (notifications)

**How it works:**
```javascript
e2.ajax.addList('chatterbox_chatter', {
  ascending: true,              // Newest at bottom
  getJSON: 'showchatter',       // Htmlcode to poll
  args: 'json',                 // Args to htmlcode
  idGroup: 'chat_',             // ID prefix for items
  period: 11,                   // Poll every 11 seconds
  preserve: '.chat',            // Don't remove items matching selector
  callback: function() { }      // Called when list changes
})
```

**Features:**
- Smart DOM updates (only add/remove changed items)
- Individual item animations (slideDown/slideUp)
- Configurable update periods
- Callback on change
- Preserve certain items from removal

**Current configurations:**
| List | Endpoint | Period | Notes |
|------|----------|--------|-------|
| `chatterbox_messages` | `showmessages` | 23s | Private messages in chatterbox |
| `messages_messages` | `testshowmessages` | 23s | Alternative private messages display |
| `chatterbox_chatter` | `showchatter` | 11s | Public chat (if autoChat enabled) |
| `notifications_list` | `notificationsJSON` | 45s | User notifications |

#### 2. Nodelet Replacement Updates (via `e2.ajax.periodicalUpdater`)

**Used by:**
- `Other Users` nodelet

**How it works:**
```javascript
new e2.ajax.periodicalUpdater('otherusers:updateNodelet:Other+Users')
```

**Features:**
- Replaces entire nodelet HTML
- Triggers via simulated click event
- Uses `e2.defaultUpdatePeriod * 60` seconds (default interval)
- Calls `updateNodelet` htmlcode

**Pattern format:** `{container_id}:{htmlcode}:{args}`

#### 3. Sleep/Wake System

**Purpose:** Conserve resources when user is inactive

**Implementation:**
```javascript
// Monitor activity
var wakeEvents = 'focusin focus mouseenter mousemove mousedown keydown keypress scroll click'

// Sleep after e2.sleepAfter minutes of inactivity (default: 10 minutes)
if (Date.now() - lastActive > e2.sleepAfter * 60000) {
  // Stop all polling
  $(robots).each(function(){ this.sleep(); })
}

// Multi-tab detection
// Only active tab polls (via 'lastActiveWindow' cookie)
if (myCookie && myCookie != windowId) {
  sleep();
}
```

**Benefits:**
- Reduces server load from inactive tabs
- Prevents multiple tabs from all polling
- Resumes automatically on user activity

### Files Involved

**`www/js/legacy.js`:**
- Lines 232-285: `e2.periodical` wrapper around setInterval
- Lines 900-933: `e2.ajax.htmlcode()` - AJAX request handler
- Lines 935-954: `e2.ajax.update()` - Update DOM from htmlcode
- Lines 975-1011: `addRobot()` - Sleep/wake system setup
- Lines 1028-1036: `listManager` - Manages periodic list updates
- Lines 1038-1071: `updateList()` - Smart list DOM updates
- Lines 1121-1127: `periodicalUpdater()` - Periodic nodelet updates
- Lines 1129-1163: `updateTrigger()` - Bind update triggers
- Lines 1165-1280: `triggerUpdate()` - Process AJAX updates
- Lines 1287-1359: List configurations (notifications, messages, chatter)
- Line 1363: **Other Users periodic update** (to be removed)
- Lines 1386-1406: Auto-ajaxify nodelet forms/links

**Active Polling (to be migrated):**
```javascript
// Line 1287: Notifications (45s)
e2.ajax.addList('notifications_list', {
  getJSON: "notificationsJSON",
  period: 45,
  // ...
})

// Line 1296: Chatterbox private messages (23s)
e2.ajax.addList('chatterbox_messages', {
  getJSON: 'showmessages',
  period: 23,
  // ...
})

// Line 1309: Messages nodelet private messages (23s)
e2.ajax.addList('messages_messages', {
  getJSON: 'testshowmessages',
  period: 23,
  // ...
})

// Line 1318: Chatterbox public chatter (11s if autoChat enabled)
e2.ajax.addList('chatterbox_chatter', {
  getJSON: 'showchatter',
  period: e2.autoChat ? 11 : -1,
  // ...
})

// Line 1363: Other Users nodelet (default period)
new e2.ajax.periodicalUpdater('otherusers:updateNodelet:Other+Users')
```

## Options for React Migration

### Option A: Individual Nodelet Polling

**Description:** Each React nodelet manages its own polling using `setInterval` in a `useEffect` hook.

**Implementation:**
```javascript
const Messages = (props) => {
  const [data, setData] = useState(props.initialData)
  const [isActive, setIsActive] = useState(true)

  useEffect(() => {
    if (!isActive) return

    const pollInterval = setInterval(async () => {
      const response = await fetch('/api/messages/')
      const newData = await response.json()
      setData(newData)
    }, 23000) // 23 seconds for messages

    return () => clearInterval(pollInterval)
  }, [isActive])

  // Activity detection to implement sleep/wake
  useEffect(() => {
    const handleActivity = () => setIsActive(true)
    const checkInactivity = setInterval(() => {
      // Check if inactive for e2.sleepAfter minutes
    }, 60000)

    window.addEventListener('mousemove', handleActivity)
    return () => {
      window.removeEventListener('mousemove', handleActivity)
      clearInterval(checkInactivity)
    }
  }, [])
}
```

**Pros:**
- ✅ Simple, isolated, no shared state
- ✅ Each component controls its own update frequency
- ✅ Easy to migrate one nodelet at a time (hybrid-friendly)
- ✅ No new backend infrastructure needed
- ✅ Components can stop polling when unmounted

**Cons:**
- ❌ Multiple simultaneous HTTP requests (one per nodelet)
- ❌ Duplicates sleep/wake logic across components
- ❌ No coordination between updates

**Migration Path:**
1. Add polling to Messages component → remove `messages_messages` from legacy.js
2. Add polling to Chatterbox component → remove `chatterbox_chatter` and `chatterbox_messages` from legacy.js
3. Add polling to OtherUsers component (already React) → remove line 1363 from legacy.js
4. Continue for each nodelet as it's migrated

---

### Option B: Centralized Polling Manager (React Context)

**Description:** Create a React Context that manages all polling centrally with coordinated updates.

**Implementation:**
```javascript
// PollingManager.js
const PollingContext = createContext()

export const PollingProvider = ({ children }) => {
  const [lastUpdate, setLastUpdate] = useState({})
  const [isActive, setIsActive] = useState(true)

  const registerPoller = (name, endpoint, interval, callback) => {
    // Register and manage all pollers centrally
    // Single setInterval for each endpoint
  }

  // Single sleep/wake system for all pollers
  useEffect(() => {
    // Activity detection
    // Sleep/wake coordination
  }, [])

  return (
    <PollingContext.Provider value={{ registerPoller, lastUpdate, isActive }}>
      {children}
    </PollingContext.Provider>
  )
}

// In E2ReactRoot.js
<PollingProvider>
  <MessagesPortal />
  <ChatterboxPortal />
  <OtherUsersPortal />
</PollingProvider>

// In Messages.js
const { registerPoller } = useContext(PollingContext)
useEffect(() => {
  return registerPoller('messages', '/api/messages/', 23000, setMessages)
}, [])
```

**Pros:**
- ✅ Single sleep/wake implementation
- ✅ Coordinated updates (can batch if needed)
- ✅ Centralized monitoring/debugging
- ✅ Can implement smart scheduling (offset intervals to spread load)

**Cons:**
- ❌ More complex architecture
- ❌ Requires refactoring all nodelets to use context
- ❌ Harder to migrate piecemeal (need infrastructure first)
- ❌ Tight coupling between nodelets

**Migration Path:**
1. Create PollingContext infrastructure
2. Update E2ReactRoot to wrap with provider
3. Convert all React nodelets at once to use context
4. Remove all legacy.js polling code

---

### Option C: Unified State Endpoint

**Description:** Single API endpoint that returns all nodelet data in one request.

**Implementation:**
```javascript
// New backend endpoint: /api/page_state/
// Returns: {
//   messages: [...],
//   chatter: [...],
//   other_users: [...],
//   notifications: [...]
// }

// In E2ReactRoot.js
const [pageState, setPageState] = useState(window.e2)

useEffect(() => {
  const pollInterval = setInterval(async () => {
    const response = await fetch('/api/page_state/')
    const newState = await response.json()
    setPageState(newState)
  }, 15000) // Single poll for all data

  return () => clearInterval(pollInterval)
}, [])

// Pass down to child components
<MessagesPortal messages={pageState.messages} />
<ChatterboxPortal chatter={pageState.chatter} />
<OtherUsersPortal users={pageState.other_users} />
```

**Pros:**
- ✅ Single HTTP request for all data
- ✅ Reduced server load (one endpoint call)
- ✅ Consistent state across all nodelets (same timestamp)
- ✅ Simple implementation in React (one useEffect)
- ✅ Easy to add caching/optimization

**Cons:**
- ❌ Requires new backend endpoint
- ❌ All nodelets update at same frequency (can't have messages at 23s, chat at 11s)
- ❌ Wastes bandwidth if user doesn't have all nodelets visible
- ❌ All-or-nothing migration (can't do hybrid)
- ❌ Tight coupling between backend and frontend

**Migration Path:**
1. Create `/api/page_state/` endpoint in Perl
2. Update E2ReactRoot to poll unified endpoint
3. Remove individual polling from all components
4. Remove all legacy.js polling code

---

### Option D: Hybrid with Shared Activity Detection (RECOMMENDED)

**Description:** Keep individual polling but extract sleep/wake into shared hook.

**Implementation:**
```javascript
// react/hooks/useActivityDetection.js (shared hook)
export const useActivityDetection = (sleepAfter = 10) => {
  const [isActive, setIsActive] = useState(true)
  const lastActivity = useRef(Date.now())

  useEffect(() => {
    const handleActivity = () => {
      lastActivity.current = Date.now()
      setIsActive(true)
    }

    const checkInactivity = setInterval(() => {
      const inactive = Date.now() - lastActivity.current > sleepAfter * 60000
      if (inactive) setIsActive(false)
    }, 60000)

    const events = ['mousemove', 'keydown', 'click', 'scroll']
    events.forEach(event => window.addEventListener(event, handleActivity))

    // Multi-tab detection via cookie
    const tabId = Math.random().toString(36)
    document.cookie = `lastActiveWindow=${tabId}; path=/`

    return () => {
      events.forEach(event => window.removeEventListener(event, handleActivity))
      clearInterval(checkInactivity)
    }
  }, [sleepAfter])

  return isActive
}

// In each component (e.g., Messages.js)
const Messages = (props) => {
  const [messages, setMessages] = useState(props.initialMessages)
  const isActive = useActivityDetection(10) // 10 minutes

  useEffect(() => {
    if (!isActive) return

    const interval = setInterval(async () => {
      const response = await fetch('/api/messages/')
      const data = await response.json()
      setMessages(data)
    }, 23000)

    return () => clearInterval(interval)
  }, [isActive])

  // ... rest of component
}
```

**Pros:**
- ✅ Individual polling flexibility (different intervals per nodelet)
- ✅ Shared sleep/wake logic (no duplication)
- ✅ Easy to migrate piecemeal (hybrid-friendly)
- ✅ No backend changes needed
- ✅ Simple architecture
- ✅ Components control their own update frequency

**Cons:**
- ❌ Multiple HTTP requests (but not a major issue)
- ❌ Each component still manages own interval (but isolated)

**Migration Path:**
1. Create `react/hooks/useActivityDetection.js` shared hook
2. Update OtherUsers to use hook and add polling → remove line 1363 from legacy.js
3. Update Messages to use hook and add polling → remove `messages_messages` from legacy.js
4. Update Chatterbox to use hook and add polling → remove `chatterbox_chatter` and `chatterbox_messages` from legacy.js
5. Continue pattern for remaining nodelets as they migrate to React

---

## Recommendation: Option D

**Reasoning:**

1. **Hybrid migration friendly** - We're in a transition state with both React and legacy nodelets. Option D allows piecemeal migration without requiring all nodelets to switch at once.

2. **Different update frequencies** - Different nodelets have different polling needs:
   - Public chat: 11 seconds (high frequency for real-time feel)
   - Private messages: 23 seconds (moderate frequency)
   - Other Users: 30-60 seconds (low frequency, list doesn't change often)
   - Notifications: 45 seconds (low frequency)

   Option D preserves this flexibility without forcing everything to one interval.

3. **No backend infrastructure changes** - Can implement entirely in React using existing API endpoints. No new Perl code needed.

4. **Simple to understand** - Each component manages its own polling. Shared hook for sleep/wake is straightforward.

5. **Testable** - Components and hooks can be tested independently.

6. **Can optimize later** - If multiple HTTP requests become an issue, can switch to Option C later. But premature optimization is unnecessary.

## Implementation Plan

### Phase 1: Create Shared Hook

**File:** `react/hooks/useActivityDetection.js`

```javascript
import { useState, useEffect, useRef } from 'react'

export const useActivityDetection = (sleepAfterMinutes = 10) => {
  const [isActive, setIsActive] = useState(true)
  const lastActivity = useRef(Date.now())
  const tabId = useRef(Math.random().toString(36).substr(2, 9))

  useEffect(() => {
    const handleActivity = () => {
      lastActivity.current = Date.now()
      setIsActive(true)

      // Multi-tab detection: mark this tab as active
      document.cookie = `lastActiveWindow=${tabId.current}; path=/`
    }

    const checkInactivity = setInterval(() => {
      const now = Date.now()
      const inactive = now - lastActivity.current > sleepAfterMinutes * 60000

      // Also check if another tab is active
      const cookies = document.cookie.split(';').reduce((acc, cookie) => {
        const [key, value] = cookie.trim().split('=')
        acc[key] = value
        return acc
      }, {})

      const otherTabActive = cookies.lastActiveWindow &&
                             cookies.lastActiveWindow !== tabId.current

      if (inactive || otherTabActive) {
        setIsActive(false)
      }
    }, 60000) // Check every minute

    // Initial activity marker
    handleActivity()

    // Listen for activity events
    const events = ['mousemove', 'keydown', 'click', 'scroll', 'focus']
    events.forEach(event => {
      window.addEventListener(event, handleActivity, { passive: true })
    })

    return () => {
      events.forEach(event => {
        window.removeEventListener(event, handleActivity)
      })
      clearInterval(checkInactivity)
    }
  }, [sleepAfterMinutes])

  return isActive
}
```

**Tests:** `react/hooks/useActivityDetection.test.js`

### Phase 2: Update OtherUsers (First Migration)

**Add to OtherUsers.js:**
```javascript
import { useActivityDetection } from '../hooks/useActivityDetection'

const OtherUsers = (props) => {
  const [otherUsersData, setOtherUsersData] = useState(props.otherUsersData)
  const isActive = useActivityDetection(10)

  // Poll for updates
  useEffect(() => {
    if (!isActive) return

    const interval = setInterval(async () => {
      try {
        const response = await fetch('/api/chatroom/current/users', {
          credentials: 'include'
        })
        const data = await response.json()
        if (data.otherUsersData) {
          setOtherUsersData(data.otherUsersData)
        }
      } catch (err) {
        console.error('Failed to fetch other users:', err)
      }
    }, 30000) // Poll every 30 seconds

    return () => clearInterval(interval)
  }, [isActive])

  // ... rest of component
}
```

**Remove from legacy.js:**
```javascript
// Line 1363 - DELETE THIS LINE
new e2.ajax.periodicalUpdater('otherusers:updateNodelet:Other+Users')
```

### Phase 3: Update Messages Nodelet

**Add to Messages.js:**
```javascript
import { useActivityDetection } from '../hooks/useActivityDetection'

const Messages = (props) => {
  const [messages, setMessages] = useState(props.initialMessages || [])
  const isActive = useActivityDetection(10)

  // Poll for new messages
  useEffect(() => {
    if (!isActive) return

    const interval = setInterval(async () => {
      try {
        const response = await fetch('/api/messages/?limit=10', {
          credentials: 'include'
        })
        const data = await response.json()
        setMessages(data)
      } catch (err) {
        console.error('Failed to fetch messages:', err)
      }
    }, 23000) // Poll every 23 seconds

    return () => clearInterval(interval)
  }, [isActive])

  // ... rest of component
}
```

**Remove from legacy.js:**
```javascript
// Lines 1296-1307 - DELETE THIS BLOCK
e2.ajax.addList('chatterbox_messages', {
  ascending: true,
  getJSON: 'showmessages',
  args: ',j',
  idGroup: 'message_',
  preserve: 'input:checked',
  period: 23,
  callback: function(){ /* ... */ }
})

// Lines 1309-1316 - DELETE THIS BLOCK
e2.ajax.addList('messages_messages', {
  ascending: true,
  getJSON: 'testshowmessages',
  args: ',j',
  idGroup: 'message_',
  preserve: '.showwidget .open',
  period: 23
})
```

### Phase 4: Update Chatterbox Nodelet

**Add to Chatterbox.js:**
```javascript
import { useActivityDetection } from '../hooks/useActivityDetection'

const Chatterbox = (props) => {
  const [chatter, setChatter] = useState(props.initialChatter || [])
  const isActive = useActivityDetection(10)
  const autoChat = props.autoChat || false // From user prefs

  // Poll for new chatter
  useEffect(() => {
    if (!isActive || !autoChat) return

    const interval = setInterval(async () => {
      try {
        const response = await fetch('/api/chatter/', {
          credentials: 'include'
        })
        const data = await response.json()
        setChatter(data)
      } catch (err) {
        console.error('Failed to fetch chatter:', err)
      }
    }, 11000) // Poll every 11 seconds

    return () => clearInterval(interval)
  }, [isActive, autoChat])

  // ... rest of component
}
```

**Remove from legacy.js:**
```javascript
// Lines 1318-1359 - DELETE THIS BLOCK
e2.ajax.addList('chatterbox_chatter', {
  ascending: true,
  getJSON: 'showchatter',
  args: 'json',
  idGroup: 'chat_',
  period: e2.autoChat ? 11 : -1,
  callback: /* ... */,
  stopAfter: e2.sleepAfter * 60,
  die: function(){ /* ... */ }
})
```

### Phase 5: Verify and Cleanup

1. Test each nodelet update mechanism independently
2. Verify sleep/wake works across all nodelets
3. Verify multi-tab detection prevents duplicate polling
4. Remove legacy.js list management code once all nodelets migrated
5. Update documentation

## Testing Checklist

- [ ] Activity detection works (updates stop after 10 minutes)
- [ ] Activity detection resumes on mouse/keyboard
- [ ] Multi-tab detection works (only one tab polls)
- [ ] Each nodelet polls at correct interval
- [ ] Polling stops when component unmounts
- [ ] No memory leaks from intervals
- [ ] Error handling works (network failures)
- [ ] Initial data loads correctly
- [ ] Updates append/replace data correctly

## Future Optimizations

Once all nodelets are migrated, consider:

1. **Batching:** Combine multiple API calls into one (Option C)
2. **WebSockets:** Real-time updates instead of polling
3. **Service Workers:** Background sync for offline support
4. **Smart intervals:** Adjust frequency based on user activity patterns

## Related Documentation

- [React Migration Strategy](react-migration-strategy.md)
- [Nodelet Migration Status](nodelet-migration-status.md)
- [Message/Chatter System](message-chatter-system.md)

---

*Last updated: 2025-11-24*

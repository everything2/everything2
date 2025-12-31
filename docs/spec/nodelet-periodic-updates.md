# Nodelet Periodic Update System

**Purpose**: Keep nodelet data fresh via background polling with activity awareness
**Status**: Implemented

---

## Overview

React nodelets use a shared activity detection hook combined with individual polling to keep data fresh. The system pauses when users are inactive to conserve resources.

---

## Architecture

| Component | Location | Purpose |
|-----------|----------|---------|
| `useActivityDetection` | `react/hooks/useActivityDetection.js` | Shared sleep/wake + multi-tab detection |
| `usePolling` | `react/hooks/usePolling.js` | Generic polling hook with activity integration |
| `useChatterPolling` | `react/hooks/useChatterPolling.js` | Chatter-specific polling with incremental updates |
| `useOtherUsersPolling` | `react/hooks/useOtherUsersPolling.js` | Other Users polling |

### Design Rationale

The system uses **individual polling per nodelet with shared activity detection** because:

1. **Different intervals**: Different nodelets have different freshness needs (chatter needs 45s, writeups need 5m)
2. **Hybrid-friendly**: Works during React migration with some legacy nodelets still active
3. **Simple**: Each component manages its own polling, shared hook handles sleep/wake
4. **Testable**: Hooks can be tested independently

---

## Activity Detection

The `useActivityDetection` hook provides:

```javascript
const { isActive, isRecentlyActive, isMultiTabActive } = useActivityDetection(10)
```

| State | Meaning |
|-------|---------|
| `isActive` | User has interacted within last N minutes (default: 10) |
| `isRecentlyActive` | User has interacted within last 60 seconds |
| `isMultiTabActive` | This tab is the active polling tab (via cookie) |

### Events Monitored

- `mousedown`, `keydown`, `scroll`, `touchstart`

### Multi-Tab Detection

Uses `lastActiveWindow` cookie to prevent duplicate polling across browser tabs. Only the most recently active tab polls.

---

## Polling Intervals

| Nodelet | Interval | Hook | API Endpoint |
|---------|----------|------|--------------|
| **Chatterbox** | 45s active / 2m idle | `useChatterPolling` | `/api/chatter/` |
| **Other Users** | 2 minutes | `useOtherUsersPolling` | `/api/chatroom/` |
| **Messages** | 2 minutes | inline | `/api/messages/` |
| **Notifications** | 2 minutes | inline | `/api/notifications/` |
| **New Writeups** | 5 minutes | inline | `/api/cool/new_writeups` |

---

## Collapse-Aware Polling

Nodelets stop polling when collapsed to reduce unnecessary requests.

### Behavior

1. **Collapsed**: Polling stops completely
2. **Missed updates tracked**: System notes when polls were skipped
3. **Immediate refresh on expand**: When uncollapsed after missing updates, fetches immediately

### Implementation Pattern

```javascript
const MyNodelet = (props) => {
  const missedUpdate = React.useRef(false)
  const pollInterval = React.useRef(null)
  const { isActive, isMultiTabActive } = useActivityDetection(10)

  // Polling effect
  React.useEffect(() => {
    const shouldPoll = isActive && isMultiTabActive && props.nodeletIsOpen

    if (shouldPoll) {
      pollInterval.current = setInterval(() => {
        loadData()
      }, INTERVAL_MS)
    } else {
      if (isActive && isMultiTabActive && !props.nodeletIsOpen) {
        missedUpdate.current = true
      }
      if (pollInterval.current) {
        clearInterval(pollInterval.current)
        pollInterval.current = null
      }
    }

    return () => {
      if (pollInterval.current) {
        clearInterval(pollInterval.current)
      }
    }
  }, [isActive, isMultiTabActive, props.nodeletIsOpen])

  // Refresh on uncollapse
  React.useEffect(() => {
    if (props.nodeletIsOpen && missedUpdate.current) {
      missedUpdate.current = false
      loadData()
    }
  }, [props.nodeletIsOpen])
}
```

---

## Chatter-Specific Features

The `useChatterPolling` hook includes additional features:

### Incremental Updates

Uses `since` parameter to fetch only new messages:
```
GET /api/chatter/?since=1703000000&room=0
```

### Room Change Detection

Immediately refreshes when user changes chat rooms instead of waiting for next poll.

### Active/Idle Interval

Polls faster when user is recently active (45s) vs idle (2m).

---

## Background Request Header

All polling requests use the `X-Ajax-Idle` header to prevent updating the user's `lastseen` timestamp:

```javascript
fetch('/api/chatter/', {
  headers: {
    'X-Ajax-Idle': '1'
  }
})
```

Without this, background polling would make users appear constantly active.

**Backend check**: `ecore/Everything/Request.pm:171-174`

---

## Focus Refresh

The `usePolling` and `useChatterPolling` hooks also refresh when the page becomes visible (via `visibilitychange` event), so data is current when returning to a backgrounded tab.

---

## Related Files

| File | Purpose |
|------|---------|
| `react/hooks/useActivityDetection.js` | Shared activity detection hook |
| `react/hooks/useActivityDetection.test.js` | Hook tests |
| `react/hooks/usePolling.js` | Generic polling hook |
| `react/hooks/useChatterPolling.js` | Chatter polling hook |
| `react/hooks/useOtherUsersPolling.js` | Other users polling hook |
| `react/components/Nodelets/Chatterbox.js` | Uses useChatterPolling |
| `react/components/Nodelets/OtherUsers.js` | Uses useOtherUsersPolling |
| `react/components/Nodelets/Messages.js` | Inline polling |
| `react/components/Nodelets/Notifications.js` | Inline polling |
| `react/components/Nodelets/NewWriteups.js` | Inline polling |

---

*Last updated: December 2025*

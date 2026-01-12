# Mobile Optimization Plan for Everything2

**Created**: 2025-12-21
**Updated**: 2026-01-09
**Status**: Ready for Implementation

## Design Vision

A mobile-first redesign that eliminates the sidebar on mobile in favor of a modern bottom navigation bar (similar to Reddit/Instagram). The header is simplified with a compact logo, prominent search, and streamlined auth.

### Mobile Layout

```
┌─────────────────────────────────────────┐
│  E2    [    Search...        🔍] Sign In│
├─────────────────────────────────────────┤
│                                         │
│          [ Main Content ]               │
│                                         │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│     🔀          💬          👤         │
│   Discover     Chat       Sign In       │  ← Guest view (3 items)
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  E2    [    Search...        🔍]  [👤]  │  ← Logged-in (avatar/icon)
├─────────────────────────────────────────┤
│                                         │
│          [ Main Content ]               │
│                                         │
├─────────────────────────────────────────┤
│  ✏️      🔀      💬      ✉️      👤    │
│ Write  Discover  Chat   Inbox  Profile  │  ← Logged-in view (5 items)
└─────────────────────────────────────────┘
```

### Key Design Decisions

1. **Compact Logo**: "E2" in Decipher font instead of full "Everything2" logo
2. **Search-Centric**: Live search takes center stage for content discovery
3. **No Sidebar on Mobile**: Nodelets are desktop-only; mobile uses bottom nav
4. **Bottom Navigation Bar**: 5 icons for core actions (logged-in users)
5. **Discover Menu**: Popup with content feeds (New Writeups, Editor's Picks, etc.)
6. **Unified Auth Modal**: Single modal with tabs for Login/Sign Up (replaces sign-in nodelet site-wide)

---

## Bottom Navigation Bar

### Logged-In Users

| Icon | Label | Destination |
|------|-------|-------------|
| ✏️ | Write | Drafts page |
| 🔀 | Discover | Popup menu (see below) |
| 💬 | Chat | Chatterlight |
| ✉️ | Inbox | Message inbox (badge for unread) |
| 👤 | Profile | User's homenode |

### Discover Menu (Popup)

When user taps Discover, a bottom sheet or popover appears:

```
┌──────────────────────────┐
│ New Writeups             │
│ Editor's Picks           │
│ Best of the Week         │
│ Random Node              │
│ Cool Archive             │
└──────────────────────────┘
```

Note: Findings will be accessible via search results (when search returns no exact match).

### Guest Users

| Icon | Label | Action |
|------|-------|--------|
| 🔀 | Discover | Popup menu |
| 💬 | Chat | Chatterlight (read-only) |
| 👤 | Sign In | Opens auth modal (Login/Sign Up tabs) |

---

## Current State Analysis

### Architecture
- Mason templates fully retired - all pages render via React
- HTMLShell.pm generates the HTML wrapper
- React components handle all page content and layout
- Search bar is a React component (SearchBar.js)
- Sidebar/nodelets are React-rendered

### What's Working
- Viewport meta tag is present in HTMLShell.pm
- Some themes have media queries (1928497, 1965235, 1965286, 1965449, 2029380)
- E2NodeToolsModal and UserToolsModal have responsive CSS patterns
- Print stylesheet is separated

### Critical Gaps

| Issue | Severity | Impact |
|-------|----------|--------|
| Default theme (Kernel Blue) has NO media queries | CRITICAL | Most users get non-responsive layout |
| No mobile navigation system | CRITICAL | Users can't navigate effectively |
| No compact logo asset | HIGH | Full logo doesn't fit mobile header |
| Fixed pixel dimensions in CSS | HIGH | Layout breaks on small screens |

### Mobile Traffic Opportunity
- Mobile currently: ~14% of sessions
- Mobile RPM significantly higher than desktop
- Improving mobile UX could increase both traffic and revenue

---

## Phase 1: Mobile Header

**Goal**: Create compact, functional mobile header

### 1.1 Create Compact E2 Logo

- Design "E2" text logo in Decipher font style
- Match Kernel Blue color scheme (#38495e)
- SVG format for crisp rendering at any size
- Approximately 40-50px wide

### 1.2 Update Header Layout for Mobile

```jsx
// Mobile header structure
<header className="mobile-header">
  <a href="/" className="e2-logo-compact">E2</a>
  <SearchBar compact={true} />
  <div className="header-auth">
    {isGuest ? (
      <button className="sign-in-btn" onClick={() => setShowAuthModal(true)}>
        Sign In
      </button>
    ) : (
      <a href={`/user/${encodeURIComponent(user.title)}`} className="user-avatar">
        {/* User avatar or icon */}
        <FaUser />
      </a>
    )}
  </div>
</header>
```

### 1.3 CSS for Mobile Header

```css
@media (max-width: 767px) {
  .mobile-header {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    gap: 10px;
  }
  .e2-logo-compact {
    font-family: 'Decipher', serif;
    font-size: 24px;
    color: #38495e;
    text-decoration: none;
    flex-shrink: 0;
  }
  .mobile-header .search-bar {
    flex: 1;
  }
  .header-auth {
    flex-shrink: 0;
  }
  .sign-in-btn {
    background: #4060b0;
    color: white;
    border: none;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
  }
  .user-avatar {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: #e8f4f8;
    border-radius: 50%;
    color: #4060b0;
  }
}
```

---

## Phase 2: Bottom Navigation Bar

**Goal**: Create Reddit-style bottom nav for mobile

### 2.1 Create MobileBottomNav Component

```jsx
// react/components/Layout/MobileBottomNav.js
import { FaPen, FaCompass, FaComments, FaEnvelope, FaUser } from 'react-icons/fa'

const MobileBottomNav = ({ user, unreadMessages = 0, onShowAuth }) => {
  const [showDiscover, setShowDiscover] = useState(false)
  const isGuest = user?.guest

  return (
    <>
      <nav className="mobile-bottom-nav">
        {!isGuest && (
          <NavItem icon={FaPen} label="Write" href="/title/Drafts" />
        )}
        <NavItem
          icon={FaCompass}
          label="Discover"
          onClick={() => setShowDiscover(true)}
        />
        <NavItem icon={FaComments} label="Chat" href="/title/chatterlight" />
        {!isGuest ? (
          <>
            <NavItem
              icon={FaEnvelope}
              label="Inbox"
              href="/title/message+inbox"
              badge={unreadMessages}
            />
            <NavItem
              icon={FaUser}
              label="Profile"
              href={`/user/${encodeURIComponent(user.title)}`}
            />
          </>
        ) : (
          <NavItem
            icon={FaUser}
            label="Sign In"
            onClick={onShowAuth}
          />
        )}
      </nav>

      {showDiscover && (
        <DiscoverMenu onClose={() => setShowDiscover(false)} />
      )}
    </>
  )
}
```

### 2.2 Create DiscoverMenu Component

```jsx
// react/components/Layout/DiscoverMenu.js
const DiscoverMenu = ({ onClose }) => {
  const menuItems = [
    { label: 'New Writeups', href: '/title/New+Writeups' },
    { label: "Editor's Picks", href: '/title/Editor+Cools' },
    { label: 'Best of the Week', href: '/title/Page+of+Cool' },
    { label: 'Random Node', href: '/?op=randomnode', isRandom: true },
    { label: 'Cool Archive', href: '/title/Cool+Archive' },
    { label: 'Findings', href: '/title/Findings' },
  ]

  return (
    <div className="discover-overlay" onClick={onClose}>
      <div className="discover-menu" onClick={e => e.stopPropagation()}>
        <h3>Discover</h3>
        {menuItems.map(item => (
          <a
            key={item.label}
            href={item.href}
            onClick={item.isRandom ? handleRandomNode : undefined}
          >
            {item.label}
          </a>
        ))}
      </div>
    </div>
  )
}
```

### 2.3 Bottom Nav CSS

```css
.mobile-bottom-nav {
  display: none;
}

@media (max-width: 767px) {
  .mobile-bottom-nav {
    display: flex;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: #fff;
    border-top: 1px solid #e0e0e0;
    box-shadow: 0 -2px 10px rgba(0,0,0,0.1);
    z-index: 1000;
    padding: 8px 0;
    padding-bottom: calc(8px + env(safe-area-inset-bottom));
  }

  .mobile-bottom-nav .nav-item {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    color: #507898;
    text-decoration: none;
    font-size: 10px;
  }

  .mobile-bottom-nav .nav-item.active {
    color: #4060b0;
  }

  .mobile-bottom-nav .nav-item svg {
    font-size: 20px;
  }

  .mobile-bottom-nav .badge {
    position: absolute;
    top: -4px;
    right: -4px;
    background: #e74c3c;
    color: white;
    font-size: 10px;
    padding: 2px 5px;
    border-radius: 10px;
    min-width: 16px;
    text-align: center;
  }

  /* Add padding to body to account for fixed bottom nav */
  body {
    padding-bottom: calc(60px + env(safe-area-inset-bottom));
  }
}

/* Discover menu styles */
.discover-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  z-index: 1001;
  display: flex;
  align-items: flex-end;
}

.discover-menu {
  background: white;
  width: 100%;
  border-radius: 16px 16px 0 0;
  padding: 20px;
  padding-bottom: calc(20px + env(safe-area-inset-bottom));
}

.discover-menu h3 {
  margin: 0 0 16px 0;
  color: #38495e;
  font-size: 18px;
}

.discover-menu a {
  display: block;
  padding: 14px 0;
  color: #38495e;
  text-decoration: none;
  border-bottom: 1px solid #f0f0f0;
  font-size: 16px;
}

.discover-menu a:last-child {
  border-bottom: none;
}
```

### 2.4 Create AuthModal Component

A unified modal with tabs for Login and Sign Up, keeping users in context. This replaces the sign-in nodelet site-wide (both mobile and desktop) for a consistent, modern auth experience.

```jsx
// react/components/Layout/AuthModal.js
import { useState } from 'react'
import { FaTimes } from 'react-icons/fa'

const AuthModal = ({ onClose, initialTab = 'login' }) => {
  const [activeTab, setActiveTab] = useState(initialTab)
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    email: '',
    confirmPassword: ''
  })
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  const handleLogin = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    try {
      const response = await fetch('/api/sessions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: formData.username,
          password: formData.password
        })
      })
      const data = await response.json()
      if (data.success) {
        window.location.reload()
      } else {
        setError(data.error || 'Login failed')
      }
    } catch (err) {
      setError('Connection error. Please try again.')
    }
    setLoading(false)
  }

  const handleSignup = async (e) => {
    e.preventDefault()
    if (formData.password !== formData.confirmPassword) {
      setError('Passwords do not match')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const response = await fetch('/api/registrations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: formData.username,
          password: formData.password,
          email: formData.email
        })
      })
      const data = await response.json()
      if (data.success) {
        // Auto-login or show success message
        window.location.reload()
      } else {
        setError(data.error || 'Registration failed')
      }
    } catch (err) {
      setError('Connection error. Please try again.')
    }
    setLoading(false)
  }

  return (
    <div className="auth-overlay" onClick={onClose}>
      <div className="auth-modal" onClick={e => e.stopPropagation()}>
        <button className="auth-close" onClick={onClose}>
          <FaTimes />
        </button>

        <div className="auth-tabs">
          <button
            className={`auth-tab ${activeTab === 'login' ? 'active' : ''}`}
            onClick={() => setActiveTab('login')}
          >
            Log In
          </button>
          <button
            className={`auth-tab ${activeTab === 'signup' ? 'active' : ''}`}
            onClick={() => setActiveTab('signup')}
          >
            Sign Up
          </button>
        </div>

        {error && <div className="auth-error">{error}</div>}

        {activeTab === 'login' ? (
          <form onSubmit={handleLogin} className="auth-form">
            <input
              type="text"
              placeholder="Username"
              value={formData.username}
              onChange={e => setFormData({...formData, username: e.target.value})}
              required
              autoComplete="username"
            />
            <input
              type="password"
              placeholder="Password"
              value={formData.password}
              onChange={e => setFormData({...formData, password: e.target.value})}
              required
              autoComplete="current-password"
            />
            <button type="submit" disabled={loading}>
              {loading ? 'Logging in...' : 'Log In'}
            </button>
            <a href="/title/Forgot+Password" className="auth-forgot">
              Forgot password?
            </a>
          </form>
        ) : (
          <form onSubmit={handleSignup} className="auth-form">
            <input
              type="text"
              placeholder="Username"
              value={formData.username}
              onChange={e => setFormData({...formData, username: e.target.value})}
              required
              autoComplete="username"
            />
            <input
              type="email"
              placeholder="Email"
              value={formData.email}
              onChange={e => setFormData({...formData, email: e.target.value})}
              required
              autoComplete="email"
            />
            <input
              type="password"
              placeholder="Password"
              value={formData.password}
              onChange={e => setFormData({...formData, password: e.target.value})}
              required
              autoComplete="new-password"
            />
            <input
              type="password"
              placeholder="Confirm Password"
              value={formData.confirmPassword}
              onChange={e => setFormData({...formData, confirmPassword: e.target.value})}
              required
              autoComplete="new-password"
            />
            <button type="submit" disabled={loading}>
              {loading ? 'Creating account...' : 'Create Account'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}
```

### 2.5 AuthModal CSS

```css
.auth-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  z-index: 1002;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.auth-modal {
  background: white;
  width: 100%;
  max-width: 400px;
  border-radius: 12px;
  padding: 24px;
  position: relative;
}

.auth-close {
  position: absolute;
  top: 12px;
  right: 12px;
  background: none;
  border: none;
  color: #507898;
  font-size: 20px;
  cursor: pointer;
  padding: 4px;
}

.auth-tabs {
  display: flex;
  gap: 0;
  margin-bottom: 20px;
  border-bottom: 2px solid #e0e0e0;
}

.auth-tab {
  flex: 1;
  background: none;
  border: none;
  padding: 12px;
  font-size: 16px;
  font-weight: 500;
  color: #507898;
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
}

.auth-tab.active {
  color: #4060b0;
  border-bottom-color: #4060b0;
}

.auth-error {
  background: #ffebee;
  color: #c62828;
  padding: 10px 12px;
  border-radius: 4px;
  margin-bottom: 16px;
  font-size: 14px;
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.auth-form input {
  padding: 12px;
  border: 1px solid #e0e0e0;
  border-radius: 6px;
  font-size: 16px;
}

.auth-form input:focus {
  outline: none;
  border-color: #4060b0;
  box-shadow: 0 0 0 3px rgba(64, 96, 176, 0.1);
}

.auth-form button[type="submit"] {
  background: #4060b0;
  color: white;
  border: none;
  padding: 14px;
  border-radius: 6px;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  margin-top: 4px;
}

.auth-form button[type="submit"]:disabled {
  background: #a0b0c0;
  cursor: not-allowed;
}

.auth-forgot {
  text-align: center;
  color: #507898;
  font-size: 14px;
  text-decoration: none;
}

.auth-forgot:hover {
  color: #4060b0;
}
```

---

## Phase 3: Hide Sidebar on Mobile

**Goal**: Completely remove sidebar from mobile view

### 3.1 CSS Changes

```css
@media (max-width: 767px) {
  #sidebar {
    display: none !important;
  }

  #wrapper {
    padding-right: 0;
  }

  #mainbody {
    width: 100%;
    float: none;
  }
}
```

### 3.2 Conditional Rendering (Optional)

Could also skip rendering nodelets entirely on mobile for performance:

```jsx
// In PageLayout.js
const isMobile = useMediaQuery('(max-width: 767px)')

return (
  <>
    <Header />
    <main>{children}</main>
    {!isMobile && <Sidebar nodelets={nodelets} />}
    {isMobile && <MobileBottomNav user={user} />}
  </>
)
```

---

## Phase 4: Utility Hooks and Constants

### 4.1 Create Breakpoint Constants

```jsx
// react/utils/breakpoints.js
export const BREAKPOINTS = {
  MOBILE: 767,
  TABLET: 991,
  DESKTOP: 1200
}

export const MEDIA_QUERIES = {
  mobile: `(max-width: ${BREAKPOINTS.MOBILE}px)`,
  tablet: `(min-width: ${BREAKPOINTS.MOBILE + 1}px) and (max-width: ${BREAKPOINTS.TABLET}px)`,
  desktop: `(min-width: ${BREAKPOINTS.TABLET + 1}px)`
}
```

### 4.2 Create useMediaQuery Hook

```jsx
// react/hooks/useMediaQuery.js
import { useState, useEffect } from 'react'

export const useMediaQuery = (query) => {
  const [matches, setMatches] = useState(
    () => typeof window !== 'undefined' && window.matchMedia(query).matches
  )

  useEffect(() => {
    const mql = window.matchMedia(query)
    const handler = (e) => setMatches(e.matches)
    mql.addEventListener('change', handler)
    return () => mql.removeEventListener('change', handler)
  }, [query])

  return matches
}

// Convenience hooks
export const useIsMobile = () => useMediaQuery('(max-width: 767px)')
export const useIsTablet = () => useMediaQuery('(min-width: 768px) and (max-width: 991px)')
export const useIsDesktop = () => useMediaQuery('(min-width: 992px)')
```

---

## Phase 5: Content Area Optimization

### 5.1 Full-Width Content on Mobile

```css
@media (max-width: 767px) {
  #mainbody {
    padding: 12px;
  }

  .writeup-content {
    font-size: 16px;
    line-height: 1.6;
  }

  /* Ensure images don't overflow */
  .writeup-content img {
    max-width: 100%;
    height: auto;
  }
}
```

### 5.2 Touch-Friendly Targets

- Minimum 44x44px tap targets for buttons and links
- Adequate spacing between interactive elements
- Larger vote/cool buttons on mobile

---

## Implementation Order

1. **Phase 4** - Create breakpoints and useMediaQuery hook (foundation)
2. **Phase 2.1-2.5** - Create MobileBottomNav, DiscoverMenu, and AuthModal components
3. **Phase 3** - Hide sidebar on mobile via CSS
4. **Phase 1** - Create compact header with E2 logo and auth trigger
5. **Phase 5** - Content area optimization
6. **Testing** - Test across devices

---

## Testing Strategy

### Device Widths to Test
- 320px - iPhone SE (smallest common)
- 375px - iPhone 12/13/14
- 390px - iPhone 14 Pro
- 768px - iPad portrait (breakpoint boundary)
- 1024px+ - Desktop (should show sidebar)

### Key Interactions to Test
- Bottom nav taps work correctly
- Discover menu opens and closes
- Search works in compact header
- Auth modal opens from header and bottom nav
- Auth modal tab switching (Login ↔ Sign Up)
- Login form submits correctly
- Sign Up form validates and submits
- Badge shows unread message count
- Safe area insets work on notched phones

### Testing Tools
- Chrome DevTools device emulation
- `node tools/browser-debug.js screenshot` at various widths
- Real device testing (iOS Safari, Android Chrome)

---

## Success Metrics

- Mobile traffic share increases (from ~14% baseline)
- Mobile bounce rate decreases
- Mobile session duration increases
- Mobile pages per session increases
- Google PageSpeed mobile score improves

---

## Notes

- Bottom nav pattern is familiar from Reddit, Instagram, Twitter
- Discover menu consolidates what nodelets do on desktop
- No need for hamburger menu since sidebar is eliminated
- Consider adding haptic feedback on nav taps (via Vibration API)
- Badge count for Inbox requires unread message count in window.e2
- Auth modal keeps users in context (no page navigation for login/signup)
- Auth modal replaces sign-in nodelet site-wide (desktop sidebar + mobile bottom nav + header)
- Auth modal can be triggered from multiple places (header button, bottom nav, sidebar on desktop)
- On desktop, sidebar "Sign In" link opens the auth modal instead of rendering the old nodelet form
- Consider social login options in future (Google, etc.)

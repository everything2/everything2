# Nodelet Migration Status

**Last Updated**: 2025-11-23
**Migration Target**: React 18.3.x with Portals

## Overview

This document tracks the migration status of all nodelets in the Everything2 codebase from Perl/Mason templates to React components. Nodelets are sidebar components that provide various functionality and information to users.

## Migration Statistics

- **Total Nodelets**: 26
- **Migrated to React**: 22 (85%)
- **Remaining in Perl**: 4 (15%)

## React Migration Pattern

All React nodelets follow this established architecture:

1. **Component** ([react/components/Nodelets/*.js](../react/components/Nodelets/)) - React functional component
2. **Portal** ([react/components/Portals/*Portal.js](../react/components/Portals/)) - Renders component into Mason DOM
3. **E2ReactRoot Integration** ([react/components/E2ReactRoot.js](../react/components/E2ReactRoot.js)) - State management and data flow
4. **Data Loading** ([ecore/Everything/Application.pm](../ecore/Everything/Application.pm)) - buildNodeInfoStructure()
5. **Perl Stub** ([ecore/Everything/Delegation/nodelet.pm](../ecore/Everything/Delegation/nodelet.pm)) - Returns empty string

### Portal Implementation Pattern ⚠️

**CRITICAL**: All portal components must extend `NodeletPortal` class, not be functional components.

**Correct Pattern** (used by all working nodelets):
```javascript
import NodeletPortal from './NodeletPortal'

class StatisticsPortal extends NodeletPortal {
  constructor(props) {
    super(props)
    this.insertRoot = document.getElementById('statistics')
  }
}

export default StatisticsPortal
```

**Incorrect Pattern** (will cause props not to flow and NodeletContainer to not render):
```javascript
// ❌ WRONG - DO NOT USE
const StatisticsPortal = (props) => {
  const container = document.getElementById('statistics')
  return ReactDOM.createPortal(
    <Statistics {...props} />,
    container
  )
}
```

**Why the class pattern is required**:
- `NodeletPortal` creates a div element and appends it to the target container
- It renders `this.props.children` into that div via `ReactDOM.createPortal()`
- E2ReactRoot passes the component as children to the portal:
  ```javascript
  <StatisticsPortal>
    <ErrorBoundary>
      <Statistics {...props} />
    </ErrorBoundary>
  </StatisticsPortal>
  ```
- The portal must render `props.children`, not create its own instance of the component

**Symptoms of incorrect portal implementation**:
- Component appears to mount but `NodeletContainer` doesn't render
- Props don't flow from E2ReactRoot to the nodelet component
- State shows correct data in DevTools but component displays nothing

**Reference**: See [StatisticsPortal.js](../react/components/Portals/StatisticsPortal.js) (fixed 2025-11-22) and [EpicenterPortal.js](../react/components/Portals/EpicenterPortal.js) for examples.

## Migrated Nodelets (React)

### 1. NewWriteups ✅
**Status**: Complete
**Function**: `new_writeups()` (line 93)
**Component**: [react/components/Nodelets/NewWriteups.js](../react/components/Nodelets/NewWriteups.js)
**Portal**: [react/components/Portals/NewWriteupsPortal.js](../react/components/Portals/NewWriteupsPortal.js)
**Description**: Real-time feed of new writeups with filtering controls (show/hide junk, count selection)
**Features**:
- NewWriteupsEntry component for individual entries
- NewWriteupsFilter for user controls
- State management for filter preferences
- Real-time updates

### 2. SignIn ✅
**Status**: Complete
**Function**: `sign_in()` (line 368)
**Component**: [react/components/Nodelets/SignIn.js](../react/components/Nodelets/SignIn.js)
**Portal**: [react/components/Portals/SignInPortal.js](../react/components/Portals/SignInPortal.js)
**Description**: Guest user sign-in form
**Features**:
- Only shown when user.guest is true
- Authentication form

### 3. RecommendedReading ✅
**Status**: Complete
**Function**: `recommended_reading()` (line 373)
**Component**: [react/components/Nodelets/RecommendedReading.js](../react/components/Nodelets/RecommendedReading.js)
**Portal**: [react/components/Portals/RecommendedReadingPortal.js](../react/components/Portals/RecommendedReadingPortal.js)
**Description**: Cool Archive user picks and Page of Cool editor selections
**Features**:
- Two sections: Cool Archive and Page of Cool
- Similar structure to ReadThis nodelet

### 4. Vitals ✅
**Status**: Complete
**Function**: `vitals()` (line 378)
**Component**: [react/components/Nodelets/Vitals.js](../react/components/Nodelets/Vitals.js)
**Portal**: [react/components/Portals/VitalsPortal.js](../react/components/Portals/VitalsPortal.js)
**Description**: Node maintenance tools, XP display, level progress
**Features**:
- Multiple collapsible sections: Maintenance, Node Info, Lists, Utilities, Misc
- Uses NodeletSection for section management
- Complex state management

### 5. EverythingDeveloper ✅
**Status**: Complete
**Function**: `everything_developer()` (line 606)
**Component**: [react/components/Nodelets/Developer.js](../react/components/Nodelets/Developer.js)
**Portal**: [react/components/Portals/DeveloperPortal.js](../react/components/Portals/DeveloperPortal.js)
**Description**: Developer tools and news for contributors
**Features**:
- Two sections: Utility and Everything Development
- Conditional rendering based on user.developer flag

### 6. RandomNodes ✅
**Status**: Complete
**Function**: `random_nodes()` (line 601)
**Component**: [react/components/Nodelets/RandomNodes.js](../react/components/Nodelets/RandomNodes.js)
**Portal**: [react/components/Portals/RandomNodesPortal.js](../react/components/Portals/RandomNodesPortal.js)
**Description**: Random node recommendations
**Features**:
- Randomized phrase header for variety
- Random node suggestions

### 7. NewLogs ✅
**Status**: Complete
**Function**: `new_logs()` (line 835)
**Component**: [react/components/Nodelets/NewLogs.js](../react/components/Nodelets/NewLogs.js)
**Portal**: [react/components/Portals/NewLogsPortal.js](../react/components/Portals/NewLogsPortal.js)
**Description**: System logs and admin messages
**Features**:
- Conditional rendering based on log availability
- Admin/moderator focused

### 8. NeglectedDrafts ✅
**Status**: Complete
**Function**: `neglected_drafts()` (line 1080)
**Component**: [react/components/Nodelets/NeglectedDrafts.js](../react/components/Nodelets/NeglectedDrafts.js)
**Portal**: [react/components/Portals/NeglectedDraftsPortal.js](../react/components/Portals/NeglectedDraftsPortal.js)
**Description**: Draft management for writers
**Features**:
- Conditional rendering based on draft availability
- Draft tracking and management

### 9. QuickReference ✅
**Status**: Complete
**Function**: `quick_reference()` (line 1120)
**Component**: [react/components/Nodelets/QuickReference.js](../react/components/Nodelets/QuickReference.js)
**Portal**: [react/components/Portals/QuickReferencePortal.js](../react/components/Portals/QuickReferencePortal.js)
**Description**: Help links and quick access tools
**Features**:
- Quick reference documentation links
- User help resources

### 10. ReadThis ✅
**Status**: Complete
**Function**: `readthis()` (line 632)
**Component**: [react/components/Nodelets/ReadThis.js](../react/components/Nodelets/ReadThis.js)
**Portal**: [react/components/Portals/ReadThisPortal.js](../react/components/Portals/ReadThisPortal.js)
**Test Suite**: [react/components/Nodelets/ReadThis.test.js](../react/components/Nodelets/ReadThis.test.js) (25 tests)
**Description**: News and featured content aggregation
**Features**:
- Three collapsible sections:
  1. **Cool Writeups** - Recent cool-marked content
  2. **Editor Selections** - Staff picks
  3. **News** - Weblog entries from "News For Noders. Stuff that matters."
- Uses frontpagenews DataStash for news content
- Footer links to Cool Archive and Page of Cool
- Comprehensive test coverage (25 tests)

### 11. Epicenter ✅
**Status**: Complete
**Function**: `epicenter()` (line 21)
**Component**: [react/components/Nodelets/Epicenter.js](../react/components/Nodelets/Epicenter.js)
**Portal**: [react/components/Portals/EpicenterPortal.js](../react/components/Portals/EpicenterPortal.js)
**Test Suite**: [react/components/Nodelets/Epicenter.test.js](../react/components/Nodelets/Epicenter.test.js) (25 tests)
**Description**: User dashboard with stats and quick navigation
**Features**:
- User authentication links (Log Out, Settings, Profile)
- Voting/Experience system (votes left, cools, XP, GP)
- Quick navigation (Drafts, Help, Random Node, Voting/XP System)
- Server time display (with optional local time)
- Borgcheck warnings
- Conditional rendering based on user level (Help page varies for new vs established users)
- GP opt-out support
- Pragmatic hybrid approach: raw data for simple elements, pre-rendered HTML for complex calculations (XP/GP changes, time display)
- Comprehensive test coverage (25 tests)

### 12. MasterControl ✅
**Status**: Complete
**Function**: `master_control()` (line 686)
**Component**: [react/components/Nodelets/MasterControl.js](../react/components/Nodelets/MasterControl.js)
**Portal**: [react/components/Portals/MasterControlPortal.js](../react/components/Portals/MasterControlPortal.js)
**Test Suite**: [react/components/Nodelets/MasterControl.test.js](../react/components/Nodelets/MasterControl.test.js) (26 tests)
**Description**: Admin control panel for editors and administrators
**Features**:
- Role-based access control (isEditor, isAdmin)
- Admin search form for node lookup
- Node note management
- Admin toolset (admin-only)
- Admin section controls (admin-only)
- CE (Content Editor) section tools
- Non-editors see "Nothing for you here" message
- Pragmatic hybrid approach using dangerouslySetInnerHTML for htmlcode-generated content
- Comprehensive test coverage (26 tests)

### 13. Statistics ✅
**Status**: Complete
**Function**: `statistics()` (line 554)
**Component**: [react/components/Nodelets/Statistics.js](../react/components/Nodelets/Statistics.js)
**Portal**: [react/components/Portals/StatisticsPortal.js](../react/components/Portals/StatisticsPortal.js)
**Test Suite**: [react/components/Nodelets/Statistics.test.js](../react/components/Nodelets/Statistics.test.js) (27 tests)
**Description**: User statistics display showing XP, level progression, fun stats, and merit system
**Features**:
- Three collapsible sections:
  1. **Yours** - Personal stats (XP, writeups, level, XP/WUs needed, GP)
  2. **Fun Stats** - Node-Fu, Golden/Silver Trinkets, Stars, Easter Eggs, Tokens
  3. **Old Merit System** - Merit, LF, Devotion, Merit mean/stddev
- Conditional rendering (XP needed vs WUs needed, GP opt-out support)
- Proper handling of zero values and missing sections
- Fixed gpOptout boolean serialization (was using scalar refs `\1`/`\0`)
- Fixed portal implementation to extend NodeletPortal class (2025-11-22)
- Comprehensive test coverage (27 tests including edge cases)

### 14. Notelet ✅
**Status**: Complete
**Function**: `notelet()` (line 216)
**Component**: [react/components/Nodelets/Notelet.js](../react/components/Nodelets/Notelet.js)
**Portal**: [react/components/Portals/NoteletPortal.js](../react/components/Portals/NoteletPortal.js)
**Test Suite**: [react/components/Nodelets/Notelet.test.js](../react/components/Nodelets/Notelet.test.js) (39 tests)
**Description**: Personal sticky notes feature for users
**Features**:
- Locked state handling (when administrator is working on account)
- No content state with setup instructions
- Content display using ParseLinks for E2 bracket syntax
- Edit link to Notelet Editor superdoc
- Remove link for nodelet management
- Links to Nodelet Settings
- Comprehensive test coverage (39 tests)

### 15. OtherUsers ✅
**Status**: Complete
**Function**: `other_users()` (line 42)
**Component**: [react/components/Nodelets/OtherUsers.js](../react/components/Nodelets/OtherUsers.js)
**Portal**: [react/components/Portals/OtherUsersPortal.js](../react/components/Portals/OtherUsersPortal.js)
**Test Suite**: [react/components/Nodelets/OtherUsers.test.js](../react/components/Nodelets/OtherUsers.test.js)
**Description**: List of online users with chatroom management
**Features**:
- Real-time user tracking and display
- Chatroom creation and management
- Room switching functionality
- User list display with cloaking support

### 16. PersonalLinks ✅
**Status**: Complete
**Function**: `personal_links()` (line 171)
**Component**: [react/components/Nodelets/PersonalLinks.js](../react/components/Nodelets/PersonalLinks.js)
**Portal**: [react/components/Portals/PersonalLinksPortal.js](../react/components/Portals/PersonalLinksPortal.js)
**Test Suite**: [react/components/Nodelets/PersonalLinks.test.js](../react/components/Nodelets/PersonalLinks.test.js)
**Description**: User's personal bookmarked links
**Features**:
- Display user's personal link collection
- Add current node to personal links
- Link management

### 17. RecentNodes ✅
**Status**: Complete
**Function**: `recent_nodes()` (line 231)
**Component**: [react/components/Nodelets/RecentNodes.js](../react/components/Nodelets/RecentNodes.js)
**Portal**: [react/components/Portals/RecentNodesPortal.js](../react/components/Portals/RecentNodesPortal.js)
**Test Suite**: [react/components/Nodelets/RecentNodes.test.js](../react/components/Nodelets/RecentNodes.test.js)
**Description**: Recently viewed nodes history
**Features**:
- Display user's browsing history
- Navigation to recently visited nodes

### 18. FavoriteNoders ✅
**Status**: Complete
**Function**: `favorite_noders()` (line 256)
**Component**: [react/components/Nodelets/FavoriteNoders.js](../react/components/Nodelets/FavoriteNoders.js)
**Portal**: [react/components/Portals/FavoriteNodersPortal.js](../react/components/Portals/FavoriteNodersPortal.js)
**Test Suite**: [react/components/Nodelets/FavoriteNoders.test.js](../react/components/Nodelets/FavoriteNoders.test.js)
**Description**: Writeups from user's favorite noders
**Features**:
- Display writeups from favorited users
- Hard-coded 5-writeup limit (TODO: API enhancement #3765)

### 19. CurrentUserPoll ✅
**Status**: Complete
**Function**: `current_user_poll()` (line 251)
**Component**: [react/components/Nodelets/CurrentUserPoll.js](../react/components/Nodelets/CurrentUserPoll.js)
**Portal**: [react/components/Portals/CurrentUserPollPortal.js](../react/components/Portals/CurrentUserPollPortal.js)
**Test Suite**: [react/components/Nodelets/CurrentUserPoll.test.js](../react/components/Nodelets/CurrentUserPoll.test.js)
**Description**: Active poll display and voting
**Features**:
- Display current user poll
- Interactive voting functionality
- Poll results display

### 20. UsergroupWriteups ✅
**Status**: Complete
**Function**: `usergroup_writeups()` (line 266)
**Component**: [react/components/Nodelets/UsergroupWriteups.js](../react/components/Nodelets/UsergroupWriteups.js)
**Portal**: [react/components/Portals/UsergroupWriteupsPortal.js](../react/components/Portals/UsergroupWriteupsPortal.js)
**Test Suite**: [react/components/Nodelets/UsergroupWriteups.test.js](../react/components/Nodelets/UsergroupWriteups.test.js)
**Description**: Writeups from specific usergroups
**Features**:
- Display writeups from selected usergroup
- Usergroup selector dropdown
- Restricted usergroup access control
- Editor override for restricted content

### 21. Categories ✅
**Status**: Complete
**Function**: `categories()` (line 300)
**Component**: [react/components/Nodelets/Categories.js](../react/components/Nodelets/Categories.js)
**Portal**: [react/components/Portals/CategoriesPortal.js](../react/components/Portals/CategoriesPortal.js)
**Test Suite**: [react/components/Nodelets/Categories.test.js](../react/components/Nodelets/Categories.test.js)
**Description**: Content category navigation
**Features**:
- Display available content categories
- Add current node to category
- Category author attribution
- Create new category link

### 22. MostWanted ✅
**Status**: Complete
**Function**: `most_wanted()` (line 305)
**Component**: [react/components/Nodelets/MostWanted.js](../react/components/Nodelets/MostWanted.js)
**Portal**: [react/components/Portals/MostWantedPortal.js](../react/components/Portals/MostWantedPortal.js)
**Test Suite**: [react/components/Nodelets/MostWanted.test.js](../react/components/Nodelets/MostWanted.test.js)
**Description**: Most wanted/requested nodes
**Features**:
- Display most requested but missing nodes
- Bounty information
- Community content gaps identification

## Remaining Nodelets (Perl)

### 23. Chatterbox ⏳
**Status**: Perl
**Function**: `chatterbox()` (line 62)
**Description**: Real-time chat interface
**Complexity**: High - Complex state, AJAX updates, real-time messaging
**Priority**: High - Core social feature, prime candidate for React
**Notes**: Uses AJAX showchatter polling (11-second refresh), complex interaction patterns

### 24. Notifications ⏳
**Status**: Perl
**Function**: `notifications()` (line 271)
**Description**: User notifications and alerts
**Complexity**: High - Real-time updates, multiple notification types
**Priority**: High - Important UX feature, excellent React candidate

### 25. Messages ⏳
**Status**: Perl
**Function**: `messages()` (line 310)
**Description**: User messaging interface
**Complexity**: High - Complex messaging, read/unread state
**Priority**: High - Core communication feature

### 26. ForReview ⏳
**Status**: Perl
**Function**: `for_review()` (line 328)
**Description**: Editor-focused nodelet showing drafts submitted for review
**Complexity**: Medium - DataStash integration, conditional display for editors
**Priority**: Medium - Editor workflow tool

## Recommended Migration Order

Based on user impact, complexity, and architectural benefits:

### Remaining High Priority Features
1. **Chatterbox** - Core social feature, would benefit from modern state management
2. **Notifications** - Important UX, real-time updates ideal for React
3. **Messages** - Core communication, complex state management
4. **ForReview** - Editor workflow tool, DataStash integration

## Migration Benefits

### Completed Migrations
- ✅ Reduced server-side rendering load
- ✅ Improved client-side interactivity
- ✅ Better state management
- ✅ Component reusability (NodeletContainer, NodeletSection, LinkNode)
- ✅ Comprehensive test coverage (429+ tests total)
- ✅ Progressive enhancement approach maintains backward compatibility
- ✅ **22 of 26 nodelets now in React (85% complete)**
- ✅ Only 4 nodelets remain (Chatterbox, Notifications, Messages, ForReview)

### Future Benefits
- 🔄 Easier feature additions and modifications
- 🔄 Better performance with client-side updates
- 🔄 Modern development experience
- 🔄 Improved maintainability

## Technical Notes

### Common Migration Pattern

1. Create React component in `react/components/Nodelets/`
2. Create Portal component in `react/components/Portals/`
3. Add data loading in `Application.pm::buildNodeInfoStructure()`
4. Update Perl function to return empty string
5. Integrate in E2ReactRoot.js
6. Add comprehensive test coverage

### Shared Components

All React nodelets use these shared components:
- **NodeletContainer** - Base wrapper with title and collapse functionality
- **NodeletSection** - Collapsible sections within nodelets
- **LinkNode** - Consistent node linking across all nodelets
- **ErrorBoundary** - Graceful error handling

### Data Flow

```
Perl Backend (Application.pm)
  ↓
buildNodeInfoStructure()
  ↓
window.e2 JSON object
  ↓
E2ReactRoot initial state
  ↓
Portal components
  ↓
Nodelet components
```

## Testing Status

- **Total React Tests**: 429
  - NewWriteups: ~20 tests
  - Vitals: ~25 tests
  - Developer: ~15 tests
  - RecommendedReading: ~15 tests
  - ReadThis: 25 tests
  - Epicenter: 25 tests
  - MasterControl: 26 tests
  - Statistics: 32 tests
  - Notelet: 39 tests
  - Other nodelets and components: ~207 tests

## Related Documentation

- [React Migration Strategy](react-migration-strategy.md) - Overall migration approach
- [React 19 Migration Plan](react-19-migration.md) - Future React 19 upgrade
- [Show Content Analysis](show_content_analysis.md) - Content rendering patterns
- [Notification System](notification-system.md) - Notification architecture

---

*Maintained by: Jay Bonci*
*For questions or updates, see [CLAUDE.md](../CLAUDE.md)*

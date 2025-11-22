# Nodelet Migration Status

**Last Updated**: 2025-11-20
**Migration Target**: React 18.3.x with Portals

## Overview

This document tracks the migration status of all nodelets in the Everything2 codebase from Perl/Mason templates to React components. Nodelets are sidebar components that provide various functionality and information to users.

## Migration Statistics

- **Total Nodelets**: 25
- **Migrated to React**: 12 (48%)
- **Remaining in Perl**: 13 (52%)

## React Migration Pattern

All React nodelets follow this established architecture:

1. **Component** ([react/components/Nodelets/*.js](../react/components/Nodelets/)) - React functional component
2. **Portal** ([react/components/Portals/*Portal.js](../react/components/Portals/)) - Renders component into Mason DOM
3. **E2ReactRoot Integration** ([react/components/E2ReactRoot.js](../react/components/E2ReactRoot.js)) - State management and data flow
4. **Data Loading** ([ecore/Everything/Application.pm](../ecore/Everything/Application.pm)) - buildNodeInfoStructure()
5. **Perl Stub** ([ecore/Everything/Delegation/nodelet.pm](../ecore/Everything/Delegation/nodelet.pm)) - Returns empty string

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
**Status**: Complete (Just Migrated!)
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

## Remaining Nodelets (Perl)

### 13. OtherUsers ⏳
**Status**: Perl
**Function**: `other_users()` (line 98)
**Description**: List of online users
**Complexity**: Medium - Real-time user tracking
**Priority**: Medium - Social feature, could benefit from React updates

### 14. Chatterbox ⏳
**Status**: Perl
**Function**: `chatterbox()` (line 383)
**Description**: Real-time chat interface
**Complexity**: High - Complex state, AJAX updates, real-time messaging
**Priority**: High - Core social feature, prime candidate for React
**Notes**: Uses AJAX showchatter polling (11-second refresh), complex interaction patterns

### 15. PersonalLinks ⏳
**Status**: Perl
**Function**: `personal_links()` (line 492)
**Description**: User's bookmarked links
**Complexity**: Low-Medium - Simple list display
**Priority**: Low - Personal feature, less critical

### 16. Statistics ⏳
**Status**: Perl
**Function**: `statistics()` (line 611)
**Description**: Site statistics display
**Complexity**: Low - Mostly static data display
**Priority**: Low - Informational, infrequent updates

### 17. Notelet ⏳
**Status**: Perl
**Function**: `notelet()` (line 647)
**Description**: Personal notes
**Complexity**: Medium - User-specific content
**Priority**: Low - Personal feature

### 18. RecentNodes ⏳
**Status**: Perl
**Function**: `recent_nodes()` (line 698)
**Description**: Recently viewed nodes
**Complexity**: Low - Simple history list
**Priority**: Low - Nice-to-have feature

### 19. CurrentUserPoll ⏳
**Status**: Perl
**Function**: `current_user_poll()` (line 769)
**Description**: Active poll display and voting
**Complexity**: Medium - Interactive voting
**Priority**: Medium - Community engagement feature

### 20. FavoriteNoders ⏳
**Status**: Perl
**Function**: `favorite_noders()` (line 782)
**Description**: User's favorite community members
**Complexity**: Low - Simple list display
**Priority**: Low - Social feature

### 21. UsergroupWriteups ⏳
**Status**: Perl
**Function**: `usergroup_writeups()` (line 840)
**Description**: Writeups from specific usergroups
**Complexity**: Medium - Filtered content display
**Priority**: Medium - Group-specific content

### 22. Notifications ⏳
**Status**: Perl
**Function**: `notifications()` (line 933)
**Description**: User notifications and alerts
**Complexity**: High - Real-time updates, multiple notification types
**Priority**: High - Important UX feature, excellent React candidate

### 23. Categories ⏳
**Status**: Perl
**Function**: `categories()` (line 962)
**Description**: Content category navigation
**Complexity**: Low - Navigation links
**Priority**: Low - Static navigation

### 24. MostWanted ⏳
**Status**: Perl
**Function**: `most_wanted()` (line 1020)
**Description**: Requested but missing nodes
**Complexity**: Low - Simple list display
**Priority**: Low - Community feature

### 25. Messages ⏳
**Status**: Perl
**Function**: `messages()` (line 1067)
**Description**: User messaging interface
**Complexity**: High - Complex messaging, read/unread state
**Priority**: High - Core communication feature

## Recommended Migration Order

Based on user impact, complexity, and architectural benefits:

### Tier 1: High Priority (Core Features)
1. **Chatterbox** - Core social feature, would benefit from modern state management
2. **Notifications** - Important UX, real-time updates ideal for React
3. **Messages** - Core communication, complex state management

### Tier 2: Medium Priority (Engagement Features)
4. **CurrentUserPoll** - Interactive, community engagement
5. **UsergroupWriteups** - Content display, moderate complexity
6. **OtherUsers** - Social awareness, real-time updates

### Tier 3: Lower Priority (Informational/Admin)
7. **Statistics** - Static display

### Tier 4: Personal/Niche Features
8. **PersonalLinks** - Personal feature
9. **Notelet** - Personal notes
10. **RecentNodes** - Personal history
11. **FavoriteNoders** - Personal list
12. **Categories** - Static navigation
13. **MostWanted** - Community list

## Migration Benefits

### Completed Migrations
- ✅ Reduced server-side rendering load
- ✅ Improved client-side interactivity
- ✅ Better state management
- ✅ Component reusability (NodeletContainer, NodeletSection, LinkNode)
- ✅ Comprehensive test coverage (193 tests total)
- ✅ Progressive enhancement approach maintains backward compatibility

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

- **Total React Tests**: 193
  - NewWriteups: ~20 tests
  - Vitals: ~25 tests
  - Developer: ~15 tests
  - RecommendedReading: ~15 tests
  - ReadThis: 25 tests
  - Epicenter: 25 tests
  - MasterControl: 26 tests
  - Other nodelets: ~42 tests

## Related Documentation

- [React Migration Strategy](react-migration-strategy.md) - Overall migration approach
- [React 19 Migration Plan](react-19-migration.md) - Future React 19 upgrade
- [Show Content Analysis](show_content_analysis.md) - Content rendering patterns
- [Notification System](notification-system.md) - Notification architecture

---

*Maintained by: Jay Bonci*
*For questions or updates, see [CLAUDE.md](../CLAUDE.md)*

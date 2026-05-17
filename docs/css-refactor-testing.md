# CSS Refactor Manual Testing Guide

This document lists all React components that were modified during the CSS refactoring session (January 2026) and need manual visual verification.

## Summary

- **Objective**: Convert inline JavaScript style objects to BEM-named CSS classes
- **CSS File**: `www/css/1973976.css`
- **Tests**: All 1,457 React tests pass
- **Files Modified**: 106 JavaScript files + 1 CSS file

## Components Requiring Visual Verification

### Fully Converted (JS styles object removed)

These components had their `const styles = {...}` objects completely removed and all styles moved to CSS:

| Component | URL Path | Access Level |
|-----------|----------|--------------|
| AvailableRooms.js | /title/Available+Rooms | Logged in |
| BountyHuntersWanted.js | /title/Bounty+Hunters+Wanted | Guest |
| CostumeRemover.js | /title/Costume+Remover | Admin |
| CreateNode.js | /title/create+node | Logged in |
| DatabaseLagOMeter.js | /title/Database+Lag-O-Meter | Admin |
| EverythingStatistics.js | /title/Everything+Statistics | Guest |
| FeedEdb.js | /title/Feed+EDB | Admin |
| GoOutside.js | /title/go+outside | Guest |
| GpOptouts.js | /title/GP+Optouts | Admin |
| Ip2name.js | /title/Ip2name | Editor/Admin |
| MyRecentWriteups.js | /title/My+Recent+Writeups | Logged in |
| NatesSecretUnborgDoc.js | /title/nates+secret+unborg+doc | Admin |
| NothingFound.js | (404 pages) | Guest |
| PermissionDenied.js | (access denied pages) | Guest |
| PitOfAbomination.js | /title/pit+of+abomination | Logged in |
| RandomNodeshells.js | /title/Random+nodeshells | Logged in |
| RecalculatedUsers.js | /title/Recalculated+Users | Admin |
| Room.js | /title/Outside | Guest |
| SuperMailbox.js | /title/Super+Mailbox | Admin |
| TheKillingFloor.js | /title/The+Killing+Floor | Admin |
| TheNodeshellHopper.js | /title/The+Nodeshell+Hopper | Admin |
| TheTokenator.js | /title/The+Tokenator | Admin |
| YourFilledNodeshells.js | /title/Your+filled+nodeshells | Logged in |

### Partially Converted (some inline styles remain)

These components had some style conversions but may still have inline styles for dynamic or conditional styling:

| Component | URL Path | Notes |
|-----------|----------|-------|
| Achievement.js | User settings | Complex conditional styles |
| CacheDump.js | /title/cache+dump | Admin tool |
| Collaboration.js | Collaboration nodes | Complex editor |
| CreateRoom.js | /title/Create+a+Room | Admin |
| DefaultDisplay.js | Various pages | Display wrapper |
| E2Bouncer.js | /title/E2+Bouncer | Admin |
| E2ColorToy.js | /title/E2+Color+Toy | Complex interactive |
| E2GiftShop.js | /title/E2+Gift+Shop | Logged in |
| E2SourceCodeFormatter.js | Source code nodes | Dev |
| EdevDocumentationIndex.js | /title/EdevDocumentationIndex | edev |
| EditorEndorsements.js | /title/Editor+Endorsements | Editor |
| EverythingsMostWanted.js | /title/Everythings+Most+Wanted | Guest |
| IpHunter.js | /title/IP+Hunter | Admin |
| MagicalWriteupReparenter.js | /title/Magical+Writeup+Reparenter | Admin |
| NodeNotesByEditor.js | /title/Node+Notes+by+Editor | Editor |
| NodeParameterEditor.js | /title/Node+parameter+editor | Admin |
| NodeRow.js | (Used in many lists) | Component |
| NodesOfTheYear.js | /title/Nodes+of+the+Year | Guest |
| Nodetype.js | Nodetype display | Admin |
| Notification.js | Notification display | Component |
| SecurityMonitor.js | /title/Security+Monitor | Admin |
| SignUp.js | /title/sign+up | Guest |
| SpamCannon.js | /title/Spam+Cannon | Admin |
| SQLPrompt.js | /title/SQL+Prompt | Admin |
| SystemNode.js | System node display | Admin |
| TextFormatter.js | /title/Text+Formatter | Guest |
| TheNodeCrypt.js | /title/The+Node+Crypt | Logged in |
| TheOracle.js | /title/The+Oracle | Guest |
| TopicArchive.js | /title/Topic+Archive | Guest |
| UsergroupMessageArchiveManager.js | /title/Usergroup+Message+Archive+Manager | Admin |
| VotingData.js | /title/Voting+Data | Admin |
| WhoKilledWhat.js | /title/Who+Killed+What | Editor |
| WriteupsByType.js | /title/Writeups+By+Type | Guest |

### Editor/Shared Components

| Component | Usage | Notes |
|-----------|-------|-------|
| MenuBar.js | Draft editor toolbar | Part of editor |
| NodeToolset.js | Master control | Admin toolset |
| SystemNodeEditor.js | System node editing | Admin |

## Testing Instructions

1. **Rebuild the container**: `./docker/devbuild.sh --skip-tests`

2. **Visual inspection**: For each component, compare appearance to production or take before/after screenshots

3. **Key elements to check**:
   - Font sizes and colors
   - Spacing and padding
   - Background colors
   - Border styles
   - Hover states
   - Button appearances
   - Form field styling

4. **Test accounts available**:
   - Guest: No login required
   - Logged in: `e2e_user` (password: `test123`)
   - Editor: Use `genericdev` (password: `blah`)
   - Admin: `e2e_admin` (password: `test123`) or `root` (password: `blah`)

## CSS Classes Added

All new CSS follows BEM naming convention: `.component-name__element--modifier`

New class prefixes added in this session:
- `.tokenator__*`
- `.permission-denied__*`
- `.go-outside__*`
- `.available-rooms__*`
- `.nothing-found__*`
- `.room__*`
- `.killing-floor__*`
- `.super-mailbox__*`
- `.pit-of-abomination__*`
- `.database-lag-meter__*`
- `.random-nodeshells__*`
- `.gp-optouts__*`
- `.feed-edb__*`
- `.nodeshell-hopper__*`
- `.costume-remover__*`
- `.recalculated-users__*`
- `.bounty-hunters-wanted__*`
- `.everything-statistics__*`
- `.my-recent-writeups__*`
- `.your-filled-nodeshells__*`
- `.nates-secret-unborg-doc__*`
- `.create-node__*`
- `.ip2name__*`

## Session 2: January 2026 Continuation

### Phase 1: `const styles = {...}` Pattern (Completed)

Additional files converted in this session:

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| RecentUsers.js | `.recent-users__*` | /title/Recent+Users | Recent user logins |
| KlaprothVanLines.js | `.klaproth-van-lines__*` | /title/Klaproth+Van+Lines | Bulk reparenting |
| SanctifyUser.js | `.sanctify-user__*` | /title/Sanctify+User | GP gifting |
| EverythingDataPages.js | `.e2-data-pages__*` | /title/Everything+Data+Pages | API directory |
| MyAchievements.js | `.my-achievements__*` | /title/My+Achievements | Achievements display |
| RegistryInformation.js | `.registry-info__*` | /title/Registry+Information | Registry entries |
| EverythingSRichestNoders.js | `.richest-noders__*` | /title/Everythings+Richest+Noders | GP wealth |
| MyBigWriteupList.js | `.my-big-writeup-list__*` | /title/my+big+writeup+list | Writeup listing |
| WeblogViewer.js | `.weblog-viewer__*` | (Common component) | Weblog viewer |
| PageHeader.js | `.page-header__*` | (Layout component) | Page headers |

### Phase 2: Inline `style={{...}}` Pattern (Completed)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| NodeNotes.js | `.node-notes__*` | (MasterControl) | Node notes management |
| UserSearch.js | `.user-search__*` | /title/Everything+User+Search | User writeup browser - complex file |
| TheCatwalk.js | `.catwalk__*` | /title/The+Catwalk | Stylesheet browser |
| Nodelet.js | `.nodelet-display__*` | (Nodelet display page) | Nodelet configuration |

### Phase 3: Additional Inline Style Conversions (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| RecentNodeNotes.js | `.recent-node-notes__*` | /title/Recent+Node+Notes | Staff-only note viewer |
| LevelDistribution.js | `.level-distribution__*` | /title/Level+Distribution | Active users by level |
| MannaFromHeaven.js | `.manna-from-heaven__*` | /title/Manna+from+heaven | Staff writeup activity |
| EverythingQuoteServer.js | `.quote-server__*` | /title/Everything+Quote+Server | Random quote display |
| EverythingsBestWriteups.js | `.best-writeups__*` | /title/Everythings+Best+Writeups | 50 most cooled (staff) |
| EverythingPollDirectory.js | `.poll-directory__*` | /title/Everything+Poll+Directory | Poll browser/admin |
| GoldenTrinkets.js | `.golden-trinkets__*` | /title/Golden+Trinkets | User karma display |
| SilverTrinkets.js | `.silver-trinkets__*` | /title/Silver+Trinkets | User sanctity display |

### Phase 4: Component/Nodelet Inline Style Conversions (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| UsergroupDescriptionEditor.js | `.usergroup-description-editor__*` | (Usergroup edit) | TipTap WYSIWYG editor |
| Chatterlight.js | `.chatterlight__*` | /title/chatterlight | Fullpage chat interface |
| Weblog.js | `.weblog-entry__*`, `.weblog__*` | (Weblog displays) | Weblog entries + pagination |
| PersonalLinks.js | `.personal-links__*` | (Personal Links nodelet) | User's saved links |
| PollDisplay.js | `.poll-display__*` | (Poll display component) | Poll voting/results |
| MostWanted.js | `.most-wanted__*` | (Most Wanted nodelet) | Bounties table |
| ForReview.js | `.for-review__*` | (For Review nodelet) | Editor draft review |
| AdminSectionLinks.js | `.admin-section-links__*` | (MasterControl) | Admin section links |

### Phase 5: Nodelet Inline Style Conversions (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| Notifications.js | `.notifications__*` | (Notifications nodelet) | Polling notifications |
| RecentNodes.js | `.recent-nodes__*` | (Recent Nodes nodelet) | Node trail display |
| Notelet.js | `.notelet__*` | (Notelet nodelet) | Personal notes |
| FavoriteNoders.js | `.favorite-noders__*` | (Favorite Noders nodelet) | Followed users' writeups |
| Statistics.js | `.statistics__*` | (Statistics nodelet) | User stats sections |
| ILikeItButton.js | `.ilikeit__*` | (Component) | Writeup like button |
| NewWriteups.js | `.newwriteups__*` | (New Writeups nodelet) | Recent writeups filter |

### Phase 6: Additional Nodelet Conversions (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| SignIn.js | `.signin__*` | (Sign In nodelet) | Login form nodelet |
| UsergroupWriteups.js | `.usergroup-writeups__*` | (Usergroup Writeups nodelet) | Usergroup content |
| Developer.js | `.dev-nodelet__*` | (Developer nodelet) | Dev tools nodelet |

### Phase 7: Core Component Conversions (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| AddToCategoryModal.js | `.modal-compact__*` | (Modal component) | Category add modal |
| AddToWeblogModal.js | `.modal-compact__*` | (Modal component) | Weblog add modal |
| DocumentComponent.js | `.document-loading` | (Layout component) | Loading state |
| NodeletSection.js | `.nodelet-section__*` | (Nodelet sections) | Collapsible sections |
| UserToolsModal.js | `.user-tools__*` | (Modal component) | User admin tools |

### Phase 8: Layout & Documents Batch (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| Weblog.js | `.weblog-entry__*` | (Weblog displays) | Table cell styles |
| E2ReactRoot.js | `.nodelet-loading-fallback` | (Root layout) | Loading fallback |
| MessageModal.js | `.message-modal__*` | (Modal component) | Autocomplete wrapper |
| PageLayout.js | `#wrapper` | (Layout) | Flex wrapper |
| ParseLinks.js | `.externalLink` | (Component) | External link inherit |
| RenunciationChainsaw.js | `.renunciation-chainsaw__*` | /title/Renunciation+Chainsaw | Bulk ownership transfer |
| Mail.js | `.mail__*` | (Mail nodes) | Mail display |
| CajaDeArena.js | `.caja__*` | /title/Caja+de+Arena | Spam detection tool |

### Phase 9: Document Display Batch (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| NodeList.js | `.nodelist__*` | /title/25, /title/Everything+New+Nodes, etc. | Recent writeups lists with striped rows |
| NodeTracker.js | `.node-tracker__*` | /title/Node+Tracker | User writing stats display |
| Htmlpage.js | `.dev-display__*` | (Htmlpage nodes) | Legacy page template display |
| Htmlcode.js | `.dev-display__*` | (Htmlcode nodes) | Reusable code snippet display |
| Maintenance.js | `.dev-display__*`, `.maintenance__badge*` | (Maintenance nodes) | Lifecycle operation nodes |
| Container.js | `.dev-display__*` | (Container nodes) | Layout template display |
| FreshBlood.js | `.fresh-blood__*` | /title/Fresh+Blood | New user registration list |
| Nodeshells.js | `.nodeshells__*` | /title/Nodeshells | Empty e2nodes list |
| EverythingObscureWriteups.js | `.obscure-writeups__*` | /title/Everythings+Obscure+Writeups | Zero-rep writeup discovery |

**Note**: Htmlpage.js, Htmlcode.js, Maintenance.js, and Container.js all share the `.dev-display__*` CSS classes for consistent developer node display styling. Maintenance.js also adds `.maintenance__badge*` classes with color-coded variants for create (green), update (blue), and delete (red) operation types.

### Phase 10: Additional Document Components (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| ListHtmlTags.js | `.list-html-tags__*` | /title/List+HTML+Tags | HTML tag reference with grid layout |
| AYearAgoToday.js | `.year-ago-today__*` | /title/A+Year+Ago+Today | Historical content viewer |
| AcceptableUsePolicy.js | `.aup__*` | /title/Acceptable+Use+Policy | Static policy document |
| E2PennyJar.js | `.penny-jar__*` | /title/E2+Penny+Jar | Donation page with give/take buttons |
| YourGravatar.js | `.your-gravatar__*` | /title/Your+Gravatar | Gravatar preview grid |
| E2SpermCounter.js | `.sperm-counter__*` | /title/E2+Sperm+Counter | Simple counter display |
| MarkAllDiscussionsAsRead.js | `.mark-discussions__*` | /title/Mark+All+Discussions+as+Read | Discussion marking tool |

### Phase 11: Additional Document Components (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| Zenmastery.js | `.zenmastery__*` | /title/zenmastery | CSS demo page for staff styling |
| RandomText.js | `.random-text-generator__*` | /title/Fezisms+Generator, /title/Piercisms+Generator | Quote generators |
| IsItHoliday.js | `.is-it-holiday__*` | /title/is+it+christmas+yet, etc. | Holiday date checker |
| ObliqueStrategiesGarden.js | `.oblique-strategies__*` | /title/Oblique+Strategies+Garden | Creative strategy grid |
| AdminBestowTool.js | `.admin-bestow__*` | /title/Superbless, /title/Give+Cools, etc. | Admin resource granting tool (full rewrite) |
| IpBlacklist.js | `.ip-blacklist__*` | /title/IP+Blacklist | IP blocking admin tool |
| RecalculateXp.js | `.recalculate-xp__*` | /title/Recalculate+XP | XP recalculation tool |
| VotingExperienceSystem.js | `.voting-experience__*` | /title/Voting%2FExperience+System | Help document (full rewrite) |

**Note**: AdminBestowTool.js and VotingExperienceSystem.js received full rewrites to remove all style object variables. Both are complex, multi-section pages that benefited from complete CSS externalization.

### Phase 12: Additional Inline Style Conversions (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| Document.js | `.e2-editor-wrapper--padded` | (Document component) | Editor wrapper padding |
| YourIgnoreList.js | `.ignore-list__*` | /title/Your+Ignore+List | Ignore list management |
| UserStatistics.js | `.user-statistics__*` | /title/User+Statistics | User stats display |
| Nodegroup.js | `.nodegroup__*` | (Nodegroup displays) | Nodegroup icon styles |
| RecordingEdit.js | `.recording-edit__*` | (Recording edit pages) | Audio recording edit |
| EdevFAQ.js | `.edev-faq__*` | /title/Edev+FAQ | Developer FAQ page |
| IronNoderProgress.js | `.iron-noder__*` | (Iron Noder display) | Progress bar (partial - width remains dynamic) |

### Phase 13: Document Components Batch (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| CategoryEdit.js | `.category-edit__*` | (Category edit pages) | Category editing |
| HomenodeInspector.js | `.homenode-inspector__*` | /title/Homenode+Inspector | Admin homenode viewer |
| Registry.js | `.registry__*` | (Registry display) | Registry entry display |
| Draft.js | `.draft-page__*` | (Draft display) | Draft viewing/editing |
| CollaborationEdit.js | `.collab-edit__*` | (Collaboration edit) | Collaboration editing |
| Writeup.js | `.writeup-page__*` | (Writeup display) | Main writeup display |
| WharfingerLinebreaker.js | `.linebreaker__*` | /title/Wharfinger+Linebreaker | Text processing utility |
| ThemeNirvana.js | `.theme-nirvana__*` | /title/Theme+Nirvana | Stylesheet browser (full rewrite) |

### Phase 14: Component & Utility Batch (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| InlineWriteupEditor.js | `.inline-editor__*` | (Inline editor component) | Link style only; mode toggle backgrounds remain dynamic |
| LogoutLink.js | `.logout-link` | (Logout component) | Cursor style; style prop pass-through preserved |
| UsergroupEditor.js | `.usergroup-editor__*` | (Usergroup modal) | Icon margin styles |
| NodegroupEditor.js | `.group-editor__*` | (Nodegroup modal) | Fixed bug with non-existent styles import; type icon styling computed dynamically |
| BuffaloGenerator.js | `.buffalo-generator__*` | /title/Buffalo+Generator, /title/Buffalo+Haiku+Generator | Container, output, button, link styles |
| TheBorgClinic.js | `.borg-clinic__*` | /title/The+Borg+Clinic | Admin borg management tool |
| QuickRename.js | `.quick-rename__*` | /title/Quick+Rename | Bulk e2node renaming; dynamic row colors remain inline |
| NodetypeChanger.js | `.nodetype-changer__*` | /title/Nodetype+Changer | Admin nodetype changing tool |

### Phase 15: Admin & Utility Components (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| E2clientEdit.js | `.e2client-edit__*` | (E2client edit pages) | Editor wrapper padding |
| UsergroupAttendanceMonitor.js | `.usergroup-attendance-monitor__*` | /title/Usergroup+Attendance+Monitor | Divider and total styles |
| YourNodeshells.js | `.your-nodeshells__*` | /title/Your+Nodeshells | Error message styling |
| EverythingsBiggestStars.js | `.biggest-stars__*` | /title/Everythings+Biggest+Stars | Container and empty state |
| Schema.js | `.schema__*` | (Schema display) | Unknown author style |
| YourInsuredWriteups.js | `.your-insured-writeups__*` | /title/Your+Insured+Writeups | Total count styling |
| UserEditVars.js | `.user-edit-vars__*` | (User vars edit) | Icon margin, column width |
| MassIpBlacklister.js | `.mass-ip-blacklister__*` | /title/Mass+IP+Blacklister | List, inline form, pagination separator |
| NodeBackup.js | `.node-backup__*` | /title/Node+Backup | Create another button margin |

### Phase 16: Static Styles & Component Consolidation (January 2026)

| Component | CSS Prefix | URL Path | Notes |
|-----------|------------|----------|-------|
| E2MarbleShop.js | `.marble-shop__*` | /title/E2+Marble+Shop | Container and message styling |
| E2Rot13Encoder.js | `.rot13-encoder__*` | /title/E2+Rot13+Encoder | Textarea and button styling |
| FreshlyBloodied.js | `.freshly-bloodied__*` | /title/Freshly+Bloodied | Pagination and table styles |
| Login.js | `.login-page__*` | /title/Log+In | Footer paragraph margin |
| PodcastEdit.js | `.podcast-edit__*` | (Podcast edit pages) | Button text margins |
| Setting.js | `.setting__*` | (Setting edit pages) | Column width |
| UsersWithInfravision.js | `.users-with-infravision__*` | /title/Users+With+Infravision | List margin |
| WhatDoesWhat.js | `.what-does-what__*` | /title/What+Does+What | Edit link alignment |
| Usergroup.js | `.usergroup-*` | (Usergroup pages) | Empty message spacing |
| WheelOfSurprise.js | `.wheel-of-surprise__*` | /title/Wheel+of+Surprise | Full conversion of disclaimer, error, button, result styles |
| CreateCategory.js | `.create-category__*` | /title/Create+Category | Editor padding, help link |

#### EditorModeToggle Component Consolidation

Refactored 3 files that had custom inline Rich/HTML toggle implementations to use the shared `EditorModeToggle` component:

| File | Change |
|------|--------|
| CategoryEdit.js | Replaced custom toggle with `<EditorModeToggle mode={editorMode} onToggle={handleModeToggle} />` |
| CreateCategory.js | Replaced custom toggle with shared component |
| InlineWriteupEditor.js | Replaced custom toggle with shared component |

The shared component is located at `react/components/Editor/EditorModeToggle.js` and is now used by 11 files across the codebase.

### Phase 17: Final Static Style Conversions (January 2026)

**Goal**: Convert remaining static inline styles to CSS classes.

**Files Modified**:

| File | CSS Classes | URL Path | Notes |
|------|-------------|----------|-------|
| EverythingPollArchive.js | `.poll-archive__*` | /title/Everything+Poll+Archive | Full conversion - removed all style objects (container, header, title, pagination, link, error, loading, list) |
| EverythingPollCreator.js | `.poll-creator__*` | /title/Everything+Poll+Creator | Full conversion - removed 20+ style objects (container, header, form, field groups, inputs, buttons, alerts, etc.) |
| EverythingPublicationDirectory.js | `.e2-pub-directory__th--*` | /title/Everything+Publication+Directory | Column width classes |
| SiteTrajectory.js | `.site-trajectory__*` | /title/Site+Trajectory | Partial conversion - static styles moved to CSS (container, form, select, table, th, td), dynamic bar widths remain inline |
| WhatToDoIfE2GoesDown.js | `.what-to-do-if-e2-goes-down__*` | /title/What+to+do+if+E2+goes+down | Full conversion - container, intro, suggestion |
| FullTextSearch.js | `.full-text-search__*` | /title/Full+Text+Search | CSE branding styles |
| StyleDefacer.js | `.style-defacer__*` | /title/Style+Defacer | Success alert, textarea, submit button, tips |
| EverythingPollDirectory.js | `.poll-directory__modal-*` | /title/Everything+Poll+Directory | Modal content and overlay styles |

**Test Changes**:
- Updated `WhatToDoIfE2GoesDown.test.js` to use class selectors instead of `div[style]` attribute selectors

**Tests**: All 1,457 tests pass

## Remaining Work

The inline style refactoring is now essentially complete. Remaining `style={{...}}` patterns are:

1. **Truly dynamic styles** that compute from data/state:
   - `SiteTrajectory.js`: Bar chart widths computed as percentages of max values
   - `EverythingPollCreator.js`: Single `style={{ flex: 1 }}` for option input flexibility
   - Various components with conditional show/hide or computed dimensions

2. **Design decision**: These dynamic styles are working as intended and do not benefit from CSS class conversion

Note: Some inline styles are intentionally dynamic (based on props/state) and should remain as inline styles rather than being converted to CSS classes.

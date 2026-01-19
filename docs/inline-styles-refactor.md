# Inline Styles Refactoring Tracker

This document tracks the systematic refactoring of inline styles from React components to CSS classes.

**Goal**: Move all inline `style={{...}}` from React components to CSS classes in the basesheet (1973976.css) or component-specific CSS files.

**Started**: ~1200 inline style occurrences across 191 files
**Remaining**: ~905 inline styles

## Progress Summary

| Status | Count |
|--------|-------|
| Completed | 11 |
| In Progress | 0 |
| Pending | 180 |

**Inline styles removed**: ~295

## Completed Components

| File | Original | Test URL |
|------|----------|----------|
| Documents/SignUp.js | 49 | /title/Sign%20Up |
| MasterControl/NodeToolset.js | 49 | Any page (sidebar Master Control) |
| Documents/TextFormatter.js | 48 | /title/Text%20Formatter |
| Documents/E2ColorToy.js | 22→3* | /title/E2%20Color%20Toy |
| Editor/MenuBar.js | 21 | /title/Drafts (Editor Beta) |
| SystemNodeEditor.js | 20 | Admin: basicedit on any node |
| Documents/SecurityMonitor.js | 20 | /title/Security%20Monitor |
| Documents/TheNodeCrypt.js | 19 | /title/The%20Node%20Crypt |
| Documents/VotingData.js | 18 | /title/Voting%20Data |
| Documents/SystemNode.js | 18 | /node/1 (or any system node) |
| Documents/DefaultDisplay.js | 14 | /node/[system-node-id] |

*E2ColorToy retains 3 inline styles for dynamic color values (backgroundColor, color)

## Components by Priority (High to Low)

### High Priority (15+ occurrences remaining)
| File | Count | Status | Test URL |
|------|-------|--------|----------|
| Documents/CacheDump.js | 18 | Pending | /title/Cache%20Dump |
| Documents/EdevDocumentationIndex.js | 18 | Pending | /title/Edev%20Documentation%20Index |
| Documents/NodeNotesByEditor.js | 17 | Pending | /title/Node%20Notes%20by%20Editor |
| Documents/WriteupsByType.js | 16 | Pending | /title/Writeups%20by%20Type |
| Documents/NodeParameterEditor.js | 15 | Pending | Admin: parameter editing |
| Documents/Notification.js | 15 | Pending | /title/Notifications |

### Medium Priority (10-14 occurrences)
| File | Count | Status | Test URL |
|------|-------|--------|----------|
| Documents/Collaboration.js | 14 | Pending | /title/test%20collaboration |
| Documents/DefaultDisplay.js | 14 | Pending | /node/[system-node-id] |
| Documents/UsergroupMessageArchiveManager.js | 14 | Pending | /title/Usergroup%20Message%20Archive%20Manager |
| Documents/TheOracle.js | 13 | Pending | /title/The%20Oracle |
| Documents/WhoKilledWhat.js | 13 | Pending | /title/Who%20Killed%20What |
| Documents/E2SourceCodeFormatter.js | 13 | Pending | /title/E2%20Source%20Code%20Formatter |
| Documents/MannaFromHeaven.js | 12 | Pending | /title/Manna%20from%20Heaven |
| Documents/TheCatwalk.js | 12 | Pending | /title/The%20Catwalk |
| Documents/Nodelet.js | 12 | Pending | Any nodelet configuration |
| Documents/UserSearch.js | 12 | Pending | /title/User%20Search |
| MasterControl/NodeNotes.js | 12 | Pending | Sidebar: Node Notes section |
| Documents/LevelDistribution.js | 11 | Pending | /title/Level%20Distribution |
| UsergroupDescriptionEditor.js | 11 | Pending | Usergroup editing |
| Documents/Chatterlight.js | 11 | Pending | /title/Chatterlight |
| Weblog.js | 10 | Pending | User's weblog page |
| Documents/RecentNodeNotes.js | 10 | Pending | /title/Recent%20Node%20Notes |
| Documents/Achievement.js | 10 | Pending | /title/Achievements |
| Documents/Nodetype.js | 10 | Pending | /title/htmlcode (or any nodetype) |
| Nodelets/PersonalLinks.js | 10 | Pending | Sidebar: Personal Links nodelet |

### Low-Medium Priority (5-9 occurrences)
| File | Count | Status | Test URL |
|------|-------|--------|----------|
| Poll/PollDisplay.js | 9 | Pending | Any poll page |
| Documents/Registry.js | 9 | Pending | /title/Registry |
| Documents/RenunciationChainsaw.js | 9 | Pending | /title/Renunciation%20Chainsaw |
| Documents/NodeList.js | 9 | Pending | Various list pages |
| Documents/Mail.js | 9 | Pending | /title/Mail |
| Documents/CajaDeArena.js | 9 | Pending | /title/Caja%20de%20Arena |
| Documents/GoldenTrinkets.js | 9 | Pending | /title/Golden%20Trinkets |
| Documents/SilverTrinkets.js | 9 | Pending | /title/Silver%20Trinkets |
| Documents/Maintenance.js | 9 | Pending | /title/[maintenance-node] |
| MasterControl/AdminSectionLinks.js | 9 | Pending | Sidebar: Admin links |
| Nodelets/ForReview.js | 9 | Pending | Sidebar: For Review nodelet |
| Nodelets/MostWanted.js | 9 | Pending | Sidebar: Most Wanted nodelet |
| Documents/EverythingsBestWriteups.js | 9 | Pending | /title/Everything's%20Best%20Writeups |
| Documents/EverythingQuoteServer.js | 8 | Pending | /title/Everything%20Quote%20Server |
| Documents/EverythingPollDirectory.js | 8 | Pending | /title/Everything%20Poll%20Directory |
| Documents/E2PennyJar.js | 8 | Pending | /title/E2%20Penny%20Jar |
| Documents/HomenodeInspector.js | 8 | Pending | /title/Homenode%20Inspector |
| Documents/AYearAgoToday.js | 8 | Pending | /title/A%20Year%20Ago%20Today |
| Documents/ListHtmlTags.js | 8 | Pending | /title/List%20Html%20Tags |
| Documents/EverythingDataPages.js | 8 | Pending | /title/Everything%20Data%20Pages |
| Documents/CategoryEdit.js | 8 | Pending | Edit any category |
| Documents/Htmlpage.js | 8 | Pending | View any htmlpage |
| Documents/Stylesheet.js | 8 | Pending | View any stylesheet |
| Documents/QuickRename.js | 8 | Pending | /title/Quick%20Rename |
| Nodelets/UsergroupWriteups.js | 8 | Pending | Sidebar: Usergroup Writeups |
| MasterControl/NodeCloner.js | 7 | Pending | Sidebar: Node Cloner |
| Documents/CollaborationEdit.js | 7 | Pending | Edit collaboration |
| Documents/Draft.js | 7 | Pending | View any draft |
| Documents/EverythingObscureWriteups.js | 7 | Pending | /title/Everything's%20Obscure%20Writeups |
| Documents/AcceptableUsePolicy.js | 7 | Pending | /title/Acceptable%20Use%20Policy |
| Documents/MarkAllDiscussionsAsRead.js | 7 | Pending | /title/Mark%20All%20Discussions%20as%20Read |
| Documents/CategoryDisplay.js | 7 | Pending | View any category |
| Documents/Datastash.js | 6 | Pending | /title/Datastash |
| Documents/Writeup.js | 6 | Pending | Any writeup page |
| Documents/Nodeshells.js | 6 | Pending | /title/Nodeshells |
| Documents/RecordingEdit.js | 6 | Pending | Edit recording |
| Documents/Htmlcode.js | 6 | Pending | View any htmlcode |
| Documents/TheBorgClinic.js | 6 | Pending | /title/The%20Borg%20Clinic |
| Documents/WharfingerLinebreaker.js | 6 | Pending | /title/Wharfinger%20Linebreaker |
| Documents/ThemeNirvana.js | 6 | Pending | /title/Theme%20Nirvana |
| Documents/Container.js | 6 | Pending | View any container |
| Documents/YourGravatar.js | 6 | Pending | /title/Your%20Gravatar |
| Layout/GoogleAds.js | 6 | Pending | Any page (guests only) |
| Nodelets/Notifications.js | 6 | Pending | Sidebar: Notifications nodelet |
| UsergroupEditor.js | 5 | Pending | Edit usergroup |
| Documents/Document.js | 5 | Pending | View any document |
| Documents/RandomText.js | 5 | Pending | /title/Random%20Text |
| Documents/EverythingPublicationDirectory.js | 5 | Pending | /title/Everything%20Publication%20Directory |
| Documents/Recording.js | 5 | Pending | View any recording |
| Documents/WheelOfSurprise.js | 5 | Pending | /title/Wheel%20of%20Surprise |
| Documents/NodetypeChanger.js | 5 | Pending | /title/Nodetype%20Changer |
| Documents/Podcast.js | 5 | Pending | View any podcast |
| Documents/PodcastEdit.js | 5 | Pending | Edit podcast |
| ILikeItButton.js | 5 | Pending | Any writeup (I Like It button) |
| Nodelets/RecentNodes.js | 5 | Pending | Sidebar: Recent Nodes nodelet |

### Low Priority (1-4 occurrences)
| File | Count | Status | Test URL |
|------|-------|--------|----------|
| InlineWriteupEditor.js | 3 | Pending | Inline writeup editing |
| NodegroupEditor.js | 3 | Pending | Edit nodegroup |
| Documents/Zenmastery.js | 3 | Pending | /title/Zen%20Mastery |
| Documents/FreshBlood.js | 3 | Pending | /title/Fresh%20Blood |
| Documents/RecalculateXp.js | 3 | Pending | /title/Recalculate%20XP |
| Documents/Nodegroup.js | 3 | Pending | View any nodegroup |
| Documents/BuffaloGenerator.js | 3 | Pending | /title/Buffalo%20Generator |
| Documents/TheNodeshellHopper.js | 3 | Pending | /title/The%20Nodeshell%20Hopper |
| Documents/E2Rot13Encoder.js | 3 | Pending | /title/E2%20Rot13%20Encoder |
| Documents/WhatToDoIfE2GoesDown.js | 3 | Pending | /title/What%20to%20do%20if%20E2%20goes%20down |
| Documents/Setting.js | 3 | Pending | View settings |
| Documents/FreshlyBloodied.js | 3 | Pending | /title/Freshly%20Bloodied |
| Nodelets/FavoriteNoders.js | 3 | Pending | Sidebar: Favorite Noders |
| Nodelets/Statistics.js | 3 | Pending | Sidebar: Statistics nodelet |
| Documents/TopicArchive.js | 1 | Pending | /title/Topic%20Archive |
| Documents/NodeTracker.js | 2 | Pending | /title/Node%20Tracker |
| Documents/DrNatesSecretLab.js | 2 | Pending | /title/Dr%20Nate's%20Secret%20Lab |
| Documents/SpamCannon.js | 1 | Pending | /title/Spam%20Cannon |
| Documents/IpHunter.js | 1 | Pending | /title/IP%20Hunter |
| Documents/NodingSpeedometer.js | 1 | Pending | /title/Noding%20Speedometer |
| Documents/TheCostumeShop.js | 2 | Pending | /title/The%20Costume%20Shop |
| Documents/E2Bouncer.js | 1 | Pending | /title/E2%20Bouncer |
| Documents/NodesOfTheYear.js | 1 | Pending | /title/Nodes%20of%20the%20Year |
| Documents/IsItHoliday.js | 2 | Pending | /title/Is%20It%20Holiday |
| Documents/CreateRoom.js | 1 | Pending | /title/Create%20Room |
| Documents/EditorEndorsements.js | 1 | Pending | /title/Editor%20Endorsements |
| Documents/ObliqueStrategiesGarden.js | 2 | Pending | /title/Oblique%20Strategies%20Garden |
| Documents/E2clientEdit.js | 4 | Pending | Edit e2client |
| Documents/AdminBestowTool.js | 4 | Pending | /title/Admin%20Bestow%20Tool |
| Documents/IpBlacklist.js | 2 | Pending | /title/IP%20Blacklist |
| Documents/VotingExperienceSystem.js | 3 | Pending | /title/Voting%20Experience%20System |
| Documents/ReputationGraph.js | 4 | Pending | /title/Reputation%20Graph |
| Documents/YourIgnoreList.js | 2 | Pending | /title/Your%20Ignore%20List |
| Documents/UserStatistics.js | 1 | Pending | User stats page |
| Documents/TheTokenator.js | 1 | Pending | /title/The%20Tokenator |
| Documents/EdevFAQ.js | 2 | Pending | /title/Edev%20FAQ |
| Documents/E2GiftShop.js | 1 | Pending | /title/E2%20Gift%20Shop |
| Documents/IronNoderProgress.js | 4 | Pending | /title/Iron%20Noder%20Progress |
| Documents/UsergroupAttendanceMonitor.js | 2 | Pending | /title/Usergroup%20Attendance%20Monitor |
| Documents/EverythingsMostWanted.js | 1 | Pending | /title/Everything's%20Most%20Wanted |
| Documents/MagicalWriteupReparenter.js | 1 | Pending | /title/Magical%20Writeup%20Reparenter |
| Documents/YourNodeshells.js | 1 | Pending | /title/Your%20Nodeshells |
| Documents/EverythingsBiggestStars.js | 2 | Pending | /title/Everything's%20Biggest%20Stars |
| Documents/Schema.js | 2 | Pending | View schema |
| Documents/NodeRow.js | 1 | Pending | Node row displays |
| Documents/YourInsuredWriteups.js | 1 | Pending | /title/Your%20Insured%20Writeups |
| Documents/E2SpermCounter.js | 4 | Pending | /title/E2%20Sperm%20Counter |
| Documents/UserEditVars.js | 4 | Pending | Edit user vars |
| Documents/E2client.js | 4 | Pending | View e2client |
| Documents/MassIpBlacklister.js | 4 | Pending | /title/Mass%20IP%20Blacklister |
| Documents/SiteTrajectory.js | 4 | Pending | /title/Site%20Trajectory |
| Documents/NodeBackup.js | 2 | Pending | /title/Node%20Backup |
| Documents/ContentReports.js | 2 | Pending | /title/Content%20Reports |
| Documents/ResetPassword.js | 2 | Pending | /title/Reset%20Password |
| Documents/EverythingPollArchive.js | 2 | Pending | /title/Everything%20Poll%20Archive |
| Documents/UserDisplay.js | 1 | Pending | View any user homenode |
| Documents/CostumeRemover.js | 1 | Pending | /title/Costume%20Remover |
| Documents/Login.js | 1 | Pending | /title/Login |
| Documents/ConfirmPassword.js | 2 | Pending | /title/Confirm%20Password |
| Documents/AdminSettings.js | 1 | Pending | /title/Admin%20Settings |
| Documents/FullTextSearch.js | 1 | Pending | /title/Full%20Text%20Search |
| Documents/KlaprothVanLines.js | 4 | Pending | /title/Klaproth%20Van%20Lines |
| Documents/LogArchive.js | 2 | Pending | /title/Log%20Archive |
| Documents/EditWeblogMenu.js | 1 | Pending | Edit weblog menu |
| Documents/SanctifyUser.js | 4 | Pending | /title/Sanctify%20User |
| Documents/SQLPrompt.js | 1 | Pending | /title/SQL%20Prompt |
| Documents/StyleDefacer.js | 4 | Pending | /title/Style%20Defacer |
| Documents/EditorBeta.js | 2 | Pending | /title/Editor%20Beta |
| Documents/WhatDoesWhat.js | 1 | Pending | /title/What%20Does%20What |
| Documents/PitOfAbomination.js | 1 | Pending | /title/Pit%20of%20Abomination |
| Documents/CreateCategory.js | 4 | Pending | /title/Create%20Category |
| Documents/E2MarbleShop.js | 2 | Pending | /title/E2%20Marble%20Shop |
| Documents/EverythingPollCreator.js | 2 | Pending | /title/Everything%20Poll%20Creator |
| Documents/UsersWithInfravision.js | 1 | Pending | /title/Users%20with%20Infravision |
| Documents/Usergroup.js | 1 | Pending | View any usergroup |
| Documents/MyBigWriteupList.js | 1 | Pending | /title/My%20Big%20Writeup%20List |
| LogoutLink.js | 1 | Pending | Logout link |
| UserToolsModal.js | 1 | Pending | User tools modal |
| MessageModal.js | 1 | Pending | Message modal |
| ParseLinks.js | 1 | Pending | Link parsing |
| DateTimePicker.js | 1 | Pending | Date/time picker |
| AddToCategoryModal.js | 1 | Pending | Add to category modal |
| PageLayout.js | 1 | Pending | Main page layout |
| AddToWeblogModal.js | 1 | Pending | Add to weblog modal |
| E2ReactRoot.js | 1 | Pending | React root |
| Common/WeblogViewer.js | 2 | Pending | Weblog viewer |
| DocumentComponent.js | 1 | Pending | Document component |
| MasterControl/MasterControlSection.js | 1 | Pending | Master control sections |
| Actions/EditorCoolButton.js | 1 | Pending | Editor cool button |
| Actions/BookmarkButton.js | 1 | Pending | Bookmark button |
| Nodelets/SignIn.js | 1 | Pending | Sidebar: Sign In nodelet |
| Nodelets/NewWriteups.js | 2 | Pending | Sidebar: New Writeups nodelet |
| Nodelets/OtherUsers.js | 4 | Pending | Sidebar: Other Users nodelet |
| Nodelets/Notelet.js | 4 | Pending | Sidebar: Notelet |
| Nodelets/Developer.js | 2 | Pending | Sidebar: Developer nodelet |
| Nodelets/CurrentUserPoll.js | 1 | Pending | Sidebar: Current poll |
| NodeletSection.js | 1 | Pending | Nodelet sections |
| Layout/E2Logo.js | 1 | Pending | E2 logo |
| Editor/PreviewContent.js | 2 | Pending | Editor preview |
| Editor/EditorModeToggle.js | 2 | Pending | Editor mode toggle |

---

## Manual Testing Checklist

After all refactoring is complete, manually test each of these pages/components:

### High-Impact Pages (Test First)
- [ ] `/title/Sign%20Up` - New user registration
- [ ] Any page with Master Control nodelet (logged in as admin)
- [ ] `/title/Text%20Formatter` - Text formatting tool
- [ ] `/title/E2%20Color%20Toy` - Color picker tool
- [ ] Editor Beta on any draft
- [ ] Admin basicedit page

### Document Pages
- [ ] `/title/Security%20Monitor`
- [ ] `/title/The%20Node%20Crypt`
- [ ] `/title/Cache%20Dump`
- [ ] `/title/Voting%20Data`
- [ ] `/title/Writeups%20by%20Type`
- [ ] `/title/Notifications`
- [ ] Any collaboration page
- [ ] Any poll page
- [ ] Any user homenode
- [ ] Any writeup page
- [ ] Any category page

### Sidebar Nodelets
- [ ] Chatterbox nodelet
- [ ] Messages nodelet
- [ ] Personal Links nodelet
- [ ] For Review nodelet
- [ ] Most Wanted nodelet
- [ ] Notifications nodelet
- [ ] Other Users nodelet
- [ ] New Writeups nodelet

### Guest View (logged out)
- [ ] Homepage with ads
- [ ] Any writeup page with ads

---

## Work Log

### Session 1 - [Date]
- Starting the systematic refactoring process
- Working through files in priority order

(Log entries will be added as work progresses)

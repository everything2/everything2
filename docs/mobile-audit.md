# Mobile Optimization Audit Report

**Generated:** 2026-01-10
**Tool:** `node tools/mobile-audit.js`

## Summary

| Metric | Count |
|--------|-------|
| Total document components | 255 |
| Components with issues | 220 |
| Components passing | 35 |
| Pass rate | 14% |

## Issues by Type

| Issue Type | Count | Severity | Description |
|------------|-------|----------|-------------|
| DUPLICATE_H1 | 40 | Warning | Component renders its own H1 when PageHeader already provides one |
| MISSING_USE_IS_MOBILE | 219 | Info | No responsive hook for mobile-specific styling |
| HARDCODED_PADDING | 14 | Info | Fixed padding that doesn't adapt to mobile |
| HARDCODED_MAX_WIDTH | 13 | Info | Fixed maxWidth that doesn't adapt to mobile |

---

## Priority 1: Duplicate H1 Tags (40 files)

These components render their own `<h1>` tag, creating duplicate headings since PageHeader already renders the page title. This is a **user-visible issue** that affects both UX and accessibility.

**Fix pattern:**
1. Remove the `<h1>` element from the component
2. Keep any intro/description text as a `<p>` element
3. Remove unused `headerStyle` and `titleStyle` constants

**Example (from CoolArchive.js):**
```jsx
// BEFORE - duplicate H1
<div style={headerStyle}>
  <h1 style={titleStyle}>Cool Archive</h1>
  <p style={introStyle}>Description text...</p>
</div>

// AFTER - no duplicate H1
<p style={introStyle}>Description text...</p>
```

### Files to fix:

| File | Status |
|------|--------|
| CategoryDisplay.js | ⬜ Pending |
| CategoryEdit.js | ⬜ Pending |
| Collaboration.js | ⬜ Pending |
| CostumeRemover.js | ⬜ Pending |
| Datastash.js | ⬜ Pending |
| Dbtable.js | ⬜ Pending |
| Debatecomment.js | ⬜ Pending |
| DebatecommentEdit.js | ⬜ Pending |
| DisplayCategories.js | ⬜ Pending |
| DrNatesSecretLab.js | ⬜ Pending |
| E2CollaborationNodes.js | ⬜ Pending |
| E2GiftShop.js | ⬜ Pending |
| E2client.js | ⬜ Pending |
| EditWeblogMenu.js | ⬜ Pending |
| EditorBeta.js | ⬜ Pending |
| EditorEndorsements.js | ⬜ Pending |
| EverythingDataPages.js | ⬜ Pending |
| EverythingPollArchive.js | ⬜ Pending |
| EverythingPollCreator.js | ⬜ Pending |
| EverythingPollDirectory.js | ⬜ Pending |
| MessageInbox.js | ⬜ Pending |
| NewUserImages.js | ⬜ Pending |
| NodeBackup.js | ⬜ Pending |
| QuickRename.js | ⬜ Pending |
| RecalculateXp.js | ⬜ Pending |
| RecalculatedUsers.js | ⬜ Pending |
| SQLPrompt.js | ⬜ Pending |
| SanctifyUser.js | ⬜ Pending |
| Setting.js | ⬜ Pending |
| Settings.js | ⬜ Pending |
| TheCostumeShop.js | ⬜ Pending |
| TheNodeshellHopper.js | ⬜ Pending |
| TopicArchive.js | ⬜ Pending |
| UnimplementedPage.js | ⬜ Pending |
| UserEdit.js | ⬜ Pending |
| UserEditVars.js | ⬜ Pending |
| UserSearch.js | ⬜ Pending |
| VotingExperienceSystem.js | ⬜ Pending |
| WharfingerLinebreaker.js | ⬜ Pending |
| WhatDoesWhat.js | ⬜ Pending |

---

## Priority 2: Hardcoded Dimensions (27 files)

These components have hardcoded padding or maxWidth that doesn't adapt to mobile viewports.

**Fix pattern:**
```jsx
// Add import
import { useIsMobile } from '../../hooks/useMediaQuery'

// Add hook
const isMobile = useIsMobile()

// Update styles
const containerStyle = {
  padding: isMobile ? '0' : '20px',
  maxWidth: isMobile ? '100%' : '1200px',
  margin: '0 auto'
}
```

### Files with hardcoded padding:

- [ ] AdminBestowTool.js
- [ ] BuffaloGenerator.js
- [ ] DoIHaveSwineFlu.js
- [ ] EverythingPollArchive.js
- [ ] EverythingPollCreator.js
- [ ] EverythingPollDirectory.js
- [ ] EverythingUserPoll.js
- [ ] SiteTrajectory.js
- [ ] TeddismsGenerator.js
- [ ] TheCatwalk.js
- [ ] ThemeNirvana.js
- [ ] UserRelations.js
- [ ] VotingExperienceSystem.js
- [ ] WriteupsByType.js

### Files with hardcoded maxWidth:

- [ ] AdminBestowTool.js
- [ ] BuffaloGenerator.js
- [ ] DoIHaveSwineFlu.js
- [ ] EverythingPollArchive.js
- [ ] EverythingPollCreator.js
- [ ] EverythingPollDirectory.js
- [ ] EverythingUserPoll.js
- [ ] SiteTrajectory.js
- [ ] TheCatwalk.js
- [ ] ThemeNirvana.js
- [ ] UserRelations.js
- [ ] VotingExperienceSystem.js
- [ ] WriteupsByType.js

---

## Priority 3: Missing useIsMobile Hook (219 files)

These components have inline styles but don't use the `useIsMobile` hook for responsive behavior. Lower priority since CSS media queries may handle basic cases.

<details>
<summary>Click to expand full list (219 files)</summary>

- AYearAgoToday.js
- AcceptableUsePolicy.js
- Achievement.js
- AdminBestowTool.js
- AdminSettings.js
- Alphabetizer.js
- AltarOfSacrifice.js
- AvailableRooms.js
- BadSpellingsListing.js
- BetweenTheCracks.js
- BlindVotingBooth.js
- BountyHuntersWanted.js
- BuffaloGenerator.js
- CacheDump.js
- CajaDeArena.js
- CategoryDisplay.js
- CategoryEdit.js
- ClientdevHome.js
- Collaboration.js
- CollaborationEdit.js
- ConfirmPassword.js
- Container.js
- ContentReports.js
- CostumeRemover.js
- CreateARegistry.js
- CreateCategory.js
- CreateNode.js
- CreateRoom.js
- DatabaseLagOMeter.js
- Datastash.js
- Dbtable.js
- Debatecomment.js
- DebatecommentEdit.js
- DefaultDisplay.js
- DisplayCategories.js
- DoIHaveSwineFlu.js
- DoYouCWhatIC.js
- DrNatesSecretLab.js
- Draft.js
- DraftsForReview.js
- DuplicatesFound.js
- E2Bouncer.js
- E2CollaborationNodes.js
- E2ColorToy.js
- E2GiftShop.js
- E2MarbleShop.js
- E2PennyJar.js
- E2Poll.js
- E2Rot13Encoder.js
- E2SourceCodeFormatter.js
- E2SpermCounter.js
- E2WordCounter.js
- E2client.js
- E2clientEdit.js
- EdevDocumentationIndex.js
- EdevFAQ.js
- EditWeblogMenu.js
- EditorBeta.js
- EditorEndorsements.js
- EverythingDataPages.js
- EverythingDocumentDirectory.js
- EverythingFinger.js
- EverythingIChing.js
- EverythingObscureWriteups.js
- EverythingPollArchive.js
- EverythingPollCreator.js
- EverythingPollDirectory.js
- EverythingPublicationDirectory.js
- EverythingQuoteServer.js
- EverythingSRichestNoders.js
- EverythingStatistics.js
- EverythingUserPoll.js
- EverythingsBestUsers.js
- EverythingsBestWriteups.js
- EverythingsBiggestStars.js
- EverythingsMostWanted.js
- FAQEditor.js
- FeedEdb.js
- Findings.js
- FreshBlood.js
- FreshlyBloodied.js
- FullTextSearch.js
- GoOutside.js
- GoldenTrinkets.js
- GpOptouts.js
- HomenodeInspector.js
- Htmlcode.js
- Htmlpage.js
- Ip2name.js
- IpBlacklist.js
- IpHunter.js
- IronNoderProgress.js
- IsItHoliday.js
- KlaprothVanLines.js
- LevelDistribution.js
- ListHtmlTags.js
- ListNodesOfType.js
- LogArchive.js
- Login.js
- MacroFaq.js
- MagicalWriteupReparenter.js
- Mail.js
- Maintenance.js
- MannaFromHeaven.js
- MarkAllDiscussionsAsRead.js
- MassIpBlacklister.js
- MessageInbox.js
- MyAchievements.js
- MyBigWriteupList.js
- MyRecentWriteups.js
- NatesSecretUnborgDoc.js
- NewUserImages.js
- NewsForNoders.js
- NodeBackup.js
- NodeForbiddance.js
- NodeHeavenTitleSearch.js
- NodeList.js
- NodeNotesByEditor.js
- NodeParameterEditor.js
- NodeRow.js
- NodeTracker.js
- Nodegroup.js
- Nodelet.js
- NodesOfTheYear.js
- Nodeshells.js
- Nodetype.js
- NodetypeChanger.js
- NodingSpeedometer.js
- NoteletEditor.js
- NothingFound.js
- Notification.js
- ObliqueStrategiesGarden.js
- PermissionDenied.js
- PitOfAbomination.js
- Podcast.js
- PodcastEdit.js
- PopularRegistries.js
- PublishModal.js
- QuickRename.js
- RandomNodeshells.js
- RandomText.js
- RecalculateXp.js
- RecalculatedUsers.js
- RecentNodeNotes.js
- RecentRegistryEntries.js
- RecentUsers.js
- Recording.js
- RecordingEdit.js
- Registry.js
- RegistryInformation.js
- RenunciationChainsaw.js
- RepublishModal.js
- ReputationGraph.js
- ResetPassword.js
- Room.js
- SQLPrompt.js
- SanctifyUser.js
- Schema.js
- SecurityMonitor.js
- ServerTelemetry.js
- Setting.js
- Settings.js
- ShowUserVars.js
- SignUp.js
- SilverTrinkets.js
- SimpleUsergroupEditor.js
- SiteTrajectory.js
- SpamCannon.js
- StyleDefacer.js
- Stylesheet.js
- SuperMailbox.js
- SuspensionInfo.js
- SystemNode.js
- TeddismsGenerator.js
- TextFormatter.js
- TheBorgClinic.js
- TheCatwalk.js
- TheCostumeShop.js
- TheKillingFloor.js
- TheNodeCrypt.js
- TheNodeshellHopper.js
- TheOldHookedPole.js
- TheOracle.js
- TheRecommender.js
- TheRegistries.js
- TheTokenator.js
- ThemeNirvana.js
- TopicArchive.js
- UserDisplay.js
- UserEdit.js
- UserEditVars.js
- UserRelations.js
- UserSearch.js
- UserStatistics.js
- Usergroup.js
- UsergroupAttendanceMonitor.js
- UsergroupDiscussions.js
- UsergroupMessageArchive.js
- UsergroupMessageArchiveManager.js
- UsersWithInfravision.js
- VotingData.js
- VotingExperienceSystem.js
- VotingOracle.js
- Websterbless.js
- WharfingerLinebreaker.js
- WhatDoesWhat.js
- WhatToDoIfE2GoesDown.js
- WheelOfSurprise.js
- WhoIsDoingWhat.js
- WhoKilledWhat.js
- WordMesserUpper.js
- Writeup.js
- WriteupsByType.js
- YourFilledNodeshells.js
- YourGravatar.js
- YourIgnoreList.js
- YourInsuredWriteups.js
- YourNodeshells.js
- Zenmastery.js

</details>

---

## How to Use This Report

1. **Start with Priority 1** (Duplicate H1s) - these are user-visible issues
2. **Test visually** using `node tools/browser-debug.js screenshot-mobile [url]`
3. **Mark items complete** by changing ⬜ to ✅ in this document
4. **Re-run audit** periodically: `node tools/mobile-audit.js --markdown > docs/mobile-audit.md`

## Related Tools

- `node tools/mobile-audit.js` - Run full audit
- `node tools/mobile-audit.js --h1-only` - List only duplicate H1 files
- `node tools/mobile-audit.js --json` - JSON output for scripting
- `node tools/browser-debug.js screenshot-mobile [url]` - Take mobile screenshot
- `node tools/browser-debug.js screenshot-as-mobile [user] [url]` - Mobile screenshot as user


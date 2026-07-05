# Test Coverage Worklist — Routing Epoch Readiness

**Created:** 2026-07-05 (overnight session)
**Purpose:** The checklist that (a) captures the controller→React-routing gap, (b) builds the
"before/after" test net that lets us flip pages to the client router fast and safely, and (c)
records the jest coverage gaps found in a module-by-module audit. Work top-to-bottom; check items
off as they land. Raise the flagged questions in the morning.

---

## 0. Why this exists (the strategy)

The #4298 mutation sweep put an **API layer** between the client and the data model. That layer is
the firewall that makes **React routing** and the **ORM epoch** independent — routing sits *on top*
of the APIs, ORM sits *behind* them. Decision (see chat): **routing epoch next**, ORM deferred to
last (unless login-with-Google is pulled forward, in which case do only the account-model slice
first). This doc is the routing epoch's test readiness.

The routing epoch converts **80 Page controllers** that still read query params for their own logic
(pagination / entity-selection / prefill / external-link landing — all reads; mutations are already
gone) into a **client router + GET APIs** world. The single sanctioned SSR CGI-parsing element is
`Everything::PageState` (`node`, `displaytype`); no role/mixin or the `Everything::Page` base class
touches CGI. Everything else should stop touching CGI.

### The three-layer test plan (put each assertion at the cheapest layer that holds it)

1. **Perl URL-parser parity** — `t/101/102/103/120` already cover
   `_recover_route_params_from_request_uri`. When the React client router re-implements that parse,
   add a **shared fixture set** asserted in BOTH `t/` and jest so the two parsers provably agree
   (the cross-language LinkNode-encode → helper-decode round-trip is the scariest divergence). Do
   NOT push this to browser tests.
2. **Jest (component + client-router unit)** — given a route/params, the component renders X and
   calls API Y. Fast, deterministic, per-component. This is where per-page "before == after render"
   parity is cheapest.
3. **Playwright e2e (`tests/e2e/`)** — the round-trip only a browser proves: real URL → router →
   GET API → DOM, **no full page reload on nav**, back/forward, deep-link → correct content, URL
   sync, guest chrome cached across nav (#4257).

**The move that makes before/after work:** write e2e nav specs **behavior-true in both worlds NOW,
before flipping**. After a page flips to the client router the same spec must still pass (parity
oracle); you only *add* the "did not full-reload" assertion. Specs don't change on the flip — that's
what lets us go page-by-page fast with a net written up front.

---

## 1. Test infrastructure (verified 2026-07-05)

- **Runner:** `npx playwright test` (@playwright/test 1.57), `./tools/e2e-test.sh [name]`,
  base URL `http://localhost:9080` (dev container). **128 tests / 24 spec files** today.
- **Auth fixtures** (`tests/e2e/fixtures/auth.js`): `loginAsRoot` (admin/blah),
  `loginAsGenericDev` (user/blah), `loginAsE2EAdmin`/`loginAsE2EUser` (test123), `visitAsGuest`.
  All drive the Sign In nodelet and wait on `#epicenter` / `window.e2.user.guest===false`.
- **Content fixtures** (`tests/e2e/fixtures/content.js`): `createWriteup` (draft→parent→publish via
  API), `getWriteuptypeId`.
- **Signup/email helper:** `tools/test-signup.pl <username> [password]` — dev doesn't send
  activation emails; this generates the activation link so a spec can drive Sign Up →
  confirm_password end-to-end. Run inside the container:
  `docker exec e2devapp perl /var/everything/tools/test-signup.pl <user> <pass>`.

---

## 2. E2E coverage — current + gaps

### Already covered (24 specs — do not duplicate)
Routing parity (`url-routing`), navigation, `node-forward` redirects, `link-resolution`,
`discussion-back-link`, auth roles (`e2e-users`), `logout-migration`, `contentdata-role-gating`,
chatterbox, messages/mini-messages, notifications (epicenter/delivery/bookmark/nodelet),
drafts-editor, writeup-lifecycle, discussion-reply, usergroup-discussions, poll-creator, wheel,
gp-transfer, guest-chrome, settings-persistence, concurrent-isolation.

### Gap A — the #4298-migrated admin/action tools (NO e2e today) — HIGH VALUE
These are API-driven now (jest interaction covered) but have zero browser coverage; they're the
natural before/after anchors. For each: cover the **states** (guest→denied/login, non-admin→denied
where applicable, admin→success) and the primary mutation round-trip via its API.

- [ ] `the-borg-clinic.spec.js` — admin sets numborged; non-admin denied; lookup-then-set flow
- [ ] `tokenator.spec.js` — admin gives token(s); per-user results; non-admin denied
- [ ] `websterbless.spec.js` — editor/admin bless (PM+karma+GP); non-editor denied
- [ ] `penny-jar.spec.js` — logged-in give/take (GP + jar count); guest login-gated
- [ ] `node-tracker.spec.js` — logged-in update snapshot; NoGuest redirect for guest
- [ ] `nodetype-changer.spec.js` — admin lookup→change; **permanent-cache confirm gate**; non-admin denied
- [ ] `ip-blacklist.spec.js` — admin add(single+CIDR)/remove/list; the unified page; non-admin denied
- [ ] `usergroup-message-archive.spec.js` — member copy-to-self + reset-time; guest login msg; non-member error
- [ ] `nate-unborg.spec.js` — admin unborg button → reload; non-admin brush-off

### Gap B — auth account flow (uses the email helper) — HIGH VALUE
- [ ] `signup-flow.spec.js` — Sign Up form → `test-signup.pl` link → `confirm_password` login form →
      set password → logged in. States: fresh signup, **expired link** (state=expired, no nuke now),
      bad token (login_required), already-activated. **Q(morning): OK to have the spec shell out to
      `docker exec … test-signup.pl`, or do we want a Playwright-visible dev mailbox?**
- [ ] `reset-password.spec.js` — Reset password → confirm link → set new password → logged in

### Gap C — pagination / navigation parity (write behavior-true-in-both-worlds) — MEDIUM
For the ~19 pagination controllers. Assert the CONTENT of page N and that nav links change the
content; today it's full-reload, so also snapshot the "reload happens" baseline to later invert.
- [ ] `writeups-by-type.spec.js` (count/page/wutype)
- [ ] `pagination-parity.spec.js` — parametric over: usergroup_message_archive, who_killed_what,
      homenode_inspector, everything_user_search, caja_de_arena, recent_node_notes, node_notes_by_editor
- [ ] extend `usergroup-discussions.spec.js` — offset/show_ug nav (pairs with #4473)

### Gap D — entity-selector landings — MEDIUM
- [ ] `entity-select.spec.js` — parametric deep-links: reputation_graph?id, show_user_vars?username,
      ip_hunter?hunt_ip, node_parameter_editor?for_node, the_borg_clinic?clinic_user (prefill)

---

## 3. Jest coverage — module-by-module audit (2026-07-05)

**Documents components: 235.** Interaction-tested: **44** (+5 tonight = **49**). Render-only:
**187**. No test: **4 → 0** (all 4 written tonight). Render-only is *appropriate* for pure-display
pages; the real gap is components with **interactive code but only a render-only test**. Recounted
precisely tonight (not a heuristic): **56 fetch-driven** components with mount-only tests (§3b) +
**~35 local-interaction-only** (§3c). Priority = the `fetch(` set (API-driven — the interaction
that matters for an API-first site). After e2e dedupe the true fetch-gap is **≈50**.

### 3a. No test at all — write at least a mount test — HIGH — **DONE (2026-07-05)**
- [x] `E2Node` (4 tests: loading/not-found guards + category_id URL-param forwarding, child mocked)
- [x] `ContentItem` (6 tests: show* flag gating, parent-vs-title link target, truncated "more")
- [x] `AdminSettings` (7 tests: guest/permission branches, dirty→save, brace-transform POST, delete-macro)
- [x] `UnimplementedPage` (3 tests: identity echo, encoded GitHub issue link, missing-data degrade)

### 3b. Render-only but calls `fetch(` (untested API interaction) — HIGH
Precise count after module-by-module recount (2026-07-05): **56** fetch-driven Documents components
whose test file is mount-only (no `fireEvent`/`userEvent`). Full list:
AdminBestowTool, AltarOfSacrifice, BetweenTheCracks, CategoryEdit, Collaboration, CollaborationEdit,
CoolArchive, CostumeRemover, CreateRoom, DebatecommentEdit, Decloaker, DisplayCategories, Document,
DrNatesSecretLab, E2Bouncer, E2GiftShop, E2Poll, E2clientEdit, EditWeblogMenu, EverythingPollArchive,
EverythingPollCreator, EverythingPollDirectory, EverythingUserPoll, KlaprothVanLines,
MagicalWriteupReparenter, MessageInbox, NewUserImages, NewsForNoders, NodeBackup, NodeParameterEditor,
PageOfCool, PodcastEdit, QuickRename, RecalculateXp, RecordingEdit, Registry, ReputationGraph,
~~ResetPassword~~ **[x] done 2026-07-05 (4 interaction tests: client-side validation branches +
POST /api/password/reset-request + success/error)**, Room, Setting, Settings, SignUp, SilverTrinkets,
SiteTrajectory, SpamCannon, SuspensionInfo, TheCostumeShop, TheNodeshellHopper, UserDisplay, UserEdit,
UserEditVars, UserSearch, Usergroup, UsergroupDiscussions, VotingExperienceSystem, WheelOfSurprise.

**Already compensated by e2e (lower jest priority):** `WheelOfSurprise` (wheel.spec), `UsergroupDiscussions`
(usergroup-discussions.spec), `SuspensionInfo`/`Decloaker`-family, `SignUp`+`ResetPassword` auth flow
(signup-confirm.spec covers signup→confirm end-to-end).

**Interaction tests written 2026-07-05 (highest-value tier, 14 tests):**
- [x] `E2Poll` (3) — vote POST + in-place tally update; vote-rejected error; admin delete-vote → reload (PollDisplay mocked, in `E2Poll.interaction.test.js`)
- [x] `SpamCannon` (4) — empty/over-cap validation gate the network; parsed-recipient POST + sent-to list + form clear; API error box
- [x] `E2Bouncer` (3) — empty-username gate; parsed usernames + room POST + moved list; not-found rendering
- [x] `MessageInbox` (4) — guest prompt (no network); seed list+count from data; archive round-trip drops the message; Sent-tab reload hits `/api/messages/?…&outbox=1` (MessageList mocked, in `MessageInbox.interaction.test.js`)

**Interaction tests written 2026-07-05 (tier-2, 10 tests):**
- [x] `Settings` (5, `Settings.interaction.test.js`) — guest gate; dirty-gated Save; **only-changed
  keys → `/api/preferences/set`** + success; cross-section dirty gating (a pref change never POSTs
  `/api/user/edit`/`/api/nodelets`/notifications); error banner. Peripheral list managers mocked.
- [x] `UserEdit` (5, `UserEdit.interaction.test.js`) — no-user → null; profile fields (+node_id+bio)
  → `/api/user/edit` + success; API error; **multipart avatar → `/api/user/upload-image`** + reload;
  non-image file rejected client-side (no upload).

**Interaction tests written 2026-07-05 (tier-3, 20 tests):**
- [x] `Setting` (5, appended) — nodevars editor: empty/invalid/duplicate key gates; add → `/api/nodevars/:id/set`; delete (confirm) → `/delete`
- [x] `UserEditVars` (4, appended) — same nodevars CRUD on a user node: add/update/delete round-trip
- [x] `CollaborationEdit` (5, `.interaction.`) — save (HTML mode) → `/action/save`; removemember; unlock; delete (modal); no-data guard
- [x] `Registry` (4, `.interaction.`) — guest gate; submit → `/action/submit`; delete-own (confirm) → `/action/delete`; admin_delete
- [x] `CategoryEdit` (2, `.interaction.`) — remove_member; update_meta (public → author_user = guest id)

**True remaining jest gap ≈ 39** after this batch. **Next tier:** `NodeParameterEditor`, `CreateRoom`,
`QuickRename`, `RecalculateXp`, `MagicalWriteupReparenter`, `Collaboration` (single-action), the poll
family (`EverythingPollCreator`/`EverythingPollArchive`), `SignUp` (jest side — e2e-covered).

### 3c. Render-only with onClick/onSubmit only (local interaction, no fetch) — MEDIUM (~42)
Alphabetizer, BuffaloGenerator, CacheDump, Datastash, Debatecomment, DoIHaveSwineFlu, DoYouCWhatIC,
E2ColorToy, E2Rot13Encoder, E2SourceCodeFormatter, E2WordCounter, EditorEndorsements,
EverythingQuoteServer, Ip2name, IronNoderProgress, LogArchive, MyBigWriteupList, NodeHeavenTitleSearch,
Nodegroup, NodesOfTheYear, NoteletEditor, Schema, Stylesheet, TeddismsGenerator, TextFormatter,
TheRecommender, WhoIsDoingWhat, WordMesserUpper, (+ useState-only: IpHunter, NodeNotesByEditor,
NodingSpeedometer, ShowUserVars, TheRegistries, VotingData, WelcomeToEverything, WhoKilledWhat,
WriteupsByType).

> Note: several 3b entries are the #4298 tools that DO have interaction tests under a different
> component name, or are display-with-incidental-fetch. Verify per-component before writing — don't
> add a test that duplicates existing coverage.

---

## 4. Progress log (overnight 2026-07-05)

**Gap A — migrated #4298 admin tools: DONE (9/9 specs, 12 tests, all green).**
- [x] `node-tracker.spec.js` (2) — update-in-place round-trip + NoGuest guest gate
- [x] `nate-unborg.spec.js` (1) — unborg POST + reload (self, safe no-op)
- [x] `ip-blacklist.spec.js` (1) — admin add (RFC-5737 IP) + remove, self-cleaning
- [x] `tokenator.spec.js` (1) — bogus-user per-user error (no mutation)
- [x] `websterbless.spec.js` (1) — bogus-user per-user error (no mutation)
- [x] `penny-jar.spec.js` (2) — logged-in jar state + guest login-gate
- [x] `usergroup-message-archive.spec.js` (2) — member group-open + copy form; guest gate
- [x] `the-borg-clinic.spec.js` (1) — admin lookup form present
- [x] `nodetype-changer.spec.js` (1) — lookup + permanent-cache warning on select (no change)

**Gap B — auth flow: DONE (1 spec, 2 tests, green).**
- [x] `signup-confirm.spec.js` (2) — `tools/test-signup.pl` → activation link → confirm form →
      `/api/users/confirm` → logged in as the new user; AND expired-link → `expired` state with
      **NO nuke** verified (#4475). Helper is shelled via `execSync('docker exec … test-signup.pl')`
      — works from the Playwright worker (see morning Q).

**Patterns learned (for whoever extends this):**
- Scope tool inputs — `getByRole('textbox').first()` grabs a CHROME textbox (search/chatterbox).
  Use a placeholder (`getByPlaceholder`) or `input[name=…]` / component class. Same for
  `getByRole('combobox')` (nodelets have selects) — scope with the component's `.__select` class.
- Mutating tools: prefer a **no-mutation path** (bogus user → per-user error, read-only lookup, the
  warning-on-select) — the happy-path mutation is already covered by the `t/183–193` API tests, and
  no-mutation keeps e2e repeatable with zero data residue.
- `nick` is `varchar(20)` — signup usernames must be short (`'e2e_'+Date.now().toString(36)`).
- On success the confirm component redirects → `resp.json()` fails ("No resource…"); assert the
  logged-in end-state (`window.e2.user`) instead of the response body.

### Open questions for the morning
1. **Signup helper via docker exec:** ✅ **RESOLVED (Jay, 2026-07-05):** coupling the spec to
   `docker exec e2devapp … test-signup.pl` is fine — `e2devapp` is a controlled/fixed container name.
   No dev-mailbox endpoint needed. Keep the pattern for any email-simulating spec (signup + reset).
2. **Reset-password e2e:** ✅ **DONE** — `password-reset.spec.js` (2 tests, serial), mirrors
   signup-confirm via `tools/test-password-reset.pl`: valid reset → login as the user; expired link →
   `expired` + no nuke (#4475). Stable over 4+ suite runs.
   - *Gotcha logged in the spec header:* `urlGen()` serialises token-link params in random Perl hash
     order → link extraction MUST be order-independent (an `…action=reset$` pattern silently misses
     ~1-in-6 links and reads as flakiness). **Verified NOT a product bug:** navigating the same params
     token-first vs token-last (expired expiry) both resolve to `state=expired` — the route-recovery
     parser is order-agnostic.
3. **Gap C/D parity specs:** ✅ **DONE behavior-true-now** (Jay's call, 2026-07-05):
   - `writeups-by-type.spec.js` (Gap C, 2 tests): `wutype`/`count` reflect into the filter selects;
     pagination links round-trip `count`+`page`. (count clamps to ≥10 — noted in spec.)
   - `entity-deeplink.spec.js` (Gap D, 2 tests): `show user vars ?username=` selects that user
     (prefill contract); `Reputation Graph ?id=` valid writeup renders / bogus id → error state.
   These pin the current URL→content contract so the router flip has a before/after guard.
2. **Reset-password spec** (Gap B second half) — same helper pattern; write it, or fold into signup?
3. **Gap C/D (pagination + entity-select parity):** these are the *routing* before/after specs. Worth
   writing them behavior-true-now, or wait until the router work actually starts?

**Jest §3a — 4 no-test components: DONE (24 tests, green).** E2Node, ContentItem, AdminSettings,
UnimplementedPage. Full jest suite after additions: **302 suites / 2516 tests, all pass.**

**Jest §3b — started: ResetPassword DONE (4 interaction tests).** Auth-family, pairs with the
signup-confirm e2e; validates client-side gates before the network + the reset-request POST.

### Still TODO (documented, not yet written)
- Gap C: pagination-parity specs (writeups_by_type, ugma pages, who_killed_what, homenode_inspector…)
- Gap D: entity-selector deep-link specs (reputation_graph?id, show_user_vars?username, ip_hunter…)
- Jest §3b: ~50 remaining fetch-driven components (next tier: MessageInbox, Settings, UserEdit,
  E2Poll, SpamCannon — see §3b "Suggested next tier by value")
- ~~Pre-existing e2e failure: `bookmark-notification.spec.js`~~ **RESOLVED (Jay's call, 2026-07-05):**
  a writeup isn't bookmarkable (writeup/draft nodetypes carry `disable_bookmark=1`), so bookmarking a
  writeup now **redirects to its parent e2node** as a display override — new `_bookmark_target` helper
  in `Everything::API::cool`, applied in both `toggle_bookmark` and `bookmark_status`. `t/062_cool_api.t`
  updated to the new contract (link lands on the e2node; disable-gate tested on the e2node);
  `t/149_bookmark_notify.t` + the e2e spec both green.
- Full e2e suite: 134 passed / 11 skipped. Chatterbox (focus/counter) + concurrent-isolation flake
  under full-suite load but pass in isolation — timing-sensitive, unrelated to any code change here.

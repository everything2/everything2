# Controller Rationalization Inventory

**Created:** 2026-07-05 · **Owner:** Jay · **Status:** living recon doc

The denominator + classification for the module-by-module controller sweep. Three intertwined
goals, tracked together so each module is touched once:

1. **Kill silent `$query` dependence** (routing epoch) — no controller reads CGI directly; params
   flow through the `PageState` facade (#4255) so the React client router can supply them.
2. **Rationalize SSR into shared roles** (ORM prep) — the genuinely server-side logic a Page and its
   API twin both need lives in one `Everything::Roles::*` unit, shaped for the Node:: object model,
   not duplicated inline in each controller.
3. **Full permission audit** (#4463) — every Page's gate and its API twin's gate must be provably the
   same. Today Pages gate via `Everything::Security::*` mixins **and** inline checks; APIs gate purely
   inline. The rollout must make these float through and match.

Method: grep-derived (param names, `with` role/mixin declarations, React `Document → /api/*` edges).
Buckets marked *(inferred)* are from the param-name signal and need a read to confirm before editing.
Feeds/tickers (`*_xml_ticker`, `*_atom_feed`, `*_json_ticker`, `rdf_search`, `*_xml`) are **out of
scope** (legacy APIs, per Jay).

---

## Headline numbers

- **255** Page controllers. **154** already free of `$query`/`param`/CGI. **~101** touch it; ~30 of
  those are feeds/tickers (out of scope) → **~70 real Page controllers** to sweep.
- **97** API controllers. **14** share an exact name with a Page (confirmed twins); many more pair
  semantically via the React Document they render.
- **4** `Everything::Security::*` mixins. **~35** Pages use a mixin explicitly; many more gate inline.
- **2** shared roles exist today (`NodeTrackerStats`, `IPBlacklist`) — the pattern to replicate.

---

## Part A — `$query` exposure, classified (~70 real Pages)

### A1. Route / dispatch recovery → **PageState route-recovery** (already built)
`nothing_found` (node,node_id,op,lastnode_id,type,tinopener), `findings` (node,lastnode_id,
not_found_by_id), `login` (lastnode_id,op), `duplicates_found` (node,lastnode_id), `short_url_lookup`
(short_string). These are the not-found/dispatch family — the `PageState` facade + legacy-URL
route-recovery helper already own this parsing; the parity harness is `t/101`/`t/103`/`t/120` + the
`link-resolution.spec.js` / `url-routing.spec.js` e2e.

### A2. Pagination → route through PageState, **covered by Gap-C parity specs**
`a_year_ago_today` (startat), `altar_of_sacrifice` (page), `caja_de_arena` (page), `everything_user_search`
(page), `fresh_blood`/`freshly_bloodied` (start), `homenode_inspector` (page), `node_notes_by_editor`
(start,limit), `nodes_of_the_year` (count), `recent_node_notes` (page), `security_monitor` (startat),
`topic_archive` (startat), `usergroup_discussions` (offset), `usergroup_message_archive` (startnum,max_show),
`who_killed_what` (offset,limit), `writeups_by_type` (page,count), `the_catwalk` (next).
→ template: `writeups-by-type.spec.js` (pagination round-trip parity).

### A3. Entity deep-link (id / user / node param) → route through PageState, **Gap-D parity specs**
`reputation_graph`/`reputation_graph_horizontal` (id), `show_user_vars` (username), `node_notes_by_editor`
(targetUser), `do_you_c_what_i_c`/`the_recommender` (cooluser), `node_parameter_editor` (for_node),
`simple_usergroup_editor` (for_usergroup), `altar_of_sacrifice` (author), `editor_endorsements` (editor),
`noding_speedometer` (speedyuser), `the_borg_clinic` (clinic_user), `e2_bouncer` (borguser), `who_killed_what`
(heavenuser), `ip_hunter` (hunt_ip,hunt_name), `ip2name` (ipaddy), `renunciation_chainsaw` (wu_id),
`drafts`/`e2_editor_beta` (other_user), `message_inbox` (spy_user,fromuser), `node_heaven_title_search`
(heaventitle). Prefill hints (harmless, still route via PageState): `websterbless`/`superbless`/
`xp_superbless`/`bestow_cools`/`bestow_easter_eggs`/`enrichify`/`fiery_teddy_bear_suit`/
`giant_teddy_bear_suit` (prefill_username), `the_old_hooked_pole` (prefill).
→ template: `entity-deeplink.spec.js`.

### A4. Filter / display / date options → route through PageState
`everything_document_directory` (edd_limit,filter_nodetype,filter_user), `caja_de_arena` (extlinks,
gonesince,published,showlength), `homenode_inspector` (dotstoo,extlinks,gonetime,goneunit,maxwus,
showlength), `my_big_writeup_list` (delimiter,orderby,raw,usersearch), `everything_s_best_users` (ebu_*),
`nodes_of_the_year` (orderby,wutype,year), `display_categories` (m,o,p), `everything_user_search`
(filterhidden,orderby), `recent_node_notes` (hidesystemnotes,onlymynotes), `the_everything2_voting_experience_system`
(fstlevel,sndlevel), `voting_data` (vote{day,day2,month,year}), `the_catwalk` (ListNodesOfType_Sort,
filter_user,filter_user_not), `buffalo_generator`/`buffalo_haiku_generator` (onlybuffalo), `the_node_crypt`
(opencoffin), `manna_from_heaven`/`who_is_doing_what` (days), `historical_iron_noder_stats` (year),
`site_trajectory`/`site_trajectory_2` (y), `log_archive` (m,y), `a_year_ago_today` (yearsago),
`the_registries` (include_empty), `my_achievements` (debug), `content_reports` (driver), `clientdev_home`/
`news_for_noders_stuff_that_matters` (nextweblog), `news_archives`/`usergroup_picks` (view_weblog),
`historical_iron_noder_stats` (year).

### A5. Mutation-leftover suspects — VERIFIED 2026-07-08

**2 CONFIRMED escapees — ✅ MIGRATED 2026-07-08 (#4479, branch `issue/4479/mutation-leftovers`):**
- ✅ **`notelet_editor`** — save/castrate writes moved to `POST /api/notelet/{save,castrate}` (NoGuest); page pure-render; shared logic in `Everything::Roles::Notelet` (max-length + payload + save/castrate). React fetch-driven; jest interaction (3) + `t/194_notelet_api.t` (guest gate + save + castrate).
- ✅ **`usergroup_message_archive_manager`** — archive on/off write moved to `POST /api/usergroup_message_archive_manager/apply` (admin, batch); page pure-render; shared logic in `Everything::Roles::UsergroupArchive` (status payload + apply). React preserves the checkbox+dropdown guard, submits via fetch; jest interaction (3) + `t/195_..._api.t` (non-admin gate + empty-apply + real toggle w/ restore).

This closes the mutation-leftover tail of #4298: no `buildReactData` writes-on-query-param remain among the audited set.

**5 CLEAN (pure-render; action already API-driven):**
- `e2node_reparenter` — reads `repare` only to look up nodes for display; reparent write is `writeup_reparent` API (React). ✅
- `the_oracle` — pure-render; var write moved to `POST /api/oracle/setvar` (#4405). ✅
- `create_node` — pure-render; create via `node` API (`canCreateNode`). ✅
- `dr_nate_s_secret_lab` — pure-render; resurrect via `resurrect` API (admin). ✅
- `magical_writeup_reparenter` — pure-render; `writeup_reparent` API. ✅

### A6. Auth flow (special)
`confirm_password` (action,expiry,token,user) — already pure-render (#4475); twin `users` (confirm).

---

## Part B — Page ↔ API twins (rationalization map)

Edge = the Page renders a React Document (`type` in `buildReactData`) which calls `/api/<controller>`.
`R` = a shared role already exists. Confirmed name-matched twins are ★.

| Page (SSR) | React Document | API twin(s) | Shared role? |
|---|---|---|---|
| ★ node_tracker | NodeTracker | node_tracker | ✅ `NodeTrackerStats` |
| ★ ip_blacklist / mass_ip_blacklister | IpBlacklist | ip_blacklist | ✅ `IPBlacklist` |
| ★ websterbless | AdminBestowTool→? / Websterbless | websterbless | — (candidate) |
| ★ nodetype_changer | NodetypeChanger | nodetype_changer | — |
| ★ the_tokenator | (Tokenator) | the_tokenator | — |
| ★ usergroup_message_archive | (UMA) | usergroup_message_archive | — |
| ★ e2_penny_jar | E2PennyJar | e2_penny_jar | — |
| ★ nate_s_secret_unborg_doc | NatesSecretUnborgDoc | nate_s_secret_unborg_doc | — |
| ★ page_of_cool | PageOfCool | page_of_cool | — |
| ★ cool_archive | CoolArchive | cool_archive, node_search | — |
| ★ superbless | AdminBestowTool | superbless | — (candidate w/ websterbless) |
| ★ drafts | Draft | drafts | — |
| settings | Settings | preferences, nodelets, user | — (candidate: prefs role) |
| show_user_vars / viewvars | ShowUserVars / UserEditVars | nodevars | — (candidate: nodevars role) |
| the_borg_clinic | TheBorgClinic | borgclinic | — |
| reputation_graph(_horizontal) | ReputationGraph | reputation | — |
| e2_bouncer | E2Bouncer | bouncer | — |
| message_inbox | MessageInbox | messages, node_search | — |
| node_parameter_editor | NodeParameterEditor | node_parameter | — |
| magical_writeup_reparenter / e2node_reparenter | MagicalWriteupReparenter | writeup_reparent | — (candidate: reparent role) |
| simple_usergroup_editor | SimpleUsergroupEditor | nodes, usergroups | — |
| collaboration(_edit) | Collaboration / CollaborationEdit | collaborations | — |
| category_edit / create_category | CategoryEdit / CreateCategory | category | — |

Full `Document → /api/*` edge list captured (80+ components); the rows above are the ones with a
non-trivial SSR seam worth a shared role. **AdminBestowTool** backs websterbless/superbless/xp_superbless
→ strongest single-role consolidation candidate.

---

## Part C — Permission audit framework (#4463)

**Two mechanisms today:**
- **Page** — declarative `Everything::Security::*` mixin (enforced by `Controller/fullpage.pm` +
  `superdoc.pm`) *and/or* inline `$user->is_*` checks in `buildReactData`, *and* the node-level
  permission bits on the superdoc/document node itself (nodepack XML).
- **API** — inline `$user->is_admin`/`is_editor`/`is_guest` per method; **no** `check_permission`
  wiring (#4463). 30+ API controllers gate this way (category 21, admin 17, collaborations 12, …).

**The 4 mixins (the canonical gates):**
| Mixin | Gate | API equivalent |
|---|---|---|
| `NoGuest` | not guest → RedirectLogin | `return … if $user->is_guest` |
| `Permissive` | always OK | (no gate) |
| `StaffOnly` | `is_editor` | `return … unless $user->is_editor` |
| `StaffOrDeveloper` | `is_editor \|\| is_developer` | `unless is_editor \|\| is_developer` |

**The current controller permission is the audit oracle.** The API gate is the only real security
boundary (a client bypasses the controller and calls `/api/*` directly). So the audit is a mechanical
check: the Page/controller's *existing* permission is the **expected** value; the API route's
*implemented* permission is the **actual**; any divergence is a finding to fix on the API side. We are
not re-architecting controller permissions — we are using them as the reference spec the API must match.

**Audit procedure, per twin (fill during each module):**
1. Extract the controller's current gate — mixin (`with 'Everything::Security::X'`), inline `is_*`,
   node perms. This is the **expected** permission.
2. Extract the API twin's per-route implemented gate. This is the **actual**.
3. Assert actual == expected (via the mixin→predicate mapping above). Record match / **MISMATCH**;
   MISMATCH = a bug on the API side (the boundary that actually enforces).
4. End-state (#4463): the gate is declared once (an `Everything::Security::*` predicate) and referenced
   by both sides — Page via `:does`, API via a per-route `gate` key in the routes table — so the audited
   match can't silently drift later. See "Object::Pad note" below.

**Object::Pad note (future-proofing, Jay 2026-07-06):** permission gates are stateless behavior-only
roles — the easy Moose→Object::Pad case (no fields/BUILD/MOP). They translate ~1:1 to
`role … { method check_permission ($req) {…} }` consumed via `:does`. Pages are whole-controller-gated
(`:does` at class level); APIs are **per-route**-gated, so they DON'T `:does` the mixin — instead each
route names the same predicate via a `gate` key in the `routes` table, which the API dispatcher resolves
and enforces. Plain data + a stateless role → survives Moose → Object::Pad → core `class` untouched, and
makes the audit greppable.

**~35 Pages declaring a mixin explicitly** (audit these against their API twins first): chatterlight*,
e2_collaboration_nodes, silver_trinkets, everything_s_best_writeups, your_nodeshells, quick_rename,
the_costume_shop, costume_remover, usergroup_picks, e2_gift_shop, edit_weblog_menu, topic_archive,
everything_s_obscure_writeups, recalculated_users, node_tracker, golden_trinkets, sanctify_user,
the_nodeshell_hopper, new_user_images, node_backup, news_archives, pit_of_abomination, recalculate_xp,
manna_from_heaven, wharfinger_s_linebreaker, your_ignore_list, recent_node_notes, what_does_what,
your_filled_nodeshells, your_insured_writeups.

### Part C.1 — Audit results, first pass (2026-07-08, 24 twins)

Oracle = current controller gate. Actual = API route's implemented gate. `is_editor` includes admins.

**MATCH (18):** node_tracker (NoGuest↔is_guest), ip_blacklist (admin↔is_admin), websterbless
(editor+admin↔is_editor||is_admin), nodetype_changer (admin), the_tokenator (admin),
usergroup_message_archive (login↔is_guest), e2_penny_jar (login), nate_s_secret_unborg_doc (admin),
sanctify (editor+level), xp/recalculate_xp (NoGuest, admin-for-others), userimages/new_user_images
(StaffOnly↔is_editor), e2nodes/quick_rename (StaffOnly↔is_editor), nodebackup (NoGuest, admin-for-others),
drafts (login + author-or-admin), writeup_reparent/reparenters (editor+admin both sides), page_of_cool
(public), cool_archive (public), e2_bouncer (chanop both sides — the Page's `is_guest` was a render
check, not the gate).

**FINDINGS + RESOLUTIONS (Jay 2026-07-08):**

| # | Twin | Finding | Resolution |
|---|---|---|---|
| 1 | **node_parameter** ↔ node_parameter_editor | API gated `is_editor\|\|is_admin`; Page gates `is_admin` only → API over-permissive on node-param read/set/delete (behavior flags like `disable_bookmark`). | ✅ **FIXED** — decision: **admin-only**. Tightened all 3 API guards (get/set/delete) to `unless $APP->isAdmin(...)`, message → "Administrators only". Now matches the oracle. |
| 2 | **superbless** grant_gp=`is_editor` vs siblings=`is_admin` | Internal inconsistency. | ✅ **INTENDED, no change** — editors *may* grant GP; grant_xp/grant_cools/fiery_hug are legacy and correctly admin-only. Behavior is correct. |
| 3 | **reputation** ↔ reputation_graph | Grep-oracle showed `is_admin`. | ✅ **Diagnosis correct; no code change** — the controller already computes `can_view = is_admin \|\| author \|\| voted` (reputation_graph.pm L61-93) and passes `can_view` to React; the `is_admin` was just the first term. Page and API already agree. Audit grep was imprecise, not the code. **→ MATCH.** |
| 4 | **preferences** ↔ settings | `set_preferences`/`set_notification` returned non-200s (`HTTP_BAD_REQUEST`/`HTTP_UNAUTHORIZED`/`HTTP_INTERNAL_SERVER_ERROR`) — breaks JSON clients (200-only rule). | ✅ **Short-term FIXED** — the 8 preferences-owned validation/data non-200s → `HTTP_OK` + `success:0` body (`t/029` updated). **Guests are already gated** by the base-class `around unauthorized_if_guest` (returns `[401]`) — the earlier "no login gate" read was wrong; my redundant inline gates were removed. That guest-401 is a base-class non-200 = part of the **already-filed larger scrub**, out of this fix's scope. ⚠️ **Client-consumption ripple (found + FIXED per Jay's directive):** 2 consumers checked HTTP status (`.ok`) not the body — **Settings.js** (×2, `/api/preferences/set`) and **StyleDefacer.js** (customstyle over-cap) would have mis-read a `200+success:0` reject as a silent SUCCESS. Both now check `!res.ok \|\| body.success === 0` (the universal failure test — works whether success carries `success:1` or nothing). Jest contract tests added for the `200+success:0` reject on both. All other `/api/preferences/set` consumers are editor-mode toggles (fire-and-forget, valid 0/1 → never `success:0`) — safe. |

### Part C.2 — Audit results, second pass (2026-07-08, remaining mutation twins)

**All MATCH — no new mismatches.**

| Twin | Oracle | Actual (API) | Notes |
|---|---|---|---|
| category ↔ CategoryEdit | editor (meta/members), owner/admin (content) | update_category owner/admin; update_meta/reorder/remove/lookup `is_editor` | MATCH |
| collaborations ↔ CollaborationEdit | owner/editor/admin; delete=admin | `_check_access` admin\|\|editor\|\|member; save lock-owner\|\|editor\|\|admin; delete admin | MATCH (ownership-based) |
| usergroups ↔ SimpleUsergroupEditor / Usergroup | editor/admin (tool); owner (self-manage) | `_can_manage_usergroup` admin\|\|editor\|\|owner | MATCH — API is the **superset**; each Page is a subset entry point |
| messages ↔ MessageInbox | login + ownership (+admin spy) | `_message_operation_okay`/`_outbox_operation_okay` is_guest + ownership | MATCH |
| node/create ↔ create_node | node-level create perm | `canCreateNode($user,$type)` → FORBIDDEN | MATCH (proper node-level gate; the 403 is a non-200 → #3768) |
| resurrect ↔ dr_nate_s_secret_lab | admin | `unless isAdmin` | MATCH |
| costumes ↔ the_costume_shop / costume_remover | NoGuest (buy) / StaffOnly (remove) | buy is_guest-gate; remove `unless isEditor` | MATCH |
| giftshop ↔ e2_gift_shop | NoGuest | all ops is_guest-gate | MATCH |
| weblogmenu ↔ edit_weblog_menu | NoGuest | `around 'update_settings' => unauthorized_if_guest` | MATCH |
| recordings/podcasts ↔ RecordingEdit/PodcastEdit | NoGuest + ownership | is_guest-gate + ownership | MATCH |
| debatecomments ↔ DebatecommentEdit | usergroup membership / author / admin | membership\|\|author\|\|admin; delete=admin | MATCH |
| e2clients ↔ E2clientEdit | NoGuest + ownership | is_guest-gate + ownership | MATCH |
| suspension ↔ SuspensionInfo | editor (site) / chanop (chat) | scoped editor/chanop | MATCH |

**Structural finding:** guest-gating is frequently done via a base-class `around … => \&Everything::API::unauthorized_if_guest` modifier (preferences, weblogmenu, …) — a **de-facto declarative gate**. This validates the #4463 direction: the mechanism to unify already half-exists; #4463 generalizes it to a per-route `gate` naming any `Everything::Security::*` predicate.

**Read-only mixin Pages (no mutation twin): audit-clean by construction.** ~18 Pages carry a `NoGuest`/`StaffOnly` mixin and have no mutation API to reconcile (chatterlight*, silver_trinkets, everything_s_best/obscure_writeups, your_nodeshells/filled/insured, the_nodeshell_hopper, golden_trinkets, recalculated_users, topic_archive, news_archives, pit_of_abomination, manna_from_heaven, wharfinger_s_linebreaker, your_ignore_list, what_does_what, recent_node_notes). Their gate IS the mixin (dispatcher-enforced); any privileged SSR data they ship is governed by that mixin. No permission-parity work; if they read via an API, that's a #3768 consumption concern, not an authz mismatch.

### Permission audit: COMPLETE
2 real mismatches found + resolved (node_parameter tightened to admin; preferences non-200 + client consumption fixed), 1 intended (superbless grant_gp editor), 1 oracle-stale/actually-match (reputation). All remaining twins consistent. Non-200 returns catalogued into #3768.

---

## Part D — SSR-role sharing plan (ORM prep)

**Existing (the pattern):** `Everything::Roles::NodeTrackerStats`, `Everything::Roles::IPBlacklist` —
each `requires qw(DB APP)`, consumed by both the Page and the API twin via `with`. Replicate this shape.

**New-role candidates (Page+API share genuine SSR logic):**
- `Everything::Roles::Bestow` — websterbless / superbless / xp_superbless (+ AdminBestowTool)
- `Everything::Roles::NodeVars` — show_user_vars / viewvars / UserEditVars ↔ `nodevars`
- `Everything::Roles::Reparent` — magical_writeup_reparenter / e2node_reparenter ↔ `writeup_reparent`
- `Everything::Roles::Preferences` — settings ↔ preferences/nodelets/user
- `Everything::Roles::Borg` — the_borg_clinic ↔ borgclinic (+ nate_s_secret_unborg_doc unborg logic)

Each role: Node::-shaped interface (blessed accessors, no raw hashrefs), unit-tested, `requires DB/APP`.

---

## Proposed module order (risk-first)

1. **A5 mutation-leftover suspects** — read + confirm each is API-driven or migrate it (highest blast radius).
2. **Permission audit of the ~35 mixin Pages vs their API twins** — record mismatches; this is the
   safety-critical reconciliation, do it before routing churn moves code around.
3. **A1 route-recovery Pages** — fold into PageState (facade already exists + parity specs green).
4. **A2 pagination + A3 entity-select** — route through PageState, each backed by the Gap-C/D specs.
5. **A4 filter/display options** — same, lower risk.
6. **Extract Part-D roles** as each twin is touched — combined pass, not a separate sweep.

## Resolved
- **Role interface** = Node:: blessed-object (Jay 2026-07-05) — roles `requires` accessors, no raw hashrefs.
- **#4463 permission shape** (Jay 2026-07-06): APIs do **not** `:does` the mixin (they're per-route, not
  per-controller). One stateless `Everything::Security::*` predicate is the single source of truth; Page
  consumes via `:does`, API via a per-route `gate` key in its routes table. Object::Pad-native.
- **Audit model** (Jay 2026-07-06): the current controller permission is the **oracle**; the audit checks
  the API's implemented gate against it. Controller perms are the reference spec, not something we
  re-architect. MISMATCH = an API-side bug (the real boundary).

## Open questions
- Node-level permission bits (nodepack XML author/group/other) vs controller mixin, when they disagree:
  which is the oracle? (Working proposal: the controller mixin is authoritative for controller-backed
  pages; node bits only matter for nodes with no React controller. Confirm.)

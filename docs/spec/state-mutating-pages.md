# State-mutating Documents → API migration tracking

**Started:** 2026-06-27 (during the #4390 contentData-dedup sweep)
**Feeds:** roadmap step 2 (skinny controllers → APIs → React) and the React-routing flip.

## Why this list

As the #4390 sweep opens every Document's Perl + React, it's the cheapest moment to also note
whether the page **mutates server state** and, if so, whether that mutation already goes through
an `/api/...` endpoint or still pokes the legacy submit path. A page can't be cleanly
React-routed until its every mutating action is a React-driven API call (the destination from
[the_old_hooked_pole / everything_s_most_wanted, #4198]). So as I touch each page I drop a row
here; the ❌ rows become the work-list for the next API round.

Status legend: ✅ already API-driven · 🟡 mutates via API but React still does a full reload ·
❌ mutates via legacy form/submit, needs an API · — read-only (no mutation).

> ⚠️ **The table below is an incremental log; its ❌/✅ statuses are partially stale.** For the current,
> complete picture see **[Full GET-mutator audit (2026-06-29, #4416)](#full-get-mutator-audit-2026-06-29-4416)** further down.

| Page | Mutates? | What it changes | API status |
|---|---|---|---|
| the_costume_shop | yes | buy / change the viewer's Halloween costume (VARS->{costume}, GP) | ✅ `POST /api/costumes/buy` — already API-driven; React owns state |
| golden_trinkets | — | (read-only; admin lookup is a `method=GET` reload) | — n/a |
| feed_edb | yes | **on `numborgings` param**: writes viewer VARS (`numborged`/`borged`) via `setVars` **and** `$DB->sqlUpdate('room', {borgd=>…}, "member_user=$UID")` | ❌ **legacy param + raw SQL, no API.** Prime candidate — admin "borg" action should become `POST /api/…`. React still full-reload. |
| everything_poll_directory | yes | vote; (admin) set-current-poll, delete a voter's vote, delete/nuke a poll node | ✅ all via `/api/*` JSON: `POST /api/poll/vote`, `/api/poll/delete_vote`, `/api/polls/set_current`, `/api/polls/delete` (read `GET /api/polls/list`). ⚠️ namespacing split: `/api/poll/*` (single) vs `/api/polls/*` (directory) |

| bad_spellings_listing | — | (read-only setting dictionary view) | — n/a |
| create_room | yes | create a chatroom | ✅ `POST /api/chatroom/create_room` (`Everything::API::chatroom`) |
| list_nodes_of_type | yes | save the viewer's node-type listing preference | ✅ `POST /api/preferences/update` (read: `GET /api/list_nodes/list`) |
| news_archives | yes | (admin) unlink a weblog entry | ✅ `POST /api/usergrouppicks/unlink` |
| node_backup | yes | generate/download a node backup | ✅ `POST /api/nodebackup/create` |
| recalculate_xp | yes | (admin) recalc a user's XP→GP; look up another user's stats | ✅ `POST /api/xp/recalculate`, `POST /api/xp/stats` |
| reputation_graph | — | (read-only; `GET /api/reputation/votes`) | — n/a |
| spam_cannon | yes | (editor) send one /msg to many recipients | ✅ `POST /api/spamcannon` |
| my_big_writeup_list | — | (read-only; `<form method=get>` re-query) | — n/a |
| magical_writeup_reparenter | yes | (admin/editor) reparent writeups to a new e2node | ✅ `POST /api/writeup_reparent/reparent` |

| between_the_cracks | — | (read-only; `GET /api/betweenthecracks/search`) | — n/a |
| create_a_registry | yes | create a registry node (logged-in only) | ✅ `POST /api/node/create` |
| display_categories | — | (read-only; GET re-render for paging/filter) | — n/a |
| findings | yes | create a draft/e2node from a failed search (logged-in only, `!user.guest`-gated) | ✅ `POST /api/node/create` |
| random_nodeshells | — | (read-only) | — n/a |
| the_catwalk | yes | clear the viewer's `customstyle` ("clearVandalism") | ❌ **legacy `?clearVandalism` GET → `setVars`, no API** |
| theme_nirvana | yes | clear the viewer's `customstyle` ("clearVandalism") | ❌ **legacy `?clearVandalism` GET → `setVars`, no API** (same pattern as the_catwalk) |
| usergroup_discussions | yes | create a usergroup discussion; save the editor-mode pref | ✅ `POST /api/debatecomments/action/create`, `POST /api/preferences/set` |
| macro_faq | — | (read-only documentation page) | — n/a |

| everything_document_directory | yes | save the viewer's sort pref (`EDD_Sort`) | ❌ **side-effect in buildReactData** (POST param → `setVars`), no API (mild) |
| mark_all_discussions_as_read | yes | mark CE/admin debates read (`lastreaddebate`) | ❌ **side-effect in buildReactData** (GET `?mark_*_read` → `sqlUpdate`/`sqlInsert`), no API |
| settings | yes | save all user settings / prefs / profile | ✅ `/api/preferences/*`, `/api/user/edit`, `/api/nodelets` |
| show_user_vars | — | (read-only inspection; admin GET lookup) | — n/a |
| simple_usergroup_editor | yes | add/remove usergroup members | ❌ **side-effect in buildReactData** (self-POST → `group_add`/`group_remove`), no API |
| the_oracle | yes | (admin) set a **target** user's var | ❌ **side-effect in buildReactData** (GET params → `setVars` on another user), no API |
| usergroup_message_archive | yes | copy group msgs to self; toggle resettime pref | ❌ **side-effect in buildReactData** (params → `sqlInsert` message / `setVars`), no API |
| e2_bouncer | yes | (chanop) move users out of a room | ✅ `POST /api/bouncer` |
| e2_gift_shop | yes | buy/give votes/ching/tokens/eggs; set topic; star | ✅ `/api/giftshop/*` (9 endpoints) |
| drafts_for_review | — | (read-only editor review queue) | — n/a |

| create_category | yes | create a category (logged-in) | ✅ `POST /api/category/create` |
| drafts / e2_editor_beta | yes | draft CRUD + autosave + editor pref | ✅ `/api/drafts/*`, `/api/autosave`, `/api/preferences/set` |
| my_recent_writeups / who_is_doing_what / what_does_what / list_nodes_of_type | — | (read-only; list_nodes saves a sort pref via `/api/preferences/update`) | — n/a |
| node_forbiddance | yes | (admin) forbid/unforbid a node | ❌ **side-effect in buildReactData** (GET `?forbid`/`?unforbid` → `sqlInsert`/`sqlDelete` on `nodelock`) |
| renunciation_chainsaw | yes | (admin) reparent writeups to another user | ❌ **side-effect in buildReactData** (self-POST → `updateNode` author + `setVars` numwriteups) |
| the_old_hooked_pole | yes | (editor) bulk user cleanup | ✅ `POST /api/admin/users/cleanup` |
| usergroup_picks | yes | (admin) unlink a weblog entry | ✅ `POST /api/usergrouppicks/unlink` |
| nothing_found | yes | create a draft/e2node from a no-results search (logged-in) | ✅ `POST /api/node/create` |

<!-- append one row per Document as the #4390 sweep reaches it -->

## API-candidate backlog (mutating, not yet API)

- **feed_edb** — the admin "simulate being borged by EDB" tool mutates via the legacy `?numborgings=N` query param processed *inside* `buildReactData` (`setVars` numborged/borged + raw `sqlUpdate room.borgd`). **Decision 2026-06-27: build the API, keep the feature** — it's a fun/legacy admin toy with negligible cost, and E2 keeps that functionality when it's performance-free (not a delete candidate). Target: `POST /api/feed_edb/borg` driven by the React component, with `buildReactData` becoming pure-render — the the_costume_shop pattern. **✅ DONE this session** — `POST /api/feed_edb/borg` + pure-render page + tests (`t/171`, FeedEdb interaction).
- **the_catwalk** + **theme_nirvana** — both clear the viewer's `customstyle` via a legacy `?clearVandalism=true` GET that `setVars`-deletes the style inside `buildReactData`. **Shared pattern → one small API** (a customstyle/clear endpoint) could serve both, then both pages go pure-render. Low priority; a clean 2-for-1.

### Side-effect-in-buildReactData cluster — the core step-2 target

> ⚠️ The status column in the table above is an incremental log and is partially stale.
> **The "Full GET-mutator audit" below (2026-06-29, #4416) is the current source of truth.**

These mutate server state **inside the page controller on render**, driven by GET/POST params. A
page can't be cleanly React-routed while *rendering it writes to the DB*. Each wants a small
`POST /api/…` so `buildReactData` becomes pure-render. The original 7-page cluster is **done**:

- ✅ **the_catwalk** + **theme_nirvana** — `?clearVandalism` → `POST /api/customstyle/clear` (#4401)
- ✅ **feed_edb** — `?numborgings` → `POST /api/feed_edb/borg`
- ✅ **simple_usergroup_editor** — self-POST → `/api/usergroups/:id/action/{adduser,removeuser}` (#4412)
- ✅ **the_oracle** — admin GET → `POST /api/oracle/setvar` (#4405)
- ✅ **mark_all_discussions_as_read** — `?mark_*_read` → `POST /api/markdiscussionsread` (#4410)
- ✅ **node_forbiddance** — `?forbid`/`?unforbid` → `POST /api/nodeforbiddance/{forbid,unforbid}` (#4408)
- ✅ **renunciation_chainsaw** — reparent → `POST /api/renunciation/{transfer,nodes}` (#4414)

## Full GET-mutator audit (2026-06-29, #4416)

Grep + per-page read of **every** `Everything::Page::*` reading request params (`$REQUEST->param`/`->cgi`):
**109 read params · 17 write on a plain GET (unguarded — no POST gate, crawler-reachable) · 0 POST-gated · 92 read-only.**
Migration pattern: write → POST `Everything::API::*`; page → pure-render; React owns the param + drives the API.

**❌ No in-code role gate** (access may still be limited by superdoc *type* — verify per page; larger blast radius, prioritize):

| Page | Writes on GET |
|---|---|
| **usergroup_message_archive** | `sqlInsert` (copy msg to inbox) + `setVars` (ugma_resettime) — *#4416, in progress* |
| confirm_password | `nukeNode` (unactivated acct on expired link) |
| e2_penny_jar | `adjustGP` / `setVars` / `updateNode` (GP transfer) |
| faq_editor | `sqlInsert`/`sqlUpdate` FAQ |
| node_tracker | `sqlInsert`/`sqlUpdate` tracking stats |
| notelet_editor | `setVars` (notelet HTML widget) |

**❌ Admin-gated** (lower blast radius, still mutate on render):
`ip_blacklist`, `mass_ip_blacklister`, `nodetype_changer`, `sql_prompt`, `style_defacer`, `the_borg_clinic`,
`the_oracle_classic`, `the_tokenator`, `websterbless`,
`list_nodes_of_type` ⚠️(*already has `/api/preferences/update`, but the audit still finds a render-time `setvars_*`→`setVars` — verify/remove the residual GET path*),
**`everything_document_directory`** (*#4416, in progress*).

> `everything_document_directory` persists `EDD_Sort` via an **in-memory `$VARS->{EDD_Sort}=`** (framework
> write-back, **not** `setVars()`) — evades a `setVars` grep + a quick read; verified by inspection. Grep for
> `$VARS->{x}=` too, not just `setVars`. (Only this one page used the pattern among the 109.)

**UI-pref-persist-on-GET sub-pattern (6):** `list_nodes_of_type`, `sql_prompt`, `style_defacer`,
`the_borg_clinic`, `the_oracle_classic`, `everything_document_directory` persist a user VARS pref from a GET
param. **Decision needed:** a generic `POST /api/userpref/:key` setvar vs per-page endpoints
(`the_oracle` chose a *dedicated* endpoint).

**Read-only view params (92) — NOT this thread (React-routing epoch, step 3):** XML/Atom tickers (14),
pagination/sort/filter views (42), single-record/user views (36). Read params purely to shape the view (no
write). The strict end-state ("page reads no params; the React router owns them") is the React-routing
migration, surfaced here but tracked there.

**Non-Page query-param readers:**
- *Legit / framework* (params belong here): `Request.pm` (request abstraction), `HTML.pm` (URL→route
  dispatcher, 47), `PageState.pm`, `Controller/*` (displaytype/unlock), `Form/*` (CSRF field-hashing).
- *Surface:* `Application.pm` — `op eq 'login'/'vote'/'cool'` **legacy opcode strings** in the model layer,
  should be dead post-#4335 (cleanup). `Delegation/maintenance.pm` — **16** form-param reads
  (`writeup_doctext`, `debatecomment_*`, `draft_publication_status`…) = the **maintenance-restructure
  blocker** (htmlcode nodetype can't retire until maintenance moves).

### Related latent bug (not a mutation, but found in the same sweep)
`$APP->isGuest($USER)` (and `isAdmin`/`isEditor`) mis-called with the **blessed** `$USER` object instead of `$USER->NODEDATA` / the `$USER->is_guest` method — silently returns false for guests/admins. **Fixed: `random_nodeshells` (#4397), `clientdev_home` (isGuest+isAdmin) + `noding_speedometer` (#4397).** Audited the rest: `welcome_to_everything`, `e2_penny_jar`, and all the xml_tickers correctly pass `->NODEDATA` (not buggy). So the latent class is now closed for known cases; the blessed-arg call is the anti-pattern to watch in new code.

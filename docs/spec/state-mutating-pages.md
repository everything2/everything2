# State-mutating Documents → API migration tracking

**Started:** 2026-06-27 (during the #4390 contentData-dedup sweep)
**Last verified: 2026-11-16** (grep of `ecore/Everything/Page/*.pm` for `setVars`/`sqlInsert`/`sqlUpdate`/`sqlDelete`/`nukeNode`/`adjustGP`/`updateNode`/`insertNode`/`group_add`/`group_remove` and in-memory `$VARS->{x} =` writes)
**Feeds:** roadmap step 2 (skinny controllers → APIs → React) and the React-routing flip.

## Why this list

A page can't be cleanly React-routed until every mutating action it offers is a React-driven
`POST /api/...` call and its controller is pure-render (the pattern from the_old_hooked_pole /
everything_s_most_wanted, #4198). This file tracks which Documents mutate state and how.

Status legend: ✅ API-driven · — read-only (no mutation).

## Current state (2026-11-16)

The render-time mutation thread is **closed**. The #4416 audit (2026-06-29) found 17 Pages that wrote
state while rendering; all were moved to APIs between #4416 and #4481 (e.g. `ip_blacklist` #4464,
`node_tracker` #4458, `nodetype_changer` #4461, `faq_editor` #4469, unborg #4468, usergroup message
archive #4472, `confirm_password` + stragglers #4479). Since then many Documents have gone further and
become **pure gates**: no `Everything::Page::*` module at all, just an entry in
`ecore/Everything/PureGates.pm` (served by `Everything::PureGatePage`, #4513), with React + an API owning
everything.

Remaining write calls in `Everything::Page::*` (both intentional framework/display side effects, not user actions):

| Page | Write | Notes |
|---|---|---|
| `personal_session_xml_ticker` | `sqlUpdate room.borgd` + `$VARS` borg fields | Inline borg-expiry check (same logic as `Everything::Application` borg expiry). Candidate to call the Application method instead of inlining. |
| `guest_front_page` | in-memory `$VARS->{nodelets}` | Seeds guest nodelet list for chrome generation; not a user mutation. |

Param readers: 60 of 175 `Everything::Page::*` modules still read request params (11 are XML tickers);
none of them write. Moving those params into React is the "no params in controllers" goal, tracked under
the React-routing epoch rather than here.

**Non-Page param readers** (expected): `Request.pm` (request abstraction), `HTML.pm` (URL→route
dispatch), `PageState.pm`, `Controller/*` (displaytype etc.), `Form/*` (CSRF field hashing).
`Everything::Delegation::maintenance` still reads ~18 form params (`writeup_doctext`, `debatecomment_*`,
`draft_publication_status`, …) — the maintenance-restructure blocker for retiring the htmlcode nodetype.
The legacy `op eq ...` strings formerly in `Application.pm` are gone (opcode removal, #4335).

## Per-page log (historical, from the #4390 sweep)

Statuses below are updated to 2026-11-16; all mutating rows are now API-driven.

| Page | Mutates? | What it changes | API |
|---|---|---|---|
| the_costume_shop | yes | buy / change Halloween costume | ✅ `POST /api/costumes/buy` |
| golden_trinkets | — | read-only | — |
| feed_edb | yes | admin "borg" toy | ✅ `POST /api/feed_edb/borg` |
| everything_poll_directory | yes | vote; admin poll management | ✅ `/api/poll/*` (single) + `/api/polls/*` (directory) |
| bad_spellings_listing | — | read-only | — |
| create_room | yes | create a chatroom | ✅ `POST /api/chatroom/create_room` |
| list_nodes_of_type | yes | node-type listing pref | ✅ `POST /api/preferences/update` |
| news_archives / usergroup_picks | yes | unlink a weblog entry | ✅ `POST /api/usergrouppicks/unlink` |
| node_backup | yes | generate a node backup | ✅ `POST /api/nodebackup/create` |
| recalculate_xp | yes | recalc XP→GP; stats lookup | ✅ `POST /api/xp/recalculate`, `/api/xp/stats` |
| reputation_graph | — | read-only (pure gate) | — |
| spam_cannon | yes | one /msg to many recipients | ✅ `POST /api/spamcannon` |
| magical_writeup_reparenter | yes | reparent writeups | ✅ `POST /api/writeup_reparent/reparent` |
| create_a_registry / findings / nothing_found | yes | create a node | ✅ `POST /api/node/create` |
| the_catwalk / theme_nirvana | yes | clear `customstyle` | ✅ `POST /api/customstyle/clear` (#4401) |
| usergroup_discussions | yes | create discussion; editor pref | ✅ `/api/debatecomments/action/create`, `/api/preferences/set` |
| everything_document_directory | yes | sort pref (`EDD_Sort`) | ✅ `/api/preferences/set`; listing via API (#4557) |
| mark_all_discussions_as_read | yes | `lastreaddebate` | ✅ `POST /api/markdiscussionsread` (#4410) |
| settings | yes | user settings / prefs / profile | ✅ `/api/preferences/*`, `/api/user/edit`, `/api/nodelets` |
| simple_usergroup_editor | yes | add/remove members | ✅ `/api/usergroups/:id/action/{adduser,removeuser}` (#4412) |
| the_oracle | yes | set a user var | ✅ `POST /api/oracle/setvar` (#4405) |
| usergroup_message_archive | yes | copy msgs; resettime pref | ✅ API (#4472) |
| e2_bouncer | yes | move users between rooms | ✅ `POST /api/bouncer` |
| e2_gift_shop | yes | gifts / topic / star | ✅ `/api/giftshop/*` |
| create_category | yes | create a category | ✅ `POST /api/category/create` |
| drafts / e2_editor_beta | yes | draft CRUD + autosave | ✅ `/api/drafts/*`, `/api/autosave`, `/api/preferences/set` |
| node_forbiddance | yes | forbid/unforbid a node | ✅ `/api/nodeforbiddance/{forbid,unforbid}` (#4408) |
| renunciation_chainsaw | yes | reparent writeups to another user | ✅ `/api/renunciation/{transfer,nodes}` (#4414) |
| the_old_hooked_pole | yes | bulk user cleanup | ✅ `POST /api/admin/users/cleanup` |

Open design question carried from the audit: generic `POST /api/userpref/:key` vs per-page endpoints for
UI-preference persistence (current practice: `/api/preferences/set` for prefs, dedicated endpoints for
tool actions).

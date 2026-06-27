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

<!-- append one row per Document as the #4390 sweep reaches it -->

## API-candidate backlog (mutating, not yet API)

- **feed_edb** — the admin "simulate being borged by EDB" tool mutates via the legacy `?numborgings=N` query param processed *inside* `buildReactData` (`setVars` numborged/borged + raw `sqlUpdate room.borgd`). **Decision 2026-06-27: build the API, keep the feature** — it's a fun/legacy admin toy with negligible cost, and E2 keeps that functionality when it's performance-free (not a delete candidate). Target: `POST /api/feed_edb/borg` driven by the React component, with `buildReactData` becoming pure-render — the the_costume_shop pattern. *(in progress)*

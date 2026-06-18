# Opcode retirement audit (#4266 → #4198)

Auditing `Everything::Delegation::opcode` — the legacy `op=…` CGI action dispatch
(HTML.pm:1258 dispatches `$query->param('op')` → `Everything::Delegation::opcode->can($op)`).
Started at 44 `sub` handlers; **8 remain live** as of 2026-06-15 (see "Live opcodes" below).
Verdict per handler was **reachable / dead / superseded-by-API**: dead + superseded were removed,
still-needed actions migrate to `POST /api/…` under #4198.

The rounds below are kept as a historical record of what was retired. The prod node-nuke checklists
from those rounds are **done** — they have been dropped here to avoid re-running completed cleanups.

## Removed (deep-scrubbed, this change)

Each verified: API does the action, the API is wired in React, and the opcode is dispatched from
**nowhere** (no `op=` form/link, no nodepack template, no internal caller; the only literal hits were
a stale comment + query-string *parse* test data in t/122).

| opcode | superseded by | React wiring | nodepack node (→ nuke from prod) |
|---|---|---|---|
| `vote` | `API::vote` (`cast_vote`) | BlindVotingBooth, WriteupDisplay | **444189** |
| `cool` | `API::cool` (`award_cool`) | WriteupDisplay, PageActions, EditorCoolButton, BookmarkButton | **447476** |
| `sanctify` | `API::sanctify` (`give`) | SanctifyUser | **1960821** |
| `resurrect` | `API::resurrect` (`resurrect_node`, uses `$DB->resurrectNode`) | DrNatesSecretLab | **754045** |

Dead-but-harmless follow-up (NOT touched here, it's a Page not an opcode):
`Everything/Page/blind_voting_booth.pm:46` still has an `if ($op eq 'vote' && $votedon)` post-vote
branch. The React component (`BlindVotingBooth.js`) casts via `API::vote` then `reload()`s — it never
sets `op=vote` — so that branch never triggers now. Safe to delete in a later Page-cleanup pass.

Removing `resurrect` also orphaned its only-callers helper htmlcodes **`resurrectNode`** +
**`reinsertCorpse`** (the API uses the NodeBase `$DB->resurrectNode` method, not these htmlcodes) —
both removed here. They had no nodepack node (internal helpers).

## Removed — phase 2 (#4269)

Same bar as phase 1: superseded by a React-wired API, dispatched from nowhere (no `op=` in
`react/`/`nodepack/`, no `ecore/` caller, no template/test reference).

| opcode | superseded by | React wiring | nodepack node (→ nuke from prod) |
|---|---|---|---|
| `favorite` | `API::favorites` (`favorite`) | UserDisplay, FavoriteUsersManager | **1930913** |
| `unfavorite` | `API::favorites` (`unfavorite`) | UserDisplay, FavoriteUsersManager | **1930914** |
| `hidewriteup` | `API::hidewriteups` (`hide_writeup`) | AdminModal | **1216701** |
| `unhidewriteup` | `API::hidewriteups` (`show_writeup`) | AdminModal | **1217041** |
| `nodenote` | `API::nodenotes` (`add_note`) | WriteupDisplay, MasterControl/NodeNotes | **1180774** |
| `ilikeit` | `API::ilikeit` (`like_writeup`) | ILikeItButton | **1920135** |

`nodenote`/`hidewriteup`/`unhidewriteup` called `htmlcode('addNodenote')`, which is **kept** — it has
other live callers (`the_old_hooked_pole`, `maintenance`, `htmlcode`) and the nodenotes API uses its
own `sqlInsert`. No orphan.

## Removed — phase 3 (#4271)

Same bar; the **hidden-form-field** sweep is what makes this the confirmed-clean subset (it caught
`changeusergroup` still wired in `UsergroupWriteups.js`, which stays for migration).

| opcode | superseded by | React wiring | nodepack node (→ nuke from prod) |
|---|---|---|---|
| `bless` | `API::superbless` (`grant_gp`/`grant_xp`) | AdminBestowTool | **444704** |
| `curse` | `API::superbless` | AdminBestowTool | **444709** |
| `bestow` | `API::superbless` | AdminBestowTool | **444712** |
| `parameter` | `API::node_parameter` | NodeParameterEditor | **2071202** |
| `pollvote` | `API::poll` (`submit_vote`) | CurrentUserPoll, EverythingPollDirectory | **1685363** |

`bless` called `htmlcode('sendPrivateMessage')`, **kept** — core PM helper, 11 other callers. No orphan.

## Removed — phase 4 (#4291)

Same bar; each verified superseded by a React-wired API, 0 `op=` dispatch, no `getNode(<name>,'opcode')`
key usage, no real test ref. Name collisions (`weblog`/`category` also exist as linktype/notification/
setting nodes used by the APIs) are harmless — only the **opcode**-type nodes were removed.

| opcode | superseded by | React wiring | nodepack node (→ nuke from prod) |
|---|---|---|---|
| `weblog` | `API::weblog` (`add_entry`/`remove_entry`) | AddToWeblogModal, Weblog | **458215** |
| `weblogify` | `API::usergroups` (`weblogify` action) | Usergroup.js | **1882499** |
| `category` | `API::category` (`add_member`/`remove_member`) | AddToCategoryModal, CategoryEdit | **1935812** |

`bookmark` was pulled from this batch: its API (`toggle_bookmark`) lacks parity with the legacy
opcode's notification behavior (e2node → all writeup authors; correct `no_bookmarkinformer` /
`no_bookmarknotification` opt-outs; structured notification). Tracked in **#4292** — fix the API, then
remove the opcode (node **419552**).

## Removed — round 5 (#4299)

1:1-validated dead opcodes (0 `op=` dispatch; functionality covered by a React-wired API or already a stub).

| opcode | superseded by | nodepack node (→ nuke from prod) |
|---|---|---|
| `massacre` | dead stub; no longer a securityLog token (caller uses `SECLOG_MASSACRE` after #4272 conversion). Also removed the dead `my $mass = getNode('massacre','opcode')` in `htmlcode::unpublishwriteup`. | **648516** |
| `leadusergroup` | `API::usergroups` `transfer_ownership` (UsergroupEditor.js / Usergroup.js) | **1887815** |

Deferred (undispatched but parity NOT clean — see #4299): `message` (chatterbox slash-commands),
`message_outbox` (outbox archive coverage), `approve_draft` (food-flag vs publication_status),
`publishdraft` (core publishing), `publishdrafttodocument` (no API), `social` (dead-but-infra).

## Removed — round 6 (#4303): bucket-2 node-tools/admin (12)

All undispatched, 0 `getNode(...,'opcode')` callers, each 1:1-superseded by a named React-wired API
(the node-tools/admin actions migrated to `API::e2node` / `API::admin` via E2NodeToolsModal /
UserToolsModal, plus `API::preferences` / `API::user`).

| opcode | node | superseded by |
|---|---|---|
| `lockaccount` 1203049 / `unlockaccount` 1203054 / `insure` 1179550 / `borg` 1307637 | | `API::admin` (lock_user/unlock_user/insure_writeup/user-borg) |
| `firmlink` 1150387 / `repair_e2node` 1298189 / `repair_e2node_noreorder` 1466148 / `orderlock` 1466528 / `softlock` 1876426 / `linktrim` 977694 | | `API::e2node` (create_firmlink/repair_node/toggle_orderlock/node_lock/remove_firmlink+manage_softlinks) |
| `changewucount` 1217094 | | `API::preferences` (nw_nojunk + nodelet settings) |
| `cure_infection` 2034111 | | `API::user` (POST /api/user/cure). Infection feature stays live; only the dead opcode removed. |

**Deferred (need a decision/API first):** `lockroom` (legacy room `criteria` toggle vs the current
`roomlocked` path), `flushcbox` (chanop chatterbox flush — **no API equivalent**).

## Removed — round 7 (bucket-3 gating migrations)

The three "still genuinely wired, need a new API" opcodes are now done — each got its API and the
opcode was retired:

| opcode | shipped in | superseded by |
|---|---|---|
| `remove` | **#4306** | bulk-remove API (AltarOfSacrifice delete form → API) |
| `removeweblog` | **#4310** | weblog API (NodeRow.js link → API) |
| `changeusergroup` | **#4312** | usergroups API (`UsergroupWriteups.js` form field → API) |

## Live opcodes — the remaining 8 (as of 2026-06-15)

These are the only handlers left in `opcode.pm`. Each needs a parity step before it can retire under
#4198:

| opcode | what it needs before retirement |
|---|---|
| `message` | messaging parity (chatterbox slash-commands) before the messages API can replace it |
| `message_outbox` | messaging parity (outbox archive coverage) |
| `lockroom` | room `criteria` toggle migrated onto the current `roomlocked` path |
| `flushcbox` | needs an API home — no equivalent exists yet (chanop chatterbox flush) |
| `socialBookmark` | feature-retire decision — not API-superseded; dead-but-with-lingering-infra (notification.pm `socialbookmark`, settings prefs, writeup.pm hooks) |
| `publishdraft` | drafts-API parity — core publishing; parity work tracked in **#4314** |
| `publishdrafttodocument` | drafts-API parity (no API equivalent yet) |
| `approve_draft` | drafts-API parity (food-flag vs publication_status) |

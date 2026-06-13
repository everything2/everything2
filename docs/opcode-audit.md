# Opcode retirement audit (#4266, phase 1)

Auditing `Everything::Delegation::opcode` (44 `sub` handlers — the legacy `op=…` CGI action
dispatch; HTML.pm:1258 dispatches `$query->param('op')` → `Everything::Delegation::opcode->can($op)`).
Verdict per handler: **reachable / dead / superseded-by-API**. Phase 1 removes the dead + superseded;
phase 2 (#4198) migrates the still-needed actions to `POST /api/…`.

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
both removed here. They had no nodepack node (internal helpers); verify none lingers in prod.

### PENDING prod cleanup (after this deploys)
Nuke the 4 orphaned `opcode` nodes from prod (nodepack delete only affects fresh builds): **444189,
447476, 1960821, 754045**. Confirm each is an `opcode` type with no inbound links first. Also check
prod for any `resurrectNode`/`reinsertCorpse` htmlcode node and nuke if present.

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

### PENDING prod cleanup (after this deploys)
Nuke the 6 orphaned `opcode` nodes: **1930913, 1930914, 1216701, 1217041, 1180774, 1920135**.

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

### PENDING prod cleanup (after this deploys)
Nuke the 5 orphaned `opcode` nodes: **444704, 444709, 444712, 2071202, 1685363**.

## Remaining 29 — first-pass classification (continue here)

- **Superseded by an existing API + 0 `op=` refs → remove candidates** (confirm the API fully
  replaces each, then delete): `bookmark`, `message`/`message_outbox` (→messages),
  `weblog`/`weblogify` (→weblog), `category`,
  `publishdraft`/`publishdrafttodocument`/`approve_draft` (→drafts),
  `leadusergroup` (→usergroups, but verify — its sibling `changeusergroup` is still wired),
  `socialBookmark`.
  *(phase 2 removed: `favorite`/`unfavorite`, `hidewriteup`/`unhidewriteup`, `nodenote`, `ilikeit`.
  phase 3 removed: `bless`/`curse`/`bestow`, `parameter`, `pollvote`.)*
- **Admin/maintenance, no API + no `op=` ref → reachability check** (likely dead or admin-tool wired):
  `massacre`, `lockroom`, `linktrim`, `firmlink`, `lockaccount`/`unlockaccount`, `changewucount`,
  `repair_e2node`/`repair_e2node_noreorder`, `borg`, `flushcbox`, `orderlock`, `softlock`,
  `cure_infection`, `insure`.
- **Still genuinely wired → migrate before removal (#4198)**: `removeweblog` (React link
  `op=removeweblog` in NodeRow.js → should use the weblog API), `remove` (AltarOfSacrifice delete form
  → needs a delete API), `changeusergroup` (hidden form field in `UsergroupWriteups.js:73` → needs the
  usergroups API), plus the other live form/link ops surfaced by the dispatch scan: `collaboration`,
  `debate`, `draft`, `e2client`, `edit`, `new`, `useredit`, `nuke`, `logout`, `randomnode`.

# PageState key tiers — data-dependency classification

**Status:** working spec for the chrome/content cache split (#4257); de-duplication home **#3981** (which also owns the React-side `is_admin`-vs-`e2.user.admin` dedup).
**Method:** every key in the `e2` blob classified by *what its value actually depends on*, not by the legacy `@CHROME_KEYS`/`@CONTENT_KEYS` cut (which was "page frame vs node content" and is wrong on ~6 keys — see Misclassifications).

## The four tiers

| Tier | Depends on | Cache scope | Invalidation |
|---|---|---|---|
| **build-constant** | the deployed build only | bake into the JS bundle / one static config | on deploy |
| **global** | global site state | **one** site-wide entry, read by 100% of requests; edge-cacheable | feed TTL (~2 min) |
| **per-user** | the viewing user | per-user; **guests collapse to one shared Guest-User entry** (the 99%) | on that user's msg/notif/pref/group change |
| **per-node** | the viewed node | per-node (`/api/nodes/:id`) or built fresh | on node edit |

The whole point: **a key's tier is the cache it belongs in.** `@CHROME_KEYS` fuses build-constant + global + per-user into one guest blob — which only works because all guests are one identity, and which re-derives the global tier per-request for logged-in users.

## Classification (≈45 keys)

### build-constant — set once at startup from `$conf`; belongs in the shell/bundle, not the per-request blob
| key | source | consumer → relocation |
|---|---|---|
| `lastCommit` | `$conf->last_commit` (`/etc/everything/last_commit`) | **is** the JS asset-path SHA — already lives in the HTML shell (it's where the JS is loaded from). Only re-surfaced as a key for `masterControl`'s "did it land?" check → derive it from the embedded asset path, no separate blob key |
| `architecture` | `$conf->architecture` | developer-nodelet only (was the aarch64-transition visual aid) → low-value; fold into the dev nodelet's own source or drop |
| `assets_location`, `use_local_assets` | `$conf->*` | asset-base config → belongs in the shell |
| `recaptcha` | `_build_recaptcha` (config site key) | guest signup modal; guest-gated → static/shell config |

> `lastCommit` and `architecture` aren't dropped outright — their *value* relocates: `lastCommit` to the asset path it already drives (read it back from there for Master Control), `architecture` into the developer nodelet that's its only consumer. Neither needs to be a top-level per-request key.

### global — one site-wide cache, read by every request
| key | source | notes |
|---|---|---|
| `news` | `_build_news($DB)` | |
| `statistics` | `_build_statistics` | |
| `recentNodes` | `_build_recentNodes` (stash) | |
| `randomNodes` | `_build_stash` | |
| `daylogLinks` | `_build_stash` | |
| `neglectedDrafts` | `_build_stash("neglecteddrafts")` | |
| `currentPoll` | `_build_currentPoll` | |
| `bounties` | `_build_bounties` | code marks AMBIGUOUS; data is global |
| `coolnodes` | assembler loop `foreach qw/coolnodes staffpicks/` → `stashData` (~7809) | global; **also re-queried by front-page controllers** → dup (see audit) |
| `staffpicks` | same loop | same |
| `newWriteups` | `filtered_newwriteups($USER)` | **hybrid**: global recent-writeups *list* + per-user hide-filter |

### per-user — per-user; guests = one shared Guest-User entry
| key | source | notes |
|---|---|---|
| `guest` | `isGuest` | |
| `user` | `_build_user($app,$USER,$VARS)` | identity + role flags + (logged-in) gp/xp/level/votes |
| `currentUserId` | `$USER->node_id` | |
| `display_prefs` | user VARS | |
| `noquickvote` `nonodeletcollapser` `hasMessagesNodelet` `developerNodelet` | user VARS/flags | |
| `messagesData` | `get_messages($USER)` | empty for guests |
| `notificationsData` | `buildNotificationsData($USER)` | empty for guests |
| `personalLinks` | `_build_personalLinks` | |
| `favoriteWriteups` | `_build_favoriteWriteups` | |
| `epicenter` | `_build_epicenter` | user control nodelet |
| `forReviewData` | `buildForReviewData($USER)` | per-role (editors); empty otherwise |
| `otherUsersData` | `buildOtherUsersData($USER)` | code marks AMBIGUOUS; **set twice in the husk (8060 + 8153)** — dedup |
| `chatterbox` | inline `$e2->{chatterbox}->{...}` | **hybrid**: room (per-room; `'outside'` for guests = global-for-guests) + miniMessages/borged (per-user) |
| `masterControl` | `_build_masterControl` | ⚠ **really per-node + role-gate**, not chrome — see Misclassifications |

### per-node — fresh per request / node-cache
| key | source | notes |
|---|---|---|
| `node_id` `title` `nodetype` | `$NODE` | |
| `node` | node stub `{title,type,node_id,createtime,can_bookmark}` | **duplicates** node_id/title/nodetype |
| `currentNodeId` `currentNodeTitle` | `$NODE` | **duplicates** node_id/title |
| `contentData` | Page-class `buildReactData` | document/Page types only |
| `nodeCategories` | per-node | |
| `usergroupData` | per-node (viewed usergroup) | |
| `noteletData` | per-node | |
| `pageheader` | `buildPageheaderData($NODE)` | ⚠ declared CHROME, is per-node |
| `quickRefSearchTerm` | `$NODE->{title}` / search query | ⚠ declared CHROME, is per-node |
| `reactPageMode` | `\1` iff document-type | ⚠ declared CHROME; **≡ `contentData != null`** — redundant, delete candidate |

## Misclassifications in `@CHROME_KEYS` (the keys that "lie")
These sit in the cacheable-chrome partition but are **not node-invariant**, so caching them generically serves the wrong page's value. Latent today only because the guest stash builds with `node => guest_node` and these are empty/overridden on the node-API render path — but they **break the moment we cache chrome for document types** (the front page):

- `pageheader` — `buildPageheaderData($NODE)` → per-node
- `quickRefSearchTerm` — `$NODE->{title}` → per-node
- `reactPageMode` — node-type-derived, always `\1` when present → **redundant** with `contentData`
- `masterControl` — per-node data (node notes / nuke toolset / admin-search-for-this-node) under a per-role gate → per-node, not chrome

(`coolnodes`/`staffpicks` are correctly global — the assembler sets them via a `foreach` loop my first grep missed — but the front-page controllers re-query them; that's duplication, not misclassification. See the audit.)

## Redundancies / dedup candidates
- **Node identity duplicated 8×+**: `node_id`/`title`/`nodetype` appear top-level, in `node`, in `currentNodeId`/`currentNodeTitle`, and **4× inside `masterControl`** (adminSearchForm, ceSection, nodeNotesData, nodeToolsetData). → one canonical node-context object, referenced.
- **`reactPageMode` ≡ `contentData` presence** → eliminate the flag; client derives it.
- **`otherUsersData` built twice** in `buildNodeInfoStructure` (lines 8060 + 8153) → compute once.
- **`newWriteups` = global list + per-user filter** → cache the list globally, apply the cheap filter per-user.
- **`coolnodes`/`staffpicks` ownership** → assembler should own them as global, or reclassify as per-page content; today controllers re-populate them.

## Cache-architecture implication
- **build-constant** → bundle/static; drop from the per-request blob entirely.
- **global** → one shared cache (the feed assembly — a dozen queries — eliminated for 100% of traffic, guest *and* logged-in; edge-cacheable).
- **per-user** → thin per-user layer; guests = one shared entry (the easy 99%), logged-in = per-user invalidation (the hard 1%, deferrable).
- **per-node** → `/api/nodes/:id` / document endpoint, as the routing endgame already targets.

## Client-router fetch policy — the consumer-side dedup that PRESERVES first paint

The consumer-side dedup is **not** "remove the key and let the component fetch on mount." That regresses first paint to paint-then-fetch (e.g. the `<Messages>` nodelet flashing empty) in exchange for pure server-side tidiness — rejected. The lever is the **SPA router reusing chrome across client navigations**:

- **Initial load (SSR):** ship the full blob → first paint with zero client fetches. `messagesData` stays as the seed for the self-fetching `<Messages>` component (its own `/api/messages` refresh owns staleness); `notificationsData` is the same shape.
- **Client navigation:** the navigation fetch is **content only** (`/api/nodes/:id`). Chrome is never part of a navigation fetch — it's seeded once at SSR and each chrome surface stays **live via its own API**: `<Messages>` → `/api/messages`, notifications → `/api/notifications`, global feeds → their tickers/TTL. Chrome isn't a snapshot the router invalidates; it's independently-live components the navigation simply doesn't re-request.

This is the react-routing epoch's "SSR first paint, client-route subsequent nav," and it's the convergence #4257 names: **initial = pagestate + node; nav = node only**. The tier table above is the contract: `per-node` = the navigation payload; everything else = seeded at SSR, self-updating via its own API, never re-fetched on nav.

> **Decision (2026-06-27):** chrome reuse over per-key removal. Keep SSR seeds (no paint-then-fetch). On successive navigations the pagestate fetch carries **node content only**; every chrome surface updates through its own dedicated API, not through navigation. The pagestate API thus has a content-only nav mode distinct from #4257's chrome-only `?lite=1` build mode.

## Controller key-duplication audit

Cross-controller sweep (Page/Controller/API). **No `Controller/*.pm` writes the blob directly** — they delegate. The duplication is two kinds, and the distinction drives priority:

### A. In-request duplication — same data built twice in ONE request (real waste)

**Front page (the 99%-traffic case).** `welcome_to_everything.pm` (superdocnolinks, node 124) and `guest_front_page.pm` (fullpage, node 2030780) run their `buildReactData` in the *same request* as `buildNodeInfoStructure`, and re-query chrome data the blob already assembled:
| data | blob assembles | controller re-queries |
|---|---|---|
| `coolnodes`, `staffpicks` | loop @ ~7809 | `welcome_to_everything.pm:41,60` |
| `news` (`frontpagenews`) | `_build_news` @ 7838 (reads `stashData("frontpagenews")`) | `welcome_to_everything.pm:116`, `guest_front_page.pm:127` |
| `daylogLinks`, `creamofthecool` | `_build_stash` | `welcome_to_everything.pm` (28–148) |

So a guest front-page hit queries `frontpagenews`/`coolnodes`/`staffpicks` **twice** — and today, because node 124/2030780 are in `GUEST_CACHE_REACT_TYPES`, the blob *also* bypasses the guest chrome cache, so it's full-assembly + controller re-query. This is the single highest-volume waste in the app.

**Nodelet-vs-pagenodelet double-gate inside `buildNodeInfoStructure`.** Three keys are gated twice — once on the user's sidebar `$nodelets`, once on a page's `pagenodelets` — and the second call silently overwrites the first, so the first call's query is pure waste whenever both fire (a fullpage/superdoc whose `pagenodelets` overlaps the user's sidebar):
| key | gate 1 | gate 2 |
|---|---|---|
| `otherUsersData` | 8060 (`$nodelets =~ /91/`) | 8153 (`pagenodelets` has 1969174) |
| `notificationsData` | 8073 (`/1930708/`) | 8148 (`pagenodelets` has 1930708) |
| `messagesData` | 8067 (`/2044453/`) | 8159 (`pagenodelets` has 2044453) |

→ `//=` on the second gate (ref-safe short-circuit — these values are hashrefs/arrayrefs, always truthy, so the RHS builder is skipped when the first gate already ran), or collapse to one gated build. `//=` is the one-character fix. (`newWriteups` is the related case: built *unconditionally* at 7791 for mobile-nav even when not in the user's nodelets — its dedup is "consume the cached global list," not a gate.)

### B. Cross-endpoint re-derivation — separate requests, NOT in-request waste (code-dup / missed cache reuse)
These are standalone endpoints that re-query the same underlying data the blob also builds; not redundant *within* a request, but they'd consume the shared **global cache** once it exists:
- `newWriteups` → `API/newwriteups.pm:16`, `Page/new_writeups_xml_ticker.pm:40`, `Page/new_writeups_atom_feed.pm:42`
- `coolnodes` → `Page/cool_nodes_xml_ticker.pm`, `Page/editor_cools_xml_ticker.pm`
- `messagesData` → `Page/message_inbox.pm:135`, `API/messages.pm:75`
- `otherUsersData` → `API/chatroom.pm:22,92,141,254`
- `usergroupData` → `API/usergroups.pm:43` (by design — in-place nodelet reload)

### Root cause
Page `buildReactData` re-assembles chrome data instead of **consuming the already-built blob/cache**. The double-gates (fixed: `//=`) were the cheap part; the front page is the expensive part — scoped below.

## Front-page dedup — IMPLEMENTED (`cached_stash`, issue/3981/blob-key-dedup)

The surface framing ("controllers should consume the chrome") doesn't directly apply, because the **shapes diverge**: the chrome builds thin `{node_id,title}` feeds for sidebar nodelets, while `welcome_to_everything` / `guest_front_page` build *rich* `{author, excerpt, createtime, linkedby,…}` feeds for the page body. The React components already read `newWriteups` from `e2` (chrome) but `coolnodes`/`staffpicks`/`news` from `contentData` (controller) — and the controller versions are genuinely richer, so "just read `e2.*`" is wrong here.

**The real cost is a repeated `stashData` JSON decode, not the wiring.** `NodeBase::stashData` (line 2941) caches the *node* via `getNode` but re-runs `$json->decode($stashnode->{vars})` on **every** call — the `# TODO: Add to permanent cache` was never done. So a front-page hit decodes the `coolnodes` / `frontpagenews` / `staffpicks` / `dayloglinks` blobs **twice** (chrome loop @ ~7809 + the controller), multi-KB each, on 99% of traffic.

**Done: `NodeBase::cached_stash`** — not a per-request memo but a **per-worker TTL cache**, because the `last_update` stamp + per-class `interval` the cron already maintains make cross-request caching free:
- entry `{ data, last_update, next_check }` off `$DB->{_stash_cache}`; served untouched while `now < next_check`.
- on expiry, one `getNode` reads `last_update`: **delta > 0** → re-decode + re-stamp (`next_check = last_update + interval`); **delta == 0** (cron hasn't regenerated) → keep the decode, back off 5s. So the decode fires only on a real regeneration, and within the window a read does **zero `getNode`, zero decode** — which also drops the datastash version-validation query from per-request to per-window (the #4385 lever).
- `last_update` is a single shared stamp → every worker derives the same window with **no cross-worker state**. The write path invalidates the entry. The returned ref is **read-only** (callers `push` into new structures — audited for the migrated sites).

**Migrated** (request-path reads → `cached_stash`): the chrome loop (`coolnodes`/`staffpicks`), `_build_news` (`frontpagenews`), `_build_stash` (`dayloglinks`/`randomnodes`/`neglecteddrafts`), `welcome_to_everything` (5 reads), `guest_front_page` (2). The front-page chrome+controller double-decode is now one decode per window. `t/168` covers correctness + memoization; `t/141` mock gained `cached_stash`.

**Perf (dev, 2026-06-27):** memory **negligible** — 1.9 KB json / ~6–11 KB decoded per worker vs ~270 MB. Decode **~97% cheaper** per read. Front-page end-to-end **~8–21% faster** (container-noisy; dev's tiny stashes + local DB *understate* prod, where each skipped `getNode` is an RDS round-trip and the site is I/O-bound). Never slower.

**Deferred:** `newwriteups`/`reviewdrafts` reads (audit `filtered_newwriteups`/`forReviewData` for in-place mutation first); the remaining read sites (tickers, `/api/*`); dropping the `GUEST_CACHE_REACT_TYPES` bypass; the cosmetic React `e2.*` feed reads.


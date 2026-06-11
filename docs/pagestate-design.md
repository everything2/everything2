# PageState — extracting the `e2` blob into a cacheable chrome/content seam

**Status:** SPIKE / proposal (2026-06-10). Branch `pagestate-spike`. For discussion — not a
committed direction. This is **Step 2** of [api-driven-architecture.md](api-driven-architecture.md),
the next priority after the return-based-response cleanup (Step 1, done).

---

## The problem in one paragraph

Every server-rendered page calls `Everything::Application::buildNodeInfoStructure` — a **946-line
god-method** (`Application.pm:6787`) that assembles a single 44-key `e2` blob mixing two very
different things: the **per-user chrome** (nodelets, identity, messages, epicenter — the same on
every page this user loads) and the **per-node content** (the node, its writeups, its categories).
Because they're fused, the chrome is re-assembled from scratch on every page load, none of it is
cacheable, and the client can't fetch "just the content" on navigation. Splitting them is the
unlock for caching, for React-owned routing, and for the I/O testing story.

## The blob today

`buildNodeInfoStructure($NODE, $USER, $VARS, $query, $REQUEST)` → a 44-key `$e2` hashref. Callers:
the main page render (`Application.pm` ~7640) and five controllers (`Controller/user.pm`,
`htmlcode.pm`, `nodelet.pm`, `usergroup.pm`). The blob is serialized into the page shell as the
`e2` global the React app boots from.

### Proposed classification of the 44 keys

**CHROME — per-user / session, identical regardless of which node is viewed (cacheable per user):**

| Group | Keys |
|---|---|
| Identity | `guest`, `user`, `currentUserId` |
| Prefs / env | `display_prefs`, `use_local_assets`, `assets_location`, `architecture`, `noquickvote`, `nonodeletcollapser`, `hasMessagesNodelet`, `recaptcha`, `lastCommit`, `reactPageMode`, `pageheader`, `quickRefSearchTerm` |
| User nodelets | `epicenter`, `messagesData`, `notificationsData`, `personalLinks`, `favoriteWriteups`, `chatterbox`, `developerNodelet` |
| Role nodelets | `masterControl`, `neglectedDrafts`, `forReviewData` |
| Site nodelets | `newWriteups`, `news`, `randomNodes`, `recentNodes`, `statistics`, `daylogLinks`, `currentPoll` |

**CONTENT — per-node (varies with the viewed node):**

`node_id`, `title`, `currentNodeId`, `currentNodeTitle`, `node`, `nodetype`, `contentData`
(the controller's `buildReactData` — the actual page body), `nodeCategories`, `usergroupData`,
`noteletData`.

**AMBIGUOUS — settle in the morning:**
- `bounties` — the Bounties *nodelet* (site-wide → chrome) or bounties *on this node* (content)?
- `otherUsersData` — "Other Users" online nodelet (chrome) vs something node-scoped?
- `recentNodes` — per-user session breadcrumb; chrome, but mutates on every navigation, so its
  cache lifetime is shorter than the rest of the chrome.

*(The skeleton `Everything::PageState` carries this exact manifest; a test asserts every blob key is
classified, so a newly-added key fails loudly instead of silently landing in the wrong resource.)*

## Proposed approach: facade first, migrate second

The 946-line method is too risky to rewrite in one pass. Two phases:

### Phase 2a — `Everything::PageState` as a partitioning facade (low risk, shippable)
`PageState->from_blob($e2)` splits the existing blob into `{ chrome => {...}, content => {...} }`
using the key manifest above. **No assembly logic moves yet** — `buildNodeInfoStructure` still runs
unchanged, so there is zero behavioural change. What this buys immediately:
- two **API resources**: `/api/pagestate` (chrome) and the existing `/api/nodes/:id` extended with
  `content`. The client can now fetch them independently.
- a **caching seam**: chrome is keyed by `(user_id, role, prefs-version)` and cacheable; content is
  keyed by node. Caching can be added at the resource edge without touching assembly.
- a **classification test net**: the manifest test pins the contract, so the migration in 2b can't
  silently drop or misroute a key.

### Phase 2b — migrate assembly key-by-key into PageState
With the seam proven, move each key's *assembly* out of `buildNodeInfoStructure` into a focused
`PageState` builder (`_build_epicenter`, `_build_messages`, …), one reviewable PR per group, until
`buildNodeInfoStructure` is an empty husk and is deleted. Each move is independently testable
(tier-2 controller tests from the architecture doc) and independently revertable.

## API surface

- **`GET /api/pagestate`** → the chrome for the current user. Cacheable per user; invalidated by
  pref changes, new messages/notifications, login/logout. This is the per-user shell the React app
  mounts once and reuses across client navigations.
- **`GET /api/nodes/:id`** (existing) → extended to carry the `content` partition for the node.
- Page load = `pagestate` + `nodes/:id`; client navigation = just `nodes/:id` (chrome reused). The
  server stops bespoke per-page HTML assembly; "page load" and "navigation" converge.

## Cacheability — the actual payoff

This is where the chrome/content split earns its keep. The design below is grounded in how E2's
caching actually works today (verified, not assumed).

### Two layers: data vs. render

Chrome freshness is **not monolithic** — it's a spectrum, and the data layer is already handled:

- **Site data is already cron-cached.** Most site-wide chrome is precomputed by `Everything::DataStash::*`
  and refreshed by the `datastash` cron (the one consolidated onto the webheads): `newwriteups` (→
  `newWriteups`), `frontpagenews` (→ `news`), `randomnodes` (→ `randomNodes`), `dayloglinks`,
  `neglecteddrafts`, `reviewdrafts`, `coolnodes`, `staffpicks`, `bestrecentnodes`. Intervals:
  `newwriteups` 60s, base 300s; cron fires every 120s → effective refresh ~2 min for the hot ones.
  Verified: the read path **does not** regenerate inline on a miss (it falls back to empty), so
  nothing recomputes the dataset on a page request. The data freshness model we want already exists.

- **The render is per-request, and that's the cost.** Even though the data is cron-cached, every
  page request re-pays:
  1. **A full `JSON->decode` of each stash blob.** `NodeBase::stashData` does `getNode` +
     `JSON->decode($stashnode->{vars})` *per read* — identical output until the next cron tick. The
     `# TODO: Add to permanent cache` at the top of `stashData` is exactly this unfulfilled memoization.
  2. **The per-user permission + preference overlay.** After decode, e.g. `newWriteups` loops the list
     applying unfavorite-author filtering, editor visibility, and `hasVoted($wu, $USER)` **per writeup**.
     So even shared data gets re-filtered and re-queried per request — this is why logged-in chrome is
     genuinely per-user even when the underlying data is global.

### Site vs. user chrome

Split chrome by *who it varies for*, not just chrome-vs-content:

- **`site` chrome** — stash-backed, identical for everyone, refresh on the datastash cadence (~2 min):
  `newWriteups`, `news`, `randomNodes`, `daylogLinks`, `statistics`, `currentPoll`, the editor stashes.
- **`user` chrome** — genuinely per-user, event-busted: `messagesData`, `notificationsData`,
  `epicenter` (XP/level/GP), `favoriteWriteups`, `personalLinks`, plus the per-user *overlay*
  (permissions + prefs) applied over the site data.

A **guest** has no `user` chrome and takes the light filter path (no `hasVoted`, no favorites), so a
guest's entire chrome collapses to `site` + static env → **one shared artifact**.

### The real cost is cardinality, not unit price

The per-node freshness check (`NodeCache::getCachedNodeByName` → `isSameVersion` → `getGlobalVersion`
→ `sqlSelect('version','version', …)`) is a **DB round-trip per cached-node read**. Each one is a
trivial primary-key SELECT on a two-int row — individually nothing. **The cost is the count.** A
"New Writeups" or front-page render fans out across every node in the list, so it's N version SELECTs
per render × every render × crawler-heavy traffic — tens of thousands of redundant SELECTs/hour
against the RDS we're keeping off the buffer-pool/connection ceiling. This lands on **RDS QPS /
connection pressure, not CPU** — the same load axis the PSGI connection cut addressed, aimed at read
volume. So the lever is **not issuing** the checks, not making them faster.

### The mechanism: a pre-compiled, TTL guest-chrome region

For content that's already TTL-bounded by its stash, re-validating each constituent node per render
buys nothing. So:

- A **separate TTL region in `NodeCache`** — deliberately **not** version-validated (that's the whole
  point) — in-process per worker, **2-min TTL** aligned to the datastash cadence (matches existing
  staleness; adds none).
- The entry is **pre-compiled**: the assembled **and JSON-serialized** guest-chrome *string*, ready to
  splice into the response. Not the structure — the finished bytes.
- **Guest request → hit → hand back the string.** Zero version SELECTs, zero stash decodes, zero
  assembly, zero JSON encode — a memory read. **Miss/expired → assemble once** (pay the version
  SELECTs + decodes + encode that one time), store the compiled string, return.
- Caps guest-chrome work at **~once per worker per 2 min** instead of once per request. At ~4 workers
  that's a handful of assemblies per 2 min serving the entire guest/crawler firehose — which is most
  of the version-SELECT volume hitting RDS today.

Why bypassing versioning is correct here: guest chrome is node-independent and identical across all
guests (one string, no keying); 2-min staleness matches the stashes themselves; TTL-invalidated, not
version-invalidated, is the deliberate override — trading freshness we don't need to skip lookups we
don't want. It also **composes with Step 1**: the compiled string drops straight into the return-based
response, so a guest pageload becomes "read one TTL entry, emit."

**This generalizes past guest chrome:** the rule is *"for content that's already TTL-bounded, don't
re-validate each constituent node per render."* The pre-compiled region is one expression of it; a
"trust the stash, skip per-item version checks" path for list rendering (front page, New Writeups,
site nodelets) is another.

### Logged-in caching

The per-user overlay (`hasVoted` / favorites / role / prefs) is the irreducible per-user cost — can't
share across users. Cache the per-user chrome keyed on `(stash_version, prefs_version, role, the
user's vote/favorite state)`; it busts on the user's vote/favorite activity or the ~2-min stash tick,
not every pageload. Sub-resource decomposition still helps: a new message busts only the `messages`
sub-resource, not the whole shell.

### No new infra

Everything above reuses existing machinery — the DataStash (DB-backed, cron-refreshed), the in-process
`NodeCache`, and the `datastash` cron. Consistent with the "no extra cache infra" posture: this is
about *not re-computing / not re-validating*, not standing up Redis.

- **Optional refinement:** have the `datastash` cron compile the guest-chrome string into its *own*
  stash (shared authority across workers) and let each worker hold a short in-process TTL copy of that
  — best-of-both (single source + memory-speed serve). The plain in-process TTL is the right first cut;
  add the cron-compiled stash only if per-worker rebuild cost shows up.
- **One guard:** on TTL expiry the first guest per worker eats the rebuild — a tiny thundering-herd,
  negligible at this worker count, with a "rebuild-in-progress" flag as the easy fix if it ever matters.

## Decisions taken (2026-06-10 design pass)

- **Cacheability model:** settled — see the Cacheability section above (site/user split, the
  pre-compiled TTL guest-chrome region, cardinality framing, no new infra).
- **`otherUsersData`:** currently a live per-request query (not stashed). **Add it as a DataStash**
  (cron-refreshed ~2 min) so it joins the `site` chrome instead of querying per render.
- **`recentNodes`:** the one genuinely per-navigation per-user key. Keep it **client-side** (or accept
  it as the per-request exception); do not let it force the rest of the chrome to be per-request.

## Open questions

1. **`bounties`** — Bounties *nodelet* (site → stash-cacheable) vs. bounties *on this node* (content)?
   Last unresolved key in `AMBIGUOUS_KEYS`.
2. **Hydration:** does the initial page load inline the pagestate payload into the shell (one round
   trip, today's behaviour) or always fetch it (simpler, one more request)? Likely inline-on-first,
   fetch-on-navigate.
3. **Per-node content vs. the controller `buildReactData` contract** — `contentData` already is the
   controller's return; how much of the other content keys (`nodeCategories`, `noteletData`) should
   move *into* the controller's return vs. stay assembled by PageState?
4. **Scope of 2a's first shippable slice** — stand up `/api/pagestate` (facade) + the pre-compiled
   guest-chrome TTL region first (the highest-value, lowest-risk slice — it's a read-path optimization
   with no behaviour change), leave the React shell wiring + the logged-in per-user cache for follow-ups.

## What's in this spike branch

- `docs/pagestate-design.md` — this doc.
- `ecore/Everything/PageState.pm` — skeleton facade: the key manifest + `from_blob` partition +
  `unclassified_keys` (the migration safety net). No assembly logic moved.
- `t/141_pagestate.t` — pins the partition contract and asserts the live blob has no unclassified
  keys.

Nothing here changes runtime behaviour — `buildNodeInfoStructure` is untouched. It's the seam and
the proposal, ready to discuss.

---

## 2a — AS BUILT (2026-06-10)

Step 2a shipped on `issue/4255/pagestate-chrome-content`. The facade is live and the React
contract is normalized + covered.

### Perl
- **`GET /api/pagestate[?node_id=N]`** (`Everything::API::pagestate`) — the full page payload the
  React app boots from: chrome + the node's `contentData` + the rendering key `contentData.type`
  (which `DocumentComponent` maps to a view). The `e2` blob, delivered as an API resource.
- **`Everything::PageState->normalize_types`** — recursively coerces integer-string ids
  (`node_id`, …) to real integers (#4152/#4108). Applied at the **single source**
  (`buildNodeInfoStructure`'s return), so the **inline render and `/api/pagestate` emit the
  identical, correctly-typed contract** — parity by construction. Fixed the live inline blob (54
  string `node_id`s → 0). Full Perl suite green (4640).
- **`tools/capture-pagestate-fixtures.sh`** — snapshots the real normalized `/api/pagestate` as
  React fixtures (`react/__fixtures__/pagestate/<type>.json`), so test fixtures match the contract
  by construction. Re-run when the contract changes.

### Facade completion — route-through-render
The first facade cut called `buildNodeInfoStructure` directly, which only produces `contentData` for
**Page-class (superdoc) nodes**. Controller-class nodes (`user`, `e2node`, `category`, `document`,
`achievement`, …) build their `contentData` *inside the controller* and render HTML, so the facade
saw `contentData.type = None`. Fixed by **routing the facade through the real render path**:
`Everything::API::pagestate` calls `$Everything::ROUTER->route_node($node, $displaytype, $REQUEST)`;
`Everything::Controller::layout` (the single chokepoint where every controller hands off its built
blob) **normalizes and stashes `$e2` on the request** (`pagestate_e2`); the facade returns that. The
rendered HTML is printed into the STDOUT capture, which app.psgi discards for the return-based API
path. Result: the facade output is **identical to the inline render for every node type**, supports
`?displaytype=`, and the controller's post-override `contentData` gets normalized too. (Caveat: it
renders the whole page to harvest the blob — wasteful, and runs page-view side effects. Step 3
— controllers RETURN their content — replaces this with a direct call.)

### React coverage (the "fixtures that match" net) — COMPLETE
Of the 234 originally-uncovered Document components: **4 dead aliases retired**, **229 covered**, and
**1 intentionally left** (`unimplemented_page`, the future-catchall error page). Full React suite:
**2258 tests green** (was 1590, +668). 234 test files, 225 fixtures. **0 components broke** under the
normalized int contract — the parity premise (normalizing both sources is safe) is empirically proven
across the entire Document view layer.

How the gap was closed in passes:
- **Facade for superdocs** → 186 covered in the first sweep.
- **Route-through-render** (above) made controller-class views reachable → +30.
- **Authed capture**: `tools/capture-pagestate-fixtures.sh` takes `E2_LOGIN_USER`/`E2_LOGIN_PASS`
  (logs in, sends the session cookie) + per-node `node_id:displaytype` specs → closed the 8
  auth-gated views (`user_edit`, `dbtable`, `setting`, …) by capturing as `root`.
  (`react/test-setup.js` also stubs jsdom's missing `Element.scrollIntoView`.)
- **Dead aliases retired** from `DocumentComponent.js` (`node_tracker2`, `sanctify`, `admin_settings`,
  `the_oracle_classic` — no server emitter; targets stay alive via the real keys).
- **Seeds**: `tools/seeds.pl` now seeds a `collaboration` + a `debate` node so the
  `collaboration`/`debatecomment` (incl. `*Edit`, `Replyto` via `displaytype=useredit`/`replyto`)
  views have a live node to capture in a fresh dev DB → the last 5 covered.

### Residual: 1 (intentional)
`unimplemented_page` — the future-catchall friendly error page (fires only for a superdoc with no
Page class; none currently exist). Deliberately left uncovered. Everything else a guest *or* an
authenticated admin can render now has a fixture-backed test against the real normalized contract.

### Addendum — name/type addressing + head metadata (2026-06-10)

Two follow-ons landed on the same branch to unblock the React-router flip:

* **Addressing.** `/api/pagestate` accepts `?node_id=N`, `?title=T[&type=X]` (`type` defaults to
  `e2node`), and `/lookup/:type/:title`. The legacy-URL → (id | type/title) resolution is **owned by
  React's client router**, not the API; the API only needs an id or a type/title. (t/142.)

* **Head metadata.** New `Everything::PageMetadata` is the single producer for the page `<head>` —
  title, canonical, robots, Open Graph, Twitter, and the schema.org JSON-LD `@graph`.
  `Everything::HTMLShell` now renders the server `<head>` *from* it (replacing its own inline
  JSON-LD/og logic — verified a byte-identical head across writeup/e2node/category/superdoc, JSON-LD
  structurally equal modulo key order). `Everything::Controller::layout` stashes the same producer's
  output on the request (`pagestate_meta`), and `Everything::API::pagestate` merges it into the blob
  it returns as the **`meta`** key. It is deliberately kept **out of the inline hydration blob** — the
  server render already emits the `<head>` in HTML, so inlining `meta` would just duplicate the
  JSON-LD bytes on every pageload (confirmed absent from the inline `e2`). So the React app can set
  `<head>` on client navigation (where there's no server render) from byte-identical data, while
  guest/initial payloads stay lean. (t/143 unit; t/142 end-to-end on the live endpoint.)
  The React-side consumer (a `useDocumentMeta`-style hook) is part of the hydration flip — the data
  is now available ahead of it.

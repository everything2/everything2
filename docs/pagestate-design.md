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

## Caching — the actual payoff

Chrome is the expensive, repeated part (every nodelet query, every page). Once it's a standalone
per-user resource:
- **Cache key:** `user_id` + a `prefs_version` (bump on VARS/nodelet change) + role. Guests get a
  single shared chrome (modulo a couple of site nodelets).
- **Invalidation:** new message/notification → drop that user's chrome; pref change → bump
  `prefs_version`; site nodelets (newWriteups, news, currentPoll) have their own short TTL and could
  be sub-resources so the rest of the chrome stays warm.
- **No new infra required** to start — even a per-request memoize + an ETag on `/api/pagestate` cuts
  repeat assembly. (Consistent with the "no extra cache infra" posture; this is about *not
  re-computing*, not standing up Redis.)

## Open questions for the morning

1. **Classification of the ambiguous three** (`bounties`, `otherUsersData`, `recentNodes`).
2. **Chrome cache key + invalidation granularity** — one blob per user vs. splitting the volatile
   site nodelets (newWriteups/news/poll) into their own short-TTL sub-resource so a new message
   doesn't cold-bust the whole shell.
3. **Hydration:** does the initial page load inline the pagestate payload into the shell (one round
   trip, today's behaviour) or always fetch it (simpler, one more request)? Likely inline-on-first,
   fetch-on-navigate.
4. **Per-node content vs. the controller `buildReactData` contract** — `contentData` already is the
   controller's return; how much of the other content keys (`nodeCategories`, `noteletData`) should
   move *into* the controller's return vs. stay assembled by PageState?
5. **Scope of 2a's first shippable slice** — just stand up `/api/pagestate` returning the chrome
   partition (facade), or also wire the React shell to consume it? I'd ship the resource + the
   classification test first, leave the client wiring for a follow-up.

## What's in this spike branch

- `docs/pagestate-design.md` — this doc.
- `ecore/Everything/PageState.pm` — skeleton facade: the key manifest + `from_blob` partition +
  `unclassified_keys` (the migration safety net). No assembly logic moved.
- `t/141_pagestate.t` — pins the partition contract and asserts the live blob has no unclassified
  keys.

Nothing here changes runtime behaviour — `buildNodeInfoStructure` is untouched. It's the seam and
the proposal, ready to discuss.

# Everything2 Developer Roadmap

**Created**: 2025-12-17 (original)
**Rewritten**: 2026-05-24 (this revision)
**Updated**: 2026-11-16 (status verified against code + GH issues: mutation audit, htmlpage, return-based controllers, guest chrome cache, pure-gate controllers all shipped; React router still unbuilt)
**Owner**: Jay Bonci
**Status**: Living document — strategic priorities + sequencing

This is the **high-level priority list**, not the project plan for any one phase. Each numbered phase below has (or will get) its own per-phase doc that holds the detailed plan, scope, and tracking. Treat this doc as the index — it answers "what's next and why," not "what exactly to do on day three of phase 4."

The prior version (Dec 2025, 5,281 lines) tried to be both index and per-phase plan and ended up being neither — by 2026-04 most phase plans had drifted from reality. This rewrite preserves the institutional context, the strategic posture, and the ordering rationale, and delegates per-phase detail to per-phase docs.

---

## Strategic posture

**Goal:** Everything2 pays for its own infrastructure via AdSense.

**Approach:** Alternating rounds — optimization rounds drive operating cost down, traffic-driving rounds grow revenue. Rinse, repeat. The cost target lowers with each pass; the revenue target rises.

**Baseline** (as of 2026-05-24 — not re-measured in the 2026-11-16 refresh):
- AWS spend: ~$345/mo
- AdSense revenue: ~$140-150/mo (trending up — May running rate is ~$153)
- Gap: about $200/mo deficit
- Target after planned optimization work: ~$170-200/mo spend, with the assumption that revenue continues organic growth and traffic rounds add discrete jumps

**Constraints on sequencing:**
- ~~**MySQL 8.4 by 2026-07-31**~~ — met (done 2026-06-07, #4226). No hard deadline is currently active.
- ~~**PSGI/Plack migration**~~ — shipped June 2026 (#4234).
- **Flexibility > 3-year reservations** — don't lock in to current Fargate / RDS shape with long commits. The post-PSGI shape (1vCPU/2GB, autoscaling) is now known; a 1-year commit is the open question (Phase 7).
- **Bug fix backlog runs in parallel** with planned phases — not its own numbered phase. Github issues are the unit of tracking for ambient maintenance.

---

## Where we are (verified 2026-11-16)

**Shipped (the gates and the big levers):**
- ✅ **MySQL 8.4 migration** — done 2026-06-07 (#4226). (Phase 1.)
- ✅ **PSGI/Plack migration** — live in prod 2026-06-08 (#4234); mod_perl + CGI.pm removed (#4244),
  Apache on mpm_event as a pure proxy, Starman serving. (Phase 6.)
- ✅ **Post-PSGI Fargate right-size + autoscaling** — 1vCPU/2GB, 2xx-per-target autoscaling, SNS alarms;
  ECS deployment circuit breaker added (#4565). (Phase 7, minus the commit.)
- ✅ **Cron sidecar** (#4246) — GET_LOCK-elected cron runs on the webheads (`E2_CRON_ENABLED`/`E2_CRON_LIVE`
  on in the prod template). Only the daily sitemap stays a dedicated EventBridge→Fargate task, by design.
  #4251 (cutover bookkeeping) is still open on GitHub. This replaced the "Cron-to-Lambda" idea (Phase 5).
- ✅ **Security-log decoupling** (#4272) — `seclog` on the `Everything::SecurityLog` enum.
- ✅ **opcode → API** (#4198 / #4335) — `Everything::Delegation::opcode` and `op=` dispatch are gone.
- ✅ **htmlcode burndown** (#4259 / #4300 / #4358) — `Everything::Delegation::htmlcode` has zero subs;
  `htmlcode()` dispatch removed from `Everything::HTML` (#4362).
- ✅ **htmlpage nodetype retired** (#4361).
- ✅ **Render-time mutation audit** (#4298 / #4416) — Page controllers no longer process form posts;
  mutating actions are `POST /api/…`.
- ✅ **Return-based controllers** (#4483) — both request paths return an `Everything::Response`; the
  app.psgi STDOUT capture is deleted.
- ✅ **Guest chrome cache** — shipped as `Everything::DataStash::guestchrome` (#4371) plus the guest-request
  diet (#4419). #4257 stays open but is now only the structural `buildNodeInfoStructure` → `PageState` move.
- ✅ **Pure-gate controllers** (#4513 onward) — 80 pages are now registry entries in `Everything::PureGates`
  (no Page module); display text and URL params moved into React for those pages.
- ✅ **TipTap v3** (#4598), dependency/CVE batches, CodeBuild fixes, and a security hardening pass (Nov 2026).

**Not done yet:** the React client router (nothing in `react/` yet), the maintenance-hook `$query` sweep,
the CSRF guard (#4301), and everything in the object-model epoch.

**Active GH issue backlog:** ~290 open issues. An `epoch:react-cleanup` tranche (#4580–#4595: shared
Modal/Pagination/Loading, one fetch wrapper, stop full-page reloads after mutations) was filed Nov 2026.

---

## Current thrust — the React-routing thread

**Destination:** full client-side React routing (SPA navigation; SSR first paint, client-route subsequent
nav). **Why it's the north star:** it moves the cost+growth curve, is incremental/reversible, and the API
layer it forces is the seam that de-risks the later ORM epoch. *(The original "end of June 2026" target
slipped. Most of the prerequisites below shipped June–July 2026; after a break (Aug to mid-Nov), the
Nov 2026 work went to security, build and dependency fixes.)*

**The unifying theme — kill silent `$query` dependence.** You cannot client-route a page that processes a
request *server-side*. The end goal is now stricter: **zero `$REQUEST->param` / `->cgi->param` reads in
Page controllers.** URL params are a React concern (read `window.location`, resolve through APIs), and
display-only text moves into React too. Controllers become pure gates.

**Status of the sequence:**
1. ✅ **Skinny down htmlcode exposure** — subs + dispatch gone. *(The htmlcode **nodetype + table stay**:
   `maintenance` keeps its code in the htmlcode table and `jsonexport` extends it. The empty module,
   `Everything::Controller::htmlcode`, and the nodetype go later, behind the maintenance teardown.)*
2. ✅ **Cacheable guest chrome** — shipped (#4371/#4419). Open follow-ups: #4257 (structural split),
   #4493 (post-deploy regen deadlock on the guestchrome datastash).
3. 🟡 **htmlpage cleanup ✅ (#4361); maintenance-hook `$query` sweep ⬜** — `Everything::Delegation::maintenance`
   (23 subs) still reads ~13 request params through `$query` (writeup/debatecomment/category/draft/node_forward
   hooks). Next concrete step: move those into `Node::<type>->create`/API params (see orm-migration-plan.md).
4. ✅ **Audit all Pages for mutation (#4298)** — closed.
5. 🟡 **API test coverage** — 132 of 133 `Everything::API::*` modules are exercised by a `t/` test (breadth
   check, not line coverage; line coverage is unmeasured). CSRF guard **#4301 still open**.
6. ⬜ **Param-free controllers** — 44 non-feed Page modules still read params (~120 call sites incl. feeds;
   61 modules with feeds/tickers). Of the 174 remaining Page modules, the rest are param-free; 80 more
   pages are pure gates. Tracking: [controller-rationalization-inventory.md](controller-rationalization-inventory.md).
7. ⬜ **React-based routing** — client router/resolver + `useDocumentMeta` + routing-parity harness + the
   progressive flip. Not started in `react/`. Server-side primitives (pagestate, route recovery,
   `normalize_types`) are done. Related: #4129 (mod_rewrite title hacks), #4355 (login-redirects).

**Then the next major epoch — object-model modernization (`Everything::Node` cleanup).** **Direction decided
2026-06-29 (see [docs/orm-migration-plan.md](orm-migration-plan.md)): DBIC is dead.** E2's domain is *nodes*
(multi-table inheritance + VARS + nodegroups), not tables. DBIC is the wrong *shape*: it can't model
the node system without rebuilding a node layer on top of it anyway. We already have that layer
(`Everything::Node::*`); the move is to **finish it, not replace it**, and to **ditch Moose for Object::Pad**
(the on-ramp to core `class` on perl 5.40), buying real field encapsulation (kills the
blessed-vs-hashref footgun), lower per-object cost, and a non-bespoke future.
NodeBase stays as the storage engine (its MTI loader is an asset). **Not started as of 2026-11-16** (no
Object::Pad in `ecore/` or `cpanfile`). Cutover sequence:
1. **`Everything::Globals` / Configuration (#4178, open)** — scoped to *"the controller bases no longer consume a
   Moose role"*.
2. **Controllers (`Everything::API` + `Everything::Page`)** — mechanical once the role's gone, all test-guarded.
3. **`Everything::Node::*`** — last, gated on killing hashref access; long pole is `Application.pm` (~9.7K
   lines, raw `$USER->{title}` by design), not the 59 Node subclasses.
4. **PluginFactory teardown (#4261)** — the payoff once controllers are plain classes.
Plus the **deferred htmlcode/maintenance teardown** and **schema versioning (sqitch, Phase 9 — an
independent parallel track, not started)**.

---

## Site history (institutional context)

Everything2 has been through several distinct architectural eras. Brief recap, because it's load-bearing for understanding why some things are the way they are.

**1999-2015 — Pure database code.** Everything (templates, server-side logic, content) lived in MySQL nodes. Code was `eval`'d at runtime from database strings. Revolutionary for its time; modern security concerns (arbitrary code execution, no audit trail) made it untenable.

**2015-2020 — Delegation pattern.** Code progressively moved from database nodes to filesystem modules (`Everything::Delegation::*`). Moose OOP introduced. Mason2 templates as interim server-side rendering layer. ~80% of code eval'd-from-database migrated to filesystem.

**2020-2025 — React integration.** REST APIs + React components for interactivity. Hybrid rendering (Mason2 server-side + React client-side). AWS containerization (Fargate, CloudFormation). The "delegation" intermediate state mostly retired.

**2025-2026 — Frontend modernization & post-Mason era.** 26 sidebar nodelets migrated to React, 200+ superdoc/htmlpage migrated to React, Mason2 mostly eliminated. Inline-styles → BEM CSS refactor (the big stalled change that landed Apr-May 2026). Mobile-first redesign shipped Jan 2026.

**2026-present — Cost rationalization & forced infrastructure work.** MySQL 8.4 migration (done June 2026). PSGI/Plack migration (live June 2026). Cost optimization (Fargate right-sizing, cron sidecar on the webheads). Retiring the delegation layer (opcode + htmlcode gone) and moving every mutation to an API, ahead of client-side React routing.

---

## The phase list (priority-ordered)

### Phase 1 — MySQL 8.4 migration ✅ DONE (2026-06-07, #4226)
- **Window:** now → 2026-07-31 (9 weeks, hard deadline) — *completed well ahead of deadline*
- **Why first:** hard deadline + the +$146/mo Extended Support penalty for missing it
- **Detailed plan:** [docs/mysql-migration-plan.md](mysql-migration-plan.md)
- **Schema cleanup tracking:** [#4074](https://github.com/everything2/everything2/issues/4074) (umbrella) + 17 child issues
- **Approach:** Phase 0 audit (mostly done) → schema cleanup (per-table SQL in GH issues) → CFN-parameterized dummy RDS for app validation (per-discussion) → blue/green production cutover

### Phase 2 — Cost Optimization Round 1 ⬜ not started (as of 2026-11-16)
- **Window:** ~~August 2026~~ — not yet taken; partly overtaken by the PSGI right-size (Phase 7) and the cron sidecar
- **Why now:** free wins post-MySQL stability; no commits locked in yet so shape changes are easy
- **Scope:**
  - Audit the 9 public IPv4 addresses ($32/mo) — likely consolidate to 4-5
  - Investigate ALB LCU rate (8.6/hr avg is high for the request volume) — likely bot connection churn
  - Right-size current-shape Fargate (running 9% CPU avg on 2 vCPU)
  - Defer Cloudflare evaluation to Phase 9 (bot defense) since they're related concerns
- **Estimated savings:** $30-50/mo
- **No long commits yet** — wait for post-PSGI shape

### Phase 3 — React simplification ⬜ not started as a phase (scope now filed as `epoch:react-cleanup`, #4580–#4595)
- **Window:** ~~August-September 2026~~ — not taken; the Nov 2026 issue tranche is the concrete work list
- **Why here:** Finish what the Jan 2026 refactor started while context is fresh; before adding new React features (social login UI)
- **Scope:**
  - Inline-styles → BEM refactor is resolved; residual theme-level work is tracked in [docs/css-consistency-audit.md](css-consistency-audit.md)
  - Migrate remaining direct `toLocale*String` callers (~10 Documents components still call them) to the shared `dateFormat` utility from #4056 work
  - Audit react/components/ for other one-off utilities that should be shared (similar to dateFormat pattern)
  - Drop any unused legacy.js / pre-React holdovers
- **No deliverable doc yet** — write one when work starts

### Phase 4 — Social login integration ⬜ not started (#4343 signup-flow overhaul is the tracked precursor)
- **Window:** ~~September-November 2026~~ — not taken
- **Why here:** user acquisition is real revenue; prerequisite "DB sanity" is satisfied by Phase 1 completion. (The new `user_oauth` table is a plain node-model addition built behind sqitch — **no DBIC**; that carve-out was retired 2026-06-29, see [docs/orm-migration-plan.md](orm-migration-plan.md).)
- **Scope:**
  - OAuth providers: Google, Facebook, Apple (TBD on Apple — adds complexity)
  - New `user_oauth` table linking external provider IDs to E2 user IDs
  - Account-linking flow for existing users (match by email)
  - Updated login UI (likely uses LoginForm + auth-modal patterns already in place)
- **Open question:** whether sqitch (Phase 9) has landed by the time this table is needed; if not, it's a natural forcing function to pull sqitch forward. (DBIC is no longer on the table — decided 2026-06-29.)
- **No deliverable doc yet** — write a plan doc before starting

### Phase 5 — ~~Cron-to-Lambda~~ → cron sidecar ✅ DONE (#4246)
- **Status:** the Lambda rewrite was **rejected** in favor of a `GET_LOCK` leader-elected cron sidecar on the
  (overprovisioned) webheads. Design: [docs/cron-sidecar-design.md](cron-sidecar-design.md). Live in prod; the
  ~50-minute daily sitemap job stays a dedicated EventBridge→Fargate task on purpose. #4251 (cutover
  issue) still open on GitHub; #4438 tracks recording the sitemap runs.

### Phase 6 — PSGI/Plack migration ✅ DONE (live in prod 2026-06-08, #4234)
- **Window:** ~~November 2026 → February 2027~~ — *pulled forward and shipped June 2026; mod_perl + CGI.pm removed*
- **Why here:** biggest single architectural move; needs stable DB and frontend (Phase 1-3 done) before starting
- **Status:** shipped and live in prod (2026-06-08); mod_perl + CGI.pm removed. Original migration plan is in git history.
- **Key facts:** app is CGI-style via ModPerl::Registry (not native mod_perl handlers), so the migration is shallower than originally feared. Phase A (PSGI wrapper, dev only) → Phase B (Apache::DBI replacement, ECS shape) → Phase C (staging + canary) → Phase D (post-migration Fargate right-sizing)
- **Compound benefits:** drops Fargate worker count ~5x, halves DB connection count, frees up the "always-on" memory pressure on RDS, removes Apache::DBI dependency

### Phase 7 — Post-PSGI Fargate right-sizing + 1-year commits 🟡 right-size + autoscaling DONE (June 2026); commits TBD
- **Window:** ~~February 2027~~ — *right-size to 1vCPU/2GB + 2xx-per-target autoscaling (min2/max6) shipped June 2026; 1-year Savings Plan commit still deferred until the shape settles*
- **Why here:** PSGI makes the smaller container shape viable; this is when the final cost shape is known and commits make sense
- **Scope:** drop to 1vCPU/2GB × 3 tasks (from 2vCPU/4GB × 2). Add 1-year all-upfront Compute Savings Plan sized to the new baseline. Evaluate RDS RI on the post-MySQL instance class.
- **Estimated savings:** additional $50-70/mo on top of Phase 6's PSGI savings; commits add another $30-40/mo
- **Total cost picture post-Phase-7:** projected ~$170-200/mo (vs current $345/mo)

### Phase 8 — React 19 upgrade ⬜ not started (still on React 18.3.1)
- **Window:** Q2 2027 (3-4 weeks)
- **Why here:** after React simplification (Phase 3) and post-PSGI stability — fewer moving parts to test against
- **Detailed plan:** [docs/react-19-migration.md](react-19-migration.md) (pre-existing, may need refresh)
- **Scope:** React 18 → 19, React Compiler adoption, deprecation cleanup. Tests against the JSX transform changes.

### Phase 9 — Schema migration framework (sqitch) ⬜ not started (no sqitch files or adoption issue yet)
- **Window:** Q2 2027 (2-3 weeks) — can be done earlier opportunistically if Phase 4 social login pushes it forward
- **Why here:** the genuinely missing piece. Production has no migrations pipeline today; every schema change is hand-applied SQL by the maintainer. Sqitch fixes that.
- **Detailed plan:** [docs/sqitch-migration-plan.md](sqitch-migration-plan.md) (alternatives analysis + why sqitch)
- **Scope:** sqitch baseline captures the current schema — **dumped from prod, not from the `nodepack/dbtable/` XML.** (Correction 2026-06-29: that XML is a jank dev-bootstrap *reference snapshot*, not a managed applier — prod schema changes are hand-applied SQL today — so there's **no coexistence problem**; sqitch becomes the *first* real migration mechanism.) Every change after baseline is a sqitch change file. An **independent parallel track** to the object-model epoch (schema, not objects); can be pulled forward anytime. The dev-pipeline wiring is an afternoon; the care is in the **prod-migration discipline** (expand/contract, online DDL on big tables, `sqitch revert`).

### Phase 10 — Bot defense modernization (Cloudflare or AWS WAF)
- **Status (2026-07):** the July 2026 datacenter bot floods were judged revenue-safe and cache-absorbed; AWS WAF was rejected on cost. Cloudflare is still unevaluated.
- **Window:** anytime independent — opportunistic
- **Why here:** mod_evasive (the current bot defender) drove a 30× AdSense RPM improvement in early 2026 by filtering bot traffic. Future-proofing this is real revenue protection — but the work has no forcing function so it slots in whenever there's bandwidth.
- **Scope:** evaluate Cloudflare (free tier covers bot management at this scale; replaces mod_evasive AND offloads ALB LCUs) vs AWS WAF rate-based rules (stays AWS-native; costs ~$5-10/mo). Decision largely about "one more vendor or not."
- **Constraint:** CloudFront was rejected at this scale (see memory) — Cloudflare's free egress is the key differentiator

### Phase 11 — Traffic-driving round (TBD)
- **Window:** alternates with optimization rounds; first plausible window is post-Phase 7
- **Why here:** per the strategic posture — costs are now meaningfully lower, time to grow the top line
- **Scope (TBD):** SEO work targeting the page-2 search rankings already in Search Console data (~430 clicks/day at avg position 17-22); content strategy; possibly newsletter or external-community outreach
- **Will spawn a separate doc when planning begins**

---

## What was in the old roadmap but is NOT here (and why)

- **"API Cleanup and Consolidation" (old Phase 2)** — implicit/ambient; ongoing work via the GH issue backlog. Not a discrete project anymore.
- **"Stylesheet Validation" (old Phase 2.5)** — done. The inline-styles refactor landed April-May 2026.
- **"Revenue Optimization" (old Phase 3)** — the per-page SEO work is folded into Phase 11. Most of the "improve guest UX" subitems are already shipped (mobile redesign, S3 caching plans were never started, etc.)
- **"React Documents/Htmlpages Migration" (old Phase 4)** — mostly done. The remaining handful of unmigrated documents are tracked in the GH backlog.
- **"Container/Mason Consolidation" (old Phase 5)** — Mason2 already mostly eliminated; the remaining work is rolled into Phase 3 (React simplification).
- **"Search Enhancements & Live Search" (old Phase 5.5)** — never started. The live-search for fulltext search did land (commit `afdf34399`). Broader work deferred — would slot into a future traffic-driving round if SEO research shows search is a meaningful entry point.
- **"Guest User Optimization with S3 caching" (old Phase 6)** — **rejected** (no new cache tier; cost). The guest-page win came in-process instead: the guestchrome datastash (#4371) + guest-request diet (#4419).
- **"Mobile Display Modernization" (old Phase 6.5)** — done. Mobile redesign shipped Jan 2026.
- **"SEO Optimization" (old Phase 8)** — folded into Phase 11 traffic-driving round.
- **"Settings/Preferences Modernization" (old Phase 9.5)** — deferred indefinitely. Would be a 6-8 week refactor with diffuse benefit; doesn't fit any growth window cleanly. Revisit if there's a specific reason (e.g., user-prefs storage hits a limit).
- **"DBIx::Class ORM Migration" (old Phase 9, "Database Optimization")** — **dead as of 2026-06-29.** DBIC is the wrong shape for a node-model domain; the object-model epoch instead finishes the `Node::*` layer in place and moves it off Moose to Object::Pad (the on-ramp to core `class`). See [docs/orm-migration-plan.md](orm-migration-plan.md).
- **"FastCGI/PSGI Migration" (old Phase 7)** — same as new Phase 6, just renumbered.

---

## Quick reference: per-phase deep-dive docs

| Phase | Detail doc | Status |
|---|---|---|
| 1 | [docs/mysql-migration-plan.md](mysql-migration-plan.md) | Done; tombstone |
| 1 (schema audit) | [docs/sqitch-migration-plan.md](sqitch-migration-plan.md) | Audit done; refocused to sqitch plan 2026-06-07 |
| 2 | (no dedicated doc yet — write when work starts) | — |
| 3 | Inline-styles refactor resolved; theme backlog in [docs/css-consistency-audit.md](css-consistency-audit.md) | 2026-06 |
| 4 | (no dedicated doc yet) | — |
| 5 | [docs/cron-sidecar-design.md](cron-sidecar-design.md) | Done (sidecar, not Lambda) |
| 6 | PSGI shipped (live in prod 2026-06-08); plan in git history | Done |
| 7 | (no dedicated doc yet — small) | Right-size done; commit TBD |
| 8 | [docs/react-19-migration.md](react-19-migration.md) | Stale; needs refresh before Phase 8 |
| 9 | [docs/sqitch-migration-plan.md](sqitch-migration-plan.md) | Plan only; not started |
| Object-model epoch | [docs/orm-migration-plan.md](orm-migration-plan.md) | Decided 2026-06-29 (no DBIC; Node:: + Object::Pad); not started |
| React routing | [controller-rationalization-inventory.md](controller-rationalization-inventory.md), [test-coverage-worklist.md](test-coverage-worklist.md), [api-driven-architecture.md](api-driven-architecture.md) | Prereqs mostly done; router not built |
| 10 | (no dedicated doc yet) | — |
| 11 | (no dedicated doc yet) | — |

---

## Things to revisit periodically

- **The cost target.** $170-200/mo post-everything is the projection. If revenue trend changes (AdSense rates, traffic shifts), re-evaluate phase priorities. Specifically: if AdSense revenue lands at $300+/mo, the cost-optimization rounds become less urgent and traffic-driving rounds become more so.
- **The GH issue backlog.** Triage opportunistically; bugs that surface during phase work get fixed in that phase's PRs when possible.
- **Hard deadlines.** Watch for new ones — AWS occasionally announces unexpected EOL dates (e.g., the MySQL 8.0 sunset). Anything with a forced timeline jumps the queue. Known upcoming: `explicit_defaults_for_timestamp` removal (#4225).
- **Strategic posture changes.** This whole roadmap is built on "E2 should pay for itself." If that goal changes (e.g., decide to subsidize indefinitely, or pivot to selling something), the ordering changes too.

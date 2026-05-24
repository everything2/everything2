# Everything2 Developer Roadmap

**Created**: 2025-12-17 (original)
**Rewritten**: 2026-05-24 (this revision)
**Owner**: Jay Bonci
**Status**: Living document — strategic priorities + sequencing

This is the **high-level priority list**, not the project plan for any one phase. Each numbered phase below has (or will get) its own per-phase doc that holds the detailed plan, scope, and tracking. Treat this doc as the index — it answers "what's next and why," not "what exactly to do on day three of phase 4."

The prior version (Dec 2025, 5,281 lines) tried to be both index and per-phase plan and ended up being neither — by 2026-04 most phase plans had drifted from reality. This rewrite preserves the institutional context, the strategic posture, and the ordering rationale, and delegates per-phase detail to per-phase docs.

---

## Strategic posture

**Goal:** Everything2 pays for its own infrastructure via AdSense.

**Approach:** Alternating rounds — optimization rounds drive operating cost down, traffic-driving rounds grow revenue. Rinse, repeat. The cost target lowers with each pass; the revenue target rises.

**Current baseline** (as of 2026-05-24):
- AWS spend: ~$345/mo
- AdSense revenue: ~$140-150/mo (trending up — May running rate is ~$153)
- Gap: about $200/mo deficit
- Target after planned optimization work: ~$170-200/mo spend, with the assumption that revenue continues organic growth and traffic rounds add discrete jumps

**Constraints on sequencing:**
- **MySQL 8.4 by 2026-07-31** is a hard deadline (RDS end of standard support). Missing it triggers RDS Extended Support pricing (+$146/mo on `db.t4g.medium` — roughly tripling the DB bill). This dominates all other priorities through July.
- **PSGI/Plack migration** delivers ~$90/mo savings and capacity headroom but has no external deadline — defer until post-MySQL.
- **Flexibility > 3-year reservations** — don't lock in to current Fargate / RDS shape with long commits, because both will shrink after PSGI lands. Commit window is post-PSGI, sized to the post-migration shape.
- **Bug fix backlog runs in parallel** with planned phases — not its own numbered phase. Github issues are the unit of tracking for ambient maintenance.

---

## Where we are (2026-05-24)

**Recently shipped:**
- Inline-styles → BEM CSS refactor (Jan 2026 work, landed Apr-May 2026)
- jQuery retirement, TinyMCE removal, mobile redesign with bottom nav
- 11 dependabot bumps incl. webpack 5.106, jest-environment-jsdom rollback (incompatibility), DOMPurify 3.4, postcss 8.5.14
- Issue #4048 — NewWriteups card refactored to share `WriteupEntry` with the sidebar nodelet; LinkNode null-anchor fix
- Issue #4056 — homenode date timezone bug; spawned a 18-component dateFormat utility migration

**Currently in flight:**
- MySQL 8.4 migration — 17 child issues created (#4075-#4091) for hand-applied schema fixes
- dateFormat utility migration in working tree (not yet committed)
- nodepack compatibility audit complete ([docs/nodepack-evaluation.md](nodepack-evaluation.md))
- ORM/DBIC re-evaluation complete ([docs/orm-migration-plan.md](orm-migration-plan.md))

**Active GH issue backlog:** open issues #4007, #4009, #4011, #4015, #4018, #4019, #4026, #4030, #4031, #4032, #4033, #4039, #4042, #4043, #4052, #4058, #4060, #4061, #4062 — mix of small bugs, mobile fixes, missing features. Triaged opportunistically alongside phase work.

---

## Site history (institutional context)

Everything2 has been through several distinct architectural eras. Brief recap, because it's load-bearing for understanding why some things are the way they are.

**1999-2015 — Pure database code.** Everything (templates, server-side logic, content) lived in MySQL nodes. Code was `eval`'d at runtime from database strings. Revolutionary for its time; modern security concerns (arbitrary code execution, no audit trail) made it untenable.

**2015-2020 — Delegation pattern.** Code progressively moved from database nodes to filesystem modules (`Everything::Delegation::*`). Moose OOP introduced. Mason2 templates as interim server-side rendering layer. ~80% of code eval'd-from-database migrated to filesystem.

**2020-2025 — React integration.** REST APIs + React components for interactivity. Hybrid rendering (Mason2 server-side + React client-side). AWS containerization (Fargate, CloudFormation). The "delegation" intermediate state mostly retired.

**2025-2026 — Frontend modernization & post-Mason era.** 26 sidebar nodelets migrated to React, 200+ superdoc/htmlpage migrated to React, Mason2 mostly eliminated. Inline-styles → BEM CSS refactor (the big stalled change that landed Apr-May 2026). Mobile-first redesign shipped Jan 2026.

**2026-present — Cost rationalization & forced infrastructure work.** MySQL 8.4 migration (forced by July 2026 RDS deadline). PSGI/Plack migration (planned). Cost optimization (Fargate right-sizing, cron-to-Lambda). Selectively deepening the React modernization (React 19 upcoming).

---

## The phase list (priority-ordered)

### Phase 1 — MySQL 8.4 migration
- **Window:** now → 2026-07-31 (9 weeks, hard deadline)
- **Why first:** hard deadline + the +$146/mo Extended Support penalty for missing it
- **Detailed plan:** [docs/mysql-migration-plan.md](mysql-migration-plan.md)
- **Schema cleanup tracking:** [#4074](https://github.com/everything2/everything2/issues/4074) (umbrella) + 17 child issues
- **Approach:** Phase 0 audit (mostly done) → schema cleanup (per-table SQL in GH issues) → CFN-parameterized dummy RDS for app validation (per-discussion) → blue/green production cutover

### Phase 2 — Cost Optimization Round 1
- **Window:** August 2026 (3-4 weeks)
- **Why now:** free wins post-MySQL stability; no commits locked in yet so shape changes are easy
- **Scope:**
  - Audit the 9 public IPv4 addresses ($32/mo) — likely consolidate to 4-5
  - Investigate ALB LCU rate (8.6/hr avg is high for the request volume) — likely bot connection churn
  - Right-size current-shape Fargate (running 9% CPU avg on 2 vCPU)
  - Defer Cloudflare evaluation to Phase 9 (bot defense) since they're related concerns
- **Estimated savings:** $30-50/mo
- **No long commits yet** — wait for post-PSGI shape

### Phase 3 — React simplification
- **Window:** August-September 2026 (3-4 weeks; can overlap with Phase 2)
- **Why here:** Finish what the Jan 2026 refactor started while context is fresh; before adding new React features (social login UI)
- **Scope:**
  - Finish the 12 partially-converted inline-styles components (per [docs/inline-styles-refactor.md](inline-styles-refactor.md))
  - Migrate remaining `formatDate` callers in chat/message components (5 files) to the shared `dateFormat` utility from #4056 work
  - Audit react/components/ for other one-off utilities that should be shared (similar to dateFormat pattern)
  - Drop any unused legacy.js / pre-React holdovers
- **No deliverable doc yet** — write one when work starts

### Phase 4 — Social login integration
- **Window:** September-November 2026 (4-6 weeks)
- **Why here:** user acquisition is real revenue; prerequisite "DB sanity" is satisfied by Phase 1 completion. (See [docs/orm-migration-plan.md](orm-migration-plan.md) Path 2 for the "introduce DBIC for the new `user_oauth` table" carve-out option.)
- **Scope:**
  - OAuth providers: Google, Facebook, Apple (TBD on Apple — adds complexity)
  - New `user_oauth` table linking external provider IDs to E2 user IDs
  - Account-linking flow for existing users (match by email)
  - Updated login UI (likely uses LoginForm + auth-modal patterns already in place)
- **Open question:** whether to introduce sqitch + DBIC at the same time for the new table (Path 2 in orm-migration-plan.md). Decision deferred until work begins.
- **No deliverable doc yet** — write a plan doc before starting

### Phase 5 — Cron-to-Lambda
- **Window:** can interleave with Phase 4 (2-3 weeks of focused work)
- **Why here:** cron is the only fixed-cost class that doesn't scale with traffic; converting eliminates ~$8-12/mo IPv4 cost from cron task ENIs and ~$30/mo Fargate cost
- **Scope:** rewrite the 5-6 SQL-only cron jobs (datastash, refresh-rooms, chatterbox-cleanup, etc.) as Python Lambda functions. Keep the 2-3 jobs that need Perl business logic (iqm-recalc, sitemap-generate) as Fargate tasks for now.
- **Estimated savings:** $30-40/mo + traffic-scaling improvement
- **No deliverable doc yet**

### Phase 6 — PSGI/Plack migration
- **Window:** November 2026 → February 2027 (5-7 weeks of focused work)
- **Why here:** biggest single architectural move; needs stable DB and frontend (Phase 1-3 done) before starting
- **Detailed plan:** [docs/psgi-plack-migration-plan.md](psgi-plack-migration-plan.md) — rewritten 2026-04-28 with corrected architecture
- **Key facts:** app is CGI-style via ModPerl::Registry (not native mod_perl handlers), so the migration is shallower than originally feared. Phase A (PSGI wrapper, dev only) → Phase B (Apache::DBI replacement, ECS shape) → Phase C (staging + canary) → Phase D (post-migration Fargate right-sizing)
- **Compound benefits:** drops Fargate worker count ~5x, halves DB connection count, frees up the "always-on" memory pressure on RDS, removes Apache::DBI dependency

### Phase 7 — Post-PSGI Fargate right-sizing + 1-year commits
- **Window:** February 2027 (1-2 weeks)
- **Why here:** PSGI makes the smaller container shape viable; this is when the final cost shape is known and commits make sense
- **Scope:** drop to 1vCPU/2GB × 3 tasks (from 2vCPU/4GB × 2). Add 1-year all-upfront Compute Savings Plan sized to the new baseline. Evaluate RDS RI on the post-MySQL instance class.
- **Estimated savings:** additional $50-70/mo on top of Phase 6's PSGI savings; commits add another $30-40/mo
- **Total cost picture post-Phase-7:** projected ~$170-200/mo (vs current $345/mo)

### Phase 8 — React 19 upgrade
- **Window:** Q2 2027 (3-4 weeks)
- **Why here:** after React simplification (Phase 3) and post-PSGI stability — fewer moving parts to test against
- **Detailed plan:** [docs/react-19-migration.md](react-19-migration.md) (pre-existing, may need refresh)
- **Scope:** React 18 → 19, React Compiler adoption, deprecation cleanup. Tests against the JSX transform changes.

### Phase 9 — Schema migration framework (sqitch)
- **Window:** Q2 2027 (2-3 weeks) — can be done earlier opportunistically if Phase 4 social login pushes it forward
- **Why here:** the genuinely missing piece. Production has no migrations pipeline today; every schema change is hand-applied SQL by the maintainer. Sqitch fixes that.
- **Detailed plan:** [docs/nodepack-evaluation.md](nodepack-evaluation.md) Part 2 covers the sqitch evaluation
- **Scope:** sqitch baseline captures current schema, every schema change after baseline becomes a sqitch change file. Begins retirement of `nodepack/dbtable/` (the XML CREATE TABLE statements).

### Phase 10 — Bot defense modernization (Cloudflare or AWS WAF)
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
- **"Guest User Optimization with S3 caching" (old Phase 6)** — never started. The original premise (eliminating guest-user DB hits via S3 caching) was tied to bigger architectural changes that haven't happened. May resurface as part of Phase 10 (bot defense / edge caching).
- **"Mobile Display Modernization" (old Phase 6.5)** — done. Mobile redesign shipped Jan 2026.
- **"SEO Optimization" (old Phase 8)** — folded into Phase 11 traffic-driving round.
- **"Settings/Preferences Modernization" (old Phase 9.5)** — deferred indefinitely. Would be a 6-8 week refactor with diffuse benefit; doesn't fit any growth window cleanly. Revisit if there's a specific reason (e.g., user-prefs storage hits a limit).
- **"DBIx::Class ORM Migration" (old Phase 9, "Database Optimization")** — rescoped to Path 1 of [docs/orm-migration-plan.md](orm-migration-plan.md): modernize NodeBase in place during PSGI work (Phase 6). Full DBIC adoption stays deferred indefinitely.
- **"FastCGI/PSGI Migration" (old Phase 7)** — same as new Phase 6, just renumbered.

---

## Quick reference: per-phase deep-dive docs

| Phase | Detail doc | Status |
|---|---|---|
| 1 | [docs/mysql-migration-plan.md](mysql-migration-plan.md) | Fresh (2026-05-24) |
| 1 (schema audit) | [docs/nodepack-evaluation.md](nodepack-evaluation.md) | Fresh (2026-05-24) |
| 2 | (no dedicated doc yet — write when work starts) | — |
| 3 | [docs/inline-styles-refactor.md](inline-styles-refactor.md) tracks the 12 remaining | Updated 2026-04 |
| 4 | (no dedicated doc yet) | — |
| 5 | (no dedicated doc yet) | — |
| 6 | [docs/psgi-plack-migration-plan.md](psgi-plack-migration-plan.md) | Fresh (2026-04-28) |
| 7 | (no dedicated doc yet — small) | — |
| 8 | [docs/react-19-migration.md](react-19-migration.md) | Stale; needs refresh before Phase 8 |
| 9 | [docs/nodepack-evaluation.md](nodepack-evaluation.md) Part 2 + [docs/orm-migration-plan.md](orm-migration-plan.md) | Fresh |
| 10 | (no dedicated doc yet) | — |
| 11 | (no dedicated doc yet) | — |

---

## Things to revisit periodically

- **The cost target.** $170-200/mo post-everything is the projection. If revenue trend changes (AdSense rates, traffic shifts), re-evaluate phase priorities. Specifically: if AdSense revenue lands at $300+/mo, the cost-optimization rounds become less urgent and traffic-driving rounds become more so.
- **The GH issue backlog.** Triage opportunistically; bugs that surface during phase work get fixed in that phase's PRs when possible.
- **Hard deadlines.** Watch for new ones — AWS occasionally announces unexpected EOL dates (e.g., the MySQL 8.0 sunset). Anything with a forced timeline jumps the queue.
- **Strategic posture changes.** This whole roadmap is built on "E2 should pay for itself." If that goal changes (e.g., decide to subsidize indefinitely, or pivot to selling something), the ordering changes too.

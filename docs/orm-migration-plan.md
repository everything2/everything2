# ORM Migration Evaluation (DBIx::Class)

**Created**: 2025-12-06 (original)
**Rewritten**: 2026-05-24 (this revision)
**Status**: Evaluation / planning — no work committed
**Prior version**: The Dec 2025 draft made architectural recommendations based on an incomplete reading of the codebase. This rewrite is grounded in a fresh survey of NodeBase, Node, and SQL call patterns done 2026-05-24.

---

## The question this doc answers

Is it worth migrating Everything2's data access layer to **DBIx::Class** — and if so, what's the realistic shape of that migration given how the codebase actually uses NodeBase today?

The TL;DR up front, so you don't have to read the whole thing:

**Mostly no, with one carve-out.** A full DBIC adoption is more expensive and less rewarding than the prior plan suggested, because most SQL in this codebase bypasses the Node domain layer and goes straight to NodeBase wrappers — so a "DBIC under NodeBase, Node preserved on top" architecture doesn't actually shrink the migration scope. The recommended path is more modest: **parameterize the existing SQL surface (security + reliability win), adopt sqitch for schema migrations (the genuinely missing piece), and consider DBIC only for genuinely new tables introduced post-MySQL**. Full DBIC adoption stays as a "if there's ever a real ORM reason" deferred option, not a 6-12 month commitment.

---

## Ground truth (what the codebase actually looks like, 2026-05-24)

### NodeBase

- **2,955 LOC, 71 public methods**, 7 of which are the SQL wrappers (`sqlSelect`, `sqlSelectMany`, `sqlSelectHashref`, `sqlInsert`, `sqlUpdate`, `sqlDelete`, `executeQuery`)
- Single DBI connection per instance, mod_perl-era assumption that `Apache::DBI` does the pooling externally
- Cache integration on reads is **transparent** (`getNodeById` checks cache before SQL); on writes it's **manual** (callers must invalidate)
- Owns the multi-table-inheritance join construction (`getNodetypeTables`, `getNodeCursor`)

### Node domain layer

- **63 Moose subclasses**, all using modern Moose (`extends 'Everything::Node'` or `extends 'Everything::Node::document'`)
- Sizes range from trivial (`achievement.pm` — 6 LOC, 0 methods) to substantial (`user.pm` — 789 LOC, 57 methods)
- Methods are a mix of accessors, business logic, JSON serialization (`json_display` / `json_reference`), and permission checks
- This layer is **solid** — well-encapsulated, well-tested implicitly via API tests, no obvious modernization debt

### Where SQL actually happens

This is the key fact the old plan understated:

- **~750 SQL-method call sites in `ecore/`** — `sqlSelect` (248), `sqlSelectMany` (177), `sqlInsert` (122), `sqlDelete` (77), `sqlUpdate` (69), `sqlSelectHashref` (59)
- **~80% use bare string WHERE clauses** — not parameterized. Example: `$DB->sqlSelectHashref('*', 'pollvote', "vote_user=$user_id AND pollvote_id=$poll_id")` — quoting is ad-hoc via `$dbh->quote()` or naming conventions
- **~20% use hashref data** for INSERT/UPDATE, which IS auto-quoted: `$DB->sqlInsert('pollvote', { vote_user => $uid, ... })`
- Direct controller/API code bypasses Node objects: spot-checked `cool.pm` has 12 raw SQL calls; `polls.pm` has 5; `writeups.pm` has 0 (it correctly uses Node methods)

### Multi-table inheritance — confirmed real and still used

- Each nodetype has an `sqltablelist` field declaring which tables to join (e.g., writeup → `"document,writeup"`)
- Loading a writeup-typed node generates `SELECT * FROM node LEFT OUTER JOIN document ... LEFT OUTER JOIN writeup ... WHERE node_id=?`
- Effectively static per nodetype but technically stored as data; cached in `typeCache` and re-fetched on cache miss
- Any ORM migration has to either reproduce this pattern (DBIC ResultSetManager subclass) or move to a static schema per node type

### What's NOT there

- **Zero DBIx::Class** anywhere in the codebase
- **Zero abandoned ORM experiments** — this is a clean greenfield decision, no cruft
- **No parameterized statements** (placeholders); everything is string-interpolation + `quote()`
- **No schema migration framework** — schema lives in `nodepack/dbtable/*.xml` as literal CREATE TABLE strings

### Test coverage of the data layer

- 105 `.t` files in `t/`; 57 (54%) touch a NodeBase SQL method directly
- Tests are integration-level (against a real MySQL container), not unit-level
- Only 1 dedicated NodeBase test file (`005_sql_injection_fixes.t`); the rest test via API endpoints

---

## Why the prior plan got it wrong

The Dec 2025 plan proposed a "two-layer architecture": replace NodeBase's persistence with DBIC under the hood, preserve all 63 Node subclasses on top, expose the same external API. The argument was that this would let controllers keep doing `$writeup->author` etc. while DBIC's benefits (prepared statements, query builder, relationship navigation) become available where needed.

The plan **wasn't wrong about the dual-layer idea** — that's a defensible architecture. The problem is the **blast-radius estimate**. The plan assumed most callers went through Node objects, so refactoring NodeBase was a contained interior change. The survey shows the opposite: **the ~750 raw SQL call sites in controllers and APIs bypass Node entirely and call NodeBase wrappers directly**. So:

- "Refactor NodeBase internally" doesn't help these 750 sites — they keep calling `$DB->sqlSelect("...", "foo")` and getting back hashrefs, exactly as before. The DBIC benefits are invisible to them.
- To actually get DBIC benefits at these 750 sites, you need to refactor each one to use a `$schema->resultset('Foo')->search(...)` pattern. That's a 6-12 month chore by itself, with no incremental milestones.
- **Or** you accept that NodeBase remains the persistence boundary forever, with DBIC as an internal implementation detail no one touches — at which point you've spent significant effort to swap engines under a stable abstraction with no user-visible benefit.

The dual-layer idea works architecturally. It just doesn't deliver the value its proponents imagine.

---

## Real pain points of the current setup

Before evaluating paths forward, here are the genuine problems with NodeBase as it stands:

1. **String-WHERE-clause SQL injection surface.** ~80% of SQL calls interpolate values into WHERE strings. Callers are *supposed* to `$dbh->quote()` first, but as the April 2026 audit found ([docs/modernization-priorities.md](modernization-priorities.md) Priority 3), this is observed in the breach. Real fixes have happened (the doc's claim of "~15 vulnerabilities" was stale by the time it was re-audited), but the *pattern* is still there for new code to perpetuate.
2. **No relationship navigation.** Each Node subclass writes its own bespoke methods for relationships: `$user->writeups()`, `$writeup->author()`, etc., each a hand-written `sqlSelect`. DBIC's `has_many` / `belongs_to` would auto-generate these.
3. **No query builder.** Complex queries are constructed by string concatenation. DBIC's `->search({ field => $val, other_field => { '>' => 100 } })` is safer.
4. **No schema introspection.** You can't ask the codebase "what columns does the writeup table have." You have to read the XML in nodepack.
5. **`Apache::DBI` dependency.** NodeBase assumes Apache::DBI is doing connection pooling. With PSGI/Plack migration coming, this assumption needs to change anyway. (Resolution: `DBI->connect_cached` works under PSGI; switch is one-line.)
6. **No transaction abstraction.** Nothing in NodeBase exposes BEGIN/COMMIT cleanly; transactions are handled (when at all) by direct `$dbh->begin_work` calls scattered around.

DBIC addresses 1, 2, 3, 5. Doesn't address 4 (separate concern — sqitch). Addresses 6 only weakly (DBIC has `txn_do` but it's still on the caller).

But DBIC also brings costs:

- **Runtime overhead.** DBIC adds 30-50% latency vs raw DBI for simple queries. On a workload where 50%+ of node fetches hit NodeCache (per production Performance Insights data), this matters less than it sounds; but for the long tail it's real.
- **Memory.** Each DBIC `Result` row is a Moose object with overhead. Multiplied by NodeCache's ~3GB working set, this is non-trivial.
- **Learning surface.** DBIC's DSL is large. Future-you debugging a slow query needs to understand DBIC's query-planning behavior, prefetch strategy, etc.
- **Schema generation churn.** Every schema change means regenerating Result classes. With no migrations framework today, this is a step you skip; with sqitch + DBIC, it's one more thing to keep in sync.

---

## Realistic paths forward (ranked by ROI)

### Path 1: Don't migrate to DBIC. Modernize NodeBase in place.

**What this looks like:**
- Add a parameterized-query convenience: `$DB->sqlSelectParam('*', 'table', 'col = ?', [$value])` that auto-binds. Migrate existing call sites opportunistically.
- Replace `Apache::DBI` with `DBI->connect_cached` as part of the PSGI migration.
- Add a thin "Result row" wrapper around the hashref returns so callers can have light typing / accessors without a full ORM (`$DB->sqlSelectAsRow('Writeup', ...)`).
- Adopt sqitch for schema migrations (separate concern — see [docs/sqitch-migration-plan.md](sqitch-migration-plan.md)).
- Leave Node domain layer untouched.

**Effort:** 4-8 weeks total, spread out, low-risk. Opportunistic — every new SQL call uses the parameterized helper; old ones are migrated when touched for other reasons.

**Value:** Closes the SQL-injection pattern, makes future code safer, gets the PSGI prerequisite in place. Doesn't deliver DBIC's relationship / query-builder ergonomics — but if those weren't deal-breakers for the last 25 years they probably aren't now.

**This is my recommendation.**

### Path 2: Sqitch for schema + DBIC for new tables only

**What this looks like:**
- Path 1, plus:
- Sqitch baseline captures current schema. Every schema change post-baseline is a sqitch change file.
- **New tables added post-baseline use DBIC**. (Example: when we add `user_oauth` for social login, build it with a DBIC Result class.)
- Old tables continue to be accessed via NodeBase. No retroactive migration of existing call sites.
- Over years, the DBIC surface grows organically as new features add new tables.

**Effort:** Path 1's 4-8 weeks, plus a few days to bootstrap sqitch + DBIC infrastructure (the Schema module, the loader, the `t/` integration), plus per-new-table effort that's about the same as just writing nodepack XML would have been.

**Value:** New features get DBIC benefits where they matter. Old code is left alone. Zero retroactive risk. The ORM grows where pressure justifies it; nowhere else.

**This is a defensible alternative to Path 1.** Costs marginally more upfront for the DBIC infrastructure; pays back the first time you add a non-trivial new table.

### Path 3: Full DBIC adoption with NodeBase as backwards-compat shim

This is the prior plan's recommendation. Rebuild NodeBase as a DBIC-backed shim that exposes the same `sqlSelect` etc. API. Node subclasses unchanged on top.

**Effort:** 4-6 months of focused solo work. Significant testing, performance benchmarking, cache-integration work.

**Value:** Internal modernization, but the ~750 callsites still call `sqlSelect`-style and get hashrefs — they see no benefit. Unless you ALSO commit to a years-long callsite migration to use DBIC's query interface directly, you've done a lot of work for an invisible internal change. The performance regression risk is real (30-50% latency penalty on cache misses).

**Not recommended** as a standalone project. The argument for it only makes sense if it's a stepping stone to Path 4, which is...

### Path 4: Full DBIC adoption, including callsite migration

Path 3 plus a 6-12 month effort to migrate the 750 call sites to use DBIC's query interface directly.

**Effort:** 12-18 months of work. Has to be done in coordinated phases (you can't have controller A using DBIC and controller B using NodeBase querying the same table — connection management gets weird). Lots of regression risk.

**Value:** Full DBIC ergonomics across the codebase. New code is cleaner. Onboarding new developers is easier (DBIC is a known quantity in the Perl world; NodeBase isn't).

**Defer indefinitely.** This would be a multi-year project competing against PSGI migration, cost optimization, React simplification, social login, and the 8-9 other things ahead of it in the roadmap. The ROI doesn't pencil out for a solo-maintained codebase.

---

## What changed in this evaluation vs the prior version

| Question | Prior plan said | This eval says |
|---|---|---|
| Should we adopt DBIC? | Yes, with dual-layer architecture | Mostly no; modernize NodeBase in place |
| Effort estimate | 6-12 months | 4-8 weeks (Path 1) or 12-18 months (Path 4) |
| Risk level | High | Low (Path 1) or High (Path 4) |
| Compatibility strategy | Dual-layer with shims | Direct in-place modernization |
| What's the prerequisite | React migration done | MySQL 8.4 done; PSGI either done or in flight |

The biggest factual delta is the blast-radius re-evaluation. The prior plan implicitly assumed Node was the dominant interface; the survey shows ~750 raw SQL call sites bypassing Node, which makes any internal NodeBase swap a heavy investment for invisible gains.

---

## Sequencing (where this lands in the global roadmap)

Per [docs/DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md):

- **Path 1** ("modernize NodeBase in place" + sqitch) slots cleanly into post-MySQL work. The PSGI migration already needs to replace `Apache::DBI` with `DBI->connect_cached`; that's the natural moment to also introduce the parameterized-query helper. Sqitch adoption is independent and can land anytime post-MySQL.
- **Path 2** is Path 1 plus a small DBIC bootstrap, triggered by the first post-MySQL feature that needs a new table (likely **social login**'s `user_oauth` table). The marginal cost is low if you're already building sqitch.
- **Path 3/4** are not in the roadmap and shouldn't be unless the cost/benefit picture changes materially.

---

## What to do next (concrete)

If you agree with Path 1 (or Path 1 + 2):

1. **No code changes now** — MySQL 8.4 migration has priority through July
2. **In Phase 2 of MySQL prep** (the staging validation work), add a `sqlSelectParam` helper to NodeBase as a forward-compatible idiom. Don't refactor any callers yet; just have the helper available.
3. **PSGI work** (Phase 4 in the roadmap) replaces `Apache::DBI` with `DBI->connect_cached`. That's the natural moment to also start using `sqlSelectParam` in new code.
4. **Sqitch adoption** lands as a follow-up (currently slotted as Phase 9 in the roadmap, "Schema migration framework"). Can come earlier if MySQL upgrade work surfaces a need.
5. **Path 2's DBIC carve-out** — when social login work begins (Phase 4 in roadmap), evaluate then whether the new `user_oauth` table is a good first DBIC adoption. Could go either way; defer the decision until it's on the table.

If you eventually decide DBIC is unavoidable (Path 4), the lift can be sequenced after PSGI lands; PSGI removes a bunch of Apache-era assumptions that would complicate any ORM work.

---

## References

- [docs/sqitch-migration-plan.md](sqitch-migration-plan.md) — sqitch and schema-migration concerns (the other half of this story)
- [docs/mysql-migration-plan.md](mysql-migration-plan.md) — MySQL 8.4 migration (current focus)
- [docs/psgi-plack-migration-plan.md](psgi-plack-migration-plan.md) — PSGI migration (downstream)
- `ecore/Everything/NodeBase.pm` — the persistence layer in question
- `ecore/Everything/Node.pm` and `ecore/Everything/Node/*.pm` — the 63-subclass domain layer

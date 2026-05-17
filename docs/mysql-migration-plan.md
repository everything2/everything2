# MySQL RDS Migration & SQL Cleanup Plan

**Created**: 2026-04-27
**Owner**: Jay Bonci
**Deadline**: July 2026 (RDS engine version sunset)
**Current**: MySQL 8.0.43 in production (`cf/everything2-production.json`)
**Target**: MySQL 8.4 LTS
**Status**: Planning

---

## Executive Summary

AWS RDS sunsets the current production MySQL engine version in July 2026, forcing a major-version upgrade to 8.4 LTS. This is a hard deadline for the version bump itself. It also creates a natural forcing function to start the longer-running ORM cleanup that's been in [orm-migration-plan.md](orm-migration-plan.md) since December 2025.

**Strategic decision: decouple the two.** The version upgrade is narrow, forced, and time-boxed. The ORM cleanup is broad, optional, and multi-quarter. Trying to land both before July would couple their risk in a way that's likely to blow up.

| Workstream | Deadline | Scope | Risk |
|---|---|---|---|
| **Version bump (8.0.43 → 8.4 LTS)** | July 2026 (forced) | Engine config, query compatibility, RDS upgrade | Medium — well-trodden path, blue/green safety net |
| **SQL injection fixes (15 known)** | Before version bump | ~15 raw `do()` interpolation sites | Low — mechanical, makes upgrade safer |
| **Schema migration framework** | Before version bump (ideal) | Establish DDL versioning (sqitch or homegrown) | Low — new tooling, doesn't touch app code |
| **DBIx::Class ORM adoption** | Post-deadline (Q3+ 2026) | Phased, feature-flagged, 6–12 months | High — touches core infrastructure |

---

## Current State

**Production RDS** (`cf/everything2-production.json`):
- Engine: `mysql` 8.0.43
- Parameter family: `mysql8.0`
- Multi-AZ disabled, deletion protection on, Performance Insights on
- Slow query and error logs export to CloudWatch

**Connection config** (`ecore/Everything/NodeBase.pm:98`):
- `mysql_enable_utf8mb4 => 1` ✅ (good — utf8mb4 is the 8.4 norm)
- DBD::mysql via `Apache::DBI` connection pooling
- No explicit transaction management in wrappers

**SQL access pattern audit** (verified 2026-04-27 — see findings below):
- ~433 queries via wrapper functions (`sqlSelect`, `sqlUpdate`, `sqlInsert`) using `quote()` — generally safe
- 5 calls via `getDatabaseHandle()->do(...)`, **all using placeholders** (audited line by line)
- 18 calls via `$dbh->do(...)`, **all using placeholders or constant DDL** (audited line by line)
- ~21 `GROUP BY` clauses — already compliant with ONLY_FULL_GROUP_BY (default in MySQL 8.0+, which we run today)
- Zero `STRAIGHT_JOIN`, zero FULLTEXT indexes, zero stored procedures (already migrated)
- Zero collisions between schema identifiers (330 backticked names from `nodepack/dbtable/*.xml`) and the MySQL 8.4 reserved word list (263 words)
- Zero `utf8` (utf8mb3) usage — schema is uniformly `utf8mb4_0900_ai_ci`

**Bottom line on the audit**: the doc previously claimed "~15 SQL injection vulnerabilities." That number is stale. As of this audit, every `do()` call site uses placeholders. The pre-upgrade SQL hardening that older docs called for has already happened (likely during the Jan 2026 work). What remains for the migration is narrow: auth plugin compatibility, schema migration framework setup, and validation against an 8.4 instance.

**Schema management**:
- Schema definition embedded in `NodeBase.pm` and node-type metadata in nodepack XML
- No DDL versioning, no migration framework
- `storedprocedures.sql` is intentionally empty

**Tests**:
- 90+ files in `t/`, including `005_sql_injection_fixes.t`
- Integration tests run against a real MySQL container — these will catch most version-incompatibility regressions

---

## Why a Version Bump Is Disruptive

Even though MySQL 8.0 → 8.4 isn't a *huge* leap, it has real teeth for a codebase like ours:

1. **`mysql_native_password` is deprecated/removed by default in 8.4**. DBD::mysql connection setup may need an explicit auth plugin or a server-side `--mysql-native-password=ON` parameter. *This is the most likely break-on-day-one issue.*
2. **ONLY_FULL_GROUP_BY is enforced by default**. 12 `GROUP BY` queries need review. Some will need `ANY_VALUE()` wrapping or explicit aggregation.
3. **Reserved word changes**. New reserved words in 8.1–8.4 may collide with column or table names (we should grep).
4. **`utf8mb3` is fully deprecated**. We're on `utf8mb4` already, but any legacy columns still on `utf8` (which aliases to utf8mb3 in 8.0) need explicit conversion.
5. **Replication and binlog format changes**. Mostly invisible to app code, but matters for the RDS upgrade itself.
6. **Performance schema changes**. Minor, but our slow-query analysis tooling may need adjustments.

None of these are dealbreakers. They're the standard checklist.

---

## Phased Plan

### Phase 0: Audit & Setup (May 2026 — ~1 week)

**Goal**: Know exactly what could break, and have a safe place to test.

Static audits already complete (2026-04-27):
- ✅ `getDatabaseHandle()->do(...)` calls — 5 found, all use placeholders
- ✅ `$dbh->do(...)` calls — 18 found, all use placeholders or constant DDL
- ✅ `GROUP BY` queries — 21 found, all already compliant with ONLY_FULL_GROUP_BY
- ✅ MySQL 8.4 reserved word collisions — none in schema (330 idents vs. 263 reserved)
- ✅ `utf8`/`utf8mb3` usage — none, schema is `utf8mb4_0900_ai_ci` throughout

Still to do:
- [ ] Spin up an `e2dev` container variant pinned to MySQL 8.4 (`docker/e2db/Dockerfile`) — call it `e2db-84`
- [ ] Run the full `t/` test suite against MySQL 8.4 locally; collect failures into a tracking doc
- [ ] Validate `mysql_native_password` / `caching_sha2_password` connection behavior with DBD::mysql against 8.4 — this is the highest-risk day-one issue
- [ ] Decide on schema migration framework (sqitch vs. homegrown) — pick something light

**Deliverable**: a tracking doc with every concrete incompatibility issue found from running tests against 8.4.

### Phase 1: Pre-Upgrade Cleanup (May–early June 2026 — ~2 weeks)

**Goal**: Establish the schema migration framework and add CI coverage for the target version.

*(SQL injection cleanup that older versions of this plan called for is already done — see audit in "Current State" above.)*

- [ ] **Establish schema migration framework** — directory structure, first baseline migration captures current state. This also addresses the `nodepack/dbtable/` retirement path (98 XMLs whose CREATE TABLE statements move to versioned SQL migrations)
- [ ] **Add a CI gate**: tests run against both MySQL 8.0 and 8.4 in parallel until cutover
- [ ] **Whitelist table names** in any remaining code that constructs `sqlXxx()` calls with dynamic table names (a small handful of admin tools — verify these still exist)
- [ ] *(Optional)* `ANY_VALUE()` audit on the 21 `GROUP BY` queries — they're already compliant under our current sql_mode, but explicit aggregation makes intent clearer

**Deliverable**: schema migration framework live, dual-engine CI passing.

### Phase 2: Compatibility Validation (June 2026 — ~2 weeks)

**Goal**: Prove on staging-equivalent infra that the app works on 8.4.

- [ ] Stand up an RDS MySQL 8.4 instance (could be a dedicated dev/staging account) using the production CloudFormation template with `EngineVersion: "8.4.x"`
- [ ] Restore a recent prod snapshot to it
- [ ] Point a non-prod ECS service at it; run smoke tests, then a full e2e pass
- [ ] Soak under realistic traffic (replay or canary) for ≥48h; watch for slow query regressions in CloudWatch
- [ ] Validate connection auth (`mysql_native_password` handling)
- [ ] Validate Apache::DBI connection pooling works against 8.4

**Deliverable**: signed-off go/no-go for production upgrade.

### Phase 3: Production Upgrade (mid-June 2026)

**Goal**: Execute the version bump with minimum drama.

**Recommended path: RDS Blue/Green Deployment**. AWS supports this for MySQL — it provisions a green replica at the new version, lets you cut over with seconds of downtime, and provides easy rollback. Avoid in-place upgrades for a major-version change in prod.

- [ ] Create blue/green deployment (CloudFormation update or console)
- [ ] Verify replication lag is zero
- [ ] Switch over during a low-traffic window
- [ ] Monitor for 24h; keep blue around for rollback
- [ ] After 1 week of stability, retire the blue side
- [ ] Update `cf/everything2-production.json` `EngineVersion` and parameter family (`mysql8.4`)

**Deliverable**: production on MySQL 8.4 LTS. Deadline met.

### Phase 4: ORM Cleanup (Q3 2026 onward — open-ended)

**Goal**: Begin executing the existing [orm-migration-plan.md](orm-migration-plan.md) — DBIx::Class as persistence layer, Everything::Node preserved as domain layer.

This is decoupled from the deadline and starts only after the version bump is solid. Approach should be feature-flagged and incremental:

- Pilot: pick one node type (suggest `room` or `weblog` — small, contained, low-traffic) and convert its persistence to DBIC while keeping `Everything::Node::room` as the public interface
- Validate: dual-write or dual-read in shadow mode, confirm parity
- Expand: convert one type per sprint
- Do **not** rip out `NodeBase.pm` until coverage is comprehensive

Estimated 6–12 months for full conversion. The forcing function from the version bump is mostly: "we now have a schema migration framework and a clean SQL surface, which makes DBIC adoption much less scary."

---

## Open Questions / Decisions Needed

1. **Exact RDS sunset date** — The user mentioned "July." Need to confirm the specific AWS notice and target a window 4 weeks before. (Check AWS console for the maintenance event on the cluster.)
2. **8.4.x patch version target** — Use the latest available in RDS at the time. AWS lags upstream by a few months.
3. **Schema migration tool** — sqitch (battle-tested, Perl-friendly, requires its own bootstrap) vs. homegrown numbered SQL files (simple, less safety). Lean sqitch unless it's overkill.
4. **Dev container MySQL version** — bump local Docker DB to 8.4 once Phase 1 is green, so all dev work runs against the target version.
5. **Blue/green vs. read replica promotion** — blue/green is preferred but adds short-term cost; confirm the spend is acceptable.
6. **CI matrix expansion** — running tests against two engine versions doubles CI time. Acceptable for the ~6 weeks until cutover; revert after.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `mysql_native_password` auth breaks on connect | Medium | Critical | Validate in Phase 0; configure RDS parameter group if needed |
| `GROUP BY` strict mode breaks ad-hoc admin queries | High | Low | Phase 1 audit catches them; admin queries are not user-facing |
| Slow-query regressions on 8.4 query optimizer | Medium | Medium | Phase 2 soak testing; CloudWatch slow query log |
| RDS blue/green cutover fails | Low | Critical | Keep blue side for ≥1 week; rollback path is provisioned |
| ORM cleanup attempted in same window as version bump | If we're not careful | Critical | Explicitly out of scope per this plan; revisit Q3 |
| Schema drift from no-migration-framework history | Already exists | Medium | Phase 1 establishes baseline; we live with current drift |

---

## Out of Scope (Explicitly)

- **Aurora MySQL migration**: separate decision, larger scope, not on July deadline
- **MariaDB migration**: cross-engine, much higher risk, no value for our workload
- **Sharding / read replicas / cache layer rework**: orthogonal to this plan
- **DBIx::Class adoption before July**: explicitly deferred to Phase 4

---

## References

- [docs/orm-migration-plan.md](orm-migration-plan.md) — long-form ORM cleanup plan (Dec 2025)
- [docs/modernization-priorities.md](modernization-priorities.md) — Priority 3 (Database Security)
- [docs/DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md) — Phase 11 (MySQL 8.4 Migration), Phase 9 (Database Optimization)
- [cf/everything2-production.json](../cf/everything2-production.json) — production RDS configuration
- [ecore/Everything/NodeBase.pm](../ecore/Everything/NodeBase.pm) — connection setup, query wrappers

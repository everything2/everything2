# Sqitch Schema Migration Plan — retiring `nodepack/dbtable`

**Created:** 2026-05-24 (as `nodepack-evaluation.md`) · **Refocused:** 2026-06-07
**Owner:** Jay Bonci
**Status:** Planning — deferred to the post-PSGI cleanup batch (sqitch is the named enabler in [modernization-dependency-tree.md](modernization-dependency-tree.md))

> **Status (verified 2026-11-16):** **not started.** No sqitch plan/change files in the repo and no
> adoption issue filed. PSGI is done, so this is now reachable whenever it's picked up. DBIx::Class was
> rejected on 2026-06-29 (see [orm-migration-plan.md](orm-migration-plan.md)), so sqitch is the only
> schema-versioning path. Also note (2026-06-29 correction): `nodepack/dbtable/` is a dev-bootstrap
> reference snapshot, not what applies prod schema — prod changes are hand-applied SQL today — so the
> baseline must come from a prod `--no-data` dump.

> **Predecessor note.** This doc began as a MySQL 8.4 compatibility audit of `nodepack/dbtable/*.xml`
> (zero-date defaults, missing PKs, `int(N)` widths, FULLTEXT). **That audit is complete and shipped** —
> the zero-date family (#4074), the PK promotions (#4092), and the 8.4 engine cutover itself
> (#4226, done 2026-06-07) are all live in prod. The audit half is retired; it survives in git history.
> What remains — and what this doc now is — is the strategic question that audit surfaced: replacing
> nodepack's *schema-management* responsibility with a real migration tool.

---

## The problem: nodepack has no migration story

`nodepack/dbtable/` holds 94 XML files (Nov 2026), one per table, each wrapping a literal `CREATE TABLE` statement
that `ecoretool import` applies to a fresh database. It works and it's load-bearing, but as a *schema
management* layer it has structural gaps that get more painful as change frequency rises:

1. **No concept of "applied migrations."** Import is idempotent ("create if absent, replace content if
   present"), but there's no schema version, no diff between versions, no audit trail, no transactional
   batching. You can't ask "what version is this database at?" or "what changed between A and B?"
2. **No rollback.** Every schema change is a one-way door. A bad column rename in prod can't be reverted
   by re-importing — that doesn't undo the applied DDL. A proper tool makes the inverse change first-class.
3. **Schema lives in `CREATE TABLE` strings.** To change schema you edit the string and re-import. No DSL,
   no diff, no verification — a typo yields a working dev DB and a broken prod schema.
4. **Drift is unenforced.** The dbtable XMLs came from a prod dump and aren't edited often, so dev/prod
   stay aligned *by habit, not by mechanism*. Nothing stops someone editing `node.xml`, passing dev tests,
   and silently diverging prod.
5. **Custom tooling for a solved problem.** `ecoretool` is bespoke Perl; the community has mature,
   rigorous schema-migration tools.

These are the two failure modes that matter most as the codebase modernizes: **silent dev/prod schema
drift** and **no rollback path**.

---

## Alternatives considered

| Tool | Approach | Runtime | Fit for E2 |
|---|---|---|---|
| **sqitch** | Numbered SQL change files with explicit dependencies; `deploy` / `verify` / `revert` scripts per change | **Perl + SQL** | **High** — Perl-native (no new runtime), plain SQL (no DSL to learn), and `deploy`/`verify`/`revert` maps cleanly onto MySQL change management |
| **Atlas** (atlasgo.io) | Declarative schema (HCL or SQL); diffs current vs. desired to *generate* migrations | Go binary | High — "schema as source of truth in the repo" fits the nodepack mental model; but adds a Go toolchain |
| **Flyway** | Numbered SQL files + a simple history table | Java/Docker | Medium — solid, but a JVM in the build/deploy path is operational weight we don't want |
| **Liquibase** | Rich XML/YAML/JSON change-sets, rollback-aware | Java/Docker | Low — a JVM **and** an XML/YAML DSL, i.e. the *opposite* of "stop hand-maintaining XML" |
| **DBIx::Class::Migration** | Migrations tied to a DBIC Result schema | Perl | **Ruled out** — DBIC was rejected 2026-06-29 ([orm-migration-plan.md](orm-migration-plan.md)) |
| **Plain numbered `.sql` + a tiny runner** | `001_init.sql`, `002_*.sql`; runner records applied versions in a `_migrations` table | shell glue | Viable — lowest abstraction, works for a solo maintainer, but you end up re-implementing sqitch's deploy/verify/revert by hand |

## Why sqitch

It wins on the axes that actually matter for this codebase:

- **No new runtime.** It's Perl — the same stack the app, `ecoretool`, and the test suite already run on.
  No JVM, no Go binary in the build/deploy pipeline.
- **Plain SQL, no DSL.** Changes are SQL scripts, not an XML/YAML/HCL abstraction. That's a deliberate move
  *away* from hand-maintained XML, not sideways into another markup (which rules out Liquibase).
- **`deploy` / `verify` / `revert` are first-class** — directly addressing the two gaps that hurt:
  rollback becomes a real artifact, and `verify` scripts let CI assert the schema actually reached the
  intended state (drift enforcement).
- **No ORM prerequisite.** Unlike DBIx::Class::Migration, it's independent of any ORM (and DBIC is now
  rejected outright), so it can land whenever it's picked up.

Atlas was the only serious runner-up; its declarative diff model is attractive, but the extra toolchain and
the fact that sqitch's imperative deploy/verify/revert maps more obviously onto careful prod change
management tipped it. Revisit Atlas only if hand-authoring change scripts becomes the bottleneck.

---

## Scope: schema vs. everything-else

**The split that matters is schema vs. content.** nodepack does many jobs; most aren't broken and shouldn't
be touched:

- `dbtable/` — the schema. **This is the only part sqitch replaces.**
- `nodetype/`, `setting/`, `achievement/` — small structured content, edited rarely. nodepack is fine here.
- `superdoc/`, `nodelet/` (and the already-deleted `htmlpage/`, `htmlcode/`, `opcode/`) — legacy content
  being deleted as the React migration finishes. **Don't modernize the storage of something you're deleting.**
- `_data/` — operational data (links, nodegroup membership) that arguably shouldn't be in a schema repo at
  all; out of scope for this plan.

So sqitch comes in *alongside* nodepack, taking only the schema responsibility.

---

## Adoption plan

1. **Bootstrap a baseline.** Generate the initial sqitch change from a `mysqldump --no-data` of the prod
   schema — one baseline migration capturing current state.
2. **Each schema change becomes a sqitch change** — a `deploy/` script, a `verify/` script, and a `revert/`
   script, with explicit dependencies.
3. **`ecoretool import` stops creating tables.** Tables come from sqitch (`sqitch deploy`) for both dev
   bootstrap and prod; nodepack continues to provide the *content* data only.
4. **Deprecate `nodepack/dbtable/`.** Once sqitch is established and the bootstrap path is cut over, the XML
   `CREATE TABLE` statements are redundant and can be deleted — the long-wanted `dbtable` retirement.

---

## Sequencing

- **Post-PSGI (PSGI is now done).** It's an enabler in the [dependency tree](modernization-dependency-tree.md)
  for the schema-touching cleanups and runs in parallel with the object-model epoch.
- **It's a hub.** Several deferred issues are blocked on having versioned migrations: **#4225**
  (`explicit_defaults_for_timestamp` retirement — its deprecation now fires live under 8.4), **#4173**
  (drop denormalized `numwriteups`), **#4180** (real soft-delete tombstoning), **#4184** (settings → JSON),
  plus the "post-sqitch" retirements **#4249** (nodepack/ecoretool schema mechanism) and **#4482**
  (legacy searchwords backend). Landing sqitch unblocks that whole cluster.
- **No adoption issue yet** — file one when the post-PSGI batch reaches it, pointing here for the plan.

---

## References

- [modernization-dependency-tree.md](modernization-dependency-tree.md) — where sqitch sits as an enabler hub
- [orm-migration-plan.md](orm-migration-plan.md) — the object-model plan (DBIx::Class rejected; finish `Node::*` on Object::Pad)
- `ecoretool/ecoretool.pl` — the current import/export CLI (loses only its table-creation role)
- `nodepack/dbtable/*.xml` — the dev-bootstrap schema snapshot being retired

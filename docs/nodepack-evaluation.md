# nodepack: compatibility audit + modern alternatives

**Created**: 2026-05-24
**Owner**: Jay Bonci
**Status**: Discussion / planning

This document does two things:

1. **Inventories the MySQL 8.4 compatibility risks** lurking in `nodepack/dbtable/*.xml` — the CREATE TABLE statements that get applied to a fresh database via `ecoretool import`. These are the same DDL fragments the production database was built from, so the risks are present in prod too.
2. **Surveys modern alternatives to nodepack** for the longer-running question of whether to keep this custom XML serialization layer at all.

The first half is actionable for the July 2026 MySQL upgrade. The second half is exploratory — no immediate action required.

---

## Part 1 — Compatibility audit

`nodepack/dbtable/` contains 98 XML files, one per database table, each with a `<_create_table_statement>` element holding the literal CREATE TABLE DDL. The DDL was generated from a prod schema dump, so the audit below is effectively a prod schema audit too.

### Summary table

| Concern | Count | Severity | Notes |
|---|---|---|---|
| `DEFAULT '0000-00-00'` zero-date columns | **18 columns in 17 tables** | **HIGH** | Rejected under MySQL 8.4 default `sql_mode` |
| Tables without `PRIMARY KEY` | 5 | MEDIUM | Performance / replication concern; blocks if `sql_require_primary_key` is enabled |
| `int(N)` display-width usage | 4 occurrences | LOW | Deprecated since 8.0, still parses; produces warnings |
| `FULLTEXT` index | 1 (`node.title`) | LOW | Supported in 8.4 InnoDB; minor behavioral diffs possible |
| `utf8` / `utf8mb3` / `latin1` charsets | 0 | — | All 98 tables already `utf8mb4_0900_ai_ci` ✓ |
| Non-InnoDB engines | 0 | — | All InnoDB ✓ |
| `ROW_FORMAT=COMPRESSED` | 0 | — | All default DYNAMIC ✓ |
| `GENERATED`/virtual columns | 0 | — | Not used |
| `ZEROFILL` columns | 0 | — | Not used |
| Foreign key constraints | 0 | — | E2's data model has no FKs |
| Stored procedures / triggers | 0 | — | None |
| Reserved word identifiers | 0 | — | Audited 2026-04-27 against the 8.4 reserved list |

### The dominant risk: zero-date defaults

MySQL 8.4's default `sql_mode` includes both `NO_ZERO_DATE` and `NO_ZERO_IN_DATE`. Under these modes:

- **At CREATE TABLE time**: a column declared `datetime NOT NULL DEFAULT '0000-00-00 00:00:00'` is rejected — `Invalid default value for 'column_name'`.
- **At INSERT/UPDATE time**: inserting a `'0000-00-00'` value into a date column is rejected.
- **At SELECT time**: reading an existing row that already contains `'0000-00-00'` typically succeeds (you get back the zero-date), but operations on that value (date arithmetic, comparisons under STRICT mode) may fail or return NULL.

The 17 affected tables and 18 columns:

| Table | Column | Notes |
|---|---|---|
| **`node`** | `createtime` | Master table; every node has a createtime. Highest impact. |
| `e2node` | `updated` | Touched on every writeup mutation |
| `weblog` | `linkedtime` | |
| `pollvote` | `votetime` | |
| `nodetracker` | `lasttime` | |
| `notified` | `notified_time` | |
| `podcast` | `pubdate` | Sparse data |
| `roomdata` | `lastused_date` | `date` (not datetime), `DEFAULT '0000-00-00'` |
| `heaven` | `createtime` | Deleted-node archive |
| `tomb` | `createtime` | Deleted-node archive |
| `krut_tomb` | `createtime` | Spam-killed archive |
| `nodebak` | `createtime`, `locktime` | Backup-on-edit |
| `dbstats` | `tstamp` | Stats logging |
| `lastreaddebate` | `dateread` | Per-user read tracking |

### What we don't know without prod access

The schema-level fix is easy: change `DEFAULT '0000-00-00 00:00:00'` to `DEFAULT '1970-01-01 00:00:01'` or make the column nullable with `DEFAULT NULL`. But the more dangerous question is **whether existing prod rows contain zero-date values**.

That's a data audit, not a schema audit. We can't answer it from this dev environment. Two ways to find out:

1. Run `SELECT COUNT(*) FROM <table> WHERE <date_col> = '0000-00-00 00:00:00'` against each of the 18 columns in production. This is read-only and cheap.
2. Stand up a snapshot-restored 8.4 instance per the migration plan's Phase 2b — the upgrade itself will surface any row that fails strict-mode validation.

Best plan: do (1) first because it's free signal. Then (2) catches anything (1) missed.

### Tables without PRIMARY KEY

- `cachedeltaversion` — single-row counter table; technically PK-less is fine here, but adding `PRIMARY KEY (deltaversion)` costs nothing
- `lastreaddebate` — currently `(user_id, debateroot_id)` is logically unique; promote to PK
- `nodeparam` — has `UNIQUE KEY nodeparamidx (node_id, paramkey)`; promote to PK
- `reparenting_writeups` — small admin table; add PK on `node_id`
- `searchwords` — search index, `KEY searchindex (word, node_id, soundex_value)`; could promote to PK

These don't block the 8.4 upgrade under default config, but if you ever enable `sql_require_primary_key` (a common hardening default) they will. The fixes are mechanical and worth doing alongside the zero-date cleanup.

### `int(N)` display-width

Four occurrences of `tinyint(1)`. MySQL 8.0 deprecated the integer display-width syntax — `int(11)`, `tinyint(1)`, etc. — because it never meant what users assumed it meant. The deprecation is a warning, not an error. 8.4 still accepts it. SHOW CREATE TABLE in 8.4 will reformat to `tinyint` (without `(1)`) on the next time the table is rebuilt. Effectively a non-issue, but worth knowing the round-trip won't be byte-identical.

### `FULLTEXT` index on `node.title`

InnoDB FULLTEXT has been stable since 5.6 and works fine in 8.4. The risk is minor behavioral diffs (ranking algorithm tweaks, stopword changes) that might shift search result orderings. Verify the writeup-search and node-search code paths in Phase 2b.

### What's NOT a problem

The audit ruled out a long list of common migration headaches:
- Charsets are already `utf8mb4` everywhere — no `utf8mb3` deprecation pain
- No column-level charset/collation overrides — clean
- No legacy storage engines (no MyISAM, MEMORY, etc.)
- No row-format compressions — default DYNAMIC works on 8.4
- No foreign key constraints — nothing to revalidate
- No stored procedures, triggers, or views — nothing to re-parse
- No reserved word collisions — verified separately
- No `mysql_native_password` references in nodepack (that's a server-side auth concern, handled separately in the migration plan)

### Recommended cleanup before the 8.4 upgrade

Two PRs, both small, both reviewable independently of the migration itself:

**PR 1 — Zero-date default cleanup** (estimated effort: 1 day)
- Change `DEFAULT '0000-00-00 00:00:00'` → `DEFAULT '1970-01-01 00:00:01'` in all 18 columns
- (Why `1970-01-01 00:00:01`? It's the lowest valid UNIX epoch value that passes both `NO_ZERO_DATE` and `NO_ZERO_IN_DATE`. The legacy "never" semantics map cleanly: any row whose date is `'1970-01-01 00:00:01'` means "never set", same as the old zero-date meaning.)
- Code review: search for explicit `'0000-00-00'` comparisons in ecore/ — if any code does `WHERE createtime != '0000-00-00 00:00:00'` as a "is this real?" check, update it.
- Apply via `ecoretool import` against the dev DB, run tests.
- Doesn't change prod yet — but lines up the schema definition with what we want 8.4 to accept.

**PR 2 — Promote unique keys to PKs** (estimated effort: half a day)
- Add `PRIMARY KEY (deltaversion)` to `cachedeltaversion`
- Promote `UNIQUE KEY nodeparamidx` → `PRIMARY KEY` on `nodeparam`
- Add `PRIMARY KEY (user_id, debateroot_id)` to `lastreaddebate`
- Add `PRIMARY KEY (node_id)` to `reparenting_writeups`
- Decide whether to add a synthetic `id INT AUTO_INCREMENT` to `searchwords` (its tuple isn't naturally unique due to soundex collisions)

Neither PR is required for the 8.4 upgrade to succeed. Both make the upgrade smoother and the schema healthier. PR 1 specifically addresses an explicit incompatibility; PR 2 is defensive.

---

## Part 2 — Modern alternatives to nodepack

### What nodepack is, structurally

`nodepack/` is an XML-based serialization of **everything that lives in the E2 database as a "node"**, including:

| Subdir | Purpose | Count |
|---|---|---|
| `dbtable/` | Schema (CREATE TABLE statements) | 98 |
| `nodetype/` | Type system definitions | 53 |
| `superdoc/` | Page templates (mostly migrated to React) | 148 |
| `restricted_superdoc/` | Admin-only superdocs | 45 |
| `htmlpage/` | Legacy server-rendered pages | 86 |
| `htmlcode/` | Server-side code snippets | 70 |
| `opcode/` | Server-side actions | 44 |
| `nodelet/` | Sidebar nodelets (mostly migrated) | 26 |
| `achievement/` | Achievement definitions | 45 |
| `setting/` | Configuration | 33 |
| `stylesheet/` | CSS themes (also in `www/css/`) | 22 |
| `nodegroup/`, `notification/`, `container/`, `linktype/`, `mail/`, `maintenance/`, `feedback_policy/`, etc. | Various structured content | ~40 |
| `_data/` | Cross-cutting relations (links, nodegroup membership, nodeparam) | 3 |
| **Total** | | **~930 XMLs** |

`ecoretool/ecoretool.pl` (a Perl CLI with import/export/bootstrap/nodeidmove plugins) round-trips these to/from MySQL. The schema is content; node types are content; settings are content; templates are content. Everything is a node.

### Why nodepack exists at all

E2's original 1999 design stored code, templates, and content all in the database — there was no concept of "files" for application logic. As the codebase modernized (eval-from-DB eliminated, code moved to filesystem), there needed to be a way to **version-control the things that genuinely had to stay in the database**: schema definitions, type metadata, configuration, achievement rules, etc. nodepack is that serialization layer. It works, and it's load-bearing — most of `ecore/` references content that's defined in nodepack XMLs.

### What makes it dated

1. **One serialization format for unrelated concerns.** Schema (`dbtable/`), templates (`superdoc/`), code (`htmlcode/`), and settings (`setting/`) all share the same XML envelope and the same import/export tool. There's no separation of concerns: a schema change and a template change look the same to git.

2. **No migration story.** nodepack import is idempotent ("create the table if it doesn't exist, replace the node content if it does"), but there's no concept of "applied migrations" — no way to ask "what schema version is this database at?" or "what changed between version A and B?" Schema changes are made by editing the dbtable XML, then re-running import; there's no down-migration, no audit trail, no transactional batching.

3. **Custom tooling for a solved problem.** `ecoretool` is ~6 Perl files and a CLI plugin system, written specifically for this codebase. The community has built mature alternatives (sqitch, Flyway, Atlas, Liquibase) that solve schema migrations more rigorously.

4. **Schema lives in CREATE TABLE strings.** The dbtable XMLs hold literal `CREATE TABLE` DDL. To make a schema change you edit the string, re-run import. There's no DSL, no diff tool, no rollback. A typo in the XML can produce a working dev DB but a broken prod schema.

5. **Mixes data model with operational data.** `_data/links.xml` is gigabytes (in prod) of link relationships. Round-tripping that through XML import/export is slow and fragile. It probably shouldn't be in a "schema source-of-truth" repo at all.

### Modern alternatives — survey

| Tool | Approach | Language | Schema-vs-data | Fit for E2 |
|---|---|---|---|---|
| **sqitch** | Numbered SQL change files with explicit dependencies, deploy / verify / revert hooks | Perl + SQL | Schema only | **High** — Perl-native, no new runtime, deploy/verify/revert maps well to MySQL blue/green |
| **Atlas** (atlasgo.io) | Declarative schema in HCL or SQL; diff between current and desired state generates migrations | Go binary + SQL | Schema only | **High** — declarative model fits well for "schema as source of truth in repo" |
| **Flyway** | Numbered SQL files, simple migration history table | Java/Docker | Schema only | Medium — Java runtime adds operational complexity |
| **Liquibase** | XML/YAML/JSON change-sets (rich DSL), rollback-aware | Java/Docker | Schema only | Medium — XML/YAML DSL is the *opposite* of "stop using XML" |
| **DBIx::Class::Migration** | Migration framework tied to a DBIC Result schema | Perl | Schema only | Pending — requires DBIC adoption first (post-deadline, per orm-migration-plan.md) |
| **Plain numbered .sql files + small runner** | `migrations/001_initial.sql`, `002_add_column.sql`; runner tracks applied versions in a `_migrations` table | Whatever shell glue | Schema only | Highest simplicity, lowest abstraction. Works for solo maintainer. |
| **pg_dump-style "schema dump + apply"** | Treat the schema as a single dump file regenerated on every change | Native MySQL tooling | Schema only | Doesn't handle migrations; only useful for bootstrap |

### Recommendation: sqitch for the schema half, leave the rest of nodepack alone (for now)

**The split that matters is schema vs. everything-else.** Nodepack does many jobs and most of them aren't broken:

- `dbtable/` — the schema. **This is the part worth migrating.**
- `nodetype/`, `setting/`, `achievement/` — small structured content, edited rarely. nodepack works fine for these.
- `superdoc/`, `htmlpage/`, `htmlcode/`, `opcode/`, `nodelet/` — legacy content that's getting deleted as React migration finishes. Don't invest in modernizing the storage of a thing you're deleting.
- `_data/` — operational data that probably doesn't belong in source control at all (in prod, anyway).

So a focused replacement: **introduce sqitch for schema migrations alongside nodepack's continued use for everything else.** Concretely:

1. **Bootstrap a sqitch baseline** that captures the current schema. Generate it from a `mysqldump --no-data` of the prod schema.
2. **Each schema change becomes a sqitch change** — a `deploy/` SQL script, a `verify/` script, and a `revert/` script.
3. **`ecoretool import` still runs for the dev bootstrap** — but it stops creating tables. Tables come from sqitch. nodepack just provides the content data.
4. **Eventually deprecate `nodepack/dbtable/`** — once sqitch is established, the XML CREATE TABLE statements are redundant and can be deleted.

For the immediate MySQL 8.4 work, the schema changes (zero-date cleanup, PK promotions) can be made *either* in nodepack/dbtable/ XMLs *or* in sqitch — pick whichever has less risk. Sqitch is the strategic answer; nodepack is the path of least resistance for getting the 8.4 upgrade done on schedule.

### Why not just stay on nodepack forever?

Two specific failure modes:

1. **Schema-content drift between dev and prod.** Today this is mostly avoided because the dbtable XMLs came from a prod dump and aren't edited often. But there's no enforcement. Someone could edit `node.xml` to add a column, run dev tests against it, and prod would diverge silently because there's no migration to apply.

2. **No rollback story.** Every schema change is a one-way door. If a column rename breaks something in prod, the only reversal is editing the XML again and reimporting — which doesn't actually revert the prod schema. A proper migration tool makes the inverse change first-class.

Both of these become more acute as the codebase modernizes and changes get more frequent.

### What this means for the July 2026 MySQL upgrade

**Don't try to migrate nodepack and bump MySQL in the same window.** The schema cleanup for 8.4 compatibility (the zero-date defaults, the missing PKs) should land via the existing nodepack mechanism — direct edits to the dbtable XMLs — because that's the lowest-risk path for the deadline.

Sqitch adoption is a follow-up project, post-deadline, ideally aligned with the broader DBIx::Class ORM work or run in parallel with it.

---

## Appendix — quick audit commands

For reproducibility / future re-runs:

```bash
# Zero-date defaults
grep -nE "'0000-00-00" nodepack/dbtable/*.xml

# Tables without PRIMARY KEY
for f in nodepack/dbtable/*.xml; do
  grep -q "PRIMARY KEY" "$f" || echo "$(basename "$f" .xml)"
done

# Charset survey
for cs in utf8 utf8mb4 utf8mb3 latin1; do
  echo "$cs: $(grep -lE "CHARSET=${cs}[^a-z0-9_]|CHARSET=${cs}\$" nodepack/dbtable/*.xml | wc -l) files"
done

# Reserved word collisions (against MySQL 8.4 reserved list)
grep -h '^  `' nodepack/dbtable/*.xml | grep -oE '`[^`]+`' | sort -u \
  | tr -d '`' | tr '[:lower:]' '[:upper:]' | sort -u > /tmp/e2-idents.txt
# Compare /tmp/e2-idents.txt against /tmp/mysql-84-reserved.txt
```

## References

- [docs/mysql-migration-plan.md](mysql-migration-plan.md) — the MySQL 8.0 → 8.4 migration plan this audit feeds into
- [docs/orm-migration-plan.md](orm-migration-plan.md) — the longer-running ORM / DBIx::Class story
- `ecoretool/ecoretool.pl` — the import/export CLI
- `nodepack/dbtable/*.xml` — the schema source-of-truth (for now)

# MySQL 8.4 Migration — COMPLETE

> **Status (verified 2026-11-16):** done in #4226 — kept as a historical record. Follow-ups below
> re-checked against GitHub.

**Status:** ✅ **Done 2026-06-07.** Production cut over from MySQL 8.0.44 to **8.4.9** (in-place RDS
major-version upgrade via CloudFormation; ~9m40s downtime window). Engine, custom param group
(`mysql8.4`), and option group all in-sync; auth on caching_sha2/TLS, data, and app all validated
post-cutover. Tracking issue: **#4226**. Landed ahead of the 2026-07-31 RDS 8.0 sunset deadline.

The original ~220-line planning doc (deadline framing, the SQL-access audit, the phased plan, the
parameter-group design, risk register) is preserved in **git history** — it's spent now that the
migration executed. We did an in-place CFN upgrade rather than the blue/green the plan proposed
(simpler for a single-AZ instance; the short window was acceptable).

## Where the still-live follow-up work lives
- **Schema migration framework (sqitch) + `nodepack/dbtable` XML retirement** →
  [modernization-dependency-tree.md](modernization-dependency-tree.md) (sqitch is the named hub);
  issues #4173, #4180, #4184, #4204, #4209 (all still open; sqitch not yet adopted).
- **`explicit_defaults_for_timestamp=0` retirement** (legacy TIMESTAMP semantics; deprecation now
  fires live under 8.4) → **#4225** (post-PSGI, needs sqitch).
- **Object model** → [orm-migration-plan.md](orm-migration-plan.md). DBIx::Class was **rejected**
  2026-06-29; the plan is to finish `Everything::Node::*` and move it from Moose to Object::Pad.
- **`everyuser` auth plugin** → #4122 is still open on GitHub, though the app already connects as a
  `caching_sha2_password` user. Close or rescope.
- **`ON UPDATE CURRENT_TIMESTAMP` cleanup** → #4111 (closed; scoped to the message tables).

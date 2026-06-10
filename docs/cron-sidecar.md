# In-Webhead Cron Sidecar — as-built reference

**Status**: implemented (#4246), cutover tracked in #4251.
**Supersedes the architecture in** [cron-sidecar-design.md](cron-sidecar-design.md) (that's the original proposal/cost rationale; the final build uses the `run_once` periodic model below, not the persistent-leader model sketched there).

E2's scheduled cron jobs run **on the webhead tasks** instead of as per-fire EventBridge → Fargate launches. This removes the `e2cron-family` scheduled-cron Fargate cost (~$840/yr + ~4 public IPs) by running the jobs on hardware that's already paid for.

---

## Model: periodic `run_once`, leader-elected per run

A thin supervised loop on **every** webhead invokes `run_once` about once a minute. `run_once` grabs a MySQL `GET_LOCK` (non-blocking); whoever wins runs the **due** jobs once, then releases. The lock is held **only for the duration of a run** — between runs nothing is held, so:

- there is no persistent leader to wedge,
- failover is automatic (the next tick re-contends on a free lock),
- a dead webhead doesn't matter — every other webhead keeps ticking independently.

Validated in prod: killing the current leader task left cron continuity intact (heartbeat never stale > ~48s vs the 90s threshold) and the app never dropped below 200.

## Components (`ecore/Everything/Cron/`)

| Module | Role |
|---|---|
| `Schedule.pm` | The 8-job registry (argv, cadence, timeout) + `due()`/`prev_fire()` timing. Schedule lives in **code**. |
| `State.pm` | Reads/writes the `cron_state` + `cron_leader` tables: `mark_started` / `mark_finished` / `mark_seen` / `heartbeat_leader` / `snapshot`. DATETIMEs stored, read back as epoch via `UNIX_TIMESTAMP` so the rest works in epochs. |
| `Health.pm` | Pure wedge evaluator: `evaluate(snapshot, now)` → per-job verdict (`ok`/`running`/`hung`/`overdue`/`failing`) + leader-stale → overall (`ok`/`degraded`/`down`) + `wedged`/`failing` lists. No DB, no clock — both injected, so it's unit-tested and reusable. |
| `Runner.pm` | The engine: `run_once` (lock → run due jobs → release), fork+exec with per-job timeout-kill, init-on-first-sight, leader heartbeat, CloudWatch metric emit. |

Entry point: `cron/cron_runner.pl` (`initEverything` → `Runner->new(dry_run, jitter_max)->run_once`). It runs **one pass and exits**; the loop re-invokes it.

Supervisor: `docker/e2app/apache2_wrapper.rb` spawns `while true; do cron_runner.pl [--dry-run]; sleep 60; done` next to the Starman supervisor.

Tests: `t/128_cron_schedule.t`, `t/129_cron_health.t`, `t/130_cron_state.t`.

## Tables (`nodepack/dbtable/cron_state.xml`, `cron_leader.xml`)

- **`cron_state`** — one row per job: `job` (unique), `status`, `started_at`, `finished_at`, `last_success`, `duration_ms`, `consecutive_failures`, `pid`, `host`, `last_output_tail`, `heartbeat`.
- **`cron_leader`** — single row: `lock_name='e2cron_leader'`, `host`, `heartbeat` (the leader liveness signal Health reads).

## The schedule (`Schedule.pm`)

| Job | Cadence | Timeout | Script |
|---|---|---|---|
| datastash | every 2 min | 600s | `cron_datastash.pl` |
| refresh-rooms | every 5 min | 120s | `cron_refresh_rooms.pl` |
| datastash-lengthy | every 6 h | 1800s | `cron_datastash.pl --lengthy` |
| iqm-recalc | daily | 900s | `cron_iqm_recalculate.pl` |
| clean-old-rooms | daily | 300s | `cron_clean_old_rooms.pl` |
| writeup-reaper | daily | 300s | `cron_writeup_reaper.pl` |
| chatterbox-cleanup | hourly (`50 * * * *`) | 120s | `cron_clean_cbox.pl` |
| generate-sitemap | daily (`0 0 * * *`) | 1800s | `cron_generate_sitemap.pl` |

The jobs are the **existing** `cron/*.pl` scripts, unchanged — the runner fork+execs them, so a job crash/leak is isolated from the runner.

## Key behaviors

- **Leader lock** — `SELECT GET_LOCK('e2cron_leader', 0)` on a **dedicated** DBI connection (NOT `connect_cached`; `mysql_auto_reconnect=0` so a silent reconnect can't drop the lock; `SET SESSION wait_timeout=120` so a hard-killed leader's ghost lock releases fast).
- **Per-job timeout-kill** — each job is forked; if it exceeds its timeout it gets `TERM`→grace→`KILL`, recorded as `timeout`. One hung job can't starve the rest.
- **Lock kept alive during long jobs** — `datastash-lengthy` can hold the lock for minutes; the wait loop re-pings the lock connection and re-heartbeats every 30s so the lock can't idle out and the leader can't read stale.
- **Init-on-first-sight** — on a cold `cron_state` (fresh deploy / dev rebuild) each unseen job is baselined to "now" *without running* (`mark_seen`), so the destructive dailies don't stampede at startup and don't read falsely-overdue.
- **Jitter** — `E2_CRON_JITTER` (seconds) adds a random pre-lock sleep so multiple webheads don't tick in phase. Default 0.

## Wedge detection → alarm

The leader emits the `E2/Cron` **`UnhealthyJobs`** metric (count of `wedged` + `failing` from `Health->evaluate`) each run and during long jobs. Emission is gated to **prod-live only** (skipped in dev and in dry-run shadow, where jobs aren't running and would read falsely-overdue).

CFN alarm **`e2-cron-wedged-jobs`**: `UnhealthyJobs > 0` for 3 min **OR missing data** (`TreatMissingData: breaching`) → publishes to the existing `E2AlertsTopic` email. The missing-data half catches **total cron death** (no webhead winning the lock and emitting). The alarm is gated behind the `EnableCronAlarm` parameter and an inline `cloudwatch:PutMetricData` policy (namespace-scoped to `E2/Cron`) sits on the task role. Cost: ~$0.40/mo.

## Dev vs prod

- **Dev** always runs the sidecar **live** (keeps `newwriteups`/datastash fresh — dev otherwise has no cron). Init-on-first-sight + datastash being read-only keep it from interfering with the test suite.
- **Prod** ships **dark** (`E2_CRON_ENABLED` unset → not spawned) and is enabled via CFN parameters at cutover.

## Cutover (CFN parameters + `ops/cf.rb`)

`cf.rb --update` deploys the template **using each parameter's `Default`** (no runtime overrides). So a cutover step = **edit the parameter's `Default` in `cf/everything2-production.json` and run `cf.rb --update`** — a reviewable diff; the committed `Default` always reflects the live state; revert = flip it back.

| Parameter | Env var | Effect when `true` |
|---|---|---|
| `EnableCron` | `E2_CRON_ENABLED` | spawn the sidecar (shadow dry-run unless `CronLive` too) |
| `CronLive` | `E2_CRON_LIVE` | run jobs **+ the 8 `Cron*Rule`s flip to `State: DISABLED`** atomically (via `CronLiveCond` — no double-execution window) |
| `EnableCronAlarm` | — | create the `e2-cron-wedged-jobs` alarm |

**Sequence** (each is a `Default` edit + `cf.rb --update`; reversible until teardown):

1. **Shadow** — `EnableCron=true`. Sidecar spawns dry-run; EventBridge still drives real jobs. Validate leader election + failover across both webheads.
2. **Live** — `CronLive=true`. Webheads run jobs; EventBridge rules disable atomically. Validate jobs running, `cron_state` advancing, the metric flowing.
3. **Alarm** — `EnableCronAlarm=true` (only after the metric is flowing, so `breaching` can't false-fire).
4. **Teardown** — delete the 8 `Cron*Rule` blocks + `ECSEventsRole` from the template, deploy. They're `DeletionPolicy: Delete`, so CFN removes them.

### Teardown keeps `e2cron-family`
The 8 EventBridge rules + `ECSEventsRole` are the *scheduled-cron* infra and get deleted. **Keep** `E2CronFargateTaskDefinition` + `FargateCronLogGroup` — `e2cron-family` doubles as the **on-demand ops task runner** for `ops/nodepack-refresh.rb` and `ops/cron-runner.rb` (which `RunTask` it directly with their own credentials, not via `ECSEventsRole`).

## Runbook

- **Is cron alive / healthy?** `cron_leader.heartbeat` age (< 90s = leader alive), `cron_state` per-job `status` + `last_success`. The `E2/Cron UnhealthyJobs` metric and the `e2-cron-wedged-jobs` alarm surface it on the alerts email.
- **Logs** — `[cron]` lines in `/aws/fargate/fargate-app-awslogs` (`leader for this run`, `started X` / `X finished: ok|fail|timeout`, or `[dry-run] would run X` in shadow).
- **Force-disable / roll back** — flip `CronLive` (and/or `EnableCron`) `Default` back to `false` + `cf.rb --update`; EventBridge rules re-enable atomically and the webhead cron goes shadow/dark.
- **A job is wedged** — `cron_state` shows `status=running` past its timeout (`hung`) or `consecutive_failures >= 3` (`failing`); check that job's `last_output_tail` and the `[cron]` logs.

## Why (cost)

Removes the per-2-minute EventBridge → Fargate task launches (cron ran effectively continuously, ~4 tasks-worth, ~$70/mo) plus ~4 always-held public IPs (~$15/mo) → **~$840/yr**, at ~zero marginal cost on the overprovisioned webheads. Detail: [cron-sidecar-design.md](cron-sidecar-design.md).

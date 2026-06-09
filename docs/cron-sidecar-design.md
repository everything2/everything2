# Cron Sidecar Design — collapse e2cron-family onto the webheads via GET_LOCK

**Status**: Design / proposed (June 2026)
**Driver**: cost. The dedicated cron Fargate tasks are ~half the Fargate+IPv4 bill.
**Owner**: Jay Bonci

---

## 1. Why

Cron is not a long-running container today — it's 8 EventBridge rules that `ecs:RunTask`
an ephemeral Fargate task (`e2cron-family`, 0.5 vCPU / 1 GB, ARM64) per fire, each with a
**public IP** for DB access. Measured (Cost Explorer, 30 days, us-west-2):

| | Qty | $/mo |
|---|---|---|
| Fargate ARM vCPU-hours (account) | 3,191.6 | 103.34 |
| Fargate ARM GB-hours (account) | 6,384.2 | 22.73 |
| Public IPv4 in-use (account) | 4,568.8 addr-hrs | 22.84 |

vCPU-hours, GB-hours, **and** IP-hours independently triangulate to **~3,000 cron
task-hours/month ≈ ~4 cron tasks running continuously** → **cron ≈ $70/mo (~$840/yr),
~$15 of it public IPv4**. The webheads (2 tasks) are the other ~$70.

**The driver is `datastash` every 2 minutes.** Measured job runtime averages 172s (max
271s) — *longer than its own 120s interval* — so 1–2 datastash tasks are always alive,
plus Fargate boot/ENI overhead you also pay for. It behaves like a 24/7 task with churn,
not 720 cheap blips/day.

Goal: run the scheduled jobs on hardware we already pay for (the webheads, which are
hugely overprovisioned), eliminating `e2cron-family` + its ~4 public IPs at ~zero marginal
cost — and fix a latent bug along the way (there is **no single-runner guard** today, so
EventBridge can overlap-fire datastash onto itself).

---

## 2. Current shape (verified)

- Each job is a thin script that does `use Everything; initEverything 'everything';` then
  one `$APP->method` call:
  - `cron_clean_cbox.pl` → `$APP->chatterbox_cleanup` — `cron(50 * * * *)`
  - `cron_refresh_rooms.pl` → `$APP->refreshRoomUsers` — `rate(5 minutes)`
  - `cron_clean_old_rooms.pl` → `$APP->clean_old_rooms` — `rate(1 day)`
  - `cron_writeup_reaper.pl` → `$APP->process_reaper_targets` — `rate(1 day)`
  - `cron_iqm_recalculate.pl` → `$APP->global_iqm_recalculate` — `rate(1 day)`
  - `cron_generate_sitemap.pl` → `Everything::S3` sitemap build → `cron(0 0 * * *)`
  - `cron_datastash.pl` → DataStash generators — `rate(2 minutes)`
  - `cron_datastash.pl --lengthy` → heavy DataStash scans — `rate(6 hours)`
- Invocation: EventBridge target `Input` overrides the `e2app` container command to
  `["/usr/bin/perl","/var/everything/cron/cron_X.pl", ...]` and `ecs:RunTask`s it on
  `E2-App-ECS-Cluster` with `AssignPublicIp: ENABLED` (CFN `cf/everything2-production.json`,
  rules ~L2161–2409, task def `E2CronFargateTaskDefinition` ~L1567).
- Entrypoint `docker/e2app/apache2_wrapper.rb`: renders config, then **`spawn`s a
  supervised `while true` Starman loop** (`starman_supervisor`, L69–77) and `exec`s Apache
  in the foreground (prod L96–104, dev L79–95). The sidecar hooks in here as a *third*
  supervised `spawn`.
- Heavy/manual jobs (`jobs/job_nodepack_builder.pl` ~30 min, `jobs/job_reconcile_rep_and_cools.pl`
  ~30 min) run on-demand on `e2heavyjob-family` (1 vCPU / 4 GB). **These stay as-is** —
  they're Lambda-hostile (>15-min, long DB txns) and cost ~nothing on-demand.

---

## 3. Design

### 3.1 One leader, runs everything (Model A)

Every webhead task runs a **cron runner** process. Exactly one is the *leader* at a time,
enforced by a MySQL named lock. The leader ticks the schedule and runs every due job
**sequentially**; non-leaders idle and retry the lock. Single active runner ⇒ the
overlap bug is fixed for free (a long job just delays the next tick on the same
single-threaded runner).

Rejected: per-job locks (Model B) — more parallelism than this light load needs, more
moving parts.

### 3.2 The lock — MySQL `GET_LOCK`

```sql
SELECT GET_LOCK('e2cron_leader', 0)   -- 1 = acquired, 0 = held elsewhere (non-blocking)
```

- The lock is held for the **lifetime of the DB connection** that took it. If the leader
  process/container dies, its session drops → MySQL auto-releases → another runner acquires
  on its next tick. Automatic failover, no lease/expiry bookkeeping, no clock skew.
- **Critical subtlety**: the lock lives on the *connection*. The runner keeps a **dedicated,
  long-lived DBI handle just for the lock** — never a `connect_cached` handle (those get
  reused/reaped) and never the per-job work handles. Keep it warm with a `SELECT 1` every
  tick so MySQL `wait_timeout` can't reap it out from under us.
- Fail-safe direction: if the leader container is SIGKILLed (no graceful drain), the ghost
  MySQL session keeps the lock until server-side timeout → cron **pauses** (does not
  double-run) until the dead session is reaped. Mitigate by `SET SESSION wait_timeout=120`
  on the lock connection + TCP keepalive, and by graceful SIGTERM (below). Pausing is the
  acceptable failure mode for these idempotent jobs.

### 3.3 Job execution — fork + exec the existing scripts

The leader runs each due job by `fork`+`exec`ing the **existing, unchanged** `cron_X.pl`
script and waiting on it. Rationale:

- Reuses the exact tested scripts — no rewrite, no behavior drift.
- Isolates a job's `die`/leak from the long-lived runner (blast radius = the child).
- Keeps the runner tiny: it's a scheduler + lock-holder + supervisor, nothing else.
- Per-run `perl + initEverything` overhead (~1–2s) is trivial vs the **whole Fargate task
  boot** it replaces — strictly faster and cheaper. Each job still opens its own transient
  DB connection exactly as the cron task does today (no change to connection pressure; the
  only net-new persistent connection is the single leader lock handle).

In-process coderefs (a job registry) were considered and rejected for v1: marginally faster
but couples job crashes/leaks to the runner. Revisit only if fork overhead ever matters
(it won't at this cadence).

### 3.4 Schedule = code, state = DB

- **Schedule** lives in code/config (a Perl table mirroring the 8 EventBridge expressions).
  Two are real cron exprs (`50 * * * *`, `0 0 * * *`); the rest are simple intervals.
  Hand-roll the tiny evaluator or use `Algorithm::Cron` if vendoring is cheap.
- **State** lives in a small table:

  ```
  cron_state(job VARCHAR PK, last_run DATETIME, last_status VARCHAR,
             last_duration_ms INT, last_output_tail TEXT, leader_heartbeat DATETIME)
  ```

  Survives failover (new leader knows when each job last ran → no double-run/skip),
  and doubles as the **observability + health surface** ("when did X last run / did it
  pass / how long"). One row is the leader heartbeat.

### 3.5 The runner loop (`ecore/Everything/Cron/Runner.pm` + `cron/cron_runner.pl`)

```
initEverything 'everything'
$lock_dbh = dedicated connection; SET SESSION wait_timeout=120
loop every TICK (~15s):
    if not leader: leader = (GET_LOCK('e2cron_leader',0) == 1)
    if leader:
        SELECT 1 on $lock_dbh          # keep lock alive + detect drop; on loss → leader=0, next tick re-acquires
        write leader_heartbeat = now()
        for job in schedule where due(now, cron_state.last_run):
            fork+exec cron/cron_X.pl; wait; record last_run/status/duration_ms/output_tail
            # sequential → no overlap, bounded load
    sleep to next tick
on SIGTERM (ECS drain): finish-or-abandon current job, RELEASE_LOCK, exit promptly  # fast graceful failover
```

### 3.6 Where it hooks in (`apache2_wrapper.rb`)

Add a third supervised spawn next to `starman_supervisor`, in **both** dev and prod
branches:

```ruby
spawn("/bin/bash", "-c",
  "while true; do PERL5LIB=/var/libraries/lib/perl5:/var/everything/ecore " \
  "/usr/bin/perl /var/everything/cron/cron_runner.pl >> #{logdest} 2>&1; " \
  "echo 'cron_runner exited, restarting in 5s' >> #{logdest}; sleep 5; done")
```

Supervised restart mirrors Starman's: a crashed runner comes back and re-contends for the
lock. Logs land in `fargate-app-awslogs` (tag lines `[cron]`); retire `fargate-cron-awslogs`.

### 3.7 The one job to watch — `datastash --lengthy`

Heavy DB scan, every 6h. Start it **local** on the leader (4×/day on an overprovisioned box
is fine). Watch the p99-latency alarm during its runs; if it blips request serving, have the
leader **dispatch just that job** to `e2heavyjob-family` via `RunTask` instead of running it
locally (negligible residual task/IP cost at 4×/day). Knob, not a blocker.

---

## 4. Rollout (incremental, reversible at every step)

1. Build `Everything::Cron::Runner`, `cron/cron_runner.pl`, the `cron_state` table, schedule
   config. Unit-test scheduler `due()` logic + lock acquire/release/failover.
2. **Shadow mode**: deploy the runner to webheads with jobs in *dry-run* (log "would run X",
   elect leader, write heartbeat) while EventBridge still drives the real jobs. Verify leader
   election, failover (kill a task), tick timing, heartbeat — with zero double-runs.
3. **Per-job cutover**: for each job, disable its EventBridge rule and enable it live in the
   runner, cheapest first (chatterbox, rooms) → datastash last. Each flip is independently
   reversible (re-enable the EB rule, dry-run the runner job).
4. After all 8 are runner-driven and stable ~1 week: delete the 8 EventBridge rules +
   `E2CronFargateTaskDefinition` from CFN; retire `ECSEventsRole` if unused elsewhere and the
   `fargate-cron-awslogs` group.
5. Keep `e2heavyjob-family` for manual jobs.

### Health / alarms
Runner emits a CloudWatch custom metric (`cron_leader_heartbeat_age`, `cron_job_age{job}`).
Alarm if the heartbeat is stale > N min or any job's age exceeds interval × K. Replaces the
implicit "is the cron task running" signal the per-task launches gave.

---

## 5. Outcome

- **Eliminates `e2cron-family`: ~$70/mo (~$840/yr)**, ~$15 of it public IPv4 (~4 IPs freed).
- Added webhead cost ≈ 0 (light fork+exec on one overprovisioned task; +1 persistent DB
  connection for the leader lock — negligible vs the 303 ceiling).
- **Fixes** the latent overlap bug; **adds** a real cron observability surface (`cron_state`).
- Composes with the cheap pre-step: dropping `datastash` from `rate(2m)` → `rate(10m)` if
  New-Writeups freshness allows, which shrinks even the residual on-webhead load.
- **Effort**: ~1.5–2 days build + a week of staged soak.

### Risks (all fail-safe or mitigated)
| Risk | Mitigation |
|---|---|
| Lock conn reaped by `wait_timeout` | `SELECT 1` every tick (15s ≪ timeout) |
| Job `die`/leak kills runner | fork+exec isolation + supervised restart |
| Ghost lock after SIGKILL | low session `wait_timeout` + TCP keepalive; pauses (never double-runs) |
| Rolling deploy | SIGTERM → `RELEASE_LOCK` → new leader; brief pause |
| `datastash --lengthy` vs serving | start local, watch p99, dispatch to heavyjob if it blips |

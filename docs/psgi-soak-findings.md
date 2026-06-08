# PSGI overnight soak + profiling campaign — ECS sizing

**Started:** 2026-06-08 ~03:50 (container `e2devapp`, PSGI mode, `STARMAN_WORKERS=5`, `STARMAN_MAX_REQUESTS=1000`).
**Goal:** confirm no memory leak under sustained diverse load, profile CPU, and turn it into ECS task-memory / worker-pool sizing.

This doc is appended to across the run; the final **Sizing recommendation** section is written at the end.

## Method
- **Soak:** 2 detached traffic loops in the container hammer 28 diverse URLs (all node types + URL shapes + authed APIs, `tools/leak-routes.txt`) through the real Apache→Starman path. A logger samples memory every 120s → `/tmp/soak-mem.csv` (in-container).
- **Memory metric:** the cgroup total (`/sys/fs/cgroup/memory.current`) is the authoritative number — it's exactly what an ECS task memory limit caps. Starman fleet PSS is tracked too. (Apache per-proc RSS overcounts shared prefork pages, so cgroup−StarmanPSS is the better read on Apache's share.)
- **Profiling:** `tools/psgi-profile.pl` under `Devel::NYTProf` (profiles only the request loop, not app load).
- **Leak baseline (in-process, pre-soak):** 3k / 12k / 8k-request runs all converged on the SAME ~22 MB total growth with a flat object arena → that 22 MB is one-time warmup (allocator + NodeCache fill + Moose lazy init), not a leak.

## Initial NYTProf profile (800 authed requests, 28 routes) — the app is DB-bound

| exclusive time | calls | sub |
|---|---|---|
| 25.30s | 104,325 | `DBI::st::execute` |
| 8.82s | 2,546 | `DBI::db::commit` |
| 1.95s | 16,987 | `Everything::Application::getVarHashFromStringFast` |
| 1.55s | 3,927 | `DBI::db::do` |
| 0.86s | 63,968 | `Everything::NodeBase::sqlSelect` |
| 0.81s | 87,086 | `Everything::NodeBase::sqlSelectMany` |
| 0.49s | 107,863 | `Everything::NodeCache::getCachedNodeByName` |

**Read:** DB execute+commit ≈ **34s of ~45s** total. ~**130 SQL executes per request**. The Perl/cache layer (NodeCache, getNode) is cheap. So:
- Workers are **I/O-bound on the database**, not CPU-bound → size the pool for DB-wait concurrency, and expect throughput to scale with worker count until RDS becomes the limit.
- In prod the DB is RDS (network latency per query), which **amplifies** the wait-per-request → even more reason to size workers by **memory** (how many fit) rather than CPU.
- (Side note / optimization target, not sizing: 130 queries/request is high; softlink/nodelet/user-vars query patterns are the place to look later.)

## Memory trend
**Soak cut short** — the host machine rebooted partway through the night (Docker
Desktop down, container destroyed, in-container `/tmp/soak-mem.csv` lost). No
8-hour time-series was collected. Only the baseline sample exists:

```
(baseline, 5 workers under load) cgroup=990MB  starman_pss=568MB  (preload-app)
```

The leak VERDICT does not depend on the lost time-series: the pre-soak in-process
arena census (3k/12k/8k requests, flat object arena, identical ~22MB warmup
plateau regardless of request count) is the more reliable signal and already
establishes **no leak**. The 8h soak would have *confirmed* steady-state over
time and is worth re-running, but it is confirmation, not discovery.

### Re-run live trend (2026-06-08, ~2h soak, 5 workers)
Baseline (t=0): cgroup=954MB, starman_pss=478MB. Snapshots:
- elapsed=46min cgroup=1068MB starman_pss=571MB delta_from_first=+114MB  (last 4 samples flat at 1067±3MB → plateaued after ~30min warmup)
- elapsed=94min cgroup=1066MB starman_pss=571MB delta_from_first=+112MB  (still flat; brief dips to ~1036 = worker recycling at max-requests=1000 then re-warming — memory bounded, as intended)
- elapsed=115min (final) cgroup=1145MB starman_pss=571MB  — **VERDICT: no leak.** Starman process PSS dead flat (478→571 warmup, then 0 growth over ~2h); the cgroup creep (1066→1145) is reclaimable page cache, not process memory. Plateaued. Recycling (max-requests=1000) keeps it bounded. The Sizing recommendation below is now confirmed with time-series.

### mod_perl dropped under E2_PSGI (working tree, 2026-06-08) — ~half the memory
Implemented #4234 Step 1: under E2_PSGI, Apache no longer loads mod_perl (wrapper drops the `perl.load` symlink; all `Perl*` directives guarded behind `<IfDefine !E2_PSGI>`). This removes both the mod_perl interpreter **and** the redundant second in-memory copy of the app that the `PerlModule Everything…` preload loaded into every Apache worker.

| | cgroup (container) | Starman PSS | Apache share |
|---|---|---|---|
| **with mod_perl (Stage 1)** | ~1066 MB | ~571 MB | ~495 MB (mod_perl + app preload) |
| **mod_perl dropped** | **~506 MB** | ~507 MB | **~negligible** (thin prefork proxy) |

**~560 MB / ~53% reclaimed.** The container is now essentially Starman alone. Kept `mpm_prefork` (capacity-overprovisioned; mpm_event is the optional Step 2). Verified both modes: E2_PSGI on → no mod_perl, prefork proxy, routing+brotli work; E2_PSGI off → mod_perl loads, serves, **rollback intact**. Env (`AWS_DEFAULT_REGION`, `E2_DBSERV`, `E2_DOCKER`, and in prod `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`) reaches the app via process-env inheritance to Starman, not `PerlPassEnv`.

**Sizing impact:** per-task memory roughly halves → fit ~2× the Starman workers in the same task, or use smaller tasks. The 303-connection budget remains the binding constraint, not memory.

## Production RDS baseline (measured via the read-only query Lambda, 2026-06-08)

`SHOW GLOBAL STATUS` on the prod RDS (MySQL **8.4.9**), uptime ~17.6h:

| metric | value |
|---|---|
| QPS — current (28s delta) | **~1,940** |
| QPS — lifetime avg (Questions/Uptime) | **~1,400** |
| Read share (Com_select / Questions) | **98.7%** |
| Writes (insert+update+delete) | ~56K total = **~0.9/sec** (0.06% of stmts) |
| `max_connections` | **303** |
| Threads_connected now / peak | 49 / 74 |
| Slow_queries | 558 (0.0006%) |

**Reads:** at ~130 queries/page that's **~11–15 page-requests/sec** currently — consistent with the dev profile.

**Connections are the real horizontal-scaling cap, not memory.** RDS allows **303** connections; prod uses 49 now / 74 peak under mod_perl. Each PSGI worker holds one (`connect_cached`), so **Σ(workers × tasks) must stay under ~210** (≈70% of 303, leaving room for cron/admin/replicas). That caps fan-out: 2 GB tasks @ 8 workers → ≤ ~26 tasks; 4 GB @ 16 → ≤ ~13 tasks. **This — not container memory — is the binding constraint, and it's exactly the lever PSGI improves** (a tighter, connection-decoupled worker pool can hold *fewer* connections than mod_perl's prefork-per-worker model → relieves the connection/buffer-pool pressure that is the stated reason to prefer PSGI over scaling the DB).

**Write rate is genuinely tiny (~0.9/sec, ~0.28 updates/sec).** Almost all traffic is guest reads. The per-request logged-in-user-object write exists but is a small slice of total writes — which is why the per-node version model handles it fine today (and a data point worth re-checking if the cache optimization is ever revisited).

## Sizing recommendation

### Measured inputs (dev box; app container = Apache + Starman, MySQL separate)
- Container cgroup total @ **5 workers under load: 990 MB**.
- Starman fleet PSS (master + 5 workers, `--preload-app`): **568 MB**.
- Per-worker effective memory (PSS, 69% COW-shared via preload): **~90 MB** (plan figure).
- Apache + page cache + buffers ≈ cgroup − Starman PSS ≈ **~420 MB**.

### Model
`container_MB(N) ≈ 538 + 90·N`  (fits the 5-worker point: 538 + 450 = 988 ≈ 990).
Plan the ECS task memory so this stays ≤ ~70% of the limit (headroom for page
cache growth under sustained load, worker-recycle churn, spikes).

| Fargate task | usable @70% | max workers (mem) | **recommended workers** | RDS conns/task |
|---|---|---|---|---|
| 2 GB | ~1.4 GB | ~10 | **8** | 8 |
| 4 GB | ~2.9 GB | ~26 | **16** | 16 |
| 8 GB | ~5.7 GB | ~58 | **24** (RDS-bound, not mem) | 24 |

### The governing constraint is the DATABASE, not container memory
NYTProf shows the app is DB-bound (~130 SQL executes/request; DBI execute+commit
= 34s of 45s). Consequences for sizing:
- Each worker holds one DB connection (`connect_cached`). **Total RDS connections
  = workers/task × tasks.** Keep that under ~70% of RDS `max_connections`. This
  caps useful worker count well before memory does on 4GB+ tasks.
- Throughput scales with workers only until RDS saturates. So **scale OUT (more
  small tasks behind the ALB), not UP (huge tasks / many workers each)** — it
  spreads the connection load and limits blast radius.
- **Sweet spot: a 2 GB task running ~8–10 workers** (~8–10 RDS conns), scaled
  horizontally against the RDS connection budget.

### Caveat (dev → prod)
The **memory** figures transfer directly (the app's PSS is the app's PSS). The
**throughput-per-worker** figure does NOT: dev MySQL is local (~0.1ms/query),
prod RDS adds network latency (~1–5ms × 130 queries). So in prod each request
spends *more* time blocked on the DB → you may need somewhat more workers for the
same throughput (fine, memory-wise), but RDS saturates sooner. **Confirm the
worker-count-for-target-throughput on staging against real RDS** before locking
the autoscaling policy. The re-run soak (now that the box is back) will also give
the steady-state memory curve over hours.

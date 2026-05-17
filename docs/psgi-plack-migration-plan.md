# PSGI/Plack Migration Plan

**Status**: Planning (rewritten 2026-04-28)
**Goal**: Replace mod_perl with PSGI/Plack to reduce per-worker memory footprint, drop Apache::DBI connection bloat, and unblock smaller container shapes on Fargate.
**Prior version**: Written 2025-11-26 under a different model; that draft assumed direct `Apache2::RequestRec` handler integration that does not exist in this codebase. This plan replaces it.

---

## Why migrate

Production metrics (us-west-2, 7-day average as of 2026-04-28):

- Fargate task CPU: **9% avg, 98% peak** on 2 vCPU. Massively over-provisioned on CPU.
- Fargate task memory: **64% avg, 93% peak** on 4 GB. Memory is the binding constraint.
- RDS connections: **50 avg, 122 peak**. Each mod_perl prefork child holds one.
- RDS freeable memory: 0.14–0.28 GB free of 4 GB. Buffer pool is fully saturated and routinely missing to disk.

The shape of the problem is mod_perl's prefork model: each Apache child process holds a full Perl interpreter, the loaded code base, and its `NodeCache` working set. With 60+ workers per task across 2 tasks, that's 120+ copies of everything in memory, and 120+ DB connections during peak. Most of those workers are idle most of the time — that's why CPU averages 9%. PSGI under a tuned process manager (Starman with ~10 workers/task) drops the worker count by ~5×, which lowers both Fargate memory pressure and DB connection pressure together.

The migration is not about features. It's about removing a structural cost multiplier so smaller, cheaper container shapes become viable.

---

## Actual architecture (what the older plan got wrong)

This codebase **does not** use mod_perl as a direct handler. There is no `Everything::HTML->handler($r)`, no `PerlTransHandler`, no `Apache2::Const`, no `Apache2::Cookie`. A grep of `ecore/` for `Apache2::` returns zero matches.

The real wiring (from `etc/templates/apache2.conf.erb`):

```apache
PerlModule Apache::DBI
PerlModule Apache2::compat DBI DBD::mysql CGI CGI::Carp
PerlResponseHandler ModPerl::Registry
```

The app is **CGI-style Perl scripts** (`www/index.pl`, `www/api/index.pl`, `www/health.pl`) running under `ModPerl::Registry`, which compiles each script once per worker and re-runs it as a cached subroutine. Each `.pl` script is two lines:

```perl
use Everything::HTML;
mod_perlInit();
```

`Everything::Request` is a `Moose` wrapper around `CGI` (CGI.pm), with delegated methods (`param`, `header`, `cookie`, `url`, `request_method`, `path_info`) and direct reads from `$ENV{REQUEST_METHOD}`, `$ENV{CONTENT_LENGTH}`, and `STDIN`. All standard CGI environment.

The only actual mod_perl/Apache-specific couplings in the running stack are:

| Module | Purpose | PSGI replacement |
|---|---|---|
| `Apache::DBI` | Persistent DB connections across requests (cached in process) | `DBI->connect_cached` or `DBIx::Connector` |
| `Apache2::SizeLimit` | Kill child when RSS > 800 MB | Starman `--max-requests N` + optional `Plack::Middleware::MemoryUsage` |
| `Apache2::compat` | Compat layer for CGI.pm under mod_perl | Not needed under PSGI |
| `ModPerl::Registry` | Compile + cache CGI scripts | Starman directly executes the PSGI app |

That's the entire coupling list. The migration is materially shallower than the prior plan implied — but the operational and deployment work is deeper than that plan assumed.

---

## Target architecture

```
Browser
   ↓ HTTPS via CloudFront → ALB
Apache 2.4 (front-end)            ← keep: handles X-Forwarded-For from CloudFront,
   ↓ mod_proxy_http / fcgi          IP/UA blocks from apache_blocks.json, gzip,
Starman (PSGI server)               mod_evasive rate limiting, static assets
   ↓ PSGI env
Plack app (app.psgi)
   ↓ thin wrapper
Everything::HTML::mod_perlInit()  ← entry point, mostly unchanged
   ↓
CGI.pm + Everything::Request + Everything::Application + ecore/...
```

**Keep Apache in front.** The current Apache config does a lot of non-trivial work: CloudFront IP allowlisting for `mod_remoteip`, `apache_blocks.json`-driven IP/UA bans, `mod_evasive` rate limiting, gzip, static file serving. Throwing Apache out means rebuilding all of that elsewhere — and Starman alone isn't the right tool for those concerns. The migration replaces the *Perl execution layer*, not the HTTP front-end.

---

## What still works untouched after migration

Most of `ecore/`. The PSGI wrapper sets `%ENV` and ties STDIN/STDOUT from the PSGI env hash, then calls `mod_perlInit()` exactly as the CGI scripts do today. CGI.pm reads from `$ENV` and STDIN the same way. `Everything::Request->cgi` builds a CGI object the same way. The vast majority of controllers, models, and the `Everything::Page`/`Everything::API` dispatch system don't know they're running under PSGI.

This is the key insight that the older plan missed: **because the app is CGI-style, not native mod_perl, PSGI is essentially a different harness around the same Perl entry point.**

---

## What does need to change

1. **A PSGI wrapper script** that bridges `$env` ↔ `%ENV`+STDIN+STDOUT. Roughly 50–100 lines. Lives at `app.psgi`.

2. **`Apache::DBI` → `DBI->connect_cached` (or `DBIx::Connector`)**. Apache::DBI is invisible — it hooks `DBI->connect` to cache by `(DSN, user, attrs)` per process. Under PSGI/Starman we get the same process persistence, so DBI's native `connect_cached` does the same job. One-line change in the connection setup (likely in `Everything::NodeBase` or wherever the initial connection happens). Add a `disconnect_on_destroy => 0` for pooling. Test that ping-on-fetch is still on.

3. **`Apache2::SizeLimit` → Starman `--max-requests N` + memory check**. The current 800 MB SizeLimit recycles workers when they bloat. Starman's `--max-requests 1000` recycles after a fixed request count, which is coarser. Add `Plack::Middleware::MemoryUsage` (or a custom middleware) to enforce a max-RSS-per-worker if the request count approach isn't tight enough.

4. **STDIN for `PUT`/`PATCH`/`DELETE` bodies**. `Everything::Request::BUILD` reads STDIN raw before CGI.pm consumes it. Under PSGI this becomes `read($env->{'psgi.input'}, $data, $content_length)`. Either the PSGI wrapper sets up tied STDIN, or `Everything::Request` learns to prefer `$env->{'psgi.input'}` when present.

5. **Apache config trimmed of mod_perl directives**. Remove `PerlModule`, `PerlResponseHandler`, `PerlOptions`, `PerlCleanupHandler`. Add a single `ProxyPass` block to Starman:

   ```apache
   ProxyPass / unix:/var/run/starman.sock|fcgi://localhost/ retry=0
   ProxyPassReverse / unix:/var/run/starman.sock|fcgi://localhost/
   ```

   Or use HTTP rather than FastCGI — simpler to debug, performance is comparable for in-container loopback. Choose at implementation time.

6. **ECS task shape**. The current task runs Apache+mod_perl in one container. PSGI gives two reasonable options:

   - **Single container, supervisord**: Apache + Starman both in one container, supervised. Closest to current deploy shape. Easiest cutover. Recommended.
   - **Multi-container task**: Two containers in one ECS task definition, sharing the task network. Cleaner separation but more moving parts.
   - **Two services with internal ALB**: Most complex. No real benefit at this scale.

   Go with single-container/supervisord for the initial migration.

7. **Dev loop**. `./docker/devbuild.sh` rebuilds the container on every change today. PSGI's hot reload (`plackup -r app.psgi`) is faster but doesn't apply when the container itself needs a rebuild. For the dev loop:

   - In development: run Starman with `-r` (auto-reload on file change). Apache in front as today.
   - Mount the source dir into the container in development only (production still uses baked images).
   - This needs a `docker-compose.dev.yml` or equivalent.

8. **The `mod_perlInit()` function**. It exists in `Everything::HTML`. Likely does global per-worker setup (DB connection, package globals). Skim it: parts that genuinely need to run once-per-worker should move to a Starman `apppreload`. Parts that run per-request stay where they are.

---

## What this plan deliberately defers

- **Replacing CGI.pm with `Plack::Request`**. CGI.pm works fine on PSGI. The speed and memory wins from migrating to `Plack::Request` are real but modest, and touching every `$REQUEST->param` call site is a large refactor. Defer until there's a specific need.
- **`Plack::Middleware::Session` for sessions**. The current session system is database-backed and uses CGI.pm cookies — it already works under PSGI as-is. Don't rewrite what isn't broken.
- **API versioning, GraphQL, WebSockets, microservices**. The older plan listed these as "Future Opportunities." They're unrelated to the migration. Don't conflate. The migration is done when the app serves traffic under Starman with equal or better reliability than mod_perl.

---

## Phase plan

### Phase A — PSGI wrapper, dev only (1–2 weeks)

Build the minimum viable wrapper to run the app under Starman in dev. Don't touch production.

- [ ] Add `app.psgi` at the repo root (or `psgi/app.psgi`)
- [ ] Wrapper translates `$env` → `%ENV`, ties `psgi.input` → STDIN, captures STDOUT
- [ ] Wrapper invokes `mod_perlInit()` and returns `[status, headers, body]`
- [ ] Add `Plack`, `Starman`, `Plack::Middleware::ReverseProxy` to `cpanfile`
- [ ] Update `docker/devbuild.sh` to install Plack stack
- [ ] Run `plackup -s Starman --workers 5 app.psgi` in the dev container, point a browser at it
- [ ] Smoke test: load homepage, log in, view a node, post a writeup
- [ ] Capture which controllers/APIs break, fix them in the wrapper (don't touch `ecore/`)

**Exit criteria**: dev container can serve full E2 traffic under Starman with no `ecore/` changes. Production untouched.

### Phase B — Operational equivalents (2–3 weeks)

Replace the Apache-specific operational concerns.

- [ ] `Apache::DBI` → `DBI->connect_cached` in `Everything::NodeBase` (or wherever). Verify connection re-use under load. Confirm ping-on-fetch behavior.
- [ ] `Apache2::SizeLimit` → Starman `--max-requests` baseline. Add memory-watcher middleware if RSS still climbs.
- [ ] Decide single-container vs multi-container ECS task shape. Implement chosen shape in dev.
- [ ] Update Apache config to proxy to Starman instead of running ModPerl::Registry. Verify all the non-mod_perl Apache features still work: CloudFront `X-Forwarded-For`, IP blocks, mod_evasive, gzip, static files.
- [ ] Apache config now serves identically in dev and prod.
- [ ] Run `wrk` or `ab` load test against dev. Compare to mod_perl baseline. Target: equal throughput at lower memory.

**Exit criteria**: dev environment is production-shaped (Apache + Starman, no mod_perl). All test users can do everything they can today. Load test shows comparable throughput.

### Phase C — Staging + canary (1–2 weeks)

The actual deployment work. This is where the older plan was approximately right; preserved here.

- [ ] Build a staging Fargate task with the new container image
- [ ] Add a second ALB target group, register staging task in it
- [ ] Optional: add a weighted listener rule to send 5% of prod traffic to staging
- [ ] Watch CloudWatch for error rate, latency, memory, connection counts. Run for ≥48 hours.
- [ ] Tune Starman worker count (start at 10/task, watch DB connections — target ≤40/task)
- [ ] Gradually shift traffic: 10% → 50% → 100% over a week
- [ ] Keep mod_perl task definition available for rollback for 2 more weeks
- [ ] After 2 weeks clean, retire mod_perl task definition and image build path

**Exit criteria**: 100% of production traffic on PSGI for 2 weeks with no rollbacks needed.

### Phase D — Right-size Fargate (after Phase C, 1 week)

Now that worker count is 5× lower, the 4 GB/2 vCPU task shape is overprovisioned.

- [ ] Measure post-migration memory/CPU shape from CloudWatch
- [ ] Resize task definition: target 1 vCPU + 2 GB. Run 3 tasks instead of 2 for fault tolerance.
- [ ] Roll out resized tasks
- [ ] Watch for a week
- [ ] If stable, this is the new baseline. Compute Savings Plan commits can be sized to this shape.

**Exit criteria**: production runs on 1 vCPU / 2 GB Fargate tasks at <70% memory utilization with peak CPU <80%.

---

## Realistic total estimate

**5–7 weeks** of focused solo work for Phases A–C. Phase D adds ~1 week.

The older plan's "7–12 days" estimate came from misreading the architecture (it imagined a deeper mod_perl coupling that doesn't exist) and underestimating the operational/deployment work. Phase A really is fast (~1 week) once the wrapper concept is right; the slow parts are Phase B's testing and Phase C's careful production rollout.

---

## Cost impact

Today (on-demand): Fargate ~$144/mo at 2 tasks × (2 vCPU + 4 GB).
After Phase D: Fargate ~$54/mo at 3 tasks × (1 vCPU + 2 GB).
Net Fargate savings: ~$90/mo.

Plus second-order wins: lower DB connection count → less RDS memory pressure → potentially defer an RDS instance class bump that would otherwise be needed within a year.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Memory leak in Perl code that mod_perl was masking via SizeLimit kills | Medium | High | Aggressive `--max-requests` baseline; memory middleware enabled from day one in Phase B |
| `mod_perlInit()` has implicit dependencies on mod_perl context | Medium | Medium | Phase A surfaces these; fix them in the wrapper or move them to per-request setup |
| CGI.pm + Starman interaction has edge cases not seen in dev | Low | Medium | Phase C's 48-hour soak catches most; gradual rollout limits blast radius |
| ALB target group cutover takes traffic faster than expected | Low | Low | Use weighted listener rules, not target group swap |
| ECS task definition changes interact poorly with deployment pipeline | Low | Medium | Phase B does the change in dev; Phase C applies it in staging first |

---

## Open questions

1. **Single container vs multi-container ECS task**: confirmed single-container/supervisord is the default plan, but worth reviewing if Apache and Starman scaling needs diverge.
2. **HTTP vs FastCGI between Apache and Starman**: HTTP is simpler to debug; FastCGI is the "traditional" answer. Performance equivalent at loopback. Decide at Phase B implementation.
3. **`mod_perlInit()` contents**: need to actually read this function in `Everything::HTML` to know what runs there and what needs PSGI-equivalent treatment.
4. **Static asset serving**: currently Apache serves `/react/*`, `/css/*`, `/images/*`. CloudFront could take over this in production. Worth doing alongside Phase C as a "while we're here" infrastructure change.

---

## References

- [PSGI Specification](https://metacpan.org/pod/PSGI)
- [Starman](https://metacpan.org/pod/Starman)
- [Plack::Builder](https://metacpan.org/pod/Plack::Builder)
- [DBI connect_cached](https://metacpan.org/pod/DBI#connect_cached)
- [Apache mod_proxy_fcgi](https://httpd.apache.org/docs/current/mod/mod_proxy_fcgi.html)
- Current Apache config: [etc/templates/apache2.conf.erb](../etc/templates/apache2.conf.erb)
- Current entry points: [www/index.pl](../www/index.pl), [www/api/index.pl](../www/api/index.pl)
- Request abstraction: [ecore/Everything/Request.pm](../ecore/Everything/Request.pm)

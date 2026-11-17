# Everything2 — AI Assistant Context

**Last Updated**: 2026-11-16
**Maintainer**: Jay Bonci (jay@bonci.net)

This file is a thin layer of non-discoverable context. For anything you can derive by reading code or running `git log`, do that instead. Treat `docs/` as the deeper reference and this file as a finger pointing at it.

E2 is a 1999-vintage Perl/MySQL community writing site mid-modernization: PSGI/Starman behind Apache (mod_perl is gone), React frontend, AWS Fargate, in-flight migration off the legacy delegation pattern. Solo-maintained. The public repo is security-sensitive: security fixes ship as a generic "Security fix" issue/PR with no exploit detail in commits, comments or test names.

---

## User preferences (durable)

- **Never create git commits.** The user handles all commits. Same for `git push`, branch deletion, force push.
- **Never use destructive shortcuts** (`--no-verify`, `--force`, `git reset --hard`) without explicit instruction.
- **Programmatic verification over manual visual review.** Manual screenshot inspection across themes/pages caused a multi-month stall in early 2026. Prefer Puppeteer / `tools/computed-style-diff.js` / `tools/mobile-layout-checker.js` style checks over "look at all these screenshots."
- **Prove user-visible changes in the real app, on video.** Before calling a feature enhancement or user-facing fix done, run the `e2e-demo` skill (`.claude/skills/e2e-demo/`): a Playwright spec through the real UI on warm workers (single user by default; one browser per user, side by side, only for collaboration features), recorded with `tools/e2e-demo.sh` (add `E2E_DEMO_DEVICE=mobile` for phone resolution) and sent to Jay. Recordings go to gitignored `e2e-demos/`; never commit them. After a security fix, rerun the affected feature's spec to show it still works, worded around the feature rather than the flaw. Unit tests alone have repeatedly certified broken multi-user features (#4661).
- **Cite-then-trust.** When older docs make claims about codebase state ("15 vulnerabilities", "11 components done"), re-grep first. Stale planning docs are common; treat them as historical scope, not current truth.

---

## Operational gotchas (non-discoverable)

| Thing | Reality |
|---|---|
| Dev container | Files **not** volume-mounted. Run `./docker/devbuild.sh --skip-tests` to apply local changes. Never `docker cp` or `apache2ctl graceful` — leads to stale state. |
| Apache logs | `/var/log/apache2/error.log` is **always empty** in dev. All app logging goes to `/tmp/development.log` (`docker exec e2devapp tail -f /tmp/development.log`). |
| HTML testing | `curl` only returns server-rendered scaffolding; React mounts client-side. Use `tools/browser-debug.js` (it has `--help`). curl is fine for liveness or pure JSON API checks. |
| Container names | `e2devapp` (Apache+app), `e2devdb` (MySQL). |
| MySQL access | `docker exec -it e2devdb mysql -u root -pblah everything` |

**Test users**: `root` / `genericdev` / `genericeditor` / `genericchanop` use password `blah`. The `e2e_*` user family (`e2e_admin`, `e2e_editor`, `e2e_user`, etc.) uses password `test123`. `normaluser1` through `normaluser30` use `blah`. Full list in `tools/seeds.pl`.

---

## Code-level gotchas (subtle, easy to recreate)

**JSON UTF-8.** `JSON::decode_json` expects raw UTF-8 bytes and decodes internally. Calling `decode_utf8` on POSTDATA *before* `decode_json` produces "Wide character in subroutine entry" with non-ASCII input.

**API responses must be HTTP 200.** Return errors as `[$self->HTTP_OK, {success => 0, error => '...'}]`; the React clients read the body only on a 200 (`res.ok`), so a 4xx turns a real error message into a generic failure. (It started as a mod_perl workaround; the client contract is why it still holds.) Some older controllers still return 4xx; #3768 tracks the recut and `docs/API.md` lists the exceptions. Never add new ones.

**Blessed vs hashref node access.** Controllers (`Everything::Page`, `Everything::API`) get blessed objects: `$user->title`. `Everything::Application.pm` gets raw hashrefs: `$USER->{title}`. Cross-conversion: `$user->NODEDATA` → hashref, `$APP->node_by_id($USER->{node_id})` → blessed.

**Don't ship circular hashrefs in JSON.** `$node->{type}` is itself a node hashref with circular references and will explode the JSON encoder. Extract: `$node->{type}{title}`.

**Don't call `Everything::Delegation::*` from controllers.** Implement logic in `buildReactData()` / an API, or extract to `Application.pm`. `Delegation::htmlcode` is down to zero subs (#4358); the remaining `achievement` / `maintenance` / `notification` / `room` modules are being displaced, so don't add callers.

**Format dates through `react/utils/dateFormat.js`, not `toLocaleDateString` directly.** Server stores all timestamps in UTC (Apache runs `TZ='+0000'`), but JS `toLocaleDateString` defaults to the *viewer's* local timezone — so a UTC timestamp late in the day renders as the next day for viewers east of UTC. Use `formatDate(input)` (long form), `formatShortDate`, `formatDateTime`, or `formatTime`. All default to `timeZone: 'UTC'`. Issue #4056 was caused by ignoring this; same bug pattern existed in ~18 components before the cleanup.

**LinkNode single-encodes; the server-side helper decodes once. Don't break the pair.** `react/components/LinkNode.js` percent-encodes title characters (`& @ + / ; ?`) exactly once via `encodeURIComponent`, and `Everything::HTML::_recover_route_params_from_request_uri` reads `$ENV{REQUEST_URI}` and decodes exactly once. The two are a matched set — change one and you must update the other, or every link with a special character in its title silently 404s (well, falls through to the `Findings:` page). The historical double-encoding workaround in `LinkNode.js` was the only thing keeping title-bearing URLs alive while the Apache rewrite block was the dispatcher; the helper replaced that workaround in #4060. PSGI is live; #4129 (open) removes both pieces together.

**A CFN env var is only "dead" if `docker/` doesn't read it either.** Config flags are read in more places than the Perl app: the container entrypoint `docker/e2app/apache2_wrapper.rb` reads env directly (e.g. `E2_CRON_ENABLED`/`E2_CRON_LIVE` gate whether the leader-elected cron sidecar even starts; `STARMAN_WORKERS`/`STARMAN_MAX_REQUESTS` launch Starman). Before removing a `E2_*` var from `cf/*.json` as cruft, grep **`docker/`** in addition to `ecore/ tools/ *.psgi`. Removing `E2_CRON_ENABLED` on the strength of an `ecore`-only grep silently killed the cron sidecar in prod (#4444) — datastashes froze until the flags were restored.

---

## Visual / styling

The "Kernel Blue" palette is the design system: `#38495e` primary, `#4060b0` link, `#507898` muted text, `#e8f4f8` light bg, `#3bb5c3` cool teal. Driven by CSS variables in `www/css/1973976.css` (basesheet, ~40K lines). Don't use `--e2-text-muted` as a *background* — it's a text color and themes override it inconsistently. Use `--e2-btn-secondary-*` for button backgrounds.

19 stylesheets in `www/css/`. Basesheet (`1973976.css`) carries shared structure; per-theme zensheets override colors. Refactor away from inline `style={{...}}` toward BEM classnames in basesheet is the dominant frontend pattern.

---

## Where to look

| Need | Place |
|---|---|
| Docs index | [docs/README.md](docs/README.md) — every doc with a one-line description. All of `docs/` was re-verified against code 2026-11-16 (each has a "Last verified" line); finished plans carry a status banner |
| Project roadmap | [docs/DEVELOPER-ROADMAP.md](docs/DEVELOPER-ROADMAP.md) ("Where we are" verified 2026-11-16; still cross-check with `git log`) |
| MySQL 8.4 migration | ✅ **done 2026-06-07** (#4226); [docs/mysql-migration-plan.md](docs/mysql-migration-plan.md) is now a tombstone, forward work in the dependency tree + #4225 |
| Object-model plan | [docs/orm-migration-plan.md](docs/orm-migration-plan.md) — DBIx::Class was **rejected** (Jun 2026); the plan is to finish `Everything::Node::*` on Object::Pad. Not started; #4178 (Globals) is step 1 |
| CSS architecture + theme backlog | [docs/stylesheet-system.md](docs/stylesheet-system.md), [docs/css-consistency-audit.md](docs/css-consistency-audit.md) (inline-styles refactor is resolved) |
| Mobile audit | [docs/mobile-audit.md](docs/mobile-audit.md), `tools/mobile-layout-checker.js` |
| Schema (current) | `nodepack/dbtable/*.xml` — CREATE TABLE statements, slated for migration to versioned SQL during MySQL work |
| Special document map | `ecore/Everything/Page/*.pm`, `ecore/Everything/PureGates.pm` (80+ pages that are pure gates with no Page module) + `react/components/DocumentComponent.js` (the live registry) |
| API reference | [docs/API.md](docs/API.md) — every routed endpoint (checked against all API modules 2026-11-16) |
| Deploy + rollback | [docs/infrastructure-overview.md](docs/infrastructure-overview.md). Deploys are manual (`ops/run-codebuild.rb` → CodeBuild → ECS force-deploy of `e2app-family` with `:latest`). The ECS circuit breaker rolls back failed deploys to the previous image digest and emails `e2-alerts` (#4565) |
| Active CSS-diff workflow | `tools/computed-style-diff.js --help` |

---

## Tooling

`tools/` has Puppeteer-based debugging utilities. The ones likely to come up:

- `browser-debug.js` — auth + screenshot + DOM inspection. The everyday tool.
- `e2e-demo.sh <spec>` — runs a Playwright spec that uses `tests/e2e/fixtures/demo.js` with recording on, and writes `e2e-demos/<spec>.mp4` plus numbered PNG stills (step banners, scroll-and-outline on results, green/red end state; multiple users stitched side by side; `E2E_DEMO_DEVICE=mobile` for phone resolution). Procedure: the `e2e-demo` skill.
- `computed-style-diff.js` — capture+compare computed styles across pages × themes × viewports. Used to verify the inline-styles refactor without manual screenshot review. Snapshots live in `screenshots/computed-styles/`.
- `mobile-layout-checker.js` — programmatic mobile layout validation (overflow, touch targets, font sizing).
- `cls-debug.js` — Cumulative Layout Shift analysis.
- `mobile-audit.js` — static AST audit of React components for mobile issues.
- `critic.pl` — Perl::Critic wrapper. `CRITIC_FULL=1` for full ruleset, default is bugs-only.

**Production DB queries (read-only)**: `tools/aws/readonly-query-lambda/` is an AWS Lambda you can invoke for ad-hoc SELECT/SHOW/EXPLAIN against the prod database. Single-statement only, auto-LIMITed, banned-construct-rejected, 25s server-side cap. Invoke pattern:
```bash
aws lambda invoke --function-name e2-readonly-query --region us-west-2 \
  --payload '{"sql":"SELECT user, host, plugin FROM mysql.user"}' \
  --cli-binary-format raw-in-base64-out /tmp/out.json && cat /tmp/out.json | jq
```
Useful for finding rows that would break under the MySQL 8.4 migration (the README has a catalog of audit queries). The Lambda runs as `everyuser` (full app grants) — handler-side validation is the safety perimeter, so don't try to defeat it.

Test command shortcuts: `./docker/devbuild.sh` (full rebuild + tests), `npm test` (React only), `prove -I/var/libraries/lib/perl5 t/foo.t` inside the container.

---

## Operational priorities (November 2026)

Shipped and off the board: PSGI (live), MySQL 8.4 (#4226), opcode→API (#4335), the htmlcode burndown (#4259/#4358), htmlpage retirement (#4361), the render-time mutation audit (#4298), return-based controllers (#4483), guest chrome caching (#4371 + the guest-request diet #4419), the cron sidecar (#4246), and a November security/hardening pass. These are pointers; verify with `git log` and `docs/DEVELOPER-ROADMAP.md` before acting. The destination is still a **faster, lighter, React-routed site**:

1. **Skinny controllers → APIs → pure gates.** Keep moving page logic into `POST /api/…` endpoints driven by React, and URL params + display text into React, until controllers are pure gates (80+ already live in `Everything::PureGates`). Left: ~44 non-feed Page modules that still read params, and the `$query` reads in `Delegation::maintenance`. As each Document migrates it graduates from a render-only fixture test to the submit→result→error pattern (templates: `TheOldHookedPole.test.js`, `EverythingsMostWanted.test.js`); ~56 data-fetching Documents are still render-only.

2. **React client router** (`epoch:react-routing`) — the SPA flip, not started in `react/`. Server-side primitives are done and tested (pagestate facade #4255, the `e2.meta` producer, the legacy-URL route-recovery helper: `t/101`/`t/103`/`t/120`/`t/142`/`t/143`). Remaining BUILD: the client router/resolver (it re-implements the Perl URL-recovery parsing; keep the two in parity, the LinkNode↔helper round-trip is the biggest untested risk), `useDocumentMeta`, a routing-parity harness, then the progressive flip (SSR first paint, client-route navigation). #4257 (moving `buildNodeInfoStructure` into PageState) is the structural prep.

3. **Permissions + API hygiene alongside:** #4498/#4463 (declarative permission mixins), #4301 (CSRF guard), #3768 (API status recut). The superdoc type encodes access (restricted→admin, oppressor→editor); re-assert it in every API that serves a page.

4. **Object-model epoch — deferred to last.** Finish `Everything::Node::*` on Object::Pad (not DBIC), starting with #4178 (Globals); sqitch is a parallel track that hasn't started. Pull forward only if it becomes a cost bottleneck or blocks a feature; the API layer from steps 1–2 is the seam that de-risks it.

**ecoretool/nodepack retirement** remains a long-term direction that happens organically as each step above displaces a category (htmlcode/opcode nodes → deleted; templates → React). Not a standalone project.

For "what shipped recently," run `git log --oneline --since="2 months ago"` rather than relying on a list here that will rot.

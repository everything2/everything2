# Everything2 — AI Assistant Context

**Last Updated**: 2026-06-11
**Maintainer**: Jay Bonci (jay@bonci.net)

This file is a thin layer of non-discoverable context. For anything you can derive by reading code or running `git log`, do that instead. Treat `docs/` as the deeper reference and this file as a finger pointing at it.

E2 is a 1999-vintage Perl/mod_perl/MySQL community writing site mid-modernization: React frontend, AWS Fargate, in-flight migration off the legacy delegation pattern. Solo-maintained.

---

## User preferences (durable)

- **Never create git commits.** The user handles all commits. Same for `git push`, branch deletion, force push.
- **Never use destructive shortcuts** (`--no-verify`, `--force`, `git reset --hard`) without explicit instruction.
- **Programmatic verification over manual visual review.** Manual screenshot inspection across themes/pages caused a multi-month stall in early 2026. Prefer Puppeteer / `tools/computed-style-diff.js` / `tools/mobile-layout-checker.js` style checks over "look at all these screenshots."
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

**API responses must be HTTP 200.** mod_perl appends HTML to non-200 responses, breaking JSON clients. Return errors as `[$self->HTTP_OK, {success => 0, error => '...'}]`. Never return 4xx/5xx from `Everything::API::*` controllers.

**Blessed vs hashref node access.** Controllers (`Everything::Page`, `Everything::API`) get blessed objects: `$user->title`. `Everything::Application.pm` gets raw hashrefs: `$USER->{title}`. Cross-conversion: `$user->NODEDATA` → hashref, `$APP->node_by_id($USER->{node_id})` → blessed.

**Don't ship circular hashrefs in JSON.** `$node->{type}` is itself a node hashref with circular references and will explode the JSON encoder. Extract: `$node->{type}{title}`.

**Don't call `Everything::Delegation::*` from controllers.** Implement logic in `buildReactData()` or extract to `Application.pm`. The delegation modules are being eliminated; the only remaining permitted exception is `Everything::Delegation::htmlcode::*` during migration cleanup.

**Format dates through `react/utils/dateFormat.js`, not `toLocaleDateString` directly.** Server stores all timestamps in UTC (Apache runs `TZ='+0000'`), but JS `toLocaleDateString` defaults to the *viewer's* local timezone — so a UTC timestamp late in the day renders as the next day for viewers east of UTC. Use `formatDate(input)` (long form), `formatShortDate`, `formatDateTime`, or `formatTime`. All default to `timeZone: 'UTC'`. Issue #4056 was caused by ignoring this; same bug pattern existed in ~18 components before the cleanup.

**LinkNode single-encodes; the server-side helper decodes once. Don't break the pair.** `react/components/LinkNode.js` percent-encodes title characters (`& @ + / ; ?`) exactly once via `encodeURIComponent`, and `Everything::HTML::_recover_route_params_from_request_uri` reads `$ENV{REQUEST_URI}` and decodes exactly once. The two are a matched set — change one and you must update the other, or every link with a special character in its title silently 404s (well, falls through to the `Findings:` page). The historical double-encoding workaround in `LinkNode.js` was the only thing keeping title-bearing URLs alive while the Apache rewrite block was the dispatcher; the helper replaced that workaround in #4060. Issue #4129 will eventually remove both pieces together when PSGI lands.

---

## Visual / styling

The "Kernel Blue" palette is the design system: `#38495e` primary, `#4060b0` link, `#507898` muted text, `#e8f4f8` light bg, `#3bb5c3` cool teal. Driven by CSS variables in `www/css/1973976.css` (basesheet, ~24K lines). Don't use `--e2-text-muted` as a *background* — it's a text color and themes override it inconsistently. Use `--e2-btn-secondary-*` for button backgrounds.

19 stylesheets in `www/css/`. Basesheet (`1973976.css`) carries shared structure; per-theme zensheets override colors. Refactor away from inline `style={{...}}` toward BEM classnames in basesheet is the dominant frontend pattern.

---

## Where to look

| Need | Place |
|---|---|
| Project roadmap | [docs/DEVELOPER-ROADMAP.md](docs/DEVELOPER-ROADMAP.md) (long; phases drift from reality, cross-check with `git log`) |
| MySQL 8.4 migration | ✅ **done 2026-06-07** (#4226); [docs/mysql-migration-plan.md](docs/mysql-migration-plan.md) is now a tombstone, forward work in the dependency tree + #4225 |
| ORM/DBIx::Class plan | [docs/orm-migration-plan.md](docs/orm-migration-plan.md) (Dec 2025, deferred) |
| Inline-styles refactor status | [docs/inline-styles-refactor.md](docs/inline-styles-refactor.md), [docs/css-refactor-testing.md](docs/css-refactor-testing.md) |
| Mobile audit | [docs/mobile-audit.md](docs/mobile-audit.md), `tools/mobile-layout-checker.js` |
| Schema (current) | `nodepack/dbtable/*.xml` — CREATE TABLE statements, slated for migration to versioned SQL during MySQL work |
| Special document map | `ecore/Everything/Page/*.pm` + `react/components/DocumentComponent.js` (the live registry; the old hand-curated `special-documents.md` was retired once delegation/document.pm was eliminated) |
| Active CSS-diff workflow | `tools/computed-style-diff.js --help` |

---

## Tooling

`tools/` has Puppeteer-based debugging utilities. The ones likely to come up:

- `browser-debug.js` — auth + screenshot + DOM inspection. The everyday tool.
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

## Operational priorities (June 2026, post-PSGI)

We're past the PSGI cutover (LIVE in prod) and the MySQL 8.4 migration (done #4226). These are pointers; verify with `git log`/`git status` before acting. The agreed sequence (decided June 2026) — the **destination is full React routing**, reached in this order:

1. **htmlcode retirement** (#4259, `epoch:infra-cleanup`) — *in progress, current detour.* Factor `Everything::Delegation::htmlcode` (65 subs, ~37 live) into real, unit-tested `Everything::Application` methods; update callers; retire the delegation subs + orphaned nodepack nodes. Batch 1 (`getGravatarMD5`/`DateTimeLocal`/`isSpecialDate`) merged (#4260). Thin/consolidate as we go. Each batch lands `Refs #4259` (umbrella stays open).

2. **opcode → API** (#4198, `epoch:react-routing`) — **the gating prerequisite for React routing.** Migrate live `op=` action handlers (`Everything::Delegation::opcode`, 44 subs) into `POST /api/…` endpoints so forms call APIs instead of server-side `op=` dispatch. *Full client-side React routing cannot be clean until this is done* (you can't client-route a page whose form POSTs `op=X` to be processed and re-rendered server-side). ~115/259 Pages read request params, but most are GET reads (fine through `/api/pagestate`); the blockers are the mutating actions = opcodes.

3. **React routing** (`epoch:react-routing`: #4255 ✅ pagestate facade, #4257 = 2b chrome/content split, + a client-router issue TBD) — the SPA flip. Pagestate facade + `normalize_types` + the `e2.meta` producer are done. Remaining: the React client router/resolver (parse legacy URL forms → id/type-title), `useDocumentMeta`, a routing-parity test harness, the progressive-flip strategy (keep SSR first paint, client-route subsequent nav), and 2b for the chrome cache. Gated by #4198.

4. **ORM / data-model / node-model** — **deferred.** Pull forward *only* if it becomes a cost bottleneck or blocks a needed feature. Rationale (decided June 2026): the node model is adequate today (RDS healthy, not pressured); React routing moves the cost+growth north star and is incremental/reversible; and the API layer built via #4198/React is the **seam that de-risks** a later ORM migration. Do ORM when the data model actively hurts, on the cleaner/smaller surface the API layer exposes — not speculatively first.

**ecoretool/nodepack retirement** remains a long-term direction that happens organically as each phase above displaces a category (htmlcode/opcode nodes → deleted; templates → React). Not a standalone project.

For "what shipped recently," run `git log --oneline --since="2 months ago"` rather than relying on a list here that will rot.

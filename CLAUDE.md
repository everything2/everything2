# Everything2 — AI Assistant Context

**Last Updated**: 2026-06-23
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
| CSS architecture + theme backlog | [docs/stylesheet-system.md](docs/stylesheet-system.md), [docs/css-consistency-audit.md](docs/css-consistency-audit.md) (inline-styles refactor is resolved) |
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

## Operational priorities (June 2026, post-PSGI, post-opcode)

We're past the PSGI cutover (LIVE in prod), the MySQL 8.4 migration (done #4226), and the **opcode→API migration (done #4335 — verified 2026-06-23)**: `Everything::Delegation::opcode` is gone, `execOpCode` + the `op=` dispatch are removed from `HTML.pm`, and there's no `nodepack/opcode/`. That was the gating prerequisite, so **React routing is now unblocked.** These are pointers; verify with `git log`/`git status` before acting. The destination is a **faster, lighter, React-routed site**, reached in this order:

1. **htmlcode retirement** (#4259, `epoch:infra-cleanup`) — *in progress, current detour.* Factor the remaining `Everything::Delegation::htmlcode` subs (~11 live: `publishwriteup`/`unpublishwriteup`, `atomise`, `canpublishas`, `send`, `screen`, `user`, `url`, `add`, `nopublishreason`, …) into real, unit-tested `Everything::Application` methods; update callers; retire the delegation subs + orphaned nodepack nodes. The sibling Delegation modules (`achievement`/`maintenance`/`notification`/`room`) are on the same chopping block as each is displaced. Each batch lands `Refs #4259` (umbrella stays open).

2. **Skinny controllers → APIs → React.** Keep collapsing server-rendered `Everything::Page`/legacy controller logic into thin shells over `POST /api/…` endpoints, with the React component owning state and calling the API — the pattern proven on `the_old_hooked_pole` + `everything_s_most_wanted` (#4198). This is the bulk of the controller detangle: every mutating page action becomes an API call a React view drives. As each Document migrates it should graduate from a render-only fixture test to the submit→result→error interaction pattern (templates: `TheOldHookedPole.test.js`, `EverythingsMostWanted.test.js`). ~60 API-driven Documents are still on render-only tests.

3. **React routing prep** (`epoch:react-routing`) — the SPA flip. Server-side primitives are DONE + tested: pagestate facade (#4255), `normalize_types`, the `e2.meta` producer, and the legacy-URL route-recovery helper (`t/101`/`t/103`/`t/120`/`t/142`/`t/143`). Remaining BUILD: the React client router/resolver (it re-implements the Perl URL-recovery parsing inline — keep the two parsers in parity; the cross-language LinkNode↔helper round-trip is the biggest untested risk), `useDocumentMeta`, a routing-parity harness, and the progressive flip (SSR first paint, client-route subsequent nav).

4. **Guest-user chrome caching detour** (#4257, the 2b chrome/content split) — *still to take.* The near-term **page-speed + payload-size** win: cache the non-personalized page chrome for guest users so we stop re-rendering and re-shipping it per request. This is the concrete performance reason to push routing forward; take it on the way to the full client-router flip.

5. **ORM / data-model / node-model cleanup** — **deferred to last.** Pull forward *only* if it becomes a cost bottleneck or blocks a needed feature. The node model is adequate today (RDS healthy, not pressured); the API layer built in steps 2–3 is the **seam that de-risks** a later ORM migration, so do it on the cleaner/smaller surface the APIs expose — not speculatively first.

**ecoretool/nodepack retirement** remains a long-term direction that happens organically as each step above displaces a category (htmlcode/opcode nodes → deleted; templates → React). Not a standalone project.

For "what shipped recently," run `git log --oneline --since="2 months ago"` rather than relying on a list here that will rot.

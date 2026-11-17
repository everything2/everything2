# Everything2 Documentation

Technical reference and modernization planning for the Everything2 codebase.

Most docs here describe the **current** state of the system or **active/deferred** forward work. Records of completed migrations are normally retired to git history (PSGI, the SecurityLog decoupling, the inline-styles refactor, etc.); the few still in the tree are grouped under "Historical records" below. For "what shipped recently," run `git log` rather than trusting any status line here.

**Last verified:** 2026-11-16 (every file in `docs/` and `docs/spec/` is listed below)

---

## Getting started & process
- **[Getting Started Guide](GETTING_STARTED.md)** ⭐ — Dev setup (devbuild, containers, test users), build/test workflow
- **[Quick Reference](quick-reference.md)** — Common commands, deploy, emergency checklists, log queries
- **[Coding Standards](coding-standards.md)** — Perl/Moose/JS/React style and conventions
- **[Code Coverage Guide](code-coverage.md)** — Coverage tooling (Devel::Cover + Jest)
- **[React Testing](react-testing.md)** — Jest + React Testing Library patterns
- **[Test Coverage Worklist](test-coverage-worklist.md)** — Routing-epoch test net: e2e/jest gaps and render-only Documents still to upgrade

## Roadmap & strategy
- **[Developer Roadmap](DEVELOPER-ROADMAP.md)** ⭐ — Strategic priorities, phase sequencing, current status
- **[Modernization Dependency Tree](modernization-dependency-tree.md)** — Epoch tree: what unblocks what, with issue links
- **[Modernization Priorities](modernization-priorities.md)** — Retired 13-priority plan; crosswalk to the dependency tree
- **[Controller Rationalization Inventory](controller-rationalization-inventory.md)** — Living per-module sweep: zero param reads in controllers, shared roles, permission audit

## Architecture & API
- **[API Documentation](API.md)** — Endpoint catalogue (hand-maintained; each controller's `routes()` is authoritative)
- **[API-Driven Architecture](api-driven-architecture.md)** — The controllers-return-data north star
- **[PageState Design](pagestate-design.md)** — Chrome/content split + React-routing facade
- **[PageState Key Tiers](pagestate-key-tiers.md)** — Each `window.e2` key classified by what it depends on (build/global/per-user/per-node) for the guest chrome cache (#4257)
- **[Node Object System](node-object-system.md)** — hashref-vs-blessed node access model

## Infrastructure & operations
- **[Infrastructure Overview](infrastructure-overview.md)** — AWS/Fargate/RDS/Docker, deploy pipeline, rollback, log groups and alarms
- **[Health Checks](health-checks.md)** — `Everything::HealthCheck` PSGI app + ECS/ALB health check config
- **[Maintenance Jobs](maintenance-jobs.md)** — One-off in-VPC Fargate job runner via the `e2-maintenance-jobs` bucket (#4282)
- **[Cron Sidecar](cron-sidecar.md)** — As-built leader-elected cron runner in the webheads (sitemap stays on EventBridge)
- **[Cron Sidecar Design](cron-sidecar-design.md)** — Original cost rationale + design (#4246); historical

## Migrations & plans
- **[Plack::Request Migration](plack-request-migration.md)** — ✅ CGI.pm removed; immutable-param and PageState follow-ups open
- **[ORM Migration Plan](orm-migration-plan.md)** — Decided 2026-06-29: no DBIx::Class; finish `Node::*` on Object::Pad
- **[Sqitch Migration Plan](sqitch-migration-plan.md)** — Versioned-schema plan (not started)
- **[React 19 Migration](react-19-migration.md)** — Not started; blocked only on `react-collapsible`

## Frontend & CSS
- **[Stylesheet System](stylesheet-system.md)** — Node-based stylesheet architecture + Kernel Blue variables
- **[CSS Consistency Audit](css-consistency-audit.md)** — Remaining per-theme variable/softlink backlog
- **[Mobile Audit](mobile-audit.md)** — Regenerable output of `tools/mobile-audit.js`

## Reference
- **[User VARS Reference](user-vars-reference.md)** — Catalogue of `setting.vars` keys and where they're read/written

## Historical records (completed work, kept for reference)
- **[MySQL 8.4 Migration](mysql-migration-plan.md)** — ✅ Done 2026-06-07 (#4226); tombstone/signpost
- **[Opcode Audit](opcode-audit.md)** — ✅ opcode→API retirement done (#4335); per-round record
- **[Step 1: Return-based Controllers](step1-return-based-controllers.md)** — ✅ STDOUT capture retired, controllers return responses (#4483)
- **[API Polling Optimization](api-polling-optimization.md)** — ✅ `initialData` nodelet polling (Nov 2025)
- **[Draft System Analysis](draft-system-analysis.md)** — Dec 2025 snapshot of the draft/writeup/publication model; not current

## Subsystem specs (`spec/`)
Focused descriptions of individual live subsystems:
- [Apache configuration](spec/apache-configuration.md) — Apache mpm_event reverse proxy to Starman: template, tuning, logging, mod_evasive
- [Apache blocks](spec/apache_blocks.md) — IP / IP-prefix / user-agent bans from `etc/apache_blocks.json`
- [Categories system](spec/categories-system.md) — User-curated node lists (React + `API::category`)
- [Developer sourcemap system](spec/developer-sourcemap-system.md) — Links E2 pages to their source components on GitHub
- [E2 global state](spec/e2-global-state.md) — The `window.e2` object every page load receives
- [Favorite noders](spec/favorite-noders.md) — Following users and the Favorite Noders nodelet
- [Halloween costume system](spec/halloween-costume-system.md) — Seasonal purchasable display-name costumes
- [Link syntax specification](spec/link-syntax-specification.md) — E2 `[bracket]` link syntax (`react/utils/linkParser.js`)
- [Node cache architecture](spec/node-cache-architecture.md) — Per-worker NodeCache and `version`-table coherency
- [Nodetype inheritance tree](spec/nodetype-inheritance-tree.md) — Nodetype hierarchy, sqltables, and controllers
- [Notification system](spec/notification-system.md) — Notification types, producers, and rendering
- [Nodelet periodic updates](spec/nodelet-periodic-updates.md) — Activity-aware background polling for nodelets
- [Other Users nodelet](spec/other-users-nodelet-spec.md) — Live chatterbox user list (React + API)
- [Random Nodes nodelet](spec/random-nodes-nodelet.md) — Rotating random e2nodes (React + DataStash)
- [State-mutating pages](spec/state-mutating-pages.md) — Which Documents mutate state and whether each goes through an API
- [XP recalculation system](spec/xp-recalculation-system.md) — 2008 legacy-XP conversion tool

---

## Maintaining these docs
- Keep technical accuracy first; cross-check claims against code and `git log` before trusting a status line.
- When a migration/refactor completes, **retire** its planning doc (git retains it) rather than leaving a stale plan.
- If a doc's only remaining value is tracking unfinished work, convert it to a GitHub issue.
- Broad roadmap docs (Developer Roadmap, dependency tree) are the exception — keep them as living indexes.

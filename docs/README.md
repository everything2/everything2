# Everything2 Documentation

Technical reference and modernization planning for the Everything2 codebase.

This index lists only docs that describe the **current** state of the system or **active/deferred** forward work. Records of completed migrations (PSGI, MySQL 8.4, the SecurityLog decoupling, the inline-styles refactor, etc.) have been retired — they live in git history. For "what shipped recently," run `git log` rather than trusting any status line here.

**Last reviewed:** 2026-06-15

---

## Getting started & process
- **[Getting Started Guide](GETTING_STARTED.md)** ⭐ — Dev setup, build/test workflow
- **[Quick Reference](quick-reference.md)** — Common commands and checklists
- **[Coding Standards](coding-standards.md)** — Perl/Moose/JS/React style and conventions
- **[Code Coverage Guide](code-coverage.md)** — Coverage tooling (Devel::Cover + Jest)
- **[React Testing](react-testing.md)** — Jest + React Testing Library patterns

## Roadmap & strategy
- **[Developer Roadmap](DEVELOPER-ROADMAP.md)** ⭐ — Strategic priorities, phase sequencing, current status
- **[Modernization Dependency Tree](modernization-dependency-tree.md)** — What unblocks what
- **[Modernization Priorities](modernization-priorities.md)** — Crosswalk/redirect to the dependency tree
- **[Opcode Audit](opcode-audit.md)** — opcode→API burndown tracker (8 live opcodes as of 2026-06)

## Architecture & API
- **[API Documentation](API.md)** — Endpoint catalogue (hand-maintained; each controller's `routes()` is authoritative)
- **[API-Driven Architecture](api-driven-architecture.md)** — The controllers-return-data north star
- **[API Polling Optimization](api-polling-optimization.md)** — `initialData` nodelet polling
- **[PageState Design](pagestate-design.md)** — Chrome/content split + React-routing facade
- **[Node Object System](node-object-system.md)** — hashref-vs-blessed node access model
- **[Draft System Analysis](draft-system-analysis.md)** — Draft/writeup/publication model

## Infrastructure & operations
- **[Infrastructure Overview](infrastructure-overview.md)** — AWS/Fargate/RDS/Docker, PSGI/Starman
- **[Health Checks](health-checks.md)** — `Everything::HealthCheck` PSGI app + ECS health config
- **[Maintenance Jobs](maintenance-jobs.md)** — One-off Fargate S3-job runner facility (#4282)
- **[Cron Sidecar](cron-sidecar.md)** — As-built leader-elected cron runner
- **[Cron Sidecar Design](cron-sidecar-design.md)** — Original cost rationale + design (#4246)

## Migrations — status
- **[MySQL 8.4 Migration](mysql-migration-plan.md)** — ✅ Done (2026-06-07); tombstone/signpost
- **[Plack::Request Migration](plack-request-migration.md)** — ✅ CGI.pm removed; PageState/param follow-ups deferred
- **[ORM Migration Plan](orm-migration-plan.md)** — Evaluated, **deferred** (modernize NodeBase in place)
- **[Sqitch Migration Plan](sqitch-migration-plan.md)** — Versioned-schema plan (not yet adopted)
- **[React 19 Migration](react-19-migration.md)** — Deferred (blocked on `react-collapsible`)

## Frontend & CSS
- **[Stylesheet System](stylesheet-system.md)** — Node-based stylesheet architecture + Kernel Blue variables
- **[CSS Consistency Audit](css-consistency-audit.md)** — Remaining per-theme variable/softlink backlog
- **[Mobile Audit](mobile-audit.md)** — Regenerable output of `tools/mobile-audit.js`

## Reference
- **[User VARS Reference](user-vars-reference.md)** — Catalogue of `setting.vars` keys

## Subsystem specs (`spec/`)
Focused descriptions of individual live subsystems:
- [Apache configuration](spec/apache-configuration.md) · [Apache blocks (IP/UA bans)](spec/apache_blocks.md)
- [Categories system](spec/categories-system.md) · [Favorite noders](spec/favorite-noders.md)
- [Developer sourcemap system](spec/developer-sourcemap-system.md) · [E2 global state](spec/e2-global-state.md)
- [Halloween costume system](spec/halloween-costume-system.md) · [Link syntax specification](spec/link-syntax-specification.md)
- [Node cache architecture](spec/node-cache-architecture.md) · [Nodetype inheritance tree](spec/nodetype-inheritance-tree.md)
- [Notification system](spec/notification-system.md) · [Nodelet periodic updates](spec/nodelet-periodic-updates.md)
- [Other Users nodelet](spec/other-users-nodelet-spec.md) · [Random Nodes nodelet](spec/random-nodes-nodelet.md)
- [XP recalculation system](spec/xp-recalculation-system.md)

---

## Maintaining these docs
- Keep technical accuracy first; cross-check claims against code and `git log` before trusting a status line.
- When a migration/refactor completes, **retire** its planning doc (git retains it) rather than leaving a stale plan.
- If a doc's only remaining value is tracking unfinished work, convert it to a GitHub issue.
- Broad roadmap docs (Developer Roadmap, dependency tree) are the exception — keep them as living indexes.

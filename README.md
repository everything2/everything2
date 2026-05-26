# Everything2

![Perl Coverage](coverage/badges/perl-coverage.svg)
![React Coverage](coverage/badges/react-coverage.svg)

Everything2 is a user-submitted content website emphasizing writing and connectivity between entries. Visit us at [everything2.com](https://everything2.com).

## Getting Started

**Quick start for developers:**

```bash
# Install Docker Desktop, then:
./docker/devbuild.sh

# Visit http://localhost:9080
```

See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) for complete development setup.

## Architecture

- **Backend:** Perl 5.38 + mod_perl2 + Apache2 + MySQL 8.0 (migrating to 8.4 LTS by July 2026)
- **Frontend:** React 18.3 + Webpack 5 (jQuery fully retired; legacy Mason templates fully retired)
- **Infrastructure:** AWS Fargate ECS, CodeBuild CI/CD, S3 asset storage, RDS MySQL
- **Development:** Docker containers (`e2devapp`, `e2devdb`) with automated testing

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| [ecore/](ecore/) | Core Everything libraries (Perl/Moose OOP) |
| [react/](react/) | React 18 frontend components |
| [www/](www/) | Static web assets (CSS, JS, images) |
| [t/](t/) | Test suite (automated in build) |
| [docker/](docker/) | Development and production containers |
| [nodepack/](nodepack/) | Node/schema artifacts (XML dumps from production) |
| [tools/](tools/) | Puppeteer/Perl utilities for debugging, coverage, layout checks |
| [docs/](docs/) | **Comprehensive documentation and guides** |

[View all directories →](docs/GETTING_STARTED.md#repository-structure)

## Documentation

### For Developers
- **[Getting Started](docs/GETTING_STARTED.md)** — Development setup and workflow
- **[Coding Standards](docs/coding-standards.md)** — Perl/JavaScript style guide
- **[Quick Reference](docs/quick-reference.md)** — Common commands and patterns
- **[Code Coverage Guide](docs/code-coverage.md)** — Coverage tooling and methodology

### Strategy & Architecture
- **[Developer Roadmap](docs/DEVELOPER-ROADMAP.md)** ⭐ — Strategic priorities, 11-phase sequencing, current status
- **[MySQL 8.4 Migration Plan](docs/mysql-migration-plan.md)** — Active workstream (deadline 2026-07-31)
- **[PSGI/Plack Migration Plan](docs/psgi-plack-migration-plan.md)** — Next major backend work
- **[ORM Migration Plan](docs/orm-migration-plan.md)** — NodeBase modernization strategy
- **[Infrastructure Overview](docs/infrastructure-overview.md)** — AWS/Docker deployment
- **[React Analysis](docs/react-analysis.md)** — Frontend implementation notes

**[Browse all documentation →](docs/README.md)**

## Current Modernization Status

| Workstream | Status | Notes |
|------------|--------|-------|
| SQL Injection Audit | ✅ Complete | Apr 2026 audit: zero remaining vulnerable sites |
| jQuery Removal | ✅ Complete | Fully retired; React covers all interactive UI |
| Mason Template Removal | ✅ Complete | `templates/` no longer carries server-rendered views |
| Inline-styles → BEM CSS Refactor | ✅ Landed | ~280-file refactor merged Apr–May 2026 |
| Mobile Redesign | ✅ Shipped | Bottom-nav layout, mobile audit tooling in `tools/` |
| Date/Timezone Standardization | ✅ Done | 18 components migrated to `react/utils/dateFormat.js` |
| Testing Infrastructure | ✅ Stable | Automated via `./docker/devbuild.sh` |
| Code Coverage | ✅ Tracked | Perl 47.9% / React tracked via Jest |
| **MySQL 8.4 Migration** | 🔄 In progress | Hard deadline 2026-07-31; 17 schema-fix issues open |
| PSGI/Plack Migration | 📋 Planned | Post-MySQL; ~$90/mo Fargate savings |
| DBIx::Class / Schema Migrations | 📋 Deferred | Post-PSGI; modernize NodeBase in place first |

See [coverage/COVERAGE-SUMMARY.md](coverage/COVERAGE-SUMMARY.md) for coverage details and [docs/DEVELOPER-ROADMAP.md](docs/DEVELOPER-ROADMAP.md) for full sequencing rationale.

## Testing

Tests run automatically during `./docker/devbuild.sh`. To run manually:

```bash
./docker/run-tests.sh              # Run all tests
./docker/run-tests.sh 012          # Run specific test
./docker/run-tests.sh sql          # Run tests matching pattern
./tools/coverage.sh                # Run tests with code coverage
```

**Current Status:** All tests passing; Perl::Critic checks passing.

**Code Coverage:** ![Perl Coverage](coverage/badges/perl-coverage.svg) ![React Coverage](coverage/badges/react-coverage.svg)

Coverage is tracked via Devel::Cover (Perl) and Jest (React). Badges update automatically during `./docker/devbuild.sh --coverage` runs. See [coverage/COVERAGE-SUMMARY.md](coverage/COVERAGE-SUMMARY.md) for detailed reports and [docs/code-coverage.md](docs/code-coverage.md) for methodology.

## Contributing

1. Fork the repository
2. Create a [GitHub issue](https://github.com/everything2/everything2/issues) (if one doesn't exist)
3. Create a feature branch: `issue/ISSUE_NUMBER/short-description`
4. Follow [Coding Standards](docs/coding-standards.md)
5. Add tests for new features
6. Ensure all tests pass (`./docker/run-tests.sh`)
7. Submit a pull request referencing the issue

**Branch naming convention:** `issue/ISSUE_NUMBER/short-description`
- Example: `issue/4048/new-writeups-anchor`

See [Contributing Guide](docs/GETTING_STARTED.md#contributing) for full details.

## Technology Stack

**Backend:**
- Perl 5.38 with Moose
- mod_perl2 + Apache2 (CGI-style scripts via `ModPerl::Registry`)
- MySQL 8.0 → migrating to 8.4 LTS
- DBI with `Apache::DBI` for connection reuse

**Frontend:**
- React 18.3 (~80 top-level components + ~250 Document components)
- Webpack 5 asset bundling
- DOMPurify for sanitized HTML rendering
- Shared utilities under `react/utils/` (e.g. `dateFormat.js`)

**Infrastructure:**
- AWS Fargate ECS (container orchestration)
- AWS CodeBuild (CI/CD)
- AWS RDS MySQL
- AWS S3 (asset storage with versioning)
- Cloudflare (CDN/edge)

**Development:**
- Carton (Perl dependency management)
- npm (Node.js dependencies)
- Test::More + Devel::Cover (Perl testing & coverage)
- Jest (React testing & coverage)
- Perl::Critic (code quality)
- Puppeteer-based debugging tools in `tools/`

## Security

If you discover a security vulnerability:

1. **Do NOT** open a public GitHub issue
2. Contact the maintainer privately at jay@bonci.net

**Recent Security Work:**
- ✅ April 2026 SQL injection re-audit: zero vulnerable sites remaining
- ✅ Test coverage in place for security-sensitive code paths
- 🔄 Ongoing: NodeBase modernization to eliminate raw-SQL call sites in controllers

## License

This project is licensed under the same terms as Perl itself, under either:

* The GNU General Public License as published by the Free Software Foundation; either version 1, or (at your option) any later version, or
* The Artistic License

See the Perl documentation for details on these licenses.

## Links

- **Website:** [everything2.com](https://everything2.com)
- **Issues:** [GitHub Issues](https://github.com/everything2/everything2/issues)
- **Documentation:** [docs/](docs/) directory

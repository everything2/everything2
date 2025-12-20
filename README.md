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

- **Backend:** Perl 5.38 + mod_perl2 + Apache2 + MySQL 8.0
- **Frontend:** React 18.2.0 + Webpack (with legacy jQuery being phased out)
- **Infrastructure:** AWS Fargate ECS, CodeBuild CI/CD, S3 asset storage
- **Development:** Docker containers with automated testing

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| [ecore/](ecore/) | Core Everything libraries (Perl/Moose OOP) |
| [react/](react/) | React 18 frontend components |
| [templates/](templates/) | Mason2 server-side templates |
| [www/](www/) | Static web assets (CSS, JS, images) |
| [t/](t/) | Test suite (automated in build) |
| [docker/](docker/) | Development and production containers |
| [docs/](docs/) | 📚 **Comprehensive documentation and guides** |

[View all directories →](docs/GETTING_STARTED.md#repository-structure)

## Documentation

### For Developers
- **[Getting Started](docs/GETTING_STARTED.md)** - Development setup and workflow
- **[Coding Standards](docs/coding-standards.md)** - Perl/JavaScript style guide
- **[Quick Reference](docs/quick-reference.md)** - Common commands and patterns

### Technical Analysis
- **[Analysis Summary](docs/analysis-summary.md)** - Complete architectural overview ⭐
- **[Modernization Priorities](docs/modernization-priorities.md)** - Strategic roadmap
- **[React Analysis](docs/react-analysis.md)** - Frontend implementation
- **[Infrastructure Overview](docs/infrastructure-overview.md)** - AWS/Docker deployment

**[Browse all documentation →](docs/README.md)**

## Current Modernization Status

| Priority | Status | Progress |
|----------|--------|----------|
| SQL Injection Fixes | ✅ Complete | 4/4 critical vulnerabilities fixed |
| Database Code Removal | 🔄 In Progress | 81% migrated to filesystem |
| Testing Infrastructure | ✅ Complete | Automated in build process |
| Code Coverage Tracking | ✅ Working | Mock-based tests enable coverage tracking |
| Mobile Responsiveness | ⚠️ Critical Gap | Zero mobile CSS currently |
| jQuery Removal | 📋 Planned | jQuery 1.11.1 → React/vanilla JS |

See [docs/status.md](docs/status.md) for detailed progress tracking and [coverage/COVERAGE-SUMMARY.md](coverage/COVERAGE-SUMMARY.md) for coverage details.

## Testing

Tests run automatically during `./docker/devbuild.sh`. To run manually:

```bash
./docker/run-tests.sh              # Run all tests
./docker/run-tests.sh 012          # Run specific test
./docker/run-tests.sh sql          # Run tests matching pattern
./tools/coverage.sh                # Run tests with code coverage
```

**Current Status:** All tests passing, Perl::Critic checks passing (235/235 modules).

**Code Coverage:** ![Perl Coverage](coverage/badges/perl-coverage.svg) ![React Coverage](coverage/badges/react-coverage.svg)

Coverage is now tracked via mock-based API tests and Jest. Badges update automatically during `./docker/devbuild.sh` runs. See [coverage/COVERAGE-SUMMARY.md](coverage/COVERAGE-SUMMARY.md) for detailed coverage reports and [Code Coverage Guide](docs/code-coverage.md) for methodology.

## Contributing

1. Fork the repository
2. Create a [GitHub issue](https://github.com/everything2/everything2/issues) (if one doesn't exist)
3. Create a feature branch: `issue/ISSUE_NUMBER/short-description`
4. Follow [Coding Standards](docs/coding-standards.md)
5. Add tests for new features
6. Ensure all tests pass (`./docker/run-tests.sh`)
7. Submit a pull request referencing the issue

**Branch naming convention:** `issue/ISSUE_NUMBER/short-description`
- Example: `issue/3597/broken-rdf-feed`

See [Contributing Guide](docs/GETTING_STARTED.md#contributing) for full details.

## Technology Stack

**Backend:**
- Perl 5.38 with Moose (100+ modules)
- mod_perl2 + Apache2
- MySQL 8.0+ with DBI
- Mason2 templating

**Frontend:**
- React 18.2.0 (29 components)
- Webpack 5 asset bundling
- Legacy jQuery 1.11.1 (being removed)

**Infrastructure:**
- AWS Fargate ECS (container orchestration)
- AWS CodeBuild (CI/CD)
- Docker (development + production)
- S3 (asset storage with versioning)

**Development:**
- Carton (Perl dependency management)
- npm (Node.js dependencies)
- Test::More (Perl testing)
- perlcritic (code quality)

## Security

We take security seriously. If you discover a security vulnerability:

1. **Do NOT** open a public GitHub issue
2. Contact the maintainers privately
3. See [SECURITY.md](docs/SECURITY.md) for details (if available)

**Recent Security Work:**
- ✅ Fixed 4 critical SQL injection vulnerabilities (2025-11-07)
- ✅ Added comprehensive test coverage for security fixes
- 🔄 Ongoing: Database code removal (eliminates eval security risks)

## License

This project is licensed under the same terms as Perl itself, under either:

* The GNU General Public License as published by the Free Software Foundation; either version 1, or (at your option) any later version, or
* The Artistic License

See the Perl documentation for details on these licenses.

## Links

- **Website:** [everything2.com](https://everything2.com)
- **Issues:** [GitHub Issues](https://github.com/everything2/everything2/issues)
- **Documentation:** [docs/](docs/) directory

---

**Last Updated:** 2025-12-17
**Build Status:** ✅ All tests passing, Perl::Critic 235/235 modules
**Code Coverage:** ![Perl](coverage/badges/perl-coverage.svg) ![React](coverage/badges/react-coverage.svg) - See [COVERAGE-SUMMARY.md](coverage/COVERAGE-SUMMARY.md)
**Modernization:** 📚 See [DEVELOPER-ROADMAP.md](docs/DEVELOPER-ROADMAP.md) for 12-phase modernization plan

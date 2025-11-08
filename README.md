# Everything2

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
| [claude/](claude/) | 📚 **Comprehensive modernization documentation** |
| [docs/](docs/) | Additional documentation |

[View all directories →](docs/GETTING_STARTED.md#repository-structure)

## Documentation

### For Developers
- **[Getting Started](docs/GETTING_STARTED.md)** - Development setup and workflow
- **[Coding Standards](claude/coding-standards.md)** - Perl/JavaScript style guide
- **[Quick Reference](claude/quick-reference.md)** - Common commands and patterns

### Technical Analysis
- **[Analysis Summary](claude/analysis-summary.md)** - Complete architectural overview ⭐
- **[Modernization Priorities](claude/modernization-priorities.md)** - Strategic roadmap
- **[React Analysis](claude/react-analysis.md)** - Frontend implementation
- **[Infrastructure Overview](claude/infrastructure-overview.md)** - AWS/Docker deployment

**[Browse all documentation →](claude/README.md)**

## Current Modernization Status

| Priority | Status | Progress |
|----------|--------|----------|
| SQL Injection Fixes | ✅ Complete | 4/4 critical vulnerabilities fixed |
| Database Code Removal | 🔄 In Progress | 81% migrated to filesystem |
| Testing Infrastructure | ✅ Complete | Automated in build process |
| Mobile Responsiveness | ⚠️ Critical Gap | Zero mobile CSS currently |
| jQuery Removal | 📋 Planned | jQuery 1.11.1 → React/vanilla JS |

See [claude/status.md](claude/status.md) for detailed progress tracking.

## Testing

Tests run automatically during `./docker/devbuild.sh`. To run manually:

```bash
./docker/run-tests.sh              # Run all tests
./docker/run-tests.sh 012          # Run specific test
./docker/run-tests.sh sql          # Run tests matching pattern
```

**Current Status:** 40/40 SQL injection tests passing, test infrastructure fully operational.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow [Coding Standards](claude/coding-standards.md)
4. Add tests for new features
5. Ensure all tests pass (`./docker/run-tests.sh`)
6. Submit a pull request

See [CONTRIBUTING.md](docs/GETTING_STARTED.md#contributing) for details.

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

[Add license information here]

## Links

- **Website:** [everything2.com](https://everything2.com)
- **Issues:** [GitHub Issues](https://github.com/everything2/everything2/issues)
- **Documentation:** [claude/](claude/) directory

---

**Last Updated:** 2025-11-07
**Build Status:** ✅ Tests passing (40/40 SQL injection tests)
**Modernization:** 📚 Comprehensive documentation available in [claude/](claude/)

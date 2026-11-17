# Everything2 Development Guide

**Last verified:** 2026-11-16

## Quick Start

Everything2 is a user-submitted content website emphasizing writing and connectivity between entries. This guide will get you set up for local development.

### Prerequisites

- Docker Desktop
- Git

### Initial Setup

1. Clone the repository
2. From the main directory, run `./docker/devbuild.sh`
3. Wait for database initialization and tests to complete (~2-5 minutes first time)
4. Visit http://localhost:9080

The build script automatically detects if the database container exists. On subsequent runs, it will only rebuild the application container unless you use `--db-only` or `--clean` flags.

**Source files are not volume-mounted** into the container. After editing code, run `./docker/devbuild.sh --skip-tests` (or the full build) to apply the change.

### Default User Credentials

The development database is seeded with test users (full list in `tools/seeds.pl`):

- **Username:** `root` (super user with full admin privileges), **Password:** `blah`
- `genericdev`, `genericeditor`, `genericchanop`, `normaluser1`–`normaluser30`, and users with special characters like `user with space`: password `blah`
- The `e2e_*` users (`e2e_admin`, `e2e_editor`, `e2e_user`, ...): password `test123`

To log in:
1. Visit http://localhost:9080
2. Use any seeded username (e.g., `root`)
3. Enter password: `blah`

**Note:** These credentials are for local development only and are never used in production.

## Repository Structure

* **[cf](https://github.com/everything2/everything2/tree/master/cf)** - CloudFormation templates for AWS infrastructure
* **[cron](https://github.com/everything2/everything2/tree/master/cron)** - Cron job scripts; run by the in-webhead cron sidecar (see [cron-sidecar.md](cron-sidecar.md))
* **[docker](https://github.com/everything2/everything2/tree/master/docker)** - Docker images for production and development builds
* **[docs](https://github.com/everything2/everything2/tree/master/docs)** - Documentation, guides, and technical analysis (this directory)
* **[ecore](https://github.com/everything2/everything2/tree/master/ecore)** - Core Everything libraries (Perl/Moose OOP)
* **[ecoretool](https://github.com/everything2/everything2/tree/master/ecoretool)** - Legacy tool for importing/exporting nodepack nodes (being retired)
* **[etc](https://github.com/everything2/everything2/tree/master/etc)** - Configuration (Apache template, `apache_blocks.json`, Webpack, environment JSON)
* **[jobs](https://github.com/everything2/everything2/tree/master/jobs)** - Manual server processes run by operations
* **[nodepack](https://github.com/everything2/everything2/tree/master/nodepack)** - Infrastructure nodes, exported to XML
* **[ops](https://github.com/everything2/everything2/tree/master/ops)** - Cloud operation scripts (AWS CodeBuild, ECS deployment)
* **[react](https://github.com/everything2/everything2/tree/master/react)** - React 18 frontend (components, hooks, utils, Jest tests)
* **[t](https://github.com/everything2/everything2/tree/master/t)** - Perl test suite (runner: `t/run.pl`)
* **[tools](https://github.com/everything2/everything2/tree/master/tools)** - Build, debugging, and ops tools (asset pipeline, perlcritic, Puppeteer helpers like `browser-debug.js`)
* **[vendor](https://github.com/everything2/everything2/tree/master/vendor)** - Vendored Perl dependency tarballs (`vendor/cache/`)
* **[www](https://github.com/everything2/everything2/tree/master/www)** - Document root: CSS, built React bundles, static files, verification files

The app entry point is `app.psgi` at the repo root.

## Development Workflow

### Running Tests

Run all tests:
```bash
./docker/run-tests.sh
```

Run specific test:
```bash
./docker/run-tests.sh 012          # By number
./docker/run-tests.sh sql          # By pattern
```

Tests automatically run during `./docker/devbuild.sh` (skip with `--skip-tests`). React tests alone: `npm test`. A single Perl test inside the container: `docker exec e2devapp prove -I/var/libraries/lib/perl5 t/NNN_name.t`.

### Debugging

- App log (Starman, app warnings, cron sidecar): `docker exec e2devapp tail -f /tmp/development.log`. Apache's `/var/log/apache2/error.log` stays empty.
- The page HTML is rendered client-side by React, so `curl` only shows the server scaffolding. Use `node tools/browser-debug.js` (Puppeteer; commands listed in its header) to inspect rendered pages; curl is fine for `/api/...` JSON.
- MySQL shell: `docker exec -it e2devdb mysql -u root -pblah everything`

### Working with Perl Dependencies

Perl dependencies are listed in `cpanfile` (resolved versions in `cpanfile.snapshot`), and their tarballs are vendored in `vendor/cache/`. The Docker build installs them with `cpanm --from vendor/cache` into `/var/libraries`, so nothing is fetched from CPAN at build time.

To add or update a dependency:
1. Modify `cpanfile`
2. Refresh `cpanfile.snapshot` and add the new tarballs to `vendor/cache/` (for example with `carton install && carton bundle`, which writes `vendor/cache`)
3. Commit `cpanfile`, `cpanfile.snapshot`, and the `vendor/cache/` changes
4. Rebuild: `./docker/devbuild.sh`

ImageMagick's Perl bindings come from the OS package (`perlmagick`), not CPAN.

### Node version

The Node version is pinned in `/.nvmrc`. CodeBuild, the Docker image, and `devbuild.sh` all read it. To bump Node, edit `.nvmrc` (and keep the `NODE_VERSION` default in `docker/e2app/Dockerfile` in sync).

### Code Style

Follow the [Coding Standards](coding-standards.md):
- Use prepared statements for all SQL queries (prevent injection)
- Use `$ref->{key}` not `$$ref{key}` (Perl Best Practices)
- Use Moose for new OOP code
- Run `perlcritic` before committing

### Docker Commands

The `devbuild.sh` script intelligently manages both database and application containers.

**Basic build (auto-detects what's needed):**
```bash
./docker/devbuild.sh
# → Builds DB if missing, always rebuilds app, runs tests
```

**Build specific components:**
```bash
./docker/devbuild.sh --db-only    # Build only database container
./docker/devbuild.sh --app-only   # Build only application container
```

**Clean and start fresh:**
```bash
./docker/devbuild.sh --clean      # Remove all containers, images, network
# Or use the wrapper:
./docker/devclean.sh

# Skip tests (fastest way to apply a code change)
./docker/devbuild.sh --skip-tests

# Run with code coverage
./docker/devbuild.sh --coverage
```

**Common workflows:**
```bash
# Code changes only (fastest - skips DB)
./docker/devbuild.sh --app-only

# Database schema changes
./docker/devdbbuild.sh            # Wrapper for --db-only

# Complete rebuild
./docker/devbuild.sh --clean && ./docker/devbuild.sh
```

**Container management:**
```bash
# Stop containers
docker stop e2devapp e2devdb

# View logs
docker exec e2devapp tail -f /tmp/development.log   # App log
docker logs e2devapp -f           # Container startup output
docker logs e2devdb -f            # Database logs

# Shell access (convenience script)
./tools/shell.sh                  # App container shell in /var/everything
./tools/shell.sh /tmp             # App container shell in specific directory

# Shell access (raw docker commands)
docker exec -it e2devapp bash     # App container
docker exec -it e2devdb bash      # Database container

# Check status
docker ps --filter "name=e2dev"
```

**Database initialization:**
The database container automatically runs `qareload.pl` to load nodepack and seeds on first build. The app container waits for the `/etc/everything/dev_db_ready` flag file before starting.

## Architecture Overview

### Backend
- **Perl** on **Starman/PSGI** (`app.psgi`); **Apache (mpm_event)** runs as a reverse proxy only — mod_perl is gone
- **Moose** - OOP framework for `ecore/Everything/*`
- **MySQL 8.4** - Primary database

### Frontend
- **React 18.3** - All page rendering
- **Webpack** - Asset bundling
- jQuery has been removed

### Infrastructure
- **AWS Fargate ECS** (ARM64) - Container orchestration
- **AWS CodeBuild** - Builds the image; deploys are started with `./ops/run-codebuild.rb`
- **S3** - Built JS/CSS stored under the git commit SHA
- **Docker** - Development and production containers

See [infrastructure-overview.md](infrastructure-overview.md) for details.

## Key Modernization Priorities

See [DEVELOPER-ROADMAP.md](DEVELOPER-ROADMAP.md) for the current roadmap, and run `git log` for up-to-date status.

## Documentation

For comprehensive technical documentation, architecture analysis, and modernization plans:

- **[Docs index](README.md)** - Every doc in `docs/`, with descriptions
- **[Quick Reference](quick-reference.md)** - Common commands and workflows
- **[Coding Standards](coding-standards.md)** - Style guide and best practices
- **[Developer Roadmap](DEVELOPER-ROADMAP.md)** - Strategic roadmap

## Getting Help

- Check existing issues: https://github.com/everything2/everything2/issues
- Review documentation in `docs/` directory
- Ask in development channels

## Contributing

### Workflow

1. **Fork the repository**
2. **Create a GitHub issue** (if one doesn't exist): https://github.com/everything2/everything2/issues
3. **Create a feature branch** following the naming convention:
   ```bash
   git checkout -b issue/ISSUE_NUMBER/short-description
   ```
   Example: `issue/3596/broken-rdf-feed` or `issue/3594/auto-managed-googleads`
4. **Make your changes** - Follow [coding-standards.md](coding-standards.md)
5. **Add tests for new features**
6. **Ensure all tests pass** - Run `./docker/run-tests.sh`
7. **Commit with proper message**:
   ```bash
   git commit -m "Fix description

   Detailed explanation of changes.

   Fixes #ISSUE_NUMBER"
   ```
8. **Push to your fork**:
   ```bash
   git push origin issue/ISSUE_NUMBER/short-description
   ```
9. **Create Pull Request** on GitHub:
   - Go to https://github.com/everything2/everything2/pulls
   - Click "New pull request"
   - Select your branch
   - Fill in PR description with `Fixes #ISSUE_NUMBER`
   - Submit for review

**See [Pull Request Guidelines](coding-standards.md#pull-request-creation) for detailed PR requirements.**

### Branch Naming Convention

All branches should follow the format:
```
issue/ISSUE_NUMBER/short-description
```

**Examples:**
- `issue/3597/broken-rdf-feed` - Fixes issue #3597
- `issue/3594/auto-managed-googleads` - Implements issue #3594
- `issue/3591/redirect-to-dotcom` - Addresses issue #3591

**Why this convention?**
- Easy issue tracking and traceability
- Clear linkage between code and reported issues
- Automated PR/issue linking in GitHub
- Consistent git history

### Code Quality Requirements

- All Perl code must pass `./docker/run-tests.sh`
- All modules must pass Perl::Critic checks
- SQL queries must use prepared statements (no string interpolation)
- Follow the style guide in [coding-standards.md](coding-standards.md)

---

**Last verified:** 2026-11-16

# Everything2 Development Guide

## Quick Start

Everything2 is a user-submitted content website emphasizing writing and connectivity between entries. This guide will get you set up for local development.

### Prerequisites

- Docker Desktop
- Git

### Initial Setup

1. Clone the repository
2. From the main directory, run `./docker/devbuild.sh`
3. Visit http://localhost:9080

Make changes to the source directory and re-run `./docker/devbuild.sh` to rebuild and relaunch the container. The database won't be touched unless you explicitly run the corresponding `devclean.sh` script.

## Repository Structure

* **[cf](https://github.com/everything2/everything2/tree/master/cf)** - CloudFormation templates for AWS infrastructure
* **[cron](https://github.com/everything2/everything2/tree/master/cron)** - Cron jobs, run in ECS Fargate, can be simulated manually
* **[docker](https://github.com/everything2/everything2/tree/master/docker)** - Docker images for production and development builds
* **[docs](https://github.com/everything2/everything2/tree/master/docs)** - Documentation, guides, and technical analysis (this directory)
* **[ecore](https://github.com/everything2/everything2/tree/master/ecore)** - Core Everything libraries (Perl/Moose OOP)
* **[ecoretool](https://github.com/everything2/everything2/tree/master/ecoretool)** - Tool for importing/exporting database nodes
* **[etc](https://github.com/everything2/everything2/tree/master/etc)** - Configuration files (Apache, Webpack, etc.)
* **[jobs](https://github.com/everything2/everything2/tree/master/jobs)** - Manual server processes run by operations
* **[node_modules](https://github.com/everything2/everything2/tree/master/node_modules)** - Node.js dependencies (npm install)
* **[nodepack](https://github.com/everything2/everything2/tree/master/nodepack)** - Infrastructure nodes, exported to XML
* **[ops](https://github.com/everything2/everything2/tree/master/ops)** - Cloud operation scripts (AWS CodeBuild, ECS deployment)
* **[react](https://github.com/everything2/everything2/tree/master/react)** - Modern React 18 frontend components
* **[t](https://github.com/everything2/everything2/tree/master/t)** - Test suite (Perl tests)
* **[templates](https://github.com/everything2/everything2/tree/master/templates)** - Mason2 templates for server-side rendering
* **[tools](https://github.com/everything2/everything2/tree/master/tools)** - Build tools (asset pipeline, perlcritic, etc.)
* **[vendor](https://github.com/everything2/everything2/tree/master/vendor)** - Carton-managed Perl dependencies
* **[www](https://github.com/everything2/everything2/tree/master/www)** - Static web assets (CSS, JS, images, index.pl)

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

Tests automatically run during `./docker/devbuild.sh`.

### Working with Perl Dependencies

E2 uses [Carton](https://metacpan.org/pod/Carton) to manage Perl dependencies. Dependencies are vendored in the `vendor/` directory.

**Prerequisites for local development (Ubuntu/Debian):**
```bash
sudo apt-get install carton mysql-server mysql-client libmysqlclient-dev libexpat1-dev imagemagick
```

For other distributions, install equivalent packages for:
- Carton (Perl dependency manager)
- MySQL server and client libraries
- libmysqlclient development headers
- libexpat development headers
- ImageMagick

To update dependencies:
1. Ensure you have the system dependencies listed above
2. Modify `cpanfile`
3. Run `carton install` to fetch new dependencies
4. Run `carton bundle` to vendor them into the source tree
5. Commit both `cpanfile.snapshot` and `vendor/` changes
6. Rebuild container: `./docker/devbuild.sh`

**Note:** Ubuntu 22.04 LTS has issues with Perlmagick6, use the OS distribution packages instead.

**Quick command:**
```bash
carton install && carton bundle
```

### Code Style

Follow the [Coding Standards](coding-standards.md):
- Use prepared statements for all SQL queries (prevent injection)
- Use `$ref->{key}` not `$$ref{key}` (Perl Best Practices)
- Use Moose for new OOP code
- Run `perlcritic` before committing

### Docker Commands

**Build and start:**
```bash
./docker/devbuild.sh
```

**Build with fresh database:**
```bash
./docker/devbuild.sh full
```

**Stop container:**
```bash
docker stop e2devapp
```

**View logs:**
```bash
docker logs e2devapp -f
```

**Shell access:**
```bash
docker exec -it e2devapp bash
```

## Architecture Overview

### Backend
- **Perl 5.38** with mod_perl2 and Apache2
- **Moose** - Modern OOP framework (100+ modules)
- **MySQL 8.0+** - Primary database
- **Mason2** - Server-side templating

### Frontend
- **React 18.2.0** - Modern frontend framework
- **Webpack** - Asset bundling
- **Legacy jQuery 1.11.1** - Being phased out

### Infrastructure
- **AWS Fargate ECS** - Container orchestration
- **AWS CodeBuild** - CI/CD pipeline
- **S3** - Asset storage with git commit hashing
- **Docker** - Development and production containers

## Key Modernization Priorities

1. ✅ **SQL Injection Fixes** - Completed (4 critical vulnerabilities fixed)
2. **Database Code Removal** - 81% complete (migration to filesystem)
3. **Mobile Responsiveness** - Critical gap, zero mobile CSS currently
4. **Testing Infrastructure** - ✅ Now automated in build process
5. **jQuery Removal** - Migrate to vanilla JS and React

See [modernization-priorities.md](modernization-priorities.md) for complete roadmap.

## Documentation

For comprehensive technical documentation, architecture analysis, and modernization plans:

- **[Analysis Summary](analysis-summary.md)** - Complete technical overview
- **[Quick Reference](quick-reference.md)** - Common commands and workflows
- **[Coding Standards](coding-standards.md)** - Style guide and best practices
- **[Modernization Priorities](modernization-priorities.md)** - Strategic roadmap

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

**Last Updated:** 2025-11-08

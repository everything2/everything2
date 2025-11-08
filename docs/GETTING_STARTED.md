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
* **[claude](../claude/)** - Comprehensive modernization documentation and analysis
* **[cron](https://github.com/everything2/everything2/tree/master/cron)** - Cron jobs, run in ECS Fargate, can be simulated manually
* **[docker](https://github.com/everything2/everything2/tree/master/docker)** - Docker images for production and development builds
* **[docs](https://github.com/everything2/everything2/tree/master/docs)** - Documentation (this directory)
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

To update dependencies:
1. Ensure you have local build tools: `libmysqlclient-dev`, `imagemagick`, `libexpat1-dev`
2. Modify `cpanfile`
3. Run `carton install`
4. Rebuild container: `./docker/devbuild.sh`

**Note:** Ubuntu 22.04 LTS has issues with Perlmagick6, use the OS distribution packages instead.

### Code Style

Follow the [Coding Standards](../claude/coding-standards.md):
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

See [claude/modernization-priorities.md](../claude/modernization-priorities.md) for complete roadmap.

## Documentation

For comprehensive technical documentation, architecture analysis, and modernization plans, see the **[claude/](../claude/)** directory:

- **[Analysis Summary](../claude/analysis-summary.md)** - Complete technical overview
- **[Quick Reference](../claude/quick-reference.md)** - Common commands and workflows
- **[Coding Standards](../claude/coding-standards.md)** - Style guide and best practices

## Getting Help

- Check existing issues: https://github.com/everything2/everything2/issues
- Review documentation in `claude/` directory
- Ask in development channels

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow coding standards
4. Add tests for new features
5. Ensure all tests pass
6. Submit a pull request

---

**Last Updated:** 2025-11-07

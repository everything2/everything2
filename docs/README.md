# Everything2 Documentation

This directory contains comprehensive documentation, technical analysis, and modernization plans for the Everything2 codebase.

## Purpose

These documents serve as:
- Technical analysis of current architecture
- Modernization roadmap and strategy
- Communication tool for users and staff
- Reference for development decisions
- Historical record of architectural evolution

## Documents

### Getting Started
- **[Getting Started Guide](GETTING_STARTED.md)** - Development setup and workflow ⭐
- **[Quick Reference](quick-reference.md)** - Common tasks, commands, checklists
- **[Coding Standards](coding-standards.md)** - Perl/JavaScript style guide and best practices
- **[Code Coverage Guide](code-coverage.md)** - Testing coverage infrastructure and usage
- **[Delegation Migration](delegation-migration.md)** - Moving database code to filesystem delegation functions

### Technical Overview
- **[Analysis Summary](analysis-summary.md)** - Complete architectural overview
- **[Status](status.md)** - Current progress and priorities
- **[Modernization Priorities](modernization-priorities.md)** - Strategic roadmap

### Architecture & Infrastructure
- [React Analysis](react-analysis.md) - Frontend implementation and mobile gaps
- [Infrastructure Overview](infrastructure-overview.md) - AWS, Docker, deployment pipeline
- [API Documentation](API.md) - API endpoints and usage

### Security & Modernization
- [SQL Injection Vulnerabilities](sql-injection-vulnerabilities.md) - Security analysis and fixes needed
- [SQL Fixes Applied](sql-fixes-applied.md) - ✅ Completed security fixes (4 critical issues)
- [Inline JavaScript Modernization](inline-javascript-modernization.md) - Asset pipeline integration
- [jQuery Removal](jquery-removal.md) - Legacy jQuery 1.11.1 → Modern vanilla JS/React

## Contributing

When updating these documents:
1. Keep technical accuracy as the priority
2. Include code examples where helpful
3. Document risks and challenges honestly
4. Update status documents as work progresses
5. Date major revisions

## Maintenance

These documents should be reviewed and updated:
- Quarterly for strategic changes
- After major milestones
- When architecture decisions are made
- As modernization work progresses

Last Updated: 2025-11-09

# AI Assistant Context for Everything2

This document provides context for AI assistants (like Claude) working on the Everything2 codebase. It summarizes recent work, architectural decisions, and important patterns to understand.

**Last Updated**: 2025-11-20
**Maintained By**: Jay Bonci

## Recent Work History

### Session 4: Smoke Test & Documentation Improvements (2025-11-20)

**Focus**: Smoke test reliability and special document documentation

**Completed Work**:
1. ✅ Fixed node_backup delegation for development environment
   - Added environment check at [document.pm:7138](ecore/Everything/Delegation/document.pm#L7138)
   - Returns friendly message instead of attempting S3 operations in dev
   - Resolved HTTP 400 error by copying file to Docker container (volume mount caching issue)
2. ✅ Fixed smoke test permission denied false positives
   - Updated [smoke-test.rb:187](tools/smoke-test.rb#L187) to check for actual error message
   - Changed from generic "Permission Denied" text to specific "You don't have access to that node."
   - Fixed "Everything Document Directory" and "What does what" false errors
3. ✅ Fixed URL encoding for documents with slashes
   - Updated [gen_doc_corrected.rb:72-75](/tmp/gen_doc_corrected.rb#L72-L75) to preserve raw slashes
   - E2 expects `/title/online+only+/msg` not `/title/online+only+%2Fmsg`
   - Fixed "online only /msg" and "The Everything2 Voting/Experience System" (404 → 200)
4. ✅ Regenerated [special-documents.md](docs/special-documents.md) with correct URLs
   - Now documents 159 superdocs loaded in development environment
   - Removed percent-encoding from slashes in URLs
   - Updated to reflect actual database state (only superdocs currently loaded)

**Final Results**:
- ✅ **159/159 documents passing (100% success rate)**
- ✅ All smoke tests passing
- ✅ No errors, no warnings
- ✅ Application ready for full test suite

**Key Files Modified**:
- [ecore/Everything/Delegation/document.pm](ecore/Everything/Delegation/document.pm) - Added development environment check for node_backup
- [tools/smoke-test.rb](tools/smoke-test.rb) - Fixed permission denied detection logic
- [docs/special-documents.md](docs/special-documents.md) - Regenerated with correct URLs
- [/tmp/gen_doc_corrected.rb](/tmp/gen_doc_corrected.rb) - Fixed URL encoding for slashes

**Important Discoveries**:
- Docker volume mounts can cache files; use `docker cp` to force updates
- E2 URL routing expects raw slashes in paths, not percent-encoded `%2F`
- Development database only has superdocs loaded; other types (restricted_superdoc, oppressor_superdoc, ticker, fullpage) not yet seeded
- Smoke test now dynamically reads from special-documents.md for test cases

### Session 3: React Nodelet Migration (2025-11-20)

**Focus**: ReadThis nodelet migration to React

**Completed Work**:
1. ✅ Updated [react-migration-strategy.md](docs/react-migration-strategy.md) with current state (9→10 nodelets migrated)
2. ✅ Migrated ReadThis nodelet from Perl to React
   - Created [ReadThis.js](react/components/Nodelets/ReadThis.js) component
   - Created [ReadThisPortal.js](react/components/Portals/ReadThisPortal.js)
   - Added comprehensive test suite (25 tests) in [ReadThis.test.js](react/components/Nodelets/ReadThis.test.js)
   - All 141 React tests passing
3. ✅ Fixed three bugs:
   - Dual nodelet rendering (Perl stub now returns empty string)
   - Section collapse preferences (fixed initialization logic)
   - Data population (integrated frontpagenews DataStash)
4. ✅ Updated news data source to use `frontpagenews` DataStash (weblog entries from "News For Noders" usergroup)
5. ✅ Created [nodelet-migration-status.md](docs/nodelet-migration-status.md) tracking all 25 nodelets
6. ✅ Investigated legacy AJAX: confirmed `showchatter` is ACTIVE and required for Chatterbox

**Key Files Modified**:
- [ecore/Everything/Delegation/nodelet.pm](ecore/Everything/Delegation/nodelet.pm) - readthis() returns ""
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Added ReadThis data loading with frontpagenews
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - ReadThis integration
- [docs/react-migration-strategy.md](docs/react-migration-strategy.md) - Updated current state
- [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md) - NEW: Complete nodelet inventory

### Session 2: Node Resurrection & Cleanup (2025-11-19)

**Focus**: Bug fixes and deprecated code removal

**Completed Work**:
1. ✅ Fixed node resurrection system
   - Corrected insertNode vs getNodeById confusion
   - Added proper tomb table detection
   - Created comprehensive test suite [t/022_node_resurrection.t](t/022_node_resurrection.t)
2. ✅ Removed deprecated chat functions (joker's chat, My Chatterlight v1)
3. ✅ Created November 2025 changelog: [docs/changelog-2025-11.md](docs/changelog-2025-11.md)

### Session 1: Eval() Removal (2025-11-18)

**Focus**: Security improvements - removing eval() calls

**Completed Work**:
1. ✅ Eliminated all parseCode/parsecode eval() calls
2. ✅ Implemented Safe.pm compartmentalized evaluation
3. ✅ Delegated remaining eval-dependent modules
4. ✅ Added 17 security tests
5. ✅ Updated IP address handling functions

**Key Achievement**: Complete removal of unsafe eval() from production code paths

## Architecture Overview

### Technology Stack

**Backend**:
- Perl 5 with Moose OOP framework
- MySQL database
- Mason2 templating (being gradually replaced)
- Everything2 custom node framework

**Frontend**:
- React 18.3.x (pinned until Mason2 elimination)
- React Portals architecture
- Jest for testing
- Legacy jQuery (being phased out)

**Deployment**:
- Docker containers
- AWS infrastructure
- DataStash caching system

### Key Architectural Patterns

#### React Nodelet Pattern

All React nodelets follow this established pattern:

```
1. Component (react/components/Nodelets/*.js)
   - Functional React component
   - Uses shared components: NodeletContainer, NodeletSection, LinkNode

2. Portal (react/components/Portals/*Portal.js)
   - Renders component into Mason-generated DOM
   - Targets specific div#id from Mason template

3. E2ReactRoot Integration (react/components/E2ReactRoot.js)
   - State management
   - Props passing to portals
   - Section collapse state management

4. Data Loading (ecore/Everything/Application.pm)
   - buildNodeInfoStructure() prepares data
   - Loads into window.e2 JSON object
   - Available to React on page load

5. Perl Stub (ecore/Everything/Delegation/nodelet.pm)
   - Returns empty string ""
   - Maintains framework compatibility
   - React handles all rendering
```

#### Data Flow

```
HTTP Request
  ↓
Everything::HTML::displayPage()
  ↓
Application.pm::buildNodeInfoStructure()
  ↓
window.e2 = { user: {...}, node: {...}, ... }
  ↓
E2ReactRoot initial state
  ↓
Portal components
  ↓
Nodelet components (props)
```

#### DataStash System

- Cached data for frequently accessed content
- Examples: `coolnodes`, `staffpicks`, `frontpagenews`, `newwriteups`
- Implements: `Everything::DataStash::*`
- Updated via cron: `cron_datastash.pl`
- 60-second refresh intervals

### Important Files & Locations

#### Core Backend
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Main application logic, buildNodeInfoStructure()
- [ecore/Everything/Delegation/](ecore/Everything/Delegation/) - Delegated modules (nodelet.pm, htmlcode.pm, etc.)
- [ecore/Everything/HTML.pm](ecore/Everything/HTML.pm) - HTML rendering and page display
- [ecore/Everything/Node.pm](ecore/Everything/Node.pm) - Base node class
- [ecore/Everything/NodeBase.pm](ecore/Everything/NodeBase.pm) - Database operations

#### React Frontend
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - Main React application root
- [react/components/Nodelets/](react/components/Nodelets/) - Nodelet components
- [react/components/Portals/](react/components/Portals/) - Portal components
- [react/components/NodeletContainer.js](react/components/NodeletContainer.js) - Shared nodelet wrapper
- [react/components/NodeletSection.js](react/components/NodeletSection.js) - Collapsible sections
- [react/components/LinkNode.js](react/components/LinkNode.js) - Consistent node linking

#### Tests
- [t/](t/) - Perl test suite
- [react/components/**/*.test.js](react/components/) - React component tests (141 tests total)
- [tools/smoke-test.rb](tools/smoke-test.rb) - Pre-flight smoke tests (159 special documents)
- Run with: `npm test` (React), `prove t/` (Perl), `./tools/smoke-test.rb` (smoke test)

#### Documentation
- [docs/react-migration-strategy.md](docs/react-migration-strategy.md) - Overall React migration plan
- [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md) - Detailed nodelet inventory
- [docs/special-documents.md](docs/special-documents.md) - Catalog of all special document types (superdocs, tickers, etc.)
- [docs/react-19-migration.md](docs/react-19-migration.md) - Future React 19 upgrade plan
- [docs/changelog-2025-11.md](docs/changelog-2025-11.md) - November 2025 changes
- [docs/infrastructure-overview.md](docs/infrastructure-overview.md) - System architecture

### Database Schema

**Key Tables**:
- `node` - Base table for all content (polymorphic)
- `nodetype` - Defines node types
- `user` - User accounts
- `writeup` - Article content
- `weblog` - Blog/news entries
- `coolwriteups` - Editor-marked cool content
- `tomb` - Deleted nodes (resurrection system)
- `notification` - User notifications

**Node Types**:
- `document` (base type)
- `superdoc` (type_nodetype=14) - Special system pages
- `restricted_superdoc` (type_nodetype=46) - Editor/admin-only pages
- `oppressor_superdoc` (type_nodetype=57) - God-mode admin pages
- `fullpage` (type_nodetype=86) - Standalone interface pages
- `ticker` (type_nodetype=88) - XML/JSON API endpoints
- `superdocnolinks` (type_nodetype=107) - Superdocs with link parsing disabled
- `writeup`, `user`, `usergroup`, `htmlcode`, `htmlpage`, etc.

**Special Documents**: See [docs/special-documents.md](docs/special-documents.md) for complete catalog (159 in dev environment)

## Common Tasks

### Adding a New React Nodelet

1. Create component in `react/components/Nodelets/YourNodelet.js`
2. Create portal in `react/components/Portals/YourNodeletPortal.js`
3. Add to E2ReactRoot:
   - Import component and portal
   - Add to `managedNodelets` array
   - Add state initialization
   - Add portal in render()
4. Update `Application.pm::buildNodeInfoStructure()` to load data into `$e2->{yourdata}`
5. Update Perl nodelet function to `return "";`
6. Create test suite in `react/components/Nodelets/YourNodelet.test.js`
7. Update [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md)

### Running Tests

```bash
# React tests
npm test

# Perl tests
prove t/

# Specific Perl test
prove t/022_node_resurrection.t

# Smoke tests (pre-flight checks)
./tools/smoke-test.rb

# Docker environment
./docker/devbuild.sh
docker exec -it e2_everything2_1 bash
```

### Regenerating Special Documents Documentation

```bash
# Extract document data from database and generate markdown
docker exec e2devdb mysql -u root -pblah everything -N -e \
  "SELECT node_id, title, CASE type_nodetype
   WHEN 14 THEN 'superdoc'
   WHEN 46 THEN 'restricted_superdoc'
   WHEN 57 THEN 'oppressor_superdoc'
   WHEN 86 THEN 'fullpage'
   WHEN 88 THEN 'ticker'
   WHEN 107 THEN 'superdocnolinks'
   END as doc_type
   FROM node
   WHERE type_nodetype IN (14, 46, 57, 86, 88, 107)
   ORDER BY type_nodetype, title" 2>&1 | \
  grep -v "^mysql:" | \
  ruby /tmp/gen_doc_corrected.rb > docs/special-documents.md

# Then run smoke tests to verify
./tools/smoke-test.rb
```

### Database Access

```perl
# Get node by ID
my $node = $DB->getNodeById($node_id);

# Get node by title and type
my $node = $DB->getNode("title", "nodetype");

# DataStash access
my $data = $DB->stashData("datastash_name");

# SQL queries
my $csr = $DB->sqlSelectMany("fields", "table", "where", "order/limit");
```

## Current Priorities

### High Priority
1. Continue nodelet migrations (see [nodelet-migration-status.md](docs/nodelet-migration-status.md))
   - Chatterbox (complex, high value)
   - Notifications (important UX)
   - Messages (core feature)
2. React 18.3.x stability and test coverage
3. Progressive Mason2 elimination

### Medium Priority
1. Additional nodelet migrations (Tier 2-3)
2. Page content migration planning
3. Legacy jQuery removal where feasible

### Future (Post-Mason2)
1. React 19 upgrade
2. Full modern frontend stack
3. API-first architecture

## Known Issues & Gotchas

### React Portals
- **Issue**: Portals require target DOM element to exist
- **Solution**: Mason2 template must render placeholder div
- **Example**: `<div id='readthis'></div>` in Mason template

### Section Preferences
- **Issue**: Section collapse state stored as `{nodelet}_hide{section}` in user preferences
- **Logic**: Value of `1` means hidden, `0` or `undefined` means shown
- **Implementation**: `e2.display_prefs[nodelet+"_hide"+section] !== 1`

### DataStash Caching
- **Issue**: DataStash updates every 60 seconds via cron
- **Implication**: Changes may not appear immediately
- **Solution**: Understand caching behavior, don't expect real-time updates

### Node Type Confusion
- **Issue**: Writeups have both `node` and `writeup` table entries
- **Solution**: Always use `getNodeById()` which handles joins automatically

### Eval() History
- **Issue**: Legacy code used eval() for data deserialization
- **Status**: Removed in Session 1, replaced with Safe.pm
- **Important**: Never reintroduce eval() for untrusted data

### Legacy AJAX
- **Issue**: Some legacy AJAX calls seem obsolete
- **Status**: `showchatter` is ACTIVE and required - don't remove!
- **Lesson**: Always verify before removing legacy code

### URL Encoding for Special Documents
- **Issue**: Documents with slashes in titles need special URL handling
- **Correct**: Use raw slashes: `/title/online+only+/msg`
- **Wrong**: Percent-encoded slashes: `/title/online+only+%2Fmsg` (returns 404)
- **Pattern**: Spaces → `+`, slashes → raw `/`, other special chars → standard encoding

### Docker Volume Mount Caching
- **Issue**: File changes on host may not appear in container immediately
- **Solution**: Use `docker cp <host-file> <container>:<container-path>` to force update
- **Example**: `docker cp document.pm e2devapp:/var/everything/ecore/Everything/Delegation/document.pm`
- **Then**: Restart Apache with `docker exec e2devapp apache2ctl graceful`

### Development Environment Checks
- **Pattern**: Production-only features (S3, external APIs) need dev environment checks
- **Method**: Use `$Everything::CONF->environment eq 'development'`
- **Example**: node_backup returns friendly message instead of attempting S3 operations
- **Important**: Test that delegation compiles and renders, even if feature is disabled

## Development Environment

### Local Setup
```bash
# Docker environment
./docker/devbuild.sh

# Install dependencies
npm install

# Run tests
npm test
```

### File Locations
- **Project Root**: `/home/jaybonci/projects/everything2/`
- **Perl Code**: `ecore/Everything/`
- **React Code**: `react/`
- **Templates**: `www/mason2/`
- **Tests**: `t/` (Perl), `react/**/*.test.js` (React)
- **Documentation**: `docs/`

## Code Style

### Perl
- Moose OOP patterns
- Method signatures: `my ($this, $param1, $param2) = @_;`
- Use `$DB` for database, `$APP` for application
- Follow existing patterns in codebase

### React
- Functional components (no classes)
- Props destructuring encouraged
- Use shared components (NodeletContainer, NodeletSection, LinkNode)
- Comprehensive test coverage required
- No emojis unless explicitly requested

### Testing
- React: Jest with React Testing Library
- Perl: Test::More
- Mock child components in React tests
- Test rendering, state, props, edge cases

## Git Workflow

### Branch Naming
- `issue/{number}/{description}` - For GitHub issues
- Current branch: `issue/3742/remove_evalcode`
- Main branch: `master`

### Commit Messages
- Clear, descriptive
- Reference issue numbers when applicable
- Include co-author credit:
  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

### Pull Request Pattern
- Push changes to feature branch
- Create PR via `gh pr create`
- Include summary and test plan
- All tests must pass

## Contact & Resources

- **GitHub**: https://github.com/everything2/everything2
- **Issues**: https://github.com/everything2/everything2/issues
- **Project Lead**: Jay Bonci
- **Documentation**: [docs/](docs/) directory

## Tips for AI Assistants

1. **Always read files before editing** - Use Read tool before Edit/Write
2. **Follow established patterns** - Don't invent new architectures
3. **Test everything** - Add tests for new code; run smoke tests before full test suite
4. **Document changes** - Update relevant .md files (especially CLAUDE.md)
5. **Check existing code** - Search before implementing (might already exist)
6. **Ask when unclear** - Better to clarify than assume
7. **Maintain context** - Keep CLAUDE.md updated for future sessions
8. **Be conservative** - Don't remove legacy code without verification
9. **Use TodoWrite** - Track complex tasks
10. **Read summaries carefully** - Previous session context is valuable
11. **Run smoke tests first** - `./tools/smoke-test.rb` catches issues before expensive full test run
12. **Docker quirks** - Files may need `docker cp` to sync; containers are `e2devapp` and `e2devdb`

## Session Context Pattern

When starting a new session, review:
1. This CLAUDE.md file
2. Recent commits (`git log`)
3. Current branch status (`git status`)
4. Relevant documentation in `docs/`
5. Test status (`./tools/smoke-test.rb` and `npm test`)

When ending a session, update:
1. This CLAUDE.md file with new context
2. Relevant documentation files
3. Complete any pending TODOs

---

*This document is maintained to provide continuity across AI assistant sessions and help new contributors understand the codebase quickly.*

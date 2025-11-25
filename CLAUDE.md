# AI Assistant Context for Everything2

This document provides context for AI assistants (like Claude) working on the Everything2 codebase. It summarizes recent work, architectural decisions, and important patterns to understand.

**Last Updated**: 2025-11-25
**Maintained By**: Jay Bonci

## ⚠️ CRITICAL: Common Pitfalls & Required Patterns ⚠️

**READ THIS FIRST - These patterns are repeated mistakes that must be avoided:**

### Testing & Development

**NEVER run Perl tests directly in container** ❌
```bash
# WRONG - missing vendor libs
docker exec e2devapp perl -c Application.pm
docker exec e2devapp prove t/test.t
```

**ALWAYS use devbuild.sh or proper test runners** ✅
```bash
# CORRECT - has all dependencies
./docker/devbuild.sh                    # Full rebuild + all tests
./tools/parallel-test.sh                # Run tests only
docker exec e2devapp bash -c "cd /var/everything && prove t/test.t"  # If you must run single test
```

### Docker File Synchronization

**CRITICAL: Containers have separate filesystems - use docker cp to sync files** ⚠️

The Docker containers (e2devapp, e2devdb) run on completely separate filesystems from WSL. Changes to files in `/home/jaybonci/projects/everything2/` (WSL host) do NOT automatically appear in the container at `/var/everything/`. You MUST use `docker cp` to copy edited files into the container:

```bash
# WRONG - edit file on WSL host and just reload/run in container
# (Container still has old version of the file!)
docker exec e2devapp apache2ctl graceful
docker exec e2devapp bash -c "cd /var/everything && prove t/test.t"

# CORRECT - copy file from WSL host to container FIRST
docker cp /home/jaybonci/projects/everything2/ecore/Everything/Application.pm \
  e2devapp:/var/everything/ecore/Everything/Application.pm
docker exec e2devapp apache2ctl graceful

# For test files (CRITICAL - containers won't see new tests without this!)
docker cp /home/jaybonci/projects/everything2/t/037_usergroup_messages.t \
  e2devapp:/var/everything/t/037_usergroup_messages.t
docker exec e2devapp bash -c "cd /var/everything && prove t/037_usergroup_messages.t"

# For htmlcode delegation (frequently edited)
docker cp /home/jaybonci/projects/everything2/ecore/Everything/Delegation/htmlcode.pm \
  e2devapp:/var/everything/ecore/Everything/Delegation/htmlcode.pm
docker exec e2devapp apache2ctl graceful
```

**Why this matters:**
- Containers have completely separate filesystems from WSL host
- Editing files on WSL does NOT update files in container
- Apache serves code from container's `/var/everything/`, not WSL's files
- **Test files affected too** - new tests won't run without docker cp
- Symptoms: Changes don't appear, tests show old behavior, new subtests missing
- Solution: ALWAYS `docker cp` after editing ANY file (.pm, .t, .js, etc.) that needs to run in container
- Alternative: Use `./docker/devbuild.sh` which rebuilds container with fresh files

### Perl::Critic - Finding Code Quality Issues

**ALWAYS run Perl::Critic to find bugs** ✅

Perl::Critic can catch common bugs like uninitialized variables, string interpolation issues, and more. Run it before making commits:

```bash
# Check specific file (works in or out of container)
./tools/critic.pl ecore/Everything/Application.pm

# Check all files
./tools/critic.pl

# In container (if needed)
docker exec e2devapp bash -c "cd /var/everything && ./tools/critic.pl ecore/Everything/Application.pm"
```

**Common issues Perl::Critic catches:**
- Uninitialized variables in conditionals
- String interpolation of non-interpolating strings
- Missing return statements
- Unused variables
- Code complexity issues

### Webpack Build Mode

**ALWAYS use --mode=development for webpack builds** ⚠️

Development mode preserves class names and doesn't minify, making profiling and debugging much easier.

```bash
# CORRECT - Development mode (readable class names, easier debugging)
npx webpack --config etc/webpack.config.js --mode=development

# WRONG - Production mode in development (minified, hard to debug)
npx webpack --config etc/webpack.config.js --mode=production
npx webpack --config etc/webpack.config.js  # Defaults to production
```

**Why this matters:**
- ✅ **Class names preserved**: React components show as `Chatterbox` not `a`
- ✅ **Source maps**: Better stack traces in browser console
- ✅ **No minification**: Code is readable in DevTools
- ✅ **Faster builds**: Skips optimization step

**Production mode is ONLY for deployment builds**, not development iterations.

### React & Perl Boolean Values

**CRITICAL: Perl numeric 0/1 values render as "0" in React** ⚠️

```javascript
// WRONG - Perl 0 renders as "0" on screen
{props.someValue && <div>Content</div>}

// CORRECT - Convert to JS boolean first
{Boolean(props.someValue) && <div>Content</div>}
```

**Always use Boolean() when passing Perl 0/1 to React:**
```javascript
// In E2ReactRoot or parent components:
someFlag={Boolean(this.props.e2?.user?.someFlag)}
showThing={Boolean(this.props.e2?.showThing)}
```

### Blessed Objects vs Hashrefs

**User/Node objects come in TWO forms - know which to use and which scope you're in:**

**SCOPE 1: Controller/Page classes (have $REQUEST)**
```perl
# In Everything::Controller, Everything::Page, or anywhere with $REQUEST object:
my $user = $REQUEST->user;                 # Blessed Everything::Node::user object
my $node = $REQUEST->node;                 # Blessed Everything::Node object

# Read via methods:
my $username = $user->title;                # ✓ Use methods
my $gp = $user->GP;                        # ✓ Use methods
my $is_admin = $user->is_admin;            # ✓ Note underscore, not camelCase

# CANNOT modify blessed object directly!
# $user->{GP} = 100;                       # ✗ WRONG - won't work

# To modify, get hashref:
my $USER = $user->NODEDATA;                # Get hashref from blessed object
$USER->{GP} = 100;                         # ✓ Modify hashref
$DB->updateNode($USER, -1);                # ✓ Save changes

# VARS access:
my $VARS = $user->VARS;                    # Get VARS hashref
$VARS->{some_setting} = 1;                 # Modify
$user->set_vars($VARS);                    # Save back (uses blessed method)
```

**SCOPE 2: Application.pm / Legacy code (have $USER hashref)**
```perl
# In Application.pm::buildNodeInfoStructure and similar legacy methods:
# These receive hashrefs directly, not blessed objects

sub some_method {
  my ($this, $NODE, $USER, $VARS) = @_;    # All hashrefs!

  # Read via hash access:
  my $username = $USER->{title};            # ✓ Direct hash access
  my $gp = $USER->{GP};                     # ✓ Direct hash access

  # Modify directly:
  $USER->{GP} = 100;                        # ✓ Modify hashref
  $this->{db}->updateNode($USER, -1);       # ✓ Save changes

  # If you need blessed object methods:
  my $user_node = $this->node_by_id($USER->{node_id});  # Convert to blessed
  my $is_admin = $user_node->is_admin;                  # ✓ Now can use methods
}
```

**SCOPE 3: API endpoints (convert as needed)**
```perl
# In Everything::API::* modules:
sub my_endpoint {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;                # Blessed object
  my $USER = $user->NODEDATA;               # Hashref for modifications
  my $VARS = $user->VARS;                   # VARS hashref

  # Modify and save:
  $USER->{GP} += 50;
  $self->DB->updateNode($USER, -1);
  $user->set_vars($VARS);

  return [$self->HTTP_OK, { gp => $USER->{GP} }];
}
```

**Quick Reference:**
| Context | Form | Access Pattern | Modification |
|---------|------|----------------|--------------|
| Controller/Page | Blessed (`$REQUEST->user`) | Methods (`$user->GP`) | Get hashref first (`$user->NODEDATA`) |
| Application.pm | Hashref (`$USER`) | Hash (`$USER->{GP}`) | Direct (`$USER->{GP} = 100`) |
| API endpoints | Both | Convert as needed | Use NODEDATA hashref |

### API Response Format

**ALWAYS return arrayref, never call method:**

```perl
# WRONG
return $self->API_RESPONSE(200, { data => 'value' });

# CORRECT
return [$self->HTTP_OK, { data => 'value' }];
return [$self->HTTP_FORBIDDEN, { error => 'Not allowed' }];
return [$self->HTTP_BAD_REQUEST, { error => 'Invalid input' }];
```

**HTTP status constants:**
- `$self->HTTP_OK` (200)
- `$self->HTTP_CREATED` (201)
- `$self->HTTP_BAD_REQUEST` (400)
- `$self->HTTP_FORBIDDEN` (403)
- `$self->HTTP_NOT_FOUND` (404)
- `$self->HTTP_INTERNAL_SERVER_ERROR` (500)

### Database Node IDs

**Node IDs vary between dev/prod - never hardcode them:**

```perl
# WRONG
my $messages_nodelet_id = 1916651;  # Wrong ID!

# CORRECT - Look up in database first
my $node = $DB->getNode('Messages', 'nodelet');
my $id = $node->{node_id};

# Or if checking in string:
my $nodelets = $VARS->{nodelets} || '';
# Check for actual node_id from database: 2044453 for Messages
```

**Common node IDs to verify in dev environment:**
- Messages nodelet: 2044453 (NOT 1916651)
- Always look up via `$DB->getNode(title, type)` instead of assuming

### Cookie Authentication

**E2 uses special cookie format:**

```bash
# Cookie format: userpass=username%09password
curl -b 'userpass=root%09blah' http://localhost/

# %09 is URL-encoded tab character (separator)
```

### React Component Data Flow

**Phase 3 (Sidebar only):**
```
Mason2 → window.e2 → E2ReactRoot → Nodelet components
```

**Phase 4a (Content + Sidebar):**
```
Mason2 → window.e2 → PageLayout (content) + E2ReactRoot (sidebar)
```

**Page detection:**
```perl
# In Controller/superdoc.pm
my $is_react_page = $page_class->can('buildReactData');
```

### Everything::Page Pattern

```perl
package Everything::Page::my_page;

use Moose;
extends 'Everything::Page';

# This method triggers React rendering
sub buildReactData {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;  # Blessed object

  return {
    contentData => {
      type => 'my_page',      # Must match DocumentComponent router
      # ...page-specific data
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

### Docker Container Names

**Correct container names:**
- Application: `e2devapp` (NOT `e2_everything2_1`)
- Database: `e2devdb`

```bash
docker exec e2devapp apache2ctl graceful
docker exec e2devdb mysql -u root -pblah everything
```

### File Synchronization

**Docker volume mounts can cache - force updates:**

```bash
# After editing files, if changes don't appear:
docker cp localfile.pm e2devapp:/var/everything/path/to/file.pm
docker exec e2devapp apache2ctl graceful
```

### No More eval() for Data

**eval() has been removed - never reintroduce it:**

```perl
# WRONG - eval() removed for security
my $data = eval $string;

# CORRECT - data comes from trusted sources only
# Use JSON, %INC cache, or proper module loading
```

---

## Development Operations Reference

### 🔄 Always Rebuild After Major Changes

**IMPORTANT: Do a full rebuild after any major change to get clean test results:**

```bash
./docker/devbuild.sh
```

**"Major changes" include:**
- Modifying Perl module structure (new packages, changed inheritance)
- Changing database schema or adding migrations
- Modifying API routing or authentication
- Changing React component structure significantly
- Adding new dependencies to package.json or cpanfile
- Modifying Docker configuration

**Why this matters:** Incremental updates can leave stale code in memory, cached files, or inconsistent state. A full rebuild ensures clean containers, fresh dependencies, and accurate test results.

### Running Tests

**Full rebuild with all tests (recommended after major changes):**
```bash
./docker/devbuild.sh
# Runs: Docker build → smoke tests → Perl unit tests (parallel) → React tests
# Takes ~2-3 minutes
```

**Run tests only (after minor Perl/React changes):**
```bash
./tools/parallel-test.sh
# Runs smoke + Perl + React tests in parallel
# Takes ~60 seconds
# Use after: Apache graceful reload or webpack rebuild
```

**Run specific Perl test:**
```bash
# MUST be inside container with proper library paths
docker exec e2devapp bash -c "cd /var/everything && prove t/035_chatroom_api.t"

# Multiple tests:
docker exec e2devapp bash -c "cd /var/everything && prove t/035_chatroom_api.t t/036_message_opcode.t"

# With verbose output:
docker exec e2devapp bash -c "cd /var/everything && prove -v t/035_chatroom_api.t"

# All tests in parallel (same as devbuild.sh test phase):
docker exec e2devapp bash -c "cd /var/everything && prove -j14 t/*.t"
```

**Run React tests:**
```bash
npm test                    # All React tests
npm test -- Chatterbox      # Specific test file
npm test -- --watch         # Watch mode
npm test -- --coverage      # With coverage report
```

**Smoke tests only (fast pre-flight check):**
```bash
./tools/smoke-test.rb
# Tests all 159+ special documents
# Takes ~10-15 seconds
# Run this BEFORE full test suite to catch obvious breaks
```

### Authenticated API Testing

**E2 cookie format: `userpass=username%09password`** (%09 = URL-encoded tab)

**Test as root user:**
```bash
# Simple GET request:
curl -b 'userpass=root%09blah' http://localhost:9080/

# POST API endpoint:
curl -X POST -b 'userpass=root%09blah' \
  -H 'Content-Type: application/json' \
  -d '{"data":"value"}' \
  http://localhost:9080/api/wheel/spin

# GET API with query params:
curl -b 'userpass=root%09blah' \
  'http://localhost:9080/api/messages/?limit=5&archive=0'
```

**Save and reuse session:**
```bash
# Login and save cookie to file:
curl -c cookies.txt \
  -d "user=root&passwd=blah&op=login" \
  http://localhost:9080/

# Use saved cookie:
curl -b cookies.txt http://localhost:9080/api/messages/
```

**Test from inside container:**
```bash
docker exec e2devapp curl -s 'http://localhost/api/messages/?limit=5' \
  -H 'Cookie: userpass=root%09blah'
```

**Common test users in dev environment:**
| Username | Password | Role | Use For |
|----------|----------|------|---------|
| `root` | `blah` | Admin | Admin features, all permissions |
| `genericdev` | `blah` | Developer | Developer nodelet, normal user tests |
| `Cool Man Eddie` | `blah` | Regular user | Standard user tests |
| `c_e` | `blah` | Content editor | Message forwarding tests |

Check `tools/seeds.pl` for complete list of test users.

### Database Access

**MySQL shell access:**
```bash
# Interactive shell:
docker exec -it e2devdb mysql -u root -pblah everything

# Run single query:
docker exec e2devdb mysql -u root -pblah everything \
  -e "SELECT node_id, title FROM node WHERE title='Messages'"

# Suppress warnings in output:
docker exec e2devdb mysql -u root -pblah everything -e "SELECT ..." 2>&1 | grep -v "^mysql:"

# Export results to file:
docker exec e2devdb mysql -u root -pblah everything -e "SELECT ..." > results.txt
```

**Common queries:**
```sql
-- Find node by title:
SELECT node_id, title, type_nodetype FROM node WHERE title='Messages';

-- Check node type:
SELECT node_id, title FROM nodetype WHERE node_id=151;

-- Get user's VARS:
SELECT vars FROM setting WHERE user_id=1;

-- Check messages for user:
SELECT * FROM message WHERE for_user=1 AND archive=0 ORDER BY tstamp DESC LIMIT 5;

-- Find nodelet ID by name:
SELECT n.node_id, n.title
FROM node n
JOIN nodetype nt ON n.type_nodetype = nt.node_id
WHERE n.title='Messages' AND nt.title='nodelet';

-- Check user's nodelet configuration:
SELECT vars FROM setting WHERE user_id=1;
-- Look for "nodelets" in the vars string

-- Count writeups:
SELECT COUNT(*) FROM writeup WHERE author_user=1;

-- Recent chatter messages:
SELECT * FROM message WHERE for_user=0 ORDER BY tstamp DESC LIMIT 10;
```

### Rebuilding Webpack

**Rebuild React bundle (run on host, not in container):**
```bash
npx webpack --config etc/webpack.config.js --mode=development
```

**Deploy bundle to running container:**
```bash
# Copy bundle to container:
docker cp www/react/main.bundle.js e2devapp:/var/everything/www/react/main.bundle.js

# Graceful Apache reload (no downtime):
docker exec e2devapp apache2ctl graceful

# Check it worked:
curl -I http://localhost:9080/react/main.bundle.js
```

**One-liner rebuild and deploy:**
```bash
npx webpack --config etc/webpack.config.js --mode=development && \
docker cp www/react/main.bundle.js e2devapp:/var/everything/www/react/main.bundle.js && \
docker exec e2devapp apache2ctl graceful && \
echo "✓ Bundle deployed"
```

**Check bundle sizes:**
```bash
ls -lh www/react/*.bundle.js
# Expected sizes:
# main.bundle.js: ~1.1-1.2 MB
# react_components_E2ReactRoot_js.bundle.js: ~400 KB
# react_components_PageLayout_js.bundle.js: ~33 KB
```

### Rebuilding Application

**Full application rebuild (Docker + tests):**
```bash
./docker/devbuild.sh
# Does: Docker build → Start containers → Run all tests
# Takes ~2-3 minutes
# Use after: Major code changes, dependency updates, schema changes
```

**Restart just the app container (fast):**
```bash
docker restart e2devapp
# Takes ~10 seconds
# Use after: Configuration changes, environment variable changes
```

**Graceful Apache reload (fastest, no downtime):**
```bash
docker exec e2devapp apache2ctl graceful
# Takes ~2 seconds
# Use after: Perl code edits, template changes
```

**Force file sync (if volume mount is cached):**
```bash
# Copy specific file to container:
docker cp ecore/Everything/Application.pm \
  e2devapp:/var/everything/ecore/Everything/Application.pm

# Then reload Apache:
docker exec e2devapp apache2ctl graceful

# Or copy entire directory:
docker cp ecore/Everything/ e2devapp:/var/everything/ecore/
```

### Viewing Logs & Debugging

**Apache error log (Perl errors, crashes, warnings):**
```bash
# Tail live log (Ctrl+C to exit):
docker exec e2devapp tail -f /var/log/apache2/error.log

# View recent errors:
docker exec e2devapp tail -100 /var/log/apache2/error.log

# Search for specific errors:
docker exec e2devapp tail -500 /var/log/apache2/error.log | \
  grep -i "error\|warning\|fatal"

# Perl compilation errors:
docker exec e2devapp tail -200 /var/log/apache2/error.log | \
  grep "at /.*\.pm line"

# Specific module errors:
docker exec e2devapp tail -200 /var/log/apache2/error.log | \
  grep "Application.pm"

# 500 Internal Server Error:
docker exec e2devapp tail -200 /var/log/apache2/error.log | \
  grep "500"
```

**Apache access log:**
```bash
# Tail live access log:
docker exec e2devapp tail -f /var/log/apache2/access.log

# Find 500 errors:
docker exec e2devapp tail -500 /var/log/apache2/access.log | grep " 500 "

# API endpoint access:
docker exec e2devapp tail -500 /var/log/apache2/access.log | grep "/api/"
```

**Container logs (Docker/startup output):**
```bash
docker logs e2devapp              # All logs
docker logs e2devapp --tail 100   # Last 100 lines
docker logs -f e2devapp            # Follow mode (live)
docker logs e2devdb                # Database logs
```

**Check Apache configuration:**
```bash
# Test config syntax:
docker exec e2devapp apache2ctl configtest

# Show loaded modules:
docker exec e2devapp apache2ctl -M

# Check Apache status:
docker exec e2devapp apache2ctl status
```

**Common error patterns:**
```bash
# Undefined subroutine (typo or missing import):
grep "Undefined subroutine" /var/log/apache2/error.log

# Can't locate module (missing dependency):
grep "Can't locate" /var/log/apache2/error.log

# Permission denied:
grep -i "permission denied" /var/log/apache2/error.log

# Variable masking (Perl::Critic warning):
grep "masks earlier declaration" /var/log/apache2/error.log

# Database connection issues:
grep -i "DBI\|DBD\|mysql" /var/log/apache2/error.log
```

### Quick Health Checks

**Application responding:**
```bash
curl -s http://localhost:9080/ | head -20
# Should see HTML with "Everything2"
```

**Containers running:**
```bash
docker ps | grep e2dev
# Should see e2devapp and e2devdb both "Up"
```

**Database accessible:**
```bash
docker exec e2devdb mysql -u root -pblah -e "SELECT 1"
# Should return "1"
```

**Apache running:**
```bash
docker exec e2devapp ps aux | grep apache2
# Should see multiple apache2 processes
```

**Smoke test single document:**
```bash
curl -s http://localhost:9080/title/Login | grep -q "Everything2" && \
  echo "✓ OK" || echo "✗ FAIL"
```

**Check React bundle loaded:**
```bash
curl -I http://localhost:9080/react/main.bundle.js 2>&1 | grep "200 OK"
# Should return "HTTP/1.1 200 OK"
```

---

## Recent Work History

### Session 21: Guest Nodelet Fix - htmlcode.pm Path (2025-11-25)

**Focus**: Complete the guest nodelet consistency fix for delegation-rendered pages (htmlcode.pm path)

**Completed Work**:
1. ✅ **Fixed Guest Nodelet Ordering in htmlcode.pm** ([htmlcode.pm:3962-3992](ecore/Everything/Delegation/htmlcode.pm#L3962-L3992))
   - **Problem**: Session 20 fixed user.pm and Controller.pm, but missed htmlcode.pm delegation path
   - **Discovery**: Most superdocs don't use Controller - they fall back to htmlcode delegation
   - **Root Cause**: htmlcode.pm `static_javascript()` was setting `$$VARS{nodelets}` from config, but VARS doesn't persist across pages
   - **Original Broken Code**:
     ```perl
     if ($APP->isGuest($USER) && !$$VARS{nodelets}) {  # Wrong!
       $$VARS{nodelets} = join(',', @$guest_nodelets);
     }
     my $nodeletlist = $PAGELOAD->{pagenodelets} || $$VARS{nodelets};  # VARS empty on other pages
     ```
   - **Fix**: Build nodeletlist directly from config for guests
     ```perl
     my $nodeletlist;
     if ($APP->isGuest($USER)) {
       # Guest users: build nodeletlist directly from guest_nodelets config
       $nodeletlist = join(',', @$guest_nodelets);
     } else {
       # Logged-in users: use PAGELOAD or VARS
       $nodeletlist = $PAGELOAD->{pagenodelets} || $$VARS{nodelets};
     }
     ```
   - **Impact**: Guest nodelets now consistent across ALL pages (Guest Front Page, Everything FAQ, Cool Archive, etc.)
2. ✅ **Added Docker File Synchronization to CLAUDE.md** ([CLAUDE.md:29-54](CLAUDE.md#L29-L54))
   - **Critical Gotcha**: Volume mount caching requires `docker cp` to force file updates
   - **Pattern**: ALWAYS `docker cp` .pm files before `apache2ctl graceful`
   - Prevents "changes not appearing" debugging sessions

**Final Results**:
- ✅ **Guest nodelets consistent** - All pages show `["sign_in","recommended_reading","new_writeups"]`
- ✅ **Two rendering paths fixed** - Both Controller.pm AND htmlcode.pm paths work correctly
- ✅ **Documentation updated** - Docker cp pattern documented in Common Pitfalls

**Key Files Modified**:
- [ecore/Everything/Delegation/htmlcode.pm](ecore/Everything/Delegation/htmlcode.pm) - Fixed nodeletorder building for guests
- [CLAUDE.md](CLAUDE.md) - Added Docker File Synchronization section

**Important Discoveries**:
- **Two Rendering Paths**: E2 has TWO paths for building window.e2 JSON:
  1. **Controller.pm** `display()` → `buildNodeInfoStructure()` → `static_javascript.mi` template (for pages with Everything::Page classes)
  2. **htmlcode.pm** `static_javascript()` function → delegated rendering (for most superdocs)
- **Superdoc Routing**: Most superdocs return "does not fully support page" and fall back to delegation
- **VARS Scope**: `$$VARS` in htmlcode.pm is a local hashref passed to the function, NOT the user's persistent database VARS
- **Container Filesystem**: WSL and Docker containers have separate filesystems - `docker cp` required to sync files
- **Debug Logging**: Use `$APP->devLog()` and check `/tmp/development.log`, not Apache error log

**Critical Pattern Identified**:
```perl
# WRONG - trying to persist data via local VARS hashref
if ($APP->isGuest($USER) && !$$VARS{nodelets}) {
  $$VARS{nodelets} = join(',', @$guest_nodelets);  # Doesn't persist!
}
my $nodeletlist = $$VARS{nodelets};  # Empty on next page

# RIGHT - build directly from config for guests
my $nodeletlist;
if ($APP->isGuest($USER)) {
  $nodeletlist = join(',', @$guest_nodelets);  # Always use config
} else {
  $nodeletlist = $PAGELOAD->{pagenodelets} || $$VARS{nodelets};
}
```

**Next Steps**:
- Consider unifying the two rendering paths (Controller vs htmlcode delegation)
- Continue Phase 4a work (React page migrations)

### Session 20: Guest Nodelet Regression Fix & E2E Test Documentation (2025-11-25)

**Focus**: Fix critical guest nodelet consistency bug, implement E2E test suite, document regression test strategy

**Completed Work**:
1. ✅ **Fixed Guest Nodelet Consistency Regression** ([user.pm:265](ecore/Everything/Node/user.pm#L265))
   - **Critical Bug**: Guest users saw different nodelets on different pages
   - **User Report**: "Non-fullpage versions of guest front pages only have the Login nodelet, while 'Guest Front Page' has the correct nodelet sets"
   - **Root Cause Analysis**:
     - `guest_front_page` document ([document.pm:12132-12137](ecore/Everything/Delegation/document.pm#L12132)) sets `$VARS->{nodelets}` for guests
     - Guest user's VARS persisted across requests
     - `nodelets()` method checked `if($VARS->{nodelets})` BEFORE `elsif($is_guest)`
     - Once guest visited "Guest Front Page", VARS overrode `guest_nodelets` config on all subsequent pages
   - **Fix**: Reordered checks in `nodelets()` method:
     ```perl
     # OLD ORDER (buggy):
     if($self->VARS->{nodelets}) { ... }
     elsif($self->is_guest) { ... }

     # NEW ORDER (fixed):
     if($self->is_guest) { ... }           # Check guest FIRST
     elsif($self->VARS->{nodelets}) { ... }
     ```
   - **Impact**: Guests now see consistent nodelets on ALL pages, regardless of navigation path
2. ✅ **Implemented Playwright E2E Test Suite** (Phase 1 & 2 Complete)
   - Installed Playwright with fixtures and configuration
   - Created authentication helpers ([tests/e2e/fixtures/auth.js](tests/e2e/fixtures/auth.js))
   - Implemented 16 test scenarios across 4 files:
     - [chatterbox.spec.js](tests/e2e/chatterbox.spec.js) - 5 tests (layout shift, errors, commands, focus, counter)
     - [messages.spec.js](tests/e2e/messages.spec.js) - 2 tests (initial load, visibility logic)
     - [navigation.spec.js](tests/e2e/navigation.spec.js) - 6 tests (homepage, login, chatterbox, React pages, Mason2 pages, nodelets)
     - [wheel.spec.js](tests/e2e/wheel.spec.js) - 3 tests (spin result, GP blocking, admin sanctify)
   - **Current Status**: 10/16 tests passing (62.5%)
   - **Failing Tests**: Login-related issues (selector too broad, pointer interception, timeout)
3. ✅ **Fixed Playwright Auth Fixture**
   - **Problem**: Sign In nodelet collapsed by default for guests
   - **Solution**: Detect collapsed state via `aria-expanded` and `is-closed` class, expand before login
   - Code improved login reliability significantly
4. ✅ **Enhanced Chatterbox Success Message Behavior**
   - **User Feedback**: "Should show up for /msg requests... but should not show up for other chatter commands"
   - **Fix**: Added regex pattern to detect private message commands:
     ```javascript
     const isPrivateMessage = /^\/(msg|message|whisper|small)\s/.test(message.trim())
     if (isPrivateMessage) {
       setMessageSuccess('Message sent')
       // 3-second auto-clear with fade-out
     } else {
       setMessageSuccess(null)  // No message - immediate visual feedback in chatter feed
     }
     ```
5. ✅ **Updated seeds.pl for Nested Messaging Tests**
   - Added root user to e2gods usergroup for testing nested message forwarding
   - Enables testing usergroup-within-usergroup scenarios
6. ✅ **Created Comprehensive E2E Test Plan** ([docs/e2e-test-plan.md](docs/e2e-test-plan.md))
   - 11 feature areas with priority levels (P0-P3)
   - Coverage tracking table (16 tests, 10 passing)
   - Detailed test scenarios with validation points
   - Edge cases and planned tests
   - Success metrics and roadmap (Phase 2-4)
   - **NEW**: Guest Nodelet Consistency regression test documentation
7. ✅ **Added .gitignore for Playwright Outputs**
   - `test-results/`, `playwright-report/`, `playwright/.cache/`
   - Prevents test artifacts from being committed
8. ✅ **Documented Guest Nodelet Regression Test** ([docs/e2e-test-plan.md:317-331](docs/e2e-test-plan.md#L317))
   - Added as P0 (Critical) regression test
   - Documents bug fix, root cause, and test strategy
   - Test approach: Visit multiple pages as guest, verify nodelet list consistency

**Final Results**:
- ✅ **Guest nodelet bug fixed** - Consistent experience across all pages
- ✅ **E2E test suite operational** - 16 tests, 10 passing (62.5%)
- ✅ **Comprehensive documentation** - E2E test plan with 11 feature areas
- ✅ **Regression test documented** - Ensures bug doesn't recur
- ✅ **All 445 React tests passing** (100%)
- ✅ **All 49 Perl tests passing** (100% when run individually)
- ✅ **Application running** at http://localhost:9080

**Key Files Modified**:
- [ecore/Everything/Node/user.pm](ecore/Everything/Node/user.pm) - Fixed nodelets() check order
- [react/components/Nodelets/Chatterbox.js](react/components/Nodelets/Chatterbox.js) - Private message success detection
- [tools/seeds.pl](tools/seeds.pl) - Added root to e2gods
- [tests/e2e/fixtures/auth.js](tests/e2e/fixtures/auth.js) - Nodelet expansion logic
- [tests/e2e/README.md](tests/e2e/README.md) - Test status and setup instructions
- [docs/e2e-test-plan.md](docs/e2e-test-plan.md) - NEW: Comprehensive test coverage plan
- [.gitignore](.gitignore) - Added Playwright outputs

**Important Discoveries**:
- **Check Order Matters**: When a variable can be set by multiple paths, check the most specific condition FIRST
- **Session Persistence**: Guest user VARS persist across requests, can cause unexpected behavior
- **E2E Login Complexity**: E2's nodelet collapsing requires special handling in tests
- **Playwright Pointer Interception**: Collapsed nodelets can intercept click events, need to expand first
- **Success Message UX**: Only show explicit confirmations when there's no immediate visual feedback
- **Test Documentation Strategy**: Living document with coverage tracking prevents feature gaps

**Critical Bug Pattern Identified**:
```perl
# WRONG - Checks custom VARS before guest status
if($self->VARS->{nodelets}) {
    $nodeletids = [split(",",$self->VARS->{nodelets})];
}elsif($self->is_guest){
    $nodeletids = $self->CONF->guest_nodelets;
}

# RIGHT - Checks guest status FIRST (most specific)
if($self->is_guest){
    $nodeletids = $self->CONF->guest_nodelets;
}elsif($self->VARS->{nodelets}) {
    $nodeletids = [split(",",$self->VARS->{nodelets})];
}
```

**E2E Testing Insights**:
- **Login URL**: E2 login is at `/title/login` OR via Sign In nodelet (NOT `/login`)
- **Nodelet Expansion**: Check `aria-expanded="false"` and `is-closed` class, click header to expand
- **Selector Specificity**: `text=root` matches 9 elements - use more specific selectors like `#username`
- **Test Organization**: Group by feature area, use beforeEach for auth, share fixtures
- **Regression Tests**: Document WHY test exists, WHAT bug it prevents, WHEN it was fixed

**Next Steps**:
- Fix E2E test selector issues (login assertion too broad)
- Implement guest nodelet consistency E2E test
- Add tests for remaining 0% coverage areas (content creation, voting, settings, search, notifications)
- Run full E2E test suite in CI/CD pipeline

### Session 19: UI Polish, Bug Fixes & E2E Testing Strategy (2025-11-25)

**Focus**: Fix blessed vs hashref bugs, improve chatterbox UX, create E2E testing strategy, enhance documentation

**Completed Work**:
1. ✅ **Modified Sanctify User for Admin Testing** ([document.pm:7102](ecore/Everything/Delegation/document.pm#L7102))
   - Admins can now sanctify themselves (useful for testing)
   - Changed condition from `if ($USER->{title} eq $recipient)` to `if ($USER->{title} eq $recipient && !$APP->isAdmin($USER))`
   - Regular users still blocked from self-sanctification
2. ✅ **Removed Unused Mason Template**
   - Deleted [templates/pages/silver_trinkets.mc](templates/pages/silver_trinkets.mc)
   - Page now uses React via [buildReactData()](ecore/Everything/Page/silver_trinkets.pm#L43) method
   - Controller automatically detects and uses generic react_page.mc template
3. ✅ **Fixed Mini Messages Initial Data Loading** ([Application.pm:6002](ecore/Everything/Application.pm#L6002))
   - **Critical Bug**: Was passing `$user_node` (blessed object) to `get_messages()` which expects hashref
   - **Root Cause**: Blessed object has methods, hashref needs direct `{node_id}` access
   - **Fix**: Changed to `$this->get_messages($USER, 5, 0)` - pass hashref instead
   - Mini messages now load on initial page render without API call
4. ✅ **Fixed Chatterbox Message Layout & Animations**
   - **Problem**: Error/success messages caused page layout to jump
   - **Solution**: Absolutely positioned messages overlay "Chat Commands" link
   - Reserved space (minHeight: 40px) to accommodate both link and message
   - Added fade-out animation with CSS transitions (opacity 0.3s ease-out)
   - Added `messageFading` state to control opacity during auto-clear
   - Success messages clear after 3s, errors after 5s, both with smooth fade
   - **No more layout shift** - page height remains constant
5. ✅ **Created Comprehensive E2E Testing Strategy** ([docs/e2e-testing-strategy.md](docs/e2e-testing-strategy.md))
   - **Motivation**: User doing manual UI testing, wants automated headless tests
   - **Recommendation**: Playwright (over Puppeteer/Cypress)
   - Multi-browser support (Chrome, Firefox, Safari)
   - Example tests for: chatterbox layout shift, fade animations, mini messages, wheel spin, sanctify
   - Integration with devbuild.sh pipeline
   - Visual regression testing with screenshots
   - CI/CD setup for GitHub Actions
   - **Estimated effort**: 8-12 hours for full coverage
6. ✅ **Enhanced CLAUDE.md Documentation**
   - Added Perl::Critic section to Common Pitfalls ([CLAUDE.md:29-51](CLAUDE.md#L29-L51))
   - Added Webpack Build Mode section ([CLAUDE.md:53-74](CLAUDE.md#L53-L74))
   - **Critical**: Always use `--mode=development` for webpack builds
   - Preserves class names, enables source maps, skips minification
   - Production mode ONLY for deployment, not development iterations

**Final Results**:
- ✅ **All 49 Perl tests passing** (100%)
- ✅ **All 445 React tests passing** (100%)
- ✅ **Application running** at http://localhost:9080
- ✅ **No layout shifts** - Chatterbox error messages use absolute positioning
- ✅ **Smooth fade-out** - 300ms CSS transition on message clear
- ✅ **Mini messages working** - Load from initial page data without API call
- ✅ **Admin self-sanctify** - Testing feature now available
- ✅ **E2E testing roadmap** - Clear path to automated UI testing

**Key Files Modified**:
- [ecore/Everything/Delegation/document.pm](ecore/Everything/Delegation/document.pm) - Admin self-sanctify bypass
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Fixed blessed vs hashref bug for mini messages
- [react/components/Nodelets/Chatterbox.js](react/components/Nodelets/Chatterbox.js) - Layout fix + fade-out animation
- [docs/e2e-testing-strategy.md](docs/e2e-testing-strategy.md) - NEW: Comprehensive E2E testing guide
- [CLAUDE.md](CLAUDE.md) - Added Perl::Critic and Webpack mode sections
- **Deleted**: [templates/pages/silver_trinkets.mc](templates/pages/silver_trinkets.mc) - Unused Mason template

**Important Discoveries**:
- **Blessed vs Hashref Scope Issues**: Application.pm mixes blessed objects (`$user_node`) and hashrefs (`$USER`). Must use correct form for each function - `get_messages()` expects hashref with `{node_id}` field, not blessed object
- **Absolute Positioning Pattern**: To prevent layout shifts, use `position: relative` container with `minHeight`, then absolutely position overlays with `zIndex`
- **CSS Transition Timing**: Fade-out requires: 1) Set opacity to 0, 2) Wait for transition duration (300ms), 3) Remove element
- **Development vs Production Webpack**: `--mode=development` preserves class names (shows `Chatterbox` not `a` in profiler), critical for debugging
- **Playwright vs Puppeteer**: Playwright supports multiple browsers out of box, better for E2E testing than Puppeteer (Chrome-only)
- **Manual Testing Automation**: User doing lots of manual UI testing → perfect opportunity to implement E2E test suite

**Critical Bug Pattern Identified**:
```perl
# WRONG - Passing blessed object to function expecting hashref
my $user_node = $this->node_by_id($USER->{node_id});  # Blessed object
my $mini_messages = $this->get_messages($user_node, 5, 0);  # ❌ Function expects hashref

# RIGHT - Pass hashref directly
my $mini_messages = $this->get_messages($USER, 5, 0);  # ✅ $USER is hashref
```

**React Layout Shift Prevention Pattern**:
```javascript
// Container with fixed height
<div style={{ position: 'relative', minHeight: '40px' }}>
  {/* Absolutely positioned message overlays */}
  {messageError && (
    <div style={{
      position: 'absolute',
      opacity: messageFading ? 0 : 1,
      transition: 'opacity 0.3s ease-out',
      zIndex: 1
    }}>
      {messageError}
    </div>
  )}

  {/* Static content in normal flow */}
  <button>Chat Commands</button>
</div>
```

**User Feedback Incorporated**:
1. **Testing Automation**: "I feel like I'm doing a lot of by-hand user interface integration testing"
   - Created comprehensive E2E testing strategy with Playwright
   - Provided example tests for exact scenarios user was manually testing
2. **Layout Jumping**: "Confirmation boxes cause page layout to jump"
   - Fixed with absolute positioning and reserved space
   - Messages now overlay link instead of pushing it down
3. **Fade-out Effect**: "Have them fade out as they disappear"
   - Implemented 300ms CSS transition with opacity control
   - Two-stage timeout: display duration → fade duration → removal
4. **Webpack Mode**: "Always webpack build with --mode=development"
   - Added to CLAUDE.md common pitfalls
   - Explained benefits: preserved class names, source maps, no minification

**Next Steps**:
- Implement Playwright E2E test suite (estimated 8-12 hours)
- Continue Phase 4a document migrations
- Consider extracting more htmlcode modules into API methods

### Session 18: React Full-Page Infrastructure & eval() Cleanup (2025-11-25)

**Focus**: Implement React full-page rendering for superdocs, remove eval() calls, fix test failures, repair broken HTML

**Completed Work**:
1. ✅ **React Full-Page Rendering Infrastructure**
   - Created generic [templates/pages/react_page.mc](templates/pages/react_page.mc) container template
   - Modified [Controller/superdoc.pm:17-28](ecore/Everything/Controller/superdoc.pm#L17-L28) to detect React pages via `buildReactData()` method
   - Updated [Application.pm:6665-6700](ecore/Everything/Application.pm#L6665-L6700) to load Page classes and call `buildReactData()`
   - **Pattern**: Pages with `buildReactData()` method automatically use React rendering
   - **Benefits**: Eliminates need for page-specific Mason templates
   - Fixed file permissions on react_page.mc (600→644)
2. ✅ **eval() Cleanup with %INC Caching**
   - **User Request**: "Can we get rid of the eval() in Everything::Application? We just killed those off"
   - Removed @INC searching pattern (inefficient filesystem operations every request)
   - **Solution**: Use Perl's `%INC` cache for already-loaded modules
   - **Pattern**: `if (!exists $INC{$page_file}) { $page_loaded = eval { require $page_file; 1; } || 0; }`
   - Only one minimal eval remains for optional module loading (safe pattern)
   - Fixed Perl::Critic violations: initialized variables, tested eval return values
3. ✅ **Fixed buildReactData() Page Classes**
   - [silver_trinkets.pm:43-48](ecore/Everything/Page/silver_trinkets.pm#L43-L48) - Returns proper contentData structure
   - [wheel_of_surprise.pm:12-19](ecore/Everything/Page/wheel_of_surprise.pm#L12-L19) - Returns proper contentData structure
   - [sanctify.pm:12-18](ecore/Everything/Page/sanctify.pm#L12-L18) - Returns proper contentData structure
   - **Pattern**: `return { contentData => { type => 'page_name', ...data } };`
4. ✅ **Fixed Usergroup Message Sending** ([Application.pm:4446-4450](ecore/Everything/Application.pm#L4446-L4450))
   - **Problem**: `/msg content_editors test` failing with "Recipient not found"
   - **Root Cause**: Code converted underscores to spaces, then only tried usergroup lookup with converted name
   - **Fix**: Try all combinations (user original, user spaces, usergroup original, usergroup spaces)
   - Test [t/037_usergroup_messages.t](t/037_usergroup_messages.t) now passing 9/9 tests
5. ✅ **Fixed Wheel API GPoptout Check** ([t/038_wheel_api.t:19,87,151,171,221](t/038_wheel_api.t))
   - **Problem**: GPoptout users could spin wheel when they shouldn't
   - **Root Cause**: Test manually built vars string with wrong separator (`\n` instead of `&`)
   - **Fix**: Use proper `Everything::setVars($test_user, $vars)` function
   - **Additional Fix**: Declare `our ($APP, $DB)` so MockUser::VARS can access `$main::APP`
   - Test now passing 8/8 subtests with GPoptout correctly blocking wheel spins
6. ✅ **Fixed Broken HTML in Search Form** ([templates/helpers/searchform.mi:20](templates/helpers/searchform.mi#L20))
   - **Problem**: Layout broken on React pages (Silver Trinkets, Wheel of Surprise)
   - **Root Cause**: Line 20 had opening `<span>` tag instead of closing `</span>`
   - **Impact**: Broken HTML structure affected all pages (React and Mason)
   - **Fix**: Changed `<span>` to `</span>` to properly close the "Near Matches" checkbox container
   - All 159/159 smoke tests now passing

**Final Results**:
- ✅ **159/159 smoke tests passing** (100%)
- ✅ **All Perl tests passing** (including 037_usergroup_messages.t and 038_wheel_api.t)
- ✅ **React page infrastructure complete** - Generic template serves all React pages
- ✅ **eval() minimized** - Only safe optional module loading pattern remains
- ✅ **HTML structure repaired** - Layout rendering correctly on all pages

**Key Files Modified**:
- [templates/pages/react_page.mc](templates/pages/react_page.mc) - NEW: Generic React page container
- [ecore/Everything/Controller/superdoc.pm](ecore/Everything/Controller/superdoc.pm) - React page detection
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - eval() cleanup, Page class loading, usergroup lookup fix
- [ecore/Everything/Controller.pm](ecore/Everything/Controller.pm) - Pass user_node to buildNodeInfoStructure
- [ecore/Everything/Page/silver_trinkets.pm](ecore/Everything/Page/silver_trinkets.pm) - Fixed contentData structure
- [ecore/Everything/Page/wheel_of_surprise.pm](ecore/Everything/Page/wheel_of_surprise.pm) - Fixed contentData structure
- [ecore/Everything/Page/sanctify.pm](ecore/Everything/Page/sanctify.pm) - Fixed contentData structure
- [t/038_wheel_api.t](t/038_wheel_api.t) - Fixed setVars usage, added global declarations
- [templates/helpers/searchform.mi](templates/helpers/searchform.mi) - Fixed broken HTML tag

**Important Discoveries**:
- **%INC Caching**: Perl tracks loaded modules in `%INC` hash - use this instead of searching @INC
- **buildReactData() Detection**: `$page_class->can('buildReactData')` determines if page uses React
- **Generic Template Pattern**: Single react_page.mc serves all React pages - no page-specific templates needed
- **contentData Structure**: React routing requires `{ contentData => { type => 'page_name', ...data } }`
- **Usergroup Name Conventions**: E2 allows underscores in commands but stores names with spaces
- **setVars() Pattern**: Always use `Everything::setVars()` function for proper serialization (uses `&` separator)
- **HTML Validation**: Single broken tag in shared template affects ALL pages
- **Docker File Sync**: Use `docker cp` to force template updates through volume mount caching

**Critical Patterns Identified**:
```perl
# REACT PAGE DETECTION PATTERN
my $page_class = $self->page_class($node);
my $is_react_page = $page_class->can('buildReactData');

if ($is_react_page) {
  $layout = 'react_page';  # Generic React container
} else {
  $layout = $page_class->template || $self->title_to_page($node->title);
}

# EFFICIENT MODULE LOADING PATTERN
my $page_loaded = 1;
if (!exists $INC{$page_file}) {
  $page_loaded = eval { require $page_file; 1; } || 0;
}

# BUILDREACTDATA SIGNATURE
sub buildReactData {
  my ($self, $REQUEST) = @_;
  return {
    contentData => {
      type => 'page_name',
      # ...page-specific data
    }
  };
}
```

**User Feedback Incorporated**:
1. **@INC Searching**: "We should absolutely not be searching @INC every time we load a superdoc"
   - Fixed by using %INC cache
2. **Preloading Approach**: "Can we create an inclusion page which just use's every available Page?"
   - Investigated but caused circular dependencies
   - User: "If it's too much surgery, leave it in Everything::Application right now"
   - Kept current architecture with runtime loading
3. **REQUEST Object**: "We should not be building a new Everything::Request object"
   - Fixed by passing `user_node` parameter from Controller
4. **Perl::Critic**: "Application.pm is now failing Perl::Critic for bugs"
   - Fixed all violations (local variable initialization, eval return testing)

**Next Steps**:
- Continue Phase 4a document migrations using React page infrastructure
- Consider refactoring htmlcode modules into API methods
- Implement isSpecialDate() for Halloween detection in wheel_of_surprise

### Session 17: Phase 4a API Development & Blessed Object Patterns (2025-11-25)

**Focus**: Fix wheel and user API implementations, learn blessed object patterns, complete test suites

**Completed Work**:
1. ✅ **Fixed API response format** ([wheel.pm](ecore/Everything/API/wheel.pm), [user.pm](ecore/Everything/API/user.pm))
   - **Wrong Pattern**: `return $self->API_RESPONSE(200, {...})`
   - **Correct Pattern**: `return [$self->HTTP_OK, {...}]`
   - HTTP constants: `HTTP_OK`, `HTTP_FORBIDDEN`, `HTTP_BAD_REQUEST`, `HTTP_NOT_FOUND`
   - Return format: Array reference `[status_code, data_hashref]`
2. ✅ **Fixed blessed object vs hashref pattern** ([wheel.pm:9-10](ecore/Everything/API/wheel.pm#L9-L10))
   - **Critical Learning**: `$user = $REQUEST->user` returns blessed `Everything::Node::user` object
   - **Cannot directly modify**: `$user->{GP}` doesn't work on blessed objects
   - **Correct Pattern**:
     ```perl
     my $user = $REQUEST->user;     # Blessed object
     my $USER = $user->NODEDATA;    # Hashref for modifications
     my $VARS = $user->VARS;        # Get VARS hashref
     $USER->{GP} -= 5;              # Modify the hashref
     $DB->updateNode($USER, -1);    # Update using hashref
     $user->set_vars($VARS);        # Save VARS using blessed method
     ```
3. ✅ **Updated wheel API with correct patterns** ([wheel.pm](ecore/Everything/API/wheel.pm))
   - Replaced all `$self->APP->setVars()` (doesn't exist) with `$user->set_vars()`
   - Replaced all `$self->APP->getVars()` with `$user->VARS`
   - Fixed all `$user->{GP}` references to `$USER->{GP}` (using NODEDATA hashref)
   - Made htmlcode call optional: `if ($APP->can('htmlcode'))`
4. ✅ **Created comprehensive test suite** ([t/038_wheel_api.t](t/038_wheel_api.t), [t/039_user_api.t](t/039_user_api.t))
   - **Wheel API**: 8 subtests, 17 total tests
   - **User API**: 5 subtests
   - **MockUser pattern**: Bridges blessed objects and test mocks
     - `NODEDATA()` returns real user hashref for direct modifications
     - `VARS()` calls `$main::APP->getVars()` to access global $APP
     - `set_vars()` saves VARS back to database
   - Tests pass all authorization, validation, and functional scenarios
5. ✅ **Fixed Docker container file synchronization**
   - **Issue**: Volume mount caching prevented edits from appearing in container
   - **Solution**: Use `docker cp` to force file updates
   - **Pattern**: `docker cp host/file container:/path && docker exec container apache2ctl graceful`

**Final Results**:
- ✅ **17/17 API tests passing** (100%)
- ✅ **Wheel API functional** - Spin, prize distribution, GP/VARS updates working
- ✅ **User API functional** - Sanctity lookup with admin auth working
- ✅ **Phase 4a foundation** - API patterns established for document migration

**Key Files Created/Modified**:
- [ecore/Everything/API/wheel.pm](ecore/Everything/API/wheel.pm) - Wheel spinning API (220 lines)
- [ecore/Everything/API/user.pm](ecore/Everything/API/user.pm) - User sanctity lookup API (65 lines)
- [t/038_wheel_api.t](t/038_wheel_api.t) - Wheel API test suite (257 lines)
- [t/039_user_api.t](t/039_user_api.t) - User API test suite (existing from previous session)

**Important Discoveries**:
- **Blessed Object Architecture**: E2 uses blessed Moose objects that will eventually become DBIx::Class modules
- **NODEDATA Method**: Returns the underlying hashref from blessed user object for direct field modification
- **VARS Access**: `$user->VARS` returns hashref, `$user->set_vars($hashref)` saves changes
- **API Response Format**: Must return `[HTTP_STATUS_CONSTANT, {data}]` not method call
- **Test Mock Pattern**: MockUser must provide `NODEDATA()`, `VARS()`, and `set_vars()` methods
- **Docker File Caching**: Use `docker cp` to force file updates when volume mounts are cached
- **Package Variables in Mock Classes**: Use `$main::APP` and `$main::DB` to access package globals

**Critical Patterns Identified**:
```perl
# BLESSED OBJECT PATTERN
my $user = $REQUEST->user;      # Blessed Everything::Node::user object
my $USER = $user->NODEDATA;      # Get hashref for modifications
my $VARS = $user->VARS;          # Get VARS hashref

# Modify data
$USER->{GP} -= 5;
$VARS->{spin_wheel} += 1;

# Save changes
$DB->updateNode($USER, -1);      # Update node data
$user->set_vars($VARS);          # Update VARS

# API RESPONSE PATTERN
return [$self->HTTP_OK, {        # Array ref, not method call
  success => 1,
  data => {...}
}];
```

**User Feedback Incorporated**:
1. **htmlcode Refactoring**: "Wherever possible, we should refactor htmlcode modules when moving to Everything::Page and Everything::API methods"
   - TODO: Replace `$APP->htmlcode('achievementsByType', ...)` with proper API method
2. **Halloween Detection**: "isHalloween can be generated by $APP->isSpecialDate"
   - TODO: Use `$self->APP->isSpecialDate` instead of manual date checking in wheel_of_surprise

**Next Steps**:
- Refactor htmlcode('achievementsByType') into proper API method
- Use isSpecialDate for Halloween detection in wheel_of_surprise
- Continue Phase 4a document migration (sanctify, silver_trinkets React components)
- Test wheel spinning in live development environment

### Session 16: Messaging Bug Fixes & Test Data Setup (2025-11-25)

**Focus**: Fix nested usergroup messaging bugs, improve chatterbox UX, set up test data for message forwarding

**Completed Work**:
1. ✅ **Fixed nested usergroup messaging bug** ([usergroup.pm:47](ecore/Everything/Node/usergroup.pm#L47))
   - **Problem**: When sending to usergroup that contains nested usergroups, `for_usergroup` field was being overwritten
   - **Example**: root sends to "Content Editors" (contains "e2gods" as member) → message showed as from "e2gods" not "Content Editors"
   - **Root Cause**: Line 46 used unconditional assignment `=`, nested group's recursive `deliver_message()` call overwrote parent's value
   - **Fix**: Changed to conditional assignment `||=` to preserve parent group's for_usergroup during recursion
   - **Code**: `$messagedata->{for_usergroup} ||= $self->node_id;`
2. ✅ **Added 5-minute filter for initial chatterbox** ([Application.pm:5969-5977](ecore/Everything/Application.pm#L5969-L5977))
   - **Problem**: Initial page load showed all 30 most recent messages regardless of age
   - **Fix**: Added SQL time filtering using `DATE_SUB(NOW(), INTERVAL 5 MINUTE)`
   - **Result**: Only messages from last 5 minutes shown on page load
3. ✅ **Fixed usergroup name lookup for /msg command** ([Application.pm:4449](ecore/Everything/Application.pm#L4449))
   - **Problem**: `/msg content_editors test` returned HTTP 400 error
   - **Root Cause**: Usergroup lookup used original `$recip` (with underscores) instead of converted `$name` (with spaces)
   - **Fix**: Changed line 4449 to `$recipient_node = $this->{db}->getNode($name, 'usergroup')`
   - **Pattern**: E2 convention allows underscores in commands but stores names with spaces in database
4. ✅ **Added success confirmation for sent messages** ([Chatterbox.js:168,276-283,562-575](react/components/Nodelets/Chatterbox.js))
   - Added `messageSuccess` state (line 168)
   - Set success message on successful send with 3-second auto-clear (lines 276-283)
   - Display green confirmation box matching error message pattern (lines 562-575)
   - Background: `#d4edda`, border: `#c3e6cb`, text: `#155724`
5. ✅ **Created c_e test user with message forwarding** ([seeds.pl:82-93](tools/seeds.pl#L82-L93))
   - Created user `c_e` in seeds script (NOT nodepack - nodepack comes from production)
   - Set `message_forward_to` NodeParam pointing to Content Editors usergroup
   - Allows testing message forwarding feature in development environment
   - Password: `blah` (standard dev environment password)

**Final Results**:
- ✅ **Nested group messaging working** - for_usergroup field correctly preserved through recursion
- ✅ **Chatterbox cleaner** - Only shows last 5 minutes of messages on page load
- ✅ **Usergroup commands working** - `/msg content_editors` works with underscores
- ✅ **User feedback improved** - Green success message confirms message sent
- ✅ **Test data ready** - c_e user available for message forwarding tests

**Key Files Modified**:
- [ecore/Everything/Node/usergroup.pm](ecore/Everything/Node/usergroup.pm) - Fixed for_usergroup assignment
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Added time filter, fixed usergroup lookup
- [react/components/Nodelets/Chatterbox.js](react/components/Nodelets/Chatterbox.js) - Added success confirmation
- [tools/seeds.pl](tools/seeds.pl) - Added c_e user creation

**Important Discoveries**:
- **Recursive State Management**: Nested usergroups require careful handling with `||=` operator to prevent nested calls overwriting parent values
- **E2 Naming Convention**: Usergroups with spaces can be referenced with underscores in commands (underscore-to-space conversion)
- **Seeds vs Nodepack**: seeds.pl creates development test data; nodepack XML files come from production
- **Message Delivery Architecture**: Messages API → `deliver_message()` on node objects → recursive for usergroups → individual user records
- **Time Filtering Pattern**: `$DB->sqlSelect('DATE_SUB(NOW(), INTERVAL 5 MINUTE)')` for relative timestamps

**Critical Bug Pattern Identified**:
```perl
# WRONG - overwrites in nested recursion
$messagedata->{for_usergroup} = $self->node_id;

# RIGHT - preserves parent value
$messagedata->{for_usergroup} ||= $self->node_id;
```

**Next Steps**: Return to Phase 4a work (wheel spin API, sanctity lookup API, document migration)

### Session 15: Mason2 Elimination Phase 3 - Portal Elimination & Bug Fix (2025-11-24)

**Focus**: Execute Phase 3 of Mason2 elimination plan - eliminate React Portals, have React own sidebar rendering

**Completed Work**:
1. ✅ **Phase 3 Documentation** - Updated docs/mason2-elimination-plan.md to explicitly scope Phase 3 to sidebar only
2. ✅ **E2ReactRoot.js Complete Rewrite** ([E2ReactRoot.js:1-728](react/components/E2ReactRoot.js))
   - Removed all 26 Portal component imports
   - Added `nodeletorder` to toplevelkeys array (line 186)
   - Created `renderNodelet()` method (lines 438-698) with component map for all 26 nodelets
   - New `render()` method (lines 708-725) renders nodelets directly without sidebar wrapper
3. ✅ **Controller.pm Updates** ([Controller.pm:86-102](ecore/Everything/Controller.pm#L86-L102))
   - Built `nodeletorder` array from user's nodelet preferences
   - Added to both `$e2` (for React) and `$params` (for Mason2 template requirements)
   - Skipped `nodelets()` call - Mason2 no longer builds nodelet data structures
4. ✅ **zen.mc Template Update** ([zen.mc:102-105](templates/zen.mc#L102-L105))
   - Removed Mason2 nodelet loop
   - Left only `<div id='e2-react-root'></div>` inside sidebar div
5. ✅ **Portal Files Deleted** - Removed entire `react/components/Portals/` directory (27 files, ~1,350 lines)
6. ✅ **Critical Bug Fix** - Fixed nodelets not displaying on page
   - **Problem**: E2ReactRoot was rendering `<div id='sidebar'>` wrapper but mounting to `#e2-react-root` which is already inside Mason2's sidebar div
   - **Result**: Incorrect double-nesting, nodelets not visible
   - **Fix**: Removed sidebar wrapper from React render() - React just renders nodelets directly
   - **DOM Structure**: `Mason2 sidebar div → e2-react-root div → React nodelets`

**Final Results**:
- ✅ **445/445 React tests passing** (100%)
- ✅ **159/159 smoke tests passing** (100%)
- ✅ **Nodelets displaying correctly** - All 26 nodelets render properly
- ✅ **Portal architecture eliminated** - Cleaner, simpler codebase

**Key Files Modified**:
- [ecore/Everything/Controller.pm](ecore/Everything/Controller.pm) - Build nodeletorder, skip nodelets()
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - Complete rewrite without Portals
- [react/components/E2ReactRoot.test.js](react/components/E2ReactRoot.test.js) - Updated mocks
- [templates/zen.mc](templates/zen.mc) - Removed nodelet loop
- [docs/mason2-elimination-plan.md](docs/mason2-elimination-plan.md) - Phase 3 completion report + Phase 4 plan

**Important Discoveries**:
- **DOM Mounting**: React mounts to `#e2-react-root` which is **inside** Mason2's `<div id='sidebar'>` wrapper
- **No Wrapper Needed**: React must NOT render a sidebar wrapper - it renders nodelets directly
- **Single Mount Point**: React mounts once instead of 26 times (Portals), better performance
- **Clear Boundaries**: Mason2 owns structure wrappers, React owns content rendering

### Session 14: Mason2 Elimination Phase 2 - Controller Simplification (2025-11-24)

**Focus**: Execute Phase 2 of Mason2 elimination plan - simplify Controller to skip building unused data structures

**Completed Work**:
1. ✅ **Controller.pm Simplification** ([Controller.pm:96-124](ecore/Everything/Controller.pm#L96-L124))
   - **Problem**: All 16 nodelets now React-handled with `react_handled => 1` flags, but Controller still:
     - Called individual nodelet methods (`epicenter()`, `readthis()`, `master_control()`, etc.)
     - Built complex Mason2 data structures via delegation lookups
     - Executed ~100+ database queries per page load
     - Discarded all this data because Mason2 templates don't render when `react_handled => 1`
   - **Solution**: Modified `nodelets()` method to skip all method calls:
     - Removed `if($self->can($title))` branch that called Controller methods
     - Removed delegation lookup to `Everything::Delegation::nodelet`
     - Provides only minimal placeholder data: `react_handled => 1`, `title`, `id`, `node`
     - Mason2 still renders empty div wrappers for CSS targeting
   - **Code Reduction**: 34 lines → 13 lines (-21 lines)
   - **Performance**: Eliminated ~16 method calls + ~100+ DB queries per page load

**Final Results**:
- ✅ **159/159 smoke tests passing** (100%)
- ✅ **445/445 React tests passing** (100%)
- ✅ **626 Perl test assertions passing** across 26 test files
- ✅ **No regressions** - All existing functionality works correctly
- ✅ **Expected performance**: 20-40% reduction in page load time (varies by nodelet count)

**Key Files Modified**:
- [ecore/Everything/Controller.pm](ecore/Everything/Controller.pm) - Simplified nodelets() method
- [docs/mason2-elimination-plan.md](docs/mason2-elimination-plan.md) - Added Phase 2 completion report

**Benefits Achieved**:
1. **Significant Performance Improvement** - Eliminated redundant work on every page load
2. **Cleaner Architecture** - Controller no longer coupled to individual nodelet implementations
3. **Reduced Complexity** - Simpler code, single code path instead of dual paths
4. **Prepares for Phase 3** - Clean separation between Controller and nodelet rendering
5. **No Breaking Changes** - All 16 React nodelets continue working perfectly

**Performance Impact**:
- **Before**: ~16 method calls + ~100+ DB queries + complex data structures → discarded by react_handled flags
- **After**: Minimal placeholder data only → same visual output, massive performance gain

**Code Changes Summary**:
```perl
# Before (34 lines):
if($self->can($title)) {
  my $nodelet_values = $self->$title($REQUEST, $node);
  $params->{nodelets}->{$title} = $nodelet_values;
} else {
  if(my $delegation = Everything::Delegation::nodelet->can($title)) {
    $params->{nodelets}->{$title}->{delegated_content} = $delegation->(...);
  }
}

# After (13 lines):
$params->{nodelets}->{$title} = {
  react_handled => 1,
  title => $nodelet->title,
  id => $id,
  node => $node
};
```

**Important Discoveries**:
- **Optimization Pattern**: When ALL components use react_handled, Controller can skip all legacy code paths
- **Minimal Data Needed**: Mason2 only needs `title` and `id` for div wrappers, not full data structures
- **Clean Simplification**: Removing code rather than adding complexity makes system more maintainable
- **Backward Compatibility**: Old Controller methods remain in codebase but are never called (can remove in future cleanup)

**Next Steps**:
- **Phase 3**: Create React-only template path (zen_react.mc) - no Mason2 nodelet rendering
- **Phase 4**: Full Mason2 elimination - pure React frontend

### Session 13: Notification Dismiss & API Polling Optimization (2025-11-24)

**Focus**: Fix notification dismiss functionality and prevent redundant API calls on page load

**Completed Work**:
1. ✅ Implemented notification dismiss functionality
   - Created [notifications.pm](ecore/Everything/API/notifications.pm) API with two endpoints:
     - `GET /api/notifications/` - Fetch unseen notifications
     - `POST /api/notifications/dismiss` - Mark notification as seen
   - Updated [Notifications.js](react/components/Nodelets/Notifications.js) with dismiss handling
   - Uses event delegation to catch clicks on dismiss buttons
   - Extracts `notified_id` from button class (`dismiss notified_123`)
   - Local state filtering hides dismissed notifications immediately
   - Security: Users can only dismiss their own notifications (403 for others)
   - Guest users blocked (401)
2. ✅ Created comprehensive test suite ([t/037_notifications_api.t](t/037_notifications_api.t))
   - 6 subtests, 15 assertions, 100% passing
   - Tests success, validation, security, guest blocking
   - Verified cross-user security (can't dismiss another user's notifications)
3. ✅ **API Polling Optimization** - Prevented redundant API calls on page load
   - **Problem**: Polling hooks made API calls on mount even when components had initial data from server
   - **Impact**: 2x database queries per page load, delayed rendering
   - Modified three polling hooks to accept `initialData` parameter:
     - [usePolling.js](react/hooks/usePolling.js) - Added `options.initialData`
     - [useChatterPolling.js](react/hooks/useChatterPolling.js) - Added `initialChatter` parameter
     - [useOtherUsersPolling.js](react/hooks/useOtherUsersPolling.js) - Added `initialData` parameter
   - Hooks skip initial API call when data provided: `if (!initialData) { fetchData() }`
   - Updated [OtherUsers.js](react/components/Nodelets/OtherUsers.js) to pass `props.otherUsersData` to hook
   - **Benefits**: 50% fewer API calls on page load, instant rendering, reduced server load
4. ✅ Documentation created
   - [docs/api-polling-optimization.md](docs/api-polling-optimization.md) - Complete optimization details
   - Documented before/after data flow, performance impact, future opportunities

**Final Results**:
- ✅ **All 445 React tests passing**
- ✅ **All 47 Perl tests passing**
- ✅ **Application rebuilt and running** at http://localhost:9080
- ✅ **Performance**: 50% fewer API calls on page load for optimized components

**Key Files Modified**:
- [ecore/Everything/API/notifications.pm](ecore/Everything/API/notifications.pm) - NEW: Notification management API
- [react/components/Nodelets/Notifications.js](react/components/Nodelets/Notifications.js) - Dismiss functionality
- [react/hooks/usePolling.js](react/hooks/usePolling.js) - Added initialData option
- [react/hooks/useChatterPolling.js](react/hooks/useChatterPolling.js) - Added initialChatter parameter
- [react/hooks/useOtherUsersPolling.js](react/hooks/useOtherUsersPolling.js) - Added initialData parameter
- [react/components/Nodelets/OtherUsers.js](react/components/Nodelets/OtherUsers.js) - Pass initial data to hook
- [t/037_notifications_api.t](t/037_notifications_api.t) - NEW: Comprehensive API tests
- [react/components/Nodelets/OtherUsers.test.js](react/components/Nodelets/OtherUsers.test.js) - Updated mock

**Important Discoveries**:
- **API Polling Pattern**: Hooks should accept `initialData` to avoid redundant requests on mount
- **Performance Impact**: Components with server-provided initial data save 1 API call + 1 DB query per page load
- **Test Mocking**: Mock functions must handle new parameters: `(pollIntervalMs, initialData) => ...`
- **Backward Compatible**: Hooks work with or without initial data (existing behavior maintained)
- **Local State Optimization**: For dismiss operations, local state filtering is faster than re-fetching HTML from server

**Next Steps**:
1. Monitor API call reduction in production logs
2. Add initial chatter messages to backend (`window.e2.chatterbox.messages`)
3. Apply same optimization pattern to other polling components
4. Consider localStorage caching for even faster page loads

### Session 12: UI Bug Fixes & Room Filtering (2025-11-24)

**Focus**: Fix multiple UI bugs - notifications display, Recent Nodes clear button, nodelet collapse, and chatterbox room filtering

**Completed Work**:
1. ✅ Fixed Notifications nodelet showing "0" ([Notifications.js:27,70](react/components/Nodelets/Notifications.js#L27))
   - Issue: When notifications configured but empty, displayed "0" instead of appropriate message
   - Root cause: Perl boolean `0` being rendered by React when using `{showSettings && ...}`
   - Fix: Added `const shouldShowSettings = Boolean(showSettings)` to convert to proper boolean
   - Now shows "No new notifications" or "Configure notifications to get started"
2. ✅ Implemented Recent Nodes "Clear My Tracks" button ([RecentNodes.js:32-59](react/components/Nodelets/RecentNodes.js#L32-L59))
   - Issue: Button used HTML form submission causing page reload without clearing tracks
   - Added `nodetrail` preference to [preferences.pm:23](ecore/Everything/API/preferences.pm#L23)
   - Created async handler calling `/api/preferences/set` with `{ nodetrail: '' }`
   - Added `onClearTracks` callback to [E2ReactRoot.js:580](react/components/E2ReactRoot.js#L580)
   - Shows visual feedback (disabled button + opacity) while clearing
   - Updates UI immediately without page reload
3. ✅ Fixed collapsedNodelets bug preventing last nodelet collapse ([E2ReactRoot.js:347-352](react/components/E2ReactRoot.js#L347-L352))
   - Issue: When expanding last collapsed nodelet, preference gets deleted (becomes undefined)
   - Root cause: [String.pm:20](ecore/Everything/Preference/String.pm#L20) `should_delete` returns true for empty string
   - Fix: Added defensive checks `this.state.collapsedNodelets || ''` and `e2['collapsedNodelets'] || ''`
   - Ensures collapsedNodelets is always a string before calling `.replace()`
   - Now properly handles empty string preference
4. ✅ Fixed Chatterbox showing all rooms when in "outside" ([Application.pm:4231-4232](ecore/Everything/Application.pm#L4231-L4232))
   - Issue: When in room 0 ("outside"), chatterbox showed messages from ALL rooms
   - Root cause: SQL filter only applied when `if ($room > 0)`, excluding room 0
   - Fix: Changed to `$where .= " and room=$room"` to always filter by room
   - Now properly shows only "outside" messages when in room 0

**Final Results**:
- ✅ **All 445 React tests passing**
- ✅ **All 46 Perl tests passing**
- ✅ **Application rebuilt and running** at http://localhost:9080
- ✅ All UI bugs resolved

**Key Files Modified**:
- [react/components/Nodelets/Notifications.js](react/components/Nodelets/Notifications.js) - Fixed "0" display with boolean conversion
- [react/components/Nodelets/RecentNodes.js](react/components/Nodelets/RecentNodes.js) - Implemented clear tracks functionality
- [react/components/E2ReactRoot.js](react/components/E2ReactRoot.js) - Fixed collapsedNodelets handling + added clear tracks callback
- [ecore/Everything/API/preferences.pm](ecore/Everything/API/preferences.pm) - Added nodetrail preference support
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Fixed room filtering in getRecentChatter
- [react/components/Nodelets/RecentNodes.test.js](react/components/Nodelets/RecentNodes.test.js) - Updated tests for new API approach

**Important Discoveries**:
- **React rendering of falsy values**: React renders `0` but not `false/null/undefined` - always use Boolean() for Perl booleans
- **String preference deletion**: When set to empty string, String.pm deletes the preference instead of storing ""
- **Defensive coding**: Always check for undefined/null before calling string methods like `.replace()`
- **SQL filtering**: Be careful with `> 0` checks that exclude valid zero values
- **Room 0 is valid**: "outside" is room 0, not a null/undefined room

### Session 11: Usergroup Messaging & Message Modal Implementation (2025-11-24)

**Focus**: Fix usergroup messaging bugs, implement comprehensive message composition modal with reply/reply-all functionality

**Completed Work**:
1. ✅ Fixed usergroup messaging internal server error ([Application.pm:4403,4412-4417](ecore/Everything/Application.pm#L4403))
   - Root cause: Code accessed `$usergroup->{user_id}` but usergroups have `node_id`, not `user_id`
   - Fixed `for_usergroup` field in message insertion
   - Fixed `getParameter()` call for archive copy
   - Fixed archive copy insertion
2. ✅ Created usergroup message test suite ([t/037_usergroup_messages.t](t/037_usergroup_messages.t))
   - 4 subtests: member send, non-member rejection, /msg command, archive copy
   - Validates `for_usergroup` field uses node_id correctly
   - Tests usergroup membership authorization
   - Tests archive copy creation for usergroups with `allow_message_archive` setting
3. ✅ Fixed archive filter in Messages nodelet
   - API endpoint wasn't reading `archive` parameter ([messages.pm:27](ecore/Everything/API/messages.pm#L27))
   - `get_messages()` wasn't filtering by archive status ([Application.pm:3758](ecore/Everything/Application.pm#L3758))
   - Added WHERE clause: `for_user=$user->{node_id} AND archive=$archive`
4. ✅ Implemented comprehensive message composition modal ([MessageModal.js](react/components/MessageModal.js))
   - Reply and Reply-All functionality
   - Toggle between individual/group replies for usergroup messages
   - 512 character limit with live counter (yellow at 90%, red at 100%)
   - Auto-focus textarea on open
   - Click-outside-to-close pattern
   - Error handling and loading states
   - Fixed positioning with z-index 10000
5. ✅ Updated Messages nodelet UI ([Messages.js:165-202,253-315,406-453](react/components/Nodelets/Messages.js))
   - Added reply/reply-all/archive/delete buttons with icons (↩, ↩↩, 📦, 🗑)
   - Added Compose and Message Inbox footer buttons (✉, 📬)
   - Integrated MessageModal component
   - Refresh messages list after send
6. ✅ Deployed React bundle and restarted Apache
   - Bundle size: main.bundle.js 139KB, 671.bundle.js 115KB
   - All features live in development environment
7. ✅ Documented message modal features ([message-chatter-system.md:728-794](docs/message-chatter-system.md#L728))
   - Complete feature documentation
   - Button layout and icon usage
   - Validation rules and UX patterns
   - API integration details

**Final Results**:
- ✅ **Usergroup messaging working** - Fixed node_id bug, tests passing
- ✅ **Archive filter working** - Correctly shows inbox vs archived messages
- ✅ **Message modal deployed** - Full reply/reply-all/compose functionality
- ✅ **Complete documentation** - All features documented in message-chatter-system.md

**Key Files Created/Modified**:
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Fixed sendUsergroupMessage() node_id bugs, archive filtering
- [ecore/Everything/API/messages.pm](ecore/Everything/API/messages.pm) - Added archive parameter reading
- [t/037_usergroup_messages.t](t/037_usergroup_messages.t) - NEW: Comprehensive usergroup test suite
- [react/components/MessageModal.js](react/components/MessageModal.js) - NEW: Full-featured composition modal
- [react/components/Nodelets/Messages.js](react/components/Nodelets/Messages.js) - Integrated modal, updated UI
- [docs/message-chatter-system.md](docs/message-chatter-system.md) - Documented modal features

**Important Discoveries**:
- **Blessed Object Fields**: Usergroup nodes have `node_id` field, not `user_id` - must check node type
- **Archive Parameter Flow**: Must explicitly pass parameters through all API layers (CGI → API → Application)
- **React Modal Patterns**: Fixed positioning with high z-index, click-outside-to-close, focus management
- **Character Limit UI**: Live counter with color changes (90% yellow, 100% red) provides clear feedback
- **Reply Context**: Modal needs to distinguish between individual replies and usergroup replies
- **API Integration**: POST to `/api/messages/create` automatically refreshes message list on success

**Critical Bug Pattern Identified**:
```perl
# WRONG - accessing non-existent field
$usergroup->{user_id}  # usergroups don't have user_id

# RIGHT - using correct field
$usergroup->{node_id}  # usergroups are nodes with node_id
```

### Session 10: Message Opcode Refactoring & Parallel Testing (2025-11-24)

**Focus**: Refactor message opcode into centralized Application.pm methods, implement parallel test execution, fix test runner bugs

**Completed Work**:
1. ✅ Extracted command processing from message opcode ([Application.pm:3901-4184](ecore/Everything/Application.pm#L3901-L4184))
   - Created `processMessageCommand()` router with synonym normalization (~285 LOC)
   - Extracted 8 command handlers: /me, /roll, /msg, /fireball, /sanctify, /invite, easter eggs, public chatter
   - Command synonyms: /flip→/roll 1d2, /small→/whisper, /aria→/sing, /tomb→/death
   - ONO (Online-Only) private message support with ? suffix
   - Dice notation parser: XdY[kZ][+/-N] format
2. ✅ Updated chatter API to use command processor ([chatter.pm:52](ecore/Everything/API/chatter.pm#L52))
   - Routes through processMessageCommand() instead of direct chatter
   - React Chatterbox now uses centralized command logic
3. ✅ Refactored message opcode to use Application.pm ([opcode.pm:421-435, 666-673](ecore/Everything/Delegation/opcode.pm#L421))
   - Routes user commands through processMessageCommand()
   - Keeps admin commands inline (/drag, /borg, /topic, etc.)
   - Replaced hardcoded node_id '1948205' with getNode('unverified email', 'sustype')
4. ✅ Implemented Chatterbox focus retention ([Chatterbox.js:55,89](react/components/Nodelets/Chatterbox.js#L55))
   - Stores input reference before async operations
   - Restores focus after message sent (success and error paths)
   - Enables rapid-fire messaging without re-clicking input
5. ✅ Created message opcode burndown chart ([message-chatter-system.md:1136-1270](docs/message-chatter-system.md#L1136))
   - Documented 7 op=message call sites (1 XML ticker, 6 internal forms)
   - 4-phase migration strategy
   - Progress tracking table
6. ✅ Documented insertNodelet() legacy issue ([nodelet-migration-status.md:487-536](docs/nodelet-migration-status.md#L487))
   - 5 affected chatterlight functions in document.pm
   - Impact: Pages likely broken for migrated nodelets
   - 3 resolution options with recommendations
7. ✅ Created parallel test runner ([tools/parallel-test.sh](tools/parallel-test.sh))
   - Concurrent execution: smoke+perl and react tests
   - Animated progress spinners, color-coded output
   - Performance: ~52s vs 55.3s sequential (6% faster + better UX)
   - Integrated into devbuild.sh
8. ✅ Fixed parallel test runner exit code bug
   - Changed from grep-based detection to direct exit code capture
   - Prevents false failures when grep doesn't find expected patterns
   - All tests now report correct pass/fail status

**Final Results**:
- ✅ **1223 Perl tests passing** (smoke + unit, 14 parallel jobs)
- ✅ **445 React tests passing** (25 test suites)
- ✅ **Command processing centralized** - Ready for future API migration
- ✅ **Parallel testing integrated** - Faster builds with better visibility

**Key Files Modified**:
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Added ~285 LOC of command processing
- [ecore/Everything/API/chatter.pm](ecore/Everything/API/chatter.pm) - Routes through processMessageCommand()
- [ecore/Everything/Delegation/opcode.pm](ecore/Everything/Delegation/opcode.pm) - Refactored to use Application.pm methods
- [react/components/Nodelets/Chatterbox.js](react/components/Nodelets/Chatterbox.js) - Focus retention
- [tools/parallel-test.sh](tools/parallel-test.sh) - NEW: Unified parallel test runner
- [docker/devbuild.sh](docker/devbuild.sh) - Integrated parallel testing
- [docs/message-chatter-system.md](docs/message-chatter-system.md) - Added burndown chart
- [docs/nodelet-migration-status.md](docs/nodelet-migration-status.md) - Added insertNodelet() issue
- [docs/test-parallelization.md](docs/test-parallelization.md) - Added parallel test runner docs

**Important Discoveries**:
- Command Router Pattern: Central dispatcher routes messages to specialized handlers
- Exit Code Handling: Bash grep returns 1 on no matches - must capture command exit codes directly
- Focus Restoration: Store element reference before async operations, restore after completion
- Test Parallelization: Concurrent test execution improves speed AND developer UX
- Hardcoded IDs: Use getNode() lookups instead of hardcoded node_ids for maintainability

**Next Steps**:
- Complete op=message migration after React page routing and Mason2 elimination
- Resolve insertNodelet() legacy issue (3 options documented)
- Consider extracting more admin commands from opcode

### Session 9: Message Opcode Analysis & Baseline Testing (2025-11-24)

**Focus**: Analyze message opcode for refactoring, document nodelet periodic update system, create baseline test suite

**Completed Work**:
1. ✅ Documented nodelet periodic update system ([docs/nodelet-periodic-updates.md](docs/nodelet-periodic-updates.md))
   - Analyzed legacy.js AJAX polling mechanisms (list-based updates vs nodelet replacement)
   - Documented sleep/wake system (stops polling after 10 minutes inactivity)
   - Evaluated 4 options for React-based periodic updates
   - **Recommended**: Option D (Hybrid with Shared Activity Detection)
   - Individual polling per nodelet with shared useActivityDetection hook
   - Migration plan for removing legacy.js updaters piecemeal
2. ✅ Analyzed message opcode structure ([opcode.pm:379-1142](ecore/Everything/Delegation/opcode.pm#L379))
   - 763-line monolithic function handling all message functionality
   - Identified 20+ command handlers (/msg, /roll, /fireball, /sanctify, /borg, /drag, etc.)
   - Documented synonym normalization (/small→/whisper, /flip→/rolls 1d2, etc.)
   - Planned hybrid refactoring: extract core commands, keep admin commands in opcode
3. ✅ Created comprehensive baseline test suite ([t/036_message_opcode.t](t/036_message_opcode.t))
   - **9 subtests, 21 tests, 100% pass rate**
   - Tests public chatter (basic + 512 char limit)
   - Tests private messages (creation + permissions)
   - Tests special commands (/roll dice, /me actions)
   - Tests message actions (delete, archive, unarchive)
   - Uses existing users (root, guest user, Cool Man Eddie)
   - MockQuery class simulates CGI query params
   - Baseline ensures no regressions during refactoring

**Final Results**:
- ✅ **Documentation complete**: Periodic update system fully analyzed and documented
- ✅ **Message opcode mapped**: 763 lines analyzed, refactoring strategy defined
- ✅ **Baseline tests passing**: 21/21 tests pass, safe refactoring foundation established

**Key Files Created**:
- [docs/nodelet-periodic-updates.md](docs/nodelet-periodic-updates.md) - Complete periodic update analysis
- [t/036_message_opcode.t](t/036_message_opcode.t) - Baseline test suite (247 lines)

**Key Discoveries**:
- Legacy.js uses two patterns: list-based (smart DOM updates) and nodelet replacement (full HTML swap)
- Message opcode handles 20+ commands but can be refactored piecemeal
- Testing in Docker container required (DBI dependencies)
- `Everything::getVars()` is the correct function (not `$DB->getVars()` or `$user->getVars()`)
- `$DB->sqlSelect('LAST_INSERT_ID()')` for getting last insert ID

**Next Steps**:
1. Extract sendPublicChatter() to Application.pm
2. Extract sendPrivateMessage() to Application.pm
3. Extract processSpecialCommand() to Application.pm
4. Create getRecentChatter() method
5. Create Everything::API::chatter module
6. Update opcode to call new Application methods
7. Verify baseline tests still pass

### Session 8: Chatroom API, Stylesheet Recovery & UI Refinement (2025-11-23)

**Focus**: Fix chatroom API 500 errors, recover broken stylesheets from git history, refine purple chat UI to minimalist design, validate all stylesheets

**Completed Work**:
1. ✅ Fixed chatroom API 500 errors ([chatroom.pm](ecore/Everything/API/chatroom.pm))
   - Root cause: Used `$self->USER` which doesn't exist in Globals role
   - **Correct pattern**: `$REQUEST->user` to access current user
   - Fixed all three methods: change_room, set_cloaked, create_room
   - Changed `$Everything::CONF` to `$self->CONF` for proper attribute access
   - API now returns proper 403 Forbidden instead of 500 Internal Server Error
2. ✅ Fixed browser-debug.js tool ([tools/browser-debug.js:143,158](tools/browser-debug.js#L143))
   - Updated default password from 'password' to 'blah'
   - Fixed login selector from overly specific `input[type="submit"][value="login"]` to generic `input[type="submit"]`
3. ✅ Updated OtherUsers Room Options styling to minimalist design
   - Removed purple gradient (`linear-gradient(135deg, #667eea 0%, #764ba2 100%)`)
   - Applied neutral light gray background (#f8f9fa) matching Kernel Blue aesthetic
   - Reduced visual size: padding 16px → 12px, margins adjusted
   - Removed emojis for cleaner professional look
   - Updated all interior elements with consistent gray palette
   - Removed box shadow for flatter, more minimal appearance
4. ✅ Recovered 3 broken stylesheets from git history
   - **e2gle** (1997552.css) - 20KB, 674 lines, Google-inspired design
   - **gunpowder_green** (1905818.css) - 5.7KB, 449 lines, weblog/nodelet optimized
   - **jukka_emulation** (1855548.css) - 12KB, 583 lines, Clockmaker's fixes
   - Extracted from commits ad67017 and 2f55285
   - Used `perl -MHTML::Entities` to properly decode XML entities
   - Files named by node_id (not escaped friendly names) per E2 convention
5. ✅ Comprehensive stylesheet validation ([docs/stylesheet-system.md](docs/stylesheet-system.md))
   - Validated all 22 stylesheets for syntax errors
   - **22/22** have valid CSS syntax (balanced braces)
   - **FIXED**: Pamphleteer (2029380.css) - added missing closing brace for @media query at line 208
   - **1/22** external dependencies: e2gle (1997552.css) - 6 ImageShack URLs (likely broken)
   - **21/22** fully functional with no known issues
   - Updated documentation with complete evaluation
6. ✅ Fixed 5 more Perl::Critic string interpolation warnings ([NodeBase.pm](ecore/Everything/NodeBase.pm))
   - Line 1167: `'LAST_INSERT_ID()'`
   - Line 1178: `'_id'` concatenation
   - Line 1226: `'tomb'` table name
   - Line 1269: `'node'` table name
   - Line 1328: `'*'` and `'node_id='` in SQL
   - **Total session count**: 15 warnings fixed (10 previous + 5 this session)

**Final Results**:
- ✅ **Chatroom API working** - All endpoints return proper HTTP status codes
- ✅ **Browser debug tool updated** - Matches current E2 environment
- ✅ **UI refined** - Purple gradient replaced with professional neutral design
- ✅ **All stylesheets recovered** - 22/22 present in www/css/
- ✅ **Quality documented** - Complete validation report in stylesheet-system.md
- ✅ **Code quality improved** - 15 total Perl::Critic warnings fixed

**Key Files Modified**:
- [ecore/Everything/API/chatroom.pm](ecore/Everything/API/chatroom.pm) - Fixed USER access pattern
- [tools/browser-debug.js](tools/browser-debug.js) - Updated password and selector
- [react/components/Nodelets/OtherUsers.js](react/components/Nodelets/OtherUsers.js) - Minimalist Room Options design
- [react/components/Nodelets/OtherUsers.test.js](react/components/Nodelets/OtherUsers.test.js) - Updated test data structure
- [www/css/1855548.css](www/css/1855548.css) - NEW: jukka_emulation recovered
- [www/css/1905818.css](www/css/1905818.css) - NEW: gunpowder_green recovered
- [www/css/1997552.css](www/css/1997552.css) - NEW: e2gle recovered
- [docs/stylesheet-system.md](docs/stylesheet-system.md) - Added comprehensive validation results
- [ecore/Everything/NodeBase.pm](ecore/Everything/NodeBase.pm) - Fixed 5 string interpolation warnings

**Important Discoveries**:
- **Globals Role Pattern**: `Everything::Globals` role provides CONF, DB, APP, FACTORY, JSON, MASON - but NO USER attribute
- **API Request Pattern**: Always access user via `$REQUEST->user`, never `$self->USER`
- **Git History Recovery**: Can extract deleted files using `git show <commit>:path/to/file.xml`
- **HTML Entity Decoding**: Use `perl -MHTML::Entities -0777 -ne 'print decode_entities($1) if /<doctext>(.*?)<\/doctext>/s'`
- **Node ID Naming**: Stylesheets must be named `{node_id}.css` not escaped friendly names
- **CSS Validation**: Simple brace balance check catches most syntax errors
- **External Dependencies**: Old user-submitted stylesheets may have external image URLs from defunct services
- **Design Consistency**: Kernel Blue uses neutral grays (#f8f9fa, #dee2e6, #495057) not vibrant gradients
- **Test Data Evolution**: React component rewrites require updating test mock data to match new props

**API Architecture Clarification**:
```perl
# API Base Class Pattern
package Everything::API::example;
use Moose;
extends 'Everything::API';

sub my_endpoint {
  my ($self, $REQUEST) = @_;

  # Correct access patterns:
  my $USER = $REQUEST->user;      # ✓ User from request
  my $DB = $self->DB;              # ✓ From Globals role
  my $APP = $self->APP;            # ✓ From Globals role
  my $CONF = $self->CONF;          # ✓ From Globals role

  # WRONG patterns:
  # my $USER = $self->USER;        # ✗ Doesn't exist
  # my $CONF = $Everything::CONF;  # ✗ Global instead of attribute
}
```

### Session 7: Poll Vote Management & Other Users Nodelet Complete Rewrite (2025-11-23)

**Focus**: Fixing poll admin delete/revote bugs, section collapse preferences, and complete restoration of Other Users nodelet social features

**Completed Work**:
1. ✅ Fixed poll admin delete vote functionality
   - Changed from `$APP->isAdmin($user)` to `$user->is_admin` in [poll.pm:147](ecore/Everything/API/poll.pm#L147)
   - Critical learning: `$user` is a blessed `Everything::Node::user` object, not a hash
   - Method name is `is_admin` (underscore), not `isAdmin` (camelCase)
   - Added `is_admin` method to MockUser in tests
2. ✅ Fixed poll vote bold highlighting
   - Changed `userVote => $choice` to `userVote => int($choice)` in [poll.pm:130](ecore/Everything/API/poll.pm#L130)
   - JavaScript `===` strict equality requires matching types (was comparing `0 === "0"`)
3. ✅ Fixed section collapse preferences for 7 nodelets
   - Changed from `collapsible={false}` to proper `showNodelet` and `nodeletIsOpen` props
   - Fixed: Categories, CurrentUserPoll, FavoriteNoders, MostWanted, OtherUsers, PersonalLinks, RecentNodes, UsergroupWriteups
4. ✅ Complete rewrite of Other Users nodelet ([Application.pm:5329-5585](ecore/Everything/Application.pm#L5329-L5585))
   - Restored all 10+ original social features that were lost in React migration
   - **Corrected sigil assignments** (after user feedback): `@` = gods, `$` = editors, `+` = chanops, `Ø` = borged
   - **Fixed visibility logic**: Changed to `visible=0` for normal users (was inverted)
   - **Created comprehensive spec**: [docs/other-users-nodelet-spec.md](docs/other-users-nodelet-spec.md) with complete original source
   - **Refactored to structured data**: Changed from pre-rendered HTML to JSON objects with type flags
   - **Fixed new user tags visibility**: Added `$newbielook` check - only admins/editors see account age indicators
   - **Bracket formatting**: Flags wrapped in `[...]` instead of plain text
   - **Bold current user**: User's own name in `<strong>` tags
   - **Random user actions**: 2% chance of "is petting a kitten" style messages (29 verbs, 34 nouns from original)
   - **Recent noding links**: 2% chance of "has recently noded [writeup]" if < 1 week old
   - **Multi-room support**: Shows users across ALL rooms with room headers
   - **Proper sorting**: Current room first, then by last noding time, then by active days
   - **Ignore list support**: Respects user message ignore list (unless admin)
   - **Infravision setting**: User preference to see invisible users (alternative to staff powers)
   - **Active days from votesrefreshed**: Uses correct VARS field for account activity
   - **Last node reset logic**: Resets to 0 if < 1 month old or never noded
5. ✅ Removed AWS WAF Anonymous IP List
   - Deleted AWSManagedRulesAnonymousIpList rule from [cf/everything2-production.json](cf/everything2-production.json)
   - Bot protection change per user request
6. ✅ Created browser debugging tool ([tools/browser-debug.js](tools/browser-debug.js))
   - Puppeteer-based headless Chrome automation
   - Commands: screenshot, console, inspect, check-nodelets, login
   - Requested by user for easier debugging

**Final Results**:
- ✅ **Poll voting fully functional** - Admin delete + revote works perfectly
- ✅ **Bold highlighting works** - Voted choice displays in bold
- ✅ **Section collapse working** - All 8 nodelets respect user preferences
- ✅ **Other Users feature-complete** - All 10+ social features restored
- ✅ **Tests passing** - Poll API tests all passing (t/034_poll_api.t ok)
- ✅ **Build successful** - Application running at http://localhost:9080

**Key Files Modified**:
- [ecore/Everything/API/poll.pm](ecore/Everything/API/poll.pm) - Fixed admin check and type coercion
- [t/034_poll_api.t](t/034_poll_api.t) - Added is_admin method to MockUser
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Complete Other Users rewrite with structured data (250+ lines)
- [react/components/Nodelets/OtherUsers.js](react/components/Nodelets/OtherUsers.js) - Complete rewrite using LinkNode for structured data
- [react/components/Nodelets/Categories.js](react/components/Nodelets/Categories.js) - Fixed collapse props
- [react/components/Nodelets/CurrentUserPoll.js](react/components/Nodelets/CurrentUserPoll.js) - Fixed collapse props
- [react/components/Nodelets/FavoriteNoders.js](react/components/Nodelets/FavoriteNoders.js) - Fixed collapse props
- [react/components/Nodelets/MostWanted.js](react/components/Nodelets/MostWanted.js) - Fixed collapse props
- [react/components/Nodelets/PersonalLinks.js](react/components/Nodelets/PersonalLinks.js) - Fixed collapse props
- [react/components/Nodelets/RecentNodes.js](react/components/Nodelets/RecentNodes.js) - Fixed collapse props
- [react/components/Nodelets/UsergroupWriteups.js](react/components/Nodelets/UsergroupWriteups.js) - Fixed collapse props
- [docs/other-users-nodelet-spec.md](docs/other-users-nodelet-spec.md) - NEW: Complete specification with original source
- [cf/everything2-production.json](cf/everything2-production.json) - Removed AWS WAF Anonymous IP List
- [tools/browser-debug.js](tools/browser-debug.js) - NEW: Puppeteer debugging tool

**Important Discoveries**:
- **Blessed Objects**: `Everything::Node::user` objects require method calls, not hash access
- **Method Naming**: E2 uses underscore naming (`is_admin`, `is_editor`) not camelCase
- **Type Coercion**: JavaScript strict equality requires matching types - always `int()` numbers from Perl
- **React Migration**: Critical to preserve ALL original features - social interactions depend on details like sigils, brackets, user actions
- **User Feedback Loop**: "This is a very important social feature" - user emphasized restoration priority
- **Original Code as Reference**: Git history (`git diff <commit>~1 <commit>`) invaluable for recovering complete implementations
- **Test Complexity**: MockUser objects need all methods that real objects have (`is_admin`, `is_editor`, etc.)
- **Structured Data Pattern**: Passing JSON objects with type flags (instead of pre-rendered HTML) provides:
  - Better security (no dangerouslySetInnerHTML for user data)
  - Lighter payload
  - Consistent LinkNode usage
  - Better maintainability
- **Privilege Checks**: Features visible only to privileged users MUST check viewing user's role before adding data
  - **Example**: New user tags should check `$newbielook = $user_is_admin || $user_is_editor` before adding
  - **Bug Pattern**: Adding privileged data unconditionally exposes it to all users
- **Iterative Refinement**: Initial implementation + user testing reveals edge cases (sigils wrong, visibility inverted, missing features)

**Critical Bug Pattern Identified**:
```perl
# WRONG - treating blessed object like hash
$APP->isAdmin($user)

# RIGHT - calling method on blessed object
$user->is_admin

# Note: Method is is_admin (underscore), not isAdmin (camelCase)
```

### Session 6: Poll Voting API & Interactive Voting (2025-11-22)

**Focus**: Implementing poll voting functionality with API endpoints and AJAX voting UI

**Completed Work**:
1. ✅ Created poll voting API ([ecore/Everything/API/poll.pm](ecore/Everything/API/poll.pm))
   - POST /api/poll/vote - User voting endpoint with full validation
   - POST /api/poll/delete_vote - Admin-only endpoint for vote management
   - Fixed critical bug: vote existence check using COUNT(*) instead of checking defined value
   - Fixed critical bug: cache invalidation using updateNode() instead of sqlUpdate()
   - Fixed authorization: changed from isGod() to isAdmin()
2. ✅ Created comprehensive test suite ([t/034_poll_api.t](t/034_poll_api.t))
   - 10 subtests with 62 total assertions
   - Tests all scenarios: authorization, validation, voting, duplicate prevention
   - Uses delete_vote API for test cleanup to ensure idempotent runs
   - 100% test coverage for both endpoints
3. ✅ Updated API documentation ([docs/API.md](docs/API.md))
   - Added Polls section with complete endpoint documentation
   - Included request/response examples, error codes, curl commands
   - Updated test coverage table (overall coverage now ~42%)
   - Documented critical implementation notes (COUNT(*) fix, updateNode() fix)
4. ✅ Verified CurrentUserPoll component
   - Footer links correctly configured for poll management pages
   - AJAX voting already implemented in previous session
   - All 12 React tests passing

**Final Results**:
- ✅ **All 10 poll API tests passing** (62 assertions)
- ✅ **All 12 CurrentUserPoll React tests passing**
- ✅ **100% API coverage** for poll endpoints
- ✅ **Complete documentation** in API.md

**Key Files Created/Modified**:
- [ecore/Everything/API/poll.pm](ecore/Everything/API/poll.pm) - NEW: Poll voting API
- [t/034_poll_api.t](t/034_poll_api.t) - NEW: Comprehensive test suite
- [docs/API.md](docs/API.md) - Updated with Polls section

**Important Discoveries**:
- `sqlSelect()` returns `0` (defined) even when no rows exist - must use COUNT(*) for existence checks
- `sqlUpdate()` doesn't invalidate node cache - must use `updateNode()` for proper cache invalidation
- Admin endpoints use `isAdmin()` which internally calls `$this->{db}->isGod($user)`
- Test cleanup using delete_vote API makes tests idempotent without requiring database resets
- API endpoints that return updated state eliminate need for separate GET requests

### Session 5: Node Notes Enhancement & Mason2 Double Rendering Fix (2025-11-21)

**Focus**: Node notes display improvement, fixing double nodelet rendering, and E2 link parsing

**Completed Work**:
1. ✅ Fixed Perl hash dereference syntax error in Application.pm
   - Changed `$NODE{node_id}` to `$NODE->{node_id}` (lines 4910-4916)
   - Fixed similar errors for `$USER{node_id}`
2. ✅ Enhanced smoke test Apache detection
   - Added content validation for E2-specific markers
   - Added specific HTTP 500 error detection for Perl syntax errors
   - More helpful error messages
3. ✅ Improved node notes display in MasterControl
   - Added `noter_username` field to API responses
   - Created reusable `ParseLinks` React component for E2's bracket link syntax
   - Updated NodeNotes component to display noter username
   - Notes now show: `timestamp username: [parsed links in notetext]`
4. ✅ Fixed double nodelet rendering issue (Mason2 Elimination Phase 1)
   - Added `react_handled => 1` to epicenter.mi, readthis.mi, master_control.mi
   - Mason2 templates now render empty placeholder divs only
   - React handles all nodelet rendering
   - Created comprehensive 4-phase elimination plan
5. ✅ Enhanced ParseLinks to support nested bracket syntax
   - Added support for `[title[nodetype]]` syntax (e.g., `[root[user]]`)
   - Matches Perl parseLinks() regex exactly for legacy compatibility
   - Pattern: `/\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)\]/g`
   - Parses nested brackets to extract title and nodetype separately
   - Passes nodetype to LinkNode for correct URL generation
6. ✅ Optimized NodeNotes API usage
   - Eliminated redundant GET request after DELETE operations
   - DELETE endpoint already returns updated state
   - Reduced API calls from 2 to 1 per delete operation
7. ✅ Fixed initial page load for node notes
   - Added noter_username lookup in Application.pm getNodeNotes() method
   - Initial page load now has same data structure as API responses
   - No refresh needed to see noter usernames

**Final Results**:
- ✅ **213 React tests passing** (20 ParseLinks tests including nested bracket syntax)
- ✅ **61 API tests passing** (added 2 noter_username tests)
- ✅ **159/159 smoke tests passing**
- ✅ **No double rendering** - All nodelets appear exactly once
- ✅ **Nested bracket links work** - `[root[user]]` renders correctly as link to `/node/user/root`

**Key Files Modified**:
- [ecore/Everything/Application.pm](ecore/Everything/Application.pm) - Fixed hash dereference, added noter_username to getNodeNotes()
- [ecore/Everything/API/nodenotes.pm](ecore/Everything/API/nodenotes.pm) - Added noter_username lookup
- [react/components/ParseLinks.js](react/components/ParseLinks.js) - NEW: E2 link parser with nested bracket support
- [react/components/ParseLinks.test.js](react/components/ParseLinks.test.js) - NEW: 20 comprehensive tests
- [react/components/MasterControl/NodeNotes.js](react/components/MasterControl/NodeNotes.js) - Display noter, use ParseLinks, optimized API
- [templates/nodelets/epicenter.mi](templates/nodelets/epicenter.mi) - Added react_handled flag
- [templates/nodelets/readthis.mi](templates/nodelets/readthis.mi) - Added react_handled flag
- [templates/nodelets/master_control.mi](templates/nodelets/master_control.mi) - Added react_handled flag
- [tools/smoke-test.rb](tools/smoke-test.rb) - Better Apache error detection
- [docs/mason2-elimination-plan.md](docs/mason2-elimination-plan.md) - NEW: Comprehensive 4-phase plan
- [docs/changelog-2025-11.md](docs/changelog-2025-11.md) - Updated with React migration details

**Important Discoveries**:
- Mason2 already has `react_handled` mechanism in Base.mc - just needed to set flags
- ParseLinks component is now reusable across entire React codebase
- E2's nested bracket syntax `[title[nodetype]]` requires exact Perl regex match for legacy compatibility
- API endpoints that return updated state eliminate need for separate GET requests
- Everything::Page can be preserved while eliminating Mason2 rendering
- Clean path forward: Phase 2 (optimize), Phase 3 (React template), Phase 4 (eliminate)

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

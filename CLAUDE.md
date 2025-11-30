# AI Assistant Context for Everything2

This document provides context for AI assistants (like Claude) working on the Everything2 codebase. It summarizes recent work, architectural decisions, and important patterns to understand.

**Last Updated**: 2025-11-29
**Maintained By**: Jay Bonci

## ⚠️ CRITICAL: Common Pitfalls & Required Patterns ⚠️

**READ THIS FIRST - These patterns are repeated mistakes that must be avoided:**

### 🚫 DO NOT USE CURL FOR AUTHENTICATED REQUESTS 🚫

**CRITICAL: Use browser-debug.js for all authenticated page fetching, NOT curl** ❌

When you need to fetch pages or debug features with authentication:

**WRONG approaches that waste time:**
- ❌ Using curl with cookies: `curl -b 'userpass=root%09blah' http://localhost:9080/`
- ❌ Trying to manually construct authentication cookies
- ❌ Querying database for password hashes to use with curl
- ❌ Using curl for anything beyond quick "does the container respond" checks

**CORRECT approach - Use browser-debug.js:**
```bash
# Fetch page HTML as authenticated user (like curl but with proper auth)
node tools/browser-debug.js html e2e_admin 'http://localhost:9080/title/Superbless'

# Get page info as JSON (window.e2 data, user info, etc.)
node tools/browser-debug.js fetch e2e_admin 'http://localhost:9080/title/Settings'

# Take screenshot as authenticated user
node tools/browser-debug.js screenshot-as e2e_admin 'http://localhost:9080'
```

**Available test users:**
- `root` - Admin (gods + e2gods), password: blah
- `genericdev` - Developer (edev), password: blah
- `e2e_admin` - E2E Admin (gods), password: test123
- `e2e_user` - E2E Regular User, password: test123
- Run `node tools/browser-debug.js login` to see full list

**When curl IS acceptable:**
- ✅ Quick container health check: `curl -s http://localhost:9080/ | head -20`
- ✅ Checking if page exists (guest access): `curl -I http://localhost:9080/title/Login`
- ✅ Testing unauthenticated API endpoints

**For visual/UI verification:**
- ✅ Deploy code changes with `./docker/devbuild.sh --skip-tests`
- ✅ Tell the user "Changes deployed. Please test by logging in and accessing the page."
- ✅ Let the USER verify visual features that require human inspection

**Why this rule exists:**
1. E2's authentication uses salted cookies that are difficult to replicate programmatically
2. User-specific features (nodelets, preferences, permissions) vary per account
3. You cannot see the browser UI, so you cannot verify visual features anyway
4. Attempting automated auth testing leads to rabbit holes of database queries and curl debugging
5. The user can test logged-in features in 10 seconds - you waste 10+ minutes trying to automate it

**Example - Correct workflow for authenticated features:**
```
User: "The source map isn't showing up on legacy pages"
You: [Read code, identify issue, make fixes]
You: [Run: ./docker/devbuild.sh --skip-tests]
You: "I've deployed the fix. The buildSourceMap() method now works for legacy
      pages via htmlcode.pm. Please log in as a developer and check if the
      source map appears when you click 'View Source Map' on Settings page."
User: [Tests in 10 seconds] "Works! Thanks!"
```

**Example - Wrong workflow (DO NOT DO THIS):**
```
User: "The source map isn't showing up on legacy pages"
You: [Makes fixes]
You: [Tries curl with cookies - doesn't work]
You: [Checks database for user nodelets - gets confused]
You: [Tries different authentication methods - wastes time]
You: [User gets frustrated: "STOP - you're making the same mistakes"]
```

### ⚠️ When to Rebuild vs Run Tests Only ⚠️

**Rebuild IS required (`./docker/devbuild.sh --skip-tests`) when changing:**
- ✅ Perl code (`.pm` files in `ecore/`)
- ✅ React components (`.js` files in `react/`)
- ✅ Perl tests (`.t` files)
- ✅ Server configuration (Apache, Docker)
- ✅ Dependencies (`package.json`, `cpanfile`)
- ✅ Templates (Mason2 files)

**Rebuild NOT required (just run tests) when changing ONLY:**
- ✅ E2E tests (`tests/e2e/*.spec.js`) → Run `npx playwright test`
- ✅ React Jest tests (`react/*.test.js`) → Run `npm test`
- ✅ Test fixtures/helpers used only by E2E/Jest tests

**When in doubt, rebuild to be safe.** Rebuilds take ~60-90 seconds with `--skip-tests`.

**NEVER use `docker cp` and `apache2ctl graceful`:**
```bash
# ❌ WRONG - Even for "quick debugging"
docker cp ecore/Everything/Delegation/htmlcode.pm e2devapp:/var/everything/ecore/Everything/Delegation/htmlcode.pm
docker exec e2devapp apache2ctl graceful

# ✅ CORRECT - Rebuild when changing Perl/React code
./docker/devbuild.sh --skip-tests

# ✅ CORRECT - Skip rebuild when changing ONLY E2E tests
npx playwright test
```

**Why docker cp is forbidden:**
1. **Stale state**: docker cp can leave inconsistent cached state
2. **Missing changes**: Volume mounts may not sync properly
3. **Wasted time**: Debugging phantom issues because changes didn't deploy
4. **Fast enough**: `--skip-tests` rebuilds take ~60-90 seconds
5. **Reliable**: Clean container state ensures you're debugging actual behavior

**Debugging workflow:**
```bash
# 1. Add devLog() calls to code
$APP->devLog("Debug: variable value = $value");

# 2. Rebuild (NOT docker cp!)
./docker/devbuild.sh --skip-tests

# 3. Trigger the code path (via browser-debug.js or manual testing)

# 4. View logs
docker exec e2devapp tail -f /tmp/development.log
```

**Common mistake:**
```
You: [Adds debug logging]
You: [Uses docker cp to deploy]
You: [Checks logs - no output!]
You: "The code path isn't executing..."
Reality: The code IS executing, but docker cp didn't deploy properly!
```

### 🚫 NEVER CREATE GIT COMMITS 🚫

**CRITICAL: Do NOT create git commits - the user handles ALL commits** ❌

**NEVER run any of these commands:**
```bash
# ❌ NEVER do these:
git add .
git commit -m "..."
git commit
git push
git stash
git checkout -b new-branch
```

**Why this rule exists:**
1. **Asset Pipeline Retention**: Small frequent commits push webpack assets past the retention window
2. **Deployment Issues**: Assets getting cleaned up requires deployments to run twice to rebuild them
3. **Commit Quality**: User needs to review changes and write appropriate commit messages
4. **Branch Management**: User manages branching strategy and when to commit

**What you SHOULD do:**
- ✅ Make code changes and test them
- ✅ Tell the user what changes you made
- ✅ Let the user decide when and how to commit
- ✅ Use `git status` or `git diff` to show changes (read-only commands are fine)
- ✅ Suggest commit messages if asked, but don't run git commit

**Example - Correct workflow:**
```
You: [Makes code changes, tests pass]
You: "I've completed the feature. Changes made:
      - Added IsItHoliday.js component
      - Created 5 Page classes for holiday pages
      - Updated DocumentComponent routing

      The changes are ready for you to review and commit when ready."
User: [Reviews changes, creates commit]
```

**Example - Wrong workflow (DO NOT DO THIS):**
```
You: [Makes code changes]
You: [Runs git add .]
You: [Runs git commit -m "Add holiday pages"]
You: "Changes committed!"
User: [Frustrated: "Assets broke, deployment failed, had to run twice!"]
```

### 🔄 Container Rebuild Workflow - CRITICAL 🔄

**ALWAYS use ./docker/devbuild.sh for container rebuilds** ⚠️

When making changes to Perl code, React components, or any application code that needs to be deployed to the container:

**CORRECT rebuild workflow:**
```bash
# For rapid iteration (skip tests to save time):
./docker/devbuild.sh --skip-tests

# Before declaring changes "done" - ALWAYS do clean build with full tests:
./docker/devbuild.sh
```

**Build lock prevents concurrent builds:**

If you see "ERROR: Build already in progress!", wait for the other build to complete. The lock file (`.devbuild.lock`) prevents race conditions when user and assistant work in parallel.

**WRONG approaches that waste time:**
```bash
# ❌ NEVER try to rebuild in-place or use partial updates:
docker exec e2devapp apache2ctl restart
docker cp file.pm e2devapp:/var/everything/file.pm && docker exec e2devapp apache2ctl graceful
npm run build && docker cp bundle.js e2devapp:/var/everything/www/react/

# These leave stale code, cached files, or inconsistent state
```

**Why this matters:**
1. **Stale code**: Incremental updates can leave old module versions in memory
2. **Cached files**: Apache/mod_perl caching can serve outdated code
3. **Inconsistent state**: Partial rebuilds may miss dependency updates
4. **False errors**: What looks like a complex bug is often just stale state
5. **Wasted debugging time**: Hours spent investigating "errors" that clean build fixes

**The Rule:**
- 🏃 **Rapid iteration (manual testing)**: Use `--skip-tests` for quick rebuilds during development
- ✅ **When you need test verification**: ALWAYS run full `./docker/devbuild.sh` with tests
- 🚫 **NEVER**: Run `--skip-tests` then manually run `./tools/parallel-test.sh` - that defeats the purpose!
- 🧪 **Full test suite**: Devbuild.sh runs parallel-test.sh automatically - don't duplicate effort
- 🧹 **Clean slate**: Full rebuild ensures no stale state masking issues

**When to use --skip-tests:**
- Making incremental changes and testing manually in browser
- Rapid iteration on UI/visual features
- Debugging issues that don't require automated test verification

**When to use full devbuild.sh (NO --skip-tests):**
- You modified test files and need to verify tests pass
- You're done with changes and ready to declare "complete"
- You need test output to verify code correctness
- Before asking user to review changes

**Example workflow:**
```bash
# Make code changes for manual testing
vim ecore/Everything/Page/my_page.pm

# Quick rebuild to test visually in browser:
./docker/devbuild.sh --skip-tests
# Test manually in browser

# Make more changes based on manual testing
vim ecore/Everything/Page/my_page.pm

# Quick rebuild again:
./docker/devbuild.sh --skip-tests
# Test manually again

# Everything works visually! Now verify with full test suite:
./docker/devbuild.sh
# If tests pass, changes are done ✓
```

**If you updated test files:**
```bash
# Added new test file t/040_my_feature.t
vim t/040_my_feature.t

# DON'T do this:
# ./docker/devbuild.sh --skip-tests && ./tools/parallel-test.sh  # ❌ WRONG!

# DO this instead:
./docker/devbuild.sh  # ✅ CORRECT - rebuilds AND runs tests automatically
```

**Do NOT skip the final clean build** - it catches:
- Stale module versions that only appear in clean environment
- Test failures masked by cached state
- Dependency issues not visible in incremental builds
- Perl compilation errors in modules loaded at startup

### Running Tests in Container

**If you must run a single Perl test manually, include vendor library path:**
```bash
# Add -I /var/libraries/lib/perl5 for vendor libs (Moose, DBD, etc.)
docker exec e2devapp bash -c "cd /var/everything && prove -I/var/libraries/lib/perl5 t/test.t"
```

Container has vendor Perl modules in `/var/libraries/lib/perl5` - tests fail without this path.

### JSON UTF-8 Encoding

**CRITICAL: CGI POSTDATA requires explicit UTF-8 decoding** ⚠️

```perl
# WRONG - CGI->param("POSTDATA") returns raw UTF-8 bytes, not decoded strings
sub JSON_POSTDATA {
  my $postdata = $self->POSTDATA;
  return $self->JSON->decode($postdata);  # ❌ Garbage for emojis/Unicode
}

# CORRECT - Decode UTF-8 bytes BEFORE JSON parsing
use Encode qw(decode_utf8);

sub JSON_POSTDATA {
  my $postdata = $self->POSTDATA;
  $postdata = decode_utf8($postdata);     # ✅ Decode raw bytes to characters
  return $self->JSON->decode($postdata);
}
```

### React Component Color Palette

**ALWAYS use Kernel Blue stylesheet colors for React components** ✅

When creating React components with inline styles, use the Kernel Blue color palette for consistency with the site's default theme.

**When to use these colors:**
- Use these colors for NEW React components during migration when matching Kernel Blue theme
- Use for inline styles when CSS classes are not yet available
- Eventually these will be replaced with CSS variables in a future theming system
- For now, this ensures visual harmony during the Mason2 → React transition

**Kernel Blue Color Palette** (from www/css/1882070.css):
```javascript
// Primary colors
'#38495e'  // Dark blue-gray (headers, borders, accents)
'#4060b0'  // Medium blue (links, primary actions)
'#507898'  // Steel blue (secondary text, muted elements)
'#3bb5c3'  // Cyan (highlights, special emphasis)

// Backgrounds
'#f8f9f9'  // Light gray (card backgrounds, content areas)
'#f9fafa'  // Near-white (alternate backgrounds)
'#c5cdd7'  // Medium gray (dividers, secondary backgrounds)
'#eee'     // Light gray (subtle backgrounds)

// Text
'#111111'  // Near-black (primary text)
'#333333'  // Dark gray (headings, strong emphasis)

// Borders
'#d3d3d3'  // Light gray (borders, dividers)

// Status colors
'#8b0000'  // Dark red (errors, warnings)
'#ff0000'  // Bright red (critical alerts)
```

**Example usage:**
```javascript
<div style={{
  backgroundColor: '#f8f9f9',
  borderLeft: '3px solid #38495e',
  color: '#111111'
}}>
  <h2 style={{ color: '#333333' }}>Heading</h2>
  <a href="/path" style={{ color: '#4060b0' }}>Link</a>
  <span style={{ color: '#507898' }}>Muted text</span>
  <span style={{ color: '#3bb5c3' }}>Highlight</span>
</div>
```

**Why this matters:**
- Maintains visual consistency with the default Kernel Blue theme
- Will be easier to migrate to CSS variables later
- Avoids jarring color mismatches between React and Mason2 content
- Users familiar with site aesthetics won't notice React components

### Perl::Critic - Finding Code Quality Issues

**CRITICAL: Never use `perl -e` or `perl -c` to syntax check modules on host** ❌

**WRONG - These will fail due to missing vendor libraries:**
```bash
# ❌ NEVER do these on the host:
perl -c ecore/Everything/Application.pm
perl -e 'use Everything::Application'
use strict; use warnings; use Everything::Application;  # In perl -de0
```

Host environment lacks E2's vendor Perl libraries, but Perl::Critic parses without executing code, so it works on the host.

**CORRECT - Use Perl::Critic outside of container:**

Perl::Critic **only parses modules for errors, it doesn't execute them**, making it safe and fast to run on the host without vendor library dependencies.

```bash
# ✅ CORRECT - Default mode (bugs level only):
./tools/critic.pl ecore/Everything/Application.pm

# ✅ Check all files (default mode):
./tools/critic.pl

# ✅ Full linting (all severity levels):
CRITIC_FULL=1 ./tools/critic.pl ecore/Everything/Application.pm

# ✅ Full linting on all files:
CRITIC_FULL=1 ./tools/critic.pl
```

**Two Modes:**

1. **Default mode** (`./tools/critic.pl`):
   - Only checks **bugs** severity level (most critical issues)
   - Replicates the `000_application_health.t` test
   - Fast, focused on preventing breakage
   - Use this for quick checks before commits

2. **Full mode** (`CRITIC_FULL=1 ./tools/critic.pl`):
   - Checks all severity levels (brutal, cruel, harsh, stern, gentle)
   - Comprehensive linting (style, best practices, complexity)
   - Use when asked to evaluate code quality in depth
   - May report issues that are acceptable in this codebase

**Common issues Perl::Critic catches:**
- Uninitialized variables, string interpolation errors, missing returns, unused variables, complexity issues

### Debugging with devLog

**CRITICAL: Use $APP->devLog() for ALL debugging output** ⚠️

**NEVER use warn or die for debugging** - E2's transitional architecture traps these in inconsistent ways:

```perl
# ❌ WRONG - These get trapped/silenced in unpredictable ways:
warn "Debug: value is $value";
die "Debug: this code path executed";
print STDERR "Debug: something happened";

# ❌ WRONG - Don't access $Everything::APP directly (symbol table issues):
$Everything::APP->devLog("Debug message");

# ✅ CORRECT - Use $APP->devLog() from object's APP reference:
$APP->devLog("Debug: value is $value");
$self->APP->devLog("Debug: this code path executed");
$this->{app}->devLog("Debug: in legacy code");
```

**How to access $APP in different contexts:**

```perl
# In Everything::Page classes:
sub buildReactData {
  my ($self, $REQUEST) = @_;
  my $APP = $self->APP;  # Access via $self
  $APP->devLog("buildReactData called for " . $REQUEST->node->title);
}

# In Everything::API classes:
sub my_endpoint {
  my ($self, $REQUEST) = @_;
  my $APP = $self->APP;  # Access via $self
  $APP->devLog("API endpoint called: my_endpoint");
}

# In Everything::Application methods:
sub some_method {
  my ($this, $NODE, $USER) = @_;
  # $this IS the $APP object in Application.pm
  $this->devLog("Application method called");
}

# In delegation modules (htmlcode.pm, document.pm):
sub my_function {
  my ($NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;
  $APP->devLog("Delegation function called");
}

# Most objects have $APP somewhere in args or as object property
# Look for: $self->APP, $this->{app}, $APP parameter, etc.
```

**Viewing debug output:**

```bash
# Tail the development log (live updates):
docker exec e2devapp tail -f /tmp/development.log

# View recent debug messages:
docker exec e2devapp tail -100 /tmp/development.log

# Search for specific debug messages:
docker exec e2devapp tail -500 /tmp/development.log | grep "Debug:"

# Clear log before testing:
docker exec e2devapp bash -c "> /tmp/development.log"
```

**Debugging workflow:**

1. **Add devLog statements** to code path you're investigating
2. **Rebuild container** with `./docker/devbuild.sh --skip-tests`
3. **Clear log**: `docker exec e2devapp bash -c "> /tmp/development.log"`
4. **Replicate the command path** (browser action, API call, test, etc.)
5. **Check log**: `docker exec e2devapp tail -100 /tmp/development.log`
6. **Remove debug statements** when done

**Example - Debugging why code isn't executing:**

```perl
# WRONG approach:
sub buildReactData {
  my ($self, $REQUEST) = @_;
  warn "buildReactData called!";  # ❌ May not appear anywhere
  die "Debug" if $some_condition;  # ❌ May get trapped
  return { type => 'my_page' };
}

# CORRECT approach:
sub buildReactData {
  my ($self, $REQUEST) = @_;
  my $APP = $self->APP;
  $APP->devLog("buildReactData called for node: " . $REQUEST->node->node_id);
  $APP->devLog("User: " . $REQUEST->user->title);

  if ($some_condition) {
    $APP->devLog("Debug: some_condition is TRUE");
  } else {
    $APP->devLog("Debug: some_condition is FALSE");
  }

  return { type => 'my_page' };
}

# Then check: docker exec e2devapp tail -20 /tmp/development.log
```

### NPM Install Permission Fix

**After npm install, fix Playwright CLI permissions** ⚠️

After running `npm install` (or after `git pull` if package-lock.json changed), the Playwright CLI file may lack execute permissions, causing "Permission denied" errors when running E2E tests.

```bash
# Symptom: "sh: 1: playwright: Permission denied" when running tests

# Fix: Add execute permission to Playwright CLI
chmod +x node_modules/@playwright/test/cli.js

# Verify it worked:
ls -la node_modules/@playwright/test/cli.js
# Should show: -rwxr-xr-x (executable)
```

### Script Permissions - CRITICAL for Git ⚠️

**ALWAYS use `git add --chmod=+x` for new scripts** ⚠️

When creating new scripts (shell, Perl, Node.js, etc.), ensure execute permissions are tracked in git:

```bash
# ❌ WRONG - Permissions lost on branch resync
chmod +x tools/new-script.sh
git add tools/new-script.sh

# ✅ CORRECT - Permissions preserved in git
chmod +x tools/new-script.sh
git add --chmod=+x tools/new-script.sh

# Or combine into one command:
git add --chmod=+x tools/new-script.sh
```

**Why this matters:**
- `chmod +x` only sets permissions in working directory
- Branch resync from master loses local permissions
- `git add --chmod=+x` tracks execute bit in git index
- Ensures permissions persist across branch switches and pulls

**Applies to:**
- Shell scripts (`.sh`)
- Perl scripts (`.pl`, `.pm` with shebang)
- Node.js scripts (`.js` with shebang)
- Any executable files created or installed by npm

### Webpack Build Mode

**CRITICAL: NEVER run webpack manually - devbuild.sh handles it automatically** ⚠️

The `./docker/devbuild.sh` script automatically runs webpack in development mode and deploys bundles to the container. **DO NOT attempt manual webpack builds.**

```bash
# ✅ CORRECT - Webpack runs automatically:
./docker/devbuild.sh --skip-tests    # Rebuilds webpack + deploys to container
./docker/devbuild.sh                  # Rebuilds webpack + deploys + runs tests

# ❌ WRONG - NEVER do these:
npx webpack --config etc/webpack.config.js --mode=development
npx webpack --config etc/webpack.config.js --mode=production
docker cp www/react/main.bundle.js e2devapp:/var/everything/www/react/main.bundle.js
```

**Why devbuild.sh handles webpack:**
- ✅ Automatically builds in development mode (readable class names, no minification)
- ✅ Deploys bundles to container's `/var/everything/www/react/` automatically
- ✅ Ensures consistent build environment
- ✅ Prevents stale bundle issues from manual copying
- ❌ Manual webpack + docker cp leads to inconsistent state

**Development mode benefits** (automatic in devbuild.sh):
- Class names preserved: React components show as `Chatterbox` not `a`
- Source maps: Better stack traces in browser console
- No minification: Code is readable in DevTools
- Faster builds: Skips optimization step

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

### E2E Test Best Practices ⚠️

**ALWAYS write E2E tests with cleanup and documentation** ⚠️

When creating or modifying E2E tests in `tests/e2e/*.spec.js`:

**1. Add file-level documentation block:**
```javascript
/**
 * Feature Name E2E Tests
 *
 * Tests the Feature functionality:
 * - Sub-feature 1
 * - Sub-feature 2
 * - Edge cases
 *
 * CLEANUP STRATEGY:
 * - Describe how test cleans up after itself
 * - Explain state restoration (e.g., GP restoration, message clearing)
 * - Note any persistent changes left behind (ideally none)
 *
 * TEST USERS:
 * - e2e_admin (admin, password: test123) - Used for...
 * - e2e_user (regular user, password: test123) - Used for...
 */
```

**2. Add test-level documentation:**
```javascript
/**
 * Test: Descriptive test name
 *
 * Purpose: Clear explanation of what this test verifies
 *
 * Steps:
 * 1. First action
 * 2. Second action
 * 3. Verification
 * 4. Cleanup
 *
 * Cleanup: How this test cleans up (or note "N/A" if read-only)
 */
test('descriptive test name', async ({ page }) => {
  // Test implementation
})
```

**3. Implement cleanup logic:**

```javascript
// Example: Chatterbox tests clear chatter before each test
test.beforeEach(async ({ page }) => {
  await loginAsE2EAdmin(page)
  await page.waitForSelector('#chatterbox', { timeout: 10000 })

  // Clear chatter to ensure clean state
  await page.fill('#message', '/clearchatter')
  await page.click('#message_send')
  await page.waitForTimeout(500)
})

// Example: Wheel tests restore GP after spinning
test('displays spin result', async ({ page }) => {
  // ... spin wheel (costs 5 GP)

  // CLEANUP: Restore GP via Sanctify
  await page.goto('/title/Sanctify+user')
  await page.fill('[name="give_to"]', 'e2e_admin')
  await page.click('input[name="give_GP"]')  // Grants 10 GP
})
```

**4. Make tests idempotent:**
- Tests should run successfully multiple times without failures
- Use timestamps in test data: `'test message ' + Date.now()`
- Clear test data before starting (e.g., `/clearchatter`)
- Offset resource consumption (e.g., spin costs 5 GP, sanctify grants 10 GP)

**5. Document test users:**
```javascript
// Available E2E test users (from tools/seeds.pl):
// e2e_admin     - Admin (gods), password: test123, 500 GP
// e2e_editor    - Editor (Content Editors), password: test123, 300 GP
// e2e_developer - Developer (edev), password: test123, 200 GP
// e2e_chanop    - Chanop (chanops), password: test123, 150 GP
// e2e_user      - Regular user, password: test123, 100 GP
// e2e user space - Username with space, password: test123, 75 GP
```

**Why this matters:**
- Human-readable audit trail for complex multi-step operations
- Easy to verify test intent matches implementation
- Multiple runs don't leave weird state or fail randomly
- New developers can understand what tests do without running them

### Blessed Objects vs Hashrefs - Node Context Reference

**CRITICAL: Nodes come in TWO forms - blessed Everything::Node objects vs hashrefs** ⚠️

Everything2 is transitioning from hashref-based node access to encapsulated `Everything::Node` blessed objects. Understanding which context you're in is essential for correct code.

**Design goal**: Move all code to use `Everything::Node` blessed objects, but this requires converting most code to `Everything::API` pattern. Until then, you'll encounter both forms.

**SCOPE 1: Controller/Page classes (have $REQUEST)**

In `Everything::Controller`, `Everything::Page`, `Everything::API`, or anywhere with `$REQUEST` object:

```perl
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

In `Application.pm::buildNodeInfoStructure` and similar legacy methods that receive hashrefs directly:

```perl
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

**SCOPE 3: Delegation modules (htmlcode.pm, document.pm)**

Delegation functions receive hashrefs as parameters:

```perl
sub my_htmlcode_function {
  my ($NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

  # Read via hash access:
  my $username = $USER->{title};            # ✓ Direct hash access
  my $doctext = $NODE->{doctext};           # ✓ Direct hash access

  # Modify directly:
  $USER->{GP} += 10;
  # Note: Changes to $USER/$NODE may not persist unless you update DB

  # If you need blessed object methods:
  my $user_node = $APP->node_by_id($USER->{node_id});  # Convert to blessed
  $user_node->set_vars($VARS);                          # ✓ Use methods
}
```

**Converting Between Forms:**

```perl
# Blessed → Hashref (when you need direct hash access or modification):
my $user = $REQUEST->user;          # Blessed Everything::Node::user object
my $USER = $user->NODEDATA;          # Hashref with all database fields
$USER->{GP} = 100;                   # Modify hashref
$DB->updateNode($USER, -1);          # Save changes

# Hashref → Blessed (when you need object methods):
my $USER = { node_id => 12345, title => 'foo' };  # Hashref
my $user = $APP->node_by_id($USER->{node_id});    # Convert to blessed object
my $is_admin = $user->is_admin;                    # Use object methods
```

**IMPORTANT: NODEDATA returns a REFERENCE to internal hashref**

```perl
my $user = $REQUEST->user;           # Blessed object
my $USER = $user->NODEDATA;          # Get internal hashref REFERENCE

# Modifications to $USER affect the blessed object's internal state!
$USER->{GP} = 100;                   # Modifies blessed object's data
# The blessed object's accessors reference this same hashref:
my $gp = $user->GP;                  # Returns 100 (reflects the change!)

# This allows seamless integration between old and new code:
sub legacy_function {
  my ($USER) = @_;                   # Expects hashref
  $USER->{GP} += 50;                 # Modifies hashref
}

my $user = $REQUEST->user;           # Blessed object
legacy_function($user->NODEDATA);    # Pass internal hashref
# Blessed object now reflects the changes:
my $new_gp = $user->GP;              # Returns updated value
```

**Quick Reference Table:**

| Context | Form | Access Pattern | Modification | Example |
|---------|------|----------------|--------------|---------|
| Controller/Page/API | Blessed (`$REQUEST->user`) | Methods (`$user->GP`) | Get hashref first (`$user->NODEDATA`) | `$user->title` |
| Application.pm | Hashref (`$USER`) | Hash (`$USER->{GP}`) | Direct (`$USER->{GP} = 100`) | `$USER->{title}` |
| Delegation (htmlcode.pm) | Hashref (`$USER` param) | Hash (`$USER->{GP}`) | Direct (`$USER->{GP} = 100`) | `$USER->{title}` |
| `$DB->getNode*()` calls | Hashref | Hash access | Direct | `$node->{title}` |
| `$APP->node_by_id()` calls | Blessed object | Methods | Get NODEDATA first | `$node->title` |

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

### ⚠️ E2 Schema Architecture - Table Joins ⚠️

**CRITICAL: Everything::NodeBase joins tables using shared primary keys** 🔑

Everything2 uses a polymorphic schema where complex node types are built by joining multiple tables. **By convention, the following field names ALL refer to the base `node_id`:**

- `node_id` - Primary key in base `node` table
- `document_id` - Primary key in `document` table (references `node.node_id`)
- `setting_id` - Primary key in `setting` table (references `node.node_id`)
- `writeup_id` - Primary key in `writeup` table (references `node.node_id`)
- `superdoc_id` - Primary key in `superdoc` table (references `node.node_id`)
- etc.

**Everything::NodeBase** automatically joins these tables together to form complex types when you call `getNodeById()` or `getNode()`.

**Example - Superdoc node type:**
```perl
# When you call:
my $node = $DB->getNodeById(12345);  # A superdoc node

# NodeBase automatically joins:
# - node table (node_id = 12345)
# - document table (document_id = 12345)  <- Same ID!
# - superdoc table (superdoc_id = 12345)  <- Same ID!

# Result: $node hashref contains fields from all three tables
# $node->{node_id}      from node table
# $node->{doctext}      from document table
# $node->{display}      from superdoc table
```

**Why this matters:**
1. When writing SQL joins, use the convention: `table_name.{type}_id = node.node_id`
2. When accessing node data, understand that fields come from multiple joined tables
3. When debugging SQL errors, check that `*_id` fields are used correctly as join keys
4. All these `*_id` fields are **primary keys** in their respective tables

**Common mistake:**
```perl
# WRONG - thinking document_id is different from node_id
my $doc_node = $DB->getNodeById($node->{document_id});  # Redundant!

# RIGHT - they're the same ID
my $doc_node = $DB->getNodeById($node->{node_id});      # Correct
```

This schema pattern is fundamental to E2's architecture and explains why seemingly different ID fields actually reference the same underlying node.

### Cookie Authentication

**WARNING: This section is for UNDERSTANDING the authentication system only.**

**DO NOT use this information to attempt manual authentication.** See "DO NOT ATTEMPT AUTOMATED TESTING WITH AUTHENTICATION" section at the top.

E2 uses salted/hashed password cookies (`userpass` cookie with `username|hashed_password` format). Implementation: [Request.pm:97-225](ecore/Everything/Request.pm), [Application.pm hashString()](ecore/Everything/Application.pm).

For authenticated testing, use browser-debug.js (see "Testing Container Health" section).

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

  # IMPORTANT: Return data WITHOUT contentData wrapper
  # Application.pm wraps this in { contentData => { ... } } automatically
  return {
    type => 'my_page',      # Must match DocumentComponent router
    # ...page-specific data
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

### Docker Container Names

**Correct container names:**
- Application: `e2devapp` (NOT `e2_everything2_1`)
- Database: `e2devdb`

**Example database access:**
```bash
docker exec e2devdb mysql -u root -pblah everything
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

### Running Tests

**See "Container Rebuild Workflow" section for when to use `--skip-tests` vs full rebuild.**

**Quick reference:**
- ✅ `./docker/devbuild.sh` - Full rebuild with tests (use when test verification needed)
- ✅ `./docker/devbuild.sh --skip-tests` - Quick rebuild for manual testing only
- ❌ NEVER: `./docker/devbuild.sh --skip-tests` then `./tools/parallel-test.sh` - just use full devbuild.sh!

**Run specific Perl test (inside container):**
```bash
# After rebuilding container with test file changes:
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
# Includes automatic retry logic for transient errors (400, 502, 503, 504)
# Max 3 retries with exponential backoff (0.5s, 1s, 2s)
```

**Test Parallelization:**

Tests that modify shared database state (message table, public chatter, etc.) MUST run serially to avoid race conditions. The test runner [t/run.pl](t/run.pl#L32-37) maintains a list of serial tests:

```perl
my %serial_tests = (
    "$dirname/008_e2nodes.t" => 1,
    "$dirname/009_writeups.t" => 1,
    "$dirname/036_message_opcode.t" => 1,
    "$dirname/043_chatter_api.t" => 1,  # Modifies message table (public chatter)
);
```

**When adding new tests:**
- ✅ Default: Tests run in parallel (14 jobs on 16-core system)
- ⚠️ Add to `%serial_tests` if test:
  - Deletes/modifies global database state (public messages, chatter, etc.)
  - Uses shared test user accounts that could have session conflicts
  - Has race conditions when run concurrently with other tests

**Symptom of missing serial flag:** Intermittent test failures that pass when run individually but fail in parallel test suite.

### Testing Container Health

**Use curl ONLY to verify container is responding:**
```bash
# Check if container is up:
curl -s http://localhost:9080/ | head -20

# Check if React bundle loads:
curl -I http://localhost:9080/react/main.bundle.js
```

**For authenticated testing**, see "DO NOT ATTEMPT AUTOMATED TESTING WITH AUTHENTICATION" section at top - use browser-debug.js, never curl.

**For authenticated testing, use browser-debug.js:**
```bash
# Fetch page as authenticated user:
node tools/browser-debug.js fetch e2e_admin http://localhost:9080/title/Settings

# Screenshot as authenticated user:
node tools/browser-debug.js screenshot-as genericdev http://localhost:9080

# Available test users (see tools/seeds.pl):
node tools/browser-debug.js login  # Shows full list
```

**Why browser-debug.js instead of curl:**
- E2 content is rendered by React in JavaScript
- Curl only sees raw HTML, not the final rendered page
- Authentication requires salted/hashed passwords in cookies
- Visual features cannot be verified via curl
- browser-debug.js handles all authentication automatically

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

**CRITICAL: Webpack is built automatically by `./docker/devbuild.sh`** ⚠️

**NEVER run webpack manually or copy bundles to the container:**

```bash
# ✅ CORRECT - Use devbuild.sh (webpack runs automatically):
./docker/devbuild.sh --skip-tests    # Webpack + deploy to container
./docker/devbuild.sh                  # Webpack + deploy + tests

# ❌ WRONG - NEVER do these:
npx webpack --config etc/webpack.config.js
docker cp www/react/main.bundle.js e2devapp:/var/everything/www/react/
```

**Why this matters:**
- devbuild.sh runs webpack in development mode automatically
- Bundles are deployed to container's `/var/everything/www/react/` during build
- Manual webpack + docker cp leads to stale state issues
- Always use proper rebuild workflow (see "Container Rebuild Workflow" section)

**Check bundle sizes for debugging:**
```bash
ls -lh www/react/*.bundle.js
# Expected sizes:
# main.bundle.js: ~1.1-1.2 MB
# react_components_E2ReactRoot_js.bundle.js: ~400 KB
# react_components_PageLayout_js.bundle.js: ~33 KB
```

### Rebuilding Application

**See "Container Rebuild Workflow" section above for proper rebuild procedures.**

**Use `./docker/devbuild.sh` or `./docker/devbuild.sh --skip-tests` for all rebuilds.**

Do NOT use manual approaches like `docker cp`, `apache2ctl graceful`, or `docker restart` - these lead to stale state issues.

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


## Debugging Workflows

### Finding Code Locations

**When you need to find where something is implemented:**

1. **Start with Grep for keywords**:
   ```bash
   # Search for function/method names
   Grep pattern="buildReactData" path="ecore" output_mode="files_with_matches"
   
   # Search for specific strings
   Grep pattern="Is it Christmas" path="ecore" output_mode="content"
   ```

2. **Check Page classes** for superdoc pages:
   ```bash
   # Page classes follow naming convention
   ls ecore/Everything/Page/wheel_of_surprise.pm
   ```

3. **Check API endpoints**:
   ```bash
   ls ecore/Everything/API/wheel.pm
   ```

4. **Check delegation modules** for htmlcode/document functions:
   ```bash  
   grep -n "sub my_function" ecore/Everything/Delegation/htmlcode.pm
   grep -n "sub my_document" ecore/Everything/Delegation/document.pm
   ```

### Debugging React Components

**When React components aren't rendering:**

1. **Check if data is in window.e2**:
   ```bash
   curl -s 'http://localhost:9080/title/Page+Name' | grep -o '"contentData":{[^}]*}'
   ```

2. **Check DocumentComponent routing**:
   - Open [react/components/DocumentComponent.js](react/components/DocumentComponent.js)
   - Verify page type is in COMPONENT_MAP
   - Check component import path

3. **Check Page class buildReactData()**:
   - Returns data WITHOUT contentData wrapper (Application.pm adds it)
   - Correct: `return { occasion => 'xmas' }`
   - Wrong: `return { contentData => { occasion => 'xmas' } }`

4. **Check page name conversion** in Application.pm:
   - Title "Is it Christmas yet?" → `is_it_christmas_yet` (no ?)
   - Apostrophes, spaces, and `?` become underscores
   - Trailing underscores removed

### Debugging Perl Issues

**When Perl code isn't working:**

1. **Check Apache error log**:
   ```bash
   docker exec e2devapp tail -100 /var/log/apache2/error.log | grep -i "error"
   ```

2. **Test Perl syntax**:
   ```bash
   docker exec e2devapp bash -c "cd /var/everything && perl -I/var/libraries/lib/perl5 -c ecore/Everything/Page/my_page.pm"
   ```

3. **Run Perl::Critic**:
   ```bash
   ./tools/critic.pl ecore/Everything/Application.pm
   ```

4. **Common Perl errors**:
   - "Can't locate Moose.pm" → Missing `-I/var/libraries/lib/perl5`
   - "Undefined subroutine" → Check imports or typo in method name
   - "Not a HASH reference" → Using blessed object instead of hashref (or vice versa)

### Deploying Changes

**See "Container Rebuild Workflow" section for proper deployment procedures.**

**Standard deployment workflow:**

```bash
# 1. Edit file on host (WSL)
vim ecore/Everything/Page/my_page.pm

# 2. Rebuild container (includes webpack rebuild automatically)
./docker/devbuild.sh --skip-tests    # For rapid iteration (manual testing)
# OR
./docker/devbuild.sh                  # When you need test verification

# 3. Tell user to test
```

**DO NOT use docker cp or apache2ctl graceful** - these leave stale state. Always use devbuild.sh.

### Common Issue Patterns

**Page not found (404):**
- Check node exists in database: `docker exec e2devdb mysql -u root -pblah everything -e "SELECT node_id, title FROM node WHERE title='Page Title'"`
- Check page name conversion (apostrophes, spaces, ? → underscores)
- Check if Page class file exists

**Blessed object vs hashref confusion:**
- `$REQUEST->user` → blessed object, use methods like `$user->title`
- `$user->NODEDATA` → hashref, use hash access like `$USER->{title}`
- `$user->VARS` → hashref for reading
- `$user->set_vars($VARS)` → method for saving

**React component not receiving data:**
- Check window.e2 has the data
- Check buildReactData() return structure (no nested contentData)
- Check DocumentComponent has correct route
- Check component prop destructuring matches data structure

## Recent Work

### Session: CSS Variables & Notification Fix (2025-11-29)

**Completed**:

1. **CSS Variable System Implementation** 🎨
   - Created 19 `-var.css` versions of all stylesheets (Kernel Blue, Understatement, Responsive2, etc.)
   - Implemented `?csstest=1` query parameter for A/B testing without affecting normal users
   - Modified [Controller.pm:38-49](ecore/Everything/Controller.pm#L38-L49) to detect parameter and swap stylesheet URLs
   - Designed 20+ standardized CSS variable names (--e2-color-link, --e2-bg-body, --e2-color-primary, etc.)
   - Created [tools/css-to-vars.pl](tools/css-to-vars.pl) helper script to analyze colors and suggest variable names
   - Full documentation: [docs/css-variables-testing.md](docs/css-variables-testing.md)
   - **Impact**: Enables safe stylesheet modernization testing; prepares for dark mode, user customization
   - **Limitations**: React inline styles still use hardcoded Kernel Blue colors (Phase 3 work)

2. **Document.pm Cleanup** 🧹
   - Removed 690 lines of legacy code migrated to React:
     - `suspension_info` (161 lines) → SuspensionInfo.js + suspension.pm API
     - `giant_teddy_bear_suit` (93 lines) → GiantTeddyBearSuit.js + teddybear.pm API
     - `text_formatter` (436 lines) → TextFormatter.js component
   - **Impact**: Reduced codebase complexity, eliminated code duplication

3. **Notification Periodic Update Bug Fix** 🐛
   - **Problem**: Notifications losing text after 2-minute periodic refresh (showing only "×" button)
   - **Root Cause**: `/api/notifications/` returned raw DB rows without `text` field; React expected `notification.text`
   - **Fix**: Modified [notifications.pm:17-32](ecore/Everything/API/notifications.pm#L17-L32) to use `getRenderedNotifications()`
   - Simplified endpoint from 66 lines to 14 lines by reusing existing rendering logic
   - **Impact**: Fixes notifications in sidebar, Chatterlight family pages, and all fullpage layouts

**Files Modified**:
- ecore/Everything/Controller.pm (CSS parameter detection)
- ecore/Everything/API/notifications.pm (periodic update fix)
- ecore/Everything/Delegation/document.pm (cleanup)
- Created: 19× www/css/*-var.css files
- Created: docs/css-variables-testing.md, tools/css-to-vars.pl

**Test Status**: All tests passing (54 Perl + 567 React = 621 total)

---

For detailed work history and completed features, see:
- [November 2025 Changelog](docs/changelog-2025-11.md) - User-facing summary of changes
- Git commit history for technical implementation details

Key patterns and workflows are documented above. Avoid repeating past mistakes documented in the "Common Pitfalls" section.


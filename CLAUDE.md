# AI Assistant Context for Everything2

Context for AI assistants working on the Everything2 codebase.

**Last Updated**: 2025-12-06
**Maintained By**: Jay Bonci

## ⚠️ CRITICAL: Common Pitfalls ⚠️

### 🚫 DO NOT USE CURL FOR AUTHENTICATED REQUESTS

Use `browser-debug.js` for all authenticated page fetching:
```bash
node tools/browser-debug.js html e2e_admin 'http://localhost:9080/title/Superbless'
node tools/browser-debug.js fetch e2e_admin 'http://localhost:9080/title/Settings'
node tools/browser-debug.js screenshot-as e2e_admin 'http://localhost:9080'
```

**Test users**: root (gods, pw:blah), genericdev (edev, pw:blah), e2e_admin (gods, pw:test123), e2e_user (pw:test123)

**When curl IS acceptable**: Container health checks (`curl -s http://localhost:9080/ | head -20`)

### 🚫 NEVER CREATE GIT COMMITS

User handles all commits. Asset pipeline retention issues.

### 🔄 Container Rebuild Workflow

**ALWAYS use devbuild.sh:**
```bash
./docker/devbuild.sh --skip-tests  # Quick rebuild (manual testing)
./docker/devbuild.sh               # Full rebuild with tests
```

**NEVER use docker cp or apache2ctl graceful** - leads to stale state.

### Running Tests in Container

```bash
docker exec e2devapp bash -c "cd /var/everything && prove -I/var/libraries/lib/perl5 t/test.t"
```

### JSON UTF-8 Encoding

```perl
# CGI POSTDATA needs explicit UTF-8 decoding BEFORE JSON parsing
use Encode qw(decode_utf8);
$postdata = decode_utf8($self->POSTDATA);
```

### React Color Palette (Kernel Blue)

```javascript
'#38495e'  // Headers, borders    '#4060b0'  // Links
'#507898'  // Secondary text      '#3bb5c3'  // Highlights
'#f8f9f9'  // Backgrounds         '#111111'  // Primary text
```

### Perl::Critic (Run on Host)

```bash
./tools/critic.pl ecore/Everything/Application.pm        # Bugs only
CRITIC_FULL=1 ./tools/critic.pl ecore/Everything/Application.pm  # Full lint
```

### Debugging with devLog

```perl
$APP->devLog("Debug: value is $value");
$self->APP->devLog("Debug: in Page class");
```
View: `docker exec e2devapp tail -f /tmp/development.log`

### React & Perl Booleans

```javascript
{Boolean(props.someValue) && <div>Content</div>}  // Perl 0 renders as "0"
```

### Blessed Objects vs Hashrefs

| Context | Form | Access | Example |
|---------|------|--------|---------|
| Controller/Page/API | Blessed (`$REQUEST->user`) | Methods | `$user->title` |
| Application.pm | Hashref (`$USER`) | Hash | `$USER->{title}` |
| Delegation modules | Hashref parameter | Hash | `$USER->{title}` |

```perl
# Blessed → Hashref: $user->NODEDATA
# Hashref → Blessed: $APP->node_by_id($USER->{node_id})
```

### JSON-Serializable Node Data

**CRITICAL**: When returning node data in JSON responses (APIs, Page buildReactData), the `type` field MUST be extracted as a string:

```perl
# ❌ WRONG - Will cause JSON nesting depth error
my $node = $DB->getNodeById($id);
return { type => $node->{type} };  # type is a hashref!

# ✅ CORRECT - Extract the string title
my $node = $DB->getNodeById($id);
return { type => $node->{type}{title} };  # Returns 'user', 'writeup', etc.
```

**Why**: Nodes loaded via `getNodeById()`/`getNode()` have `type` as a hashref like `{title => 'user', node_id => 123, ...}`. Including this directly in JSON responses causes "json text or perl structure exceeds maximum nesting level" errors due to circular references.

**Pattern**: Always extract scalar values from nested hashrefs before JSON serialization.

### API Response Format

**CRITICAL (mod_perl workaround)**: Always return `HTTP_OK` (200) for API responses, even for application errors. Apache/mod_perl appends HTML error pages to non-200 responses, corrupting JSON.

```perl
# ✅ CORRECT - Return 200 with success field for application errors
return [$self->HTTP_OK, {success => 1, data => 'value'}];           # Success
return [$self->HTTP_OK, {success => 0, error => 'User not found'}]; # App error

# ❌ WRONG - Apache appends HTML error page to JSON, corrupting response
return [$self->HTTP_BAD_REQUEST, {error => 'Bad input'}];   # Corrupted!
return [$self->HTTP_NOT_FOUND, {error => 'Not found'}];     # Corrupted!
```

**Why**: When returning non-200 HTTP status codes (4xx, 5xx), Apache appends its default HTML error page to the JSON response body, causing browser JSON parsing to fail with "Failed to fetch" or decoding errors. This will be fixed when migrating to FastCGI.

**Pattern**:
- Success: `{success => 1, ...data...}`
- Error: `{success => 0, error => "message"}`
- React checks `data.success` to determine result

### Everything::Page Pattern

```perl
package Everything::Page::my_page;
use Moose;
extends 'Everything::Page';

sub buildReactData {
  my ($self, $REQUEST) = @_;
  return { type => 'my_page' };  # NO contentData wrapper
}

__PACKAGE__->meta->make_immutable;
1;
```

### E2 Schema - Table Joins

`node_id`, `document_id`, `superdoc_id`, etc. ALL refer to the same base `node.node_id`. NodeBase joins automatically.

### Database Node IDs

Never hardcode - IDs vary between dev/prod:
```perl
my $node = $DB->getNode('Messages', 'nodelet');
my $id = $node->{node_id};
```

### Container Names

- Application: `e2devapp`
- Database: `e2devdb` (mysql -u root -pblah everything)

---

## 🎯 Architectural Goals

### Eliminate Everything::Delegation Modules

**GOAL**: Remove all `Everything::Delegation::*` modules from the codebase entirely.

**Rules**:
- **NEVER** call delegation functions from controllers (Everything::Page, Everything::API)
- **ESPECIALLY FORBIDDEN** for document delegation functions (`Everything::Delegation::document::*`)
- Controllers must implement logic directly in `buildReactData()` or extract to Application.pm methods
- **Temporary exception**: `Everything::Delegation::htmlcode::*` functions MAY be called during migration for backwards compatibility

**Rationale**:
- Delegation modules are legacy code patterns from the Mason1/Mason2 era
- They use hashrefs instead of blessed objects, creating type confusion
- They bypass proper access control and security checks
- They cannot be properly tested or type-checked
- React migration eliminates the need for these rendering helpers

**Migration Pattern**:
```perl
# ❌ BAD - Calling delegation from Page controller
sub buildReactData {
    my ($self, $REQUEST) = @_;
    my $html = Everything::Delegation::document::my_doc(
        $self->DB, $query, $NODE, $USER, $USERVARS, undef, $self->APP
    );
    return { html => $html };
}

# ✅ GOOD - Implement logic in Page class
sub buildReactData {
    my ($self, $REQUEST) = @_;
    my $data = $self->APP->getSomeData($REQUEST->user);
    return {
        type => 'my_doc',
        items => $data
    };
}

# ✅ ACCEPTABLE (temporary) - Extract to Application.pm
sub buildReactData {
    my ($self, $REQUEST) = @_;
    my $result = $self->APP->processMyDocument($REQUEST);
    return $result;
}
```

**Current State**: Several Page classes still call delegation functions temporarily. These must be refactored before the delegation modules can be fully removed.

---

## Development Operations

### Running Tests

```bash
./docker/devbuild.sh                # Full rebuild + tests
npm test                            # React tests
./tools/smoke-test.rb              # Fast smoke test (159+ docs)
```

**Serial tests** (modify shared state): Add to `%serial_tests` in [t/run.pl](t/run.pl)

### Database Access

```bash
docker exec -it e2devdb mysql -u root -pblah everything
docker exec e2devdb mysql -u root -pblah everything -e "SELECT node_id, title FROM node WHERE title='Messages'"
```

### Logs

```bash
docker exec e2devapp tail -f /var/log/apache2/error.log   # Perl errors
docker exec e2devapp tail -f /tmp/development.log         # devLog output
docker logs e2devapp                                       # Container startup
```

### Quick Health Checks

```bash
curl -s http://localhost:9080/ | head -20
docker ps | grep e2dev
docker exec e2devdb mysql -u root -pblah -e "SELECT 1"
```

---

## Debugging Workflows

### Finding Code Locations

1. **Grep for keywords**: `Grep pattern="buildReactData" path="ecore"`
2. **Page classes**: `ecore/Everything/Page/page_name.pm`
3. **API endpoints**: `ecore/Everything/API/endpoint.pm`
4. **Delegation**: `grep -n "sub func" ecore/Everything/Delegation/htmlcode.pm`

### Debugging React Components

1. Check `window.e2.contentData` in browser console
2. Verify type is in [DocumentComponent.js](react/components/DocumentComponent.js) COMPONENT_MAP
3. Check `buildReactData()` returns data WITHOUT contentData wrapper
4. Page name conversion: "Is it Christmas yet?" → `is_it_christmas_yet`

### Debugging Perl Issues

1. Check Apache error log: `docker exec e2devapp tail -100 /var/log/apache2/error.log`
2. Run Perl::Critic: `./tools/critic.pl ecore/Everything/Module.pm`
3. Add devLog statements, rebuild, check `/tmp/development.log`

### Common Errors

- "Can't locate Moose.pm" → Missing vendor path (`-I/var/libraries/lib/perl5`)
- "Not a HASH reference" → Blessed object vs hashref confusion
- Page not found → Check node exists, page name conversion, Page class file

---

## E2E Test Best Practices

```javascript
/**
 * Feature E2E Tests
 * CLEANUP STRATEGY: How test cleans up
 * TEST USERS: e2e_admin (gods, pw:test123), e2e_user (pw:test123)
 */
test('descriptive name', async ({ page }) => {
  // Use timestamps: 'test message ' + Date.now()
  // Clear before: /clearchatter
  // Restore resources: spin costs 5 GP, sanctify grants 10 GP
})
```

---

## Recent Completed Work

### React Document Migrations (December 2025)
- **93 documents migrated** (36% complete): Ongoing conversion from E2 Legacy delegation to React Page classes
- Recent migrations: Permission Denied, Super Mailbox, Available Rooms, Random Nodeshells, Database Lag-o-meter, Nothing Found, Duplicates Found, Findings

### E2 Editor Beta (November 2025)
- Tiptap-based editor with draft management, version history, autosave
- Client-side HTML sanitization using DOMPurify (`react/components/Editor/E2HtmlSanitizer.js`)
- PUT/PATCH/DELETE request body fix in `Request.pm` (reads STDIN before CGI.pm consumes it)

### User Blocking & Interactions (December 2025)
- **Pit of Abomination modernization**: Unified user blocking interface (writeup hiding + message blocking)
- **User Interactions API**: RESTful API for managing blocked users (`/api/userinteractions`)

### XML/Ticker Migrations (December 2025)
- All 21 XML tickers migrated to Page classes with proper Content-Type headers
- 2 ATOM feeds migrated with E2-specific link conversions

# AI Assistant Context for Everything2

Context for AI assistants working on the Everything2 codebase.

**Last Updated**: 2025-12-14
**Maintained By**: Jay Bonci

## ⚠️ CRITICAL: Common Pitfalls ⚠️

### 🚫 DO NOT USE CURL FOR HTML TESTING

**CRITICAL**: curl cannot render React components - it only shows server-generated HTML. Since E2 renders pages client-side with React, curl will NOT show the actual UI that users see.

**Always use `browser-debug.js` for testing**:
```bash
# HTML/Page testing (renders React components)
node tools/browser-debug.js html guest 'http://localhost:9080/node/good%20poetry'
node tools/browser-debug.js html e2e_admin 'http://localhost:9080/title/Superbless'
node tools/browser-debug.js fetch e2e_user 'http://localhost:9080/title/Settings'

# API testing (POST/PUT/DELETE JSON endpoints)
node tools/browser-debug.js post e2e_admin 'http://localhost:9080/api/drafts' '{"title":"Test"}'
node tools/browser-debug.js put e2e_admin 'http://localhost:9080/api/drafts/123' '{"title":"Updated"}'
node tools/browser-debug.js delete e2e_admin 'http://localhost:9080/api/userinteractions/123/action/delete'

# Screenshots
node tools/browser-debug.js screenshot 'http://localhost:9080'
node tools/browser-debug.js screenshot-as e2e_admin 'http://localhost:9080/title/Settings'

# Other commands
node tools/browser-debug.js eval guest 'http://localhost:9080' 'return window.e2'
node tools/browser-debug.js a11y guest 'http://localhost:9080/title/tomato'
node tools/browser-debug.js readability guest 'http://localhost:9080/node/2212929'
```

**curl is ONLY acceptable for**:
- Liveness checks (is Apache responding?)
- Direct API endpoint testing when browser context is not needed

**Test users**: root (gods, pw:blah), genericdev (edev, pw:blah), e2e_admin (gods, pw:test123), e2e_user (pw:test123)

### 🚫 NEVER CREATE GIT COMMITS

User handles all commits.

### 🔄 Container Rebuild Workflow

**⚠️ CRITICAL**: The development container does NOT have files volume-mounted. Local file changes are NOT automatically reflected in the container. You MUST rebuild the container to see your changes:

```bash
./docker/devbuild.sh --skip-tests  # Quick rebuild (use this most of the time)
./docker/devbuild.sh               # Full rebuild with tests
```

**NEVER use docker cp or apache2ctl graceful** - leads to stale state. Always use `devbuild.sh`.

### JSON UTF-8 Encoding

```perl
use Encode qw(decode_utf8);
$postdata = decode_utf8($self->POSTDATA);  # BEFORE JSON parsing
```

### Blessed Objects vs Hashrefs

| Context | Form | Access |
|---------|------|--------|
| Controller/Page/API | Blessed (`$REQUEST->user`) | Methods: `$user->title` |
| Application.pm | Hashref (`$USER`) | Hash: `$USER->{title}` |

```perl
# Blessed → Hashref: $user->NODEDATA
# Hashref → Blessed: $APP->node_by_id($USER->{node_id})
```

### JSON-Serializable Node Data

```perl
# ❌ WRONG - type is a hashref with circular refs
return { type => $node->{type} };

# ✅ CORRECT - Extract the string
return { type => $node->{type}{title} };
```

### API Response Format

Always return HTTP 200 for API responses (mod_perl appends HTML to non-200):
```perl
return [$self->HTTP_OK, {success => 1, data => 'value'}];           # Success
return [$self->HTTP_OK, {success => 0, error => 'User not found'}]; # Error
```

### 🎨 Kernel Blue Styling

Use the E2 "Kernel Blue" color palette for all React component styling:

| Color | Hex | Usage |
|-------|-----|-------|
| Kernel Blue | `#38495e` | Primary text, headers, borders |
| Link Blue | `#4060b0` | Links, buttons, usergroup indicators |
| Muted Blue | `#507898` | Secondary text, icons, hints |
| Light Background | `#e8f4f8` | Hover states, selected items |
| Cool Teal | `#3bb5c3` | C! indicators, special highlights |

---

## Development Quick Reference

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

### Running Tests

```bash
./docker/devbuild.sh                # Full rebuild + tests
docker exec e2devapp bash -c "cd /var/everything && prove -I/var/libraries/lib/perl5 t/test.t"
npm test                            # React tests
./tools/smoke-test.rb              # Fast smoke test
```

### Database Access

```bash
docker exec -it e2devdb mysql -u root -pblah everything
```

### Logs

**⚠️ IMPORTANT**: Apache error.log and access.log are always EMPTY in development. All useful logging goes to `/tmp/development.log`:

```bash
docker exec e2devapp tail -f /tmp/development.log         # ALL logs go here
# docker exec e2devapp tail -f /var/log/apache2/error.log # ALWAYS EMPTY - don't use
```

### Debugging with devLog

```perl
$APP->devLog("Debug: value is $value");
```

### Perl::Critic

```bash
./tools/critic.pl ecore/Everything/Application.pm        # Bugs only
CRITIC_FULL=1 ./tools/critic.pl ecore/Everything/Application.pm  # Full
```

### Container Names

- Application: `e2devapp`
- Database: `e2devdb`

---

## 🎯 Architectural Goals

### Eliminate Everything::Delegation Modules

**NEVER** call delegation functions from controllers (Everything::Page, Everything::API). Controllers must implement logic directly in `buildReactData()` or extract to Application.pm methods.

**Temporary exception**: `Everything::Delegation::htmlcode::*` MAY be called during migration.

---

## Recent Completed Work

### Infrastructure Modernization (December 2025)
- **HTTP-only internal traffic**: ALB→ECS switched from HTTPS to HTTP
- **Apache config consolidation**: Single `apache2.conf.erb`, removed SSL
- **IPv6 dual-stack**: Full IPv6 support across VPC, ALB, CloudFront
- **CloudFront/WAF integration**: Rate limiting, bot control, origin verification
- **API sessions fix (#3865)**: WAF exclusion for `/api/sessions`

### React Document Migrations (December 2025)
- **93+ documents migrated** to React Page classes

### E2 Editor Beta (November 2025)
- Tiptap-based editor with draft management, version history, autosave

See [docs/changelog-2025-12.md](docs/changelog-2025-12.md) for detailed changes.

# AI Assistant Context for Everything2

Context for AI assistants working on the Everything2 codebase.

**Last Updated**: 2025-12-14
**Maintained By**: Jay Bonci

## ⚠️ CRITICAL: Common Pitfalls ⚠️

### 🚫 DO NOT USE CURL FOR AUTHENTICATED REQUESTS

Use `browser-debug.js` for all authenticated page fetching:
```bash
node tools/browser-debug.js html e2e_admin 'http://localhost:9080/title/Superbless'
node tools/browser-debug.js fetch e2e_admin 'http://localhost:9080/title/Settings'
```

**Test users**: root (gods, pw:blah), genericdev (edev, pw:blah), e2e_admin (gods, pw:test123), e2e_user (pw:test123)

### 🚫 NEVER CREATE GIT COMMITS

User handles all commits.

### 🔄 Container Rebuild Workflow

```bash
./docker/devbuild.sh --skip-tests  # Quick rebuild
./docker/devbuild.sh               # Full rebuild with tests
```

**NEVER use docker cp or apache2ctl graceful** - leads to stale state.

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

```bash
docker exec e2devapp tail -f /var/log/apache2/error.log   # Perl errors
docker exec e2devapp tail -f /tmp/development.log         # devLog output
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

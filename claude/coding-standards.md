# Everything2 Coding Standards

**Date:** 2025-11-07
**Status:** Active Guidelines

## Purpose

This document defines coding standards for E2 modernization work. These standards ensure consistency, maintainability, and compliance with Perl Best Practices and perlcritic.

## Perl Coding Standards

### Hash Dereferencing

**Preferred:** Use arrow operator `->{}` for hash dereferencing

```perl
# ✅ GOOD - Arrow operator (Perl Best Practices)
my $value = $ref->{key};
my $nested = $object->{user}->{name};
my $node_id = $NODE->{node_id};
my $user_id = $USER->{user_id};
```

**Avoid:** Double-sigil dereferencing

```perl
# ❌ AVOID - Double-sigil (legacy style)
my $value = $$ref{key};
my $nested = $$object{user}{name};
my $node_id = $$NODE{node_id};
my $user_id = $$USER{user_id};
```

**Rationale:**
- Perl Best Practices recommendation (Damian Conway)
- Required by perlcritic
- More readable and consistent
- Clearer precedence rules
- Easier to parse visually

**References:**
- Perl Best Practices, Chapter 6: References
- perlcritic policy: `ProhibitDoubleDesigilation`

### SQL Security

**Required:** Use prepared statements with placeholders for all SQL queries

```perl
# ✅ GOOD - Prepared statement with placeholders
my $sth = $dbh->prepare('SELECT * FROM user WHERE user_id=?');
$sth->execute($user_id);

# ✅ GOOD - Using quote() for values
my $result = $DB->sqlSelect('*', 'user',
    'user_id=' . $DB->quote($user_id));

# ❌ BAD - Direct interpolation
my $sth = $dbh->do("SELECT * FROM user WHERE user_id=$user_id");
```

**Integer Validation:**

```perl
# ✅ GOOD - Validate integers before use
foreach my $id (@node_ids) {
    die "Invalid node ID: $id" unless $id =~ /^\d+$/;
}

# ✅ GOOD - Use int() for user input
my $id = int($query->param('node_id'));
```

### Moose Usage

**Required:** Use Moose for all new object-oriented code

```perl
# ✅ GOOD - Moose class
package Everything::MyModule;
use Moose;

has 'attribute' => (is => 'ro', isa => 'Str', required => 1);

sub my_method {
    my ($self) = @_;
    return $self->attribute;
}

__PACKAGE__->meta->make_immutable;
1;
```

**Avoid:** Old-style blessed references for new code

```perl
# ❌ AVOID for new code - Old-style OOP
package Everything::MyModule;

sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}
```

### Modern Perl Features

**Preferred:** Use modern Perl features

```perl
# ✅ GOOD - use strict and warnings
use strict;
use warnings;

# ✅ GOOD - Lexical variables (my)
my $variable = 'value';
my @array = (1, 2, 3);
my %hash = (key => 'value');

# ✅ GOOD - Three-argument open
open my $fh, '<', $filename or die "Cannot open $filename: $!";

# ❌ AVOID - Two-argument open
open FH, $filename or die;
```

### String Quoting

**Preferred:** Use single quotes for strings, double quotes when interpolation needed

```perl
# ✅ GOOD - Single quotes for literals
my $string = 'Hello World';
my $sql = 'SELECT * FROM user WHERE user_id=?';

# ✅ GOOD - Double quotes for interpolation
my $message = "User: $username";
my $query = "SELECT * FROM $table WHERE id=$id";

# ✅ GOOD - qq{} for SQL with quotes
my $sql = qq{INSERT INTO user (name, email) VALUES ('$name', '$email')};
```

### Error Handling

**Required:** Always check return values

```perl
# ✅ GOOD - Check database operations
my $sth = $dbh->prepare($sql) or die "Prepare failed: " . $dbh->errstr;
$sth->execute(@params) or die "Execute failed: " . $sth->errstr;

# ✅ GOOD - eval for exception handling
eval {
    $self->risky_operation();
};
if ($@) {
    warn "Operation failed: $@";
    return;
}

# ❌ AVOID - Ignoring return values
$dbh->prepare($sql);
$sth->execute(@params);
```

### Comments

**Required:** Document non-obvious code

```perl
# ✅ GOOD - Clear comments explaining why
# Fixed SQL injection: validate node IDs as integers before query
foreach my $id (@node_ids) {
    die "Invalid node ID: $id" unless $id =~ /^\d+$/;
}

# ✅ GOOD - Security-related changes must be commented
# Fixed SQL injection: use prepared statement with placeholders
my $sth = $dbh->prepare('UPDATE table SET col=? WHERE id=?');

# ❌ AVOID - Obvious comments
my $count = 0;  # Initialize count to zero
```

## JavaScript Coding Standards

### Modern JavaScript

**Required:** Use ES6+ features for all new JavaScript

```javascript
// ✅ GOOD - const/let instead of var
const element = document.querySelector('#id');
let counter = 0;

// ✅ GOOD - Arrow functions
const handleClick = (event) => {
    console.log('Clicked:', event.target);
};

// ✅ GOOD - Template literals
const message = `User ${username} logged in at ${timestamp}`;

// ✅ GOOD - Destructuring
const { name, email } = user;
const [first, second] = array;

// ❌ AVOID - var (function scoped)
var element = document.getElementById('id');
```

### DOM Manipulation

**Preferred:** Use vanilla JS, not jQuery for new code

```javascript
// ✅ GOOD - Vanilla JS (modern browsers)
const element = document.querySelector('#id');
element.addEventListener('click', handleClick);
element.classList.add('active');

// ⚠️ LEGACY - jQuery (only for existing code)
const element = $('#id');
element.on('click', handleClick);
element.addClass('active');
```

### React Components

**Required:** Use functional components with hooks

```javascript
// ✅ GOOD - Functional component with hooks
import { useState, useEffect } from 'react';

const MyComponent = ({ prop1, prop2 }) => {
    const [state, setState] = useState(initialValue);

    useEffect(() => {
        // Effect logic
    }, [dependencies]);

    return <div>{state}</div>;
};

// ❌ AVOID for new code - Class components
class MyComponent extends React.Component {
    constructor(props) {
        super(props);
        this.state = { value: 0 };
    }
    render() {
        return <div>{this.state.value}</div>;
    }
}
```

### Asset Pipeline

**Required:** All JavaScript must go through asset pipeline

```perl
# ✅ GOOD - Use asset pipeline
my $js = '<script src="' . $APP->asset_uri('my-script.js') . '"></script>';

# ❌ AVOID - Inline JavaScript
my $js = '<script>function foo() { ... }</script>';
```

## Testing Standards

### Test Structure

**Required:** All tests must use Test::More

```perl
#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More;

# Test code here

done_testing();
```

### Test Coverage

**Required:** New code must have tests

- **Critical code:** 80%+ coverage
- **New features:** 70%+ coverage
- **Bug fixes:** Test for regression

### Test Naming

```perl
# ✅ GOOD - Descriptive test names
ok($result, "Function returns expected value");
is($count, 5, "Count is correct after operation");
like($error, qr/Invalid/, "Error message indicates invalid input");

# ❌ AVOID - Generic test names
ok($result, "test 1");
is($count, 5);
```

## Git Commit Standards

### Commit Messages

**Format:**
```
Short summary (50 chars or less)

Longer description if needed, explaining:
- What changed
- Why it changed
- Any breaking changes or side effects

References: #issue-number
```

**Examples:**

```
Fix SQL injection in opcode removeweblog

Replaced direct interpolation with prepared statement using
placeholders. Added integer validation for node IDs.

Security: Fixes CVE-YYYY-XXXX
References: #1234
```

```
Add tests for SQL injection fixes

Created comprehensive test suite with 20 tests covering:
- IP blacklist validation
- Node ID validation
- SQL injection attempt rejection
- Edge cases and malicious input

References: #1234
```

### Commit Atomicity

**Preferred:** One logical change per commit

```
✅ GOOD:
- Commit 1: Fix SQL injection in links.pm
- Commit 2: Fix SQL injection in nodegroup.pm
- Commit 3: Add tests for SQL fixes

❌ AVOID:
- Commit 1: Fix all SQL injection and add tests and update docs
```

## Code Review Standards

### Before Submitting

**Checklist:**
- [ ] Run perlcritic: `CRITIC_FULL=1 ./tools/critic.pl .`
- [ ] Run tests: `prove -lv t/*.t`
- [ ] Test locally: http://localhost:9080
- [ ] Check for security issues
- [ ] Add/update documentation
- [ ] Clear commit message

### Review Focus

**Reviewers should check:**
1. Security (SQL injection, XSS, etc.)
2. Performance (unnecessary queries, N+1 problems)
3. Style (follows standards)
4. Tests (adequate coverage)
5. Documentation (code comments, docs updated)

## Documentation Standards

### Code Comments

```perl
# ✅ GOOD - Explain why, not what
# Use prepared statement to prevent SQL injection
my $sth = $dbh->prepare('SELECT * FROM user WHERE id=?');

# Fixed: Previous code concatenated user input directly
# which allowed SQL injection attacks via malicious node IDs

# ❌ AVOID - Stating the obvious
# Prepare SQL statement
my $sth = $dbh->prepare('SELECT * FROM user WHERE id=?');
```

### POD Documentation

```perl
=head1 NAME

Everything::MyModule - Brief description

=head1 SYNOPSIS

    use Everything::MyModule;
    my $obj = Everything::MyModule->new();
    $obj->method();

=head1 DESCRIPTION

Longer description of what this module does.

=head1 METHODS

=head2 method_name

Description of what this method does.

=cut
```

## Security Standards

### Input Validation

**Required:** Validate all user input

```perl
# ✅ GOOD - Validate before use
die "Invalid node ID" unless $id =~ /^\d+$/;
die "Invalid email" unless $email =~ /^[\w\.-]+@[\w\.-]+\.\w+$/;

# ✅ GOOD - Whitelist, not blacklist
my %VALID_TYPES = map { $_ => 1 } qw(user writeup document);
die "Invalid type" unless $VALID_TYPES{$type};
```

### Secrets Management

**Required:** Never commit secrets

```perl
# ✅ GOOD - Use configuration
my $api_key = $CONFIG->{api_key};

# ✅ GOOD - Use environment variables
my $secret = $ENV{SECRET_KEY};

# ❌ NEVER - Hardcoded secrets
my $api_key = 'sk_live_abc123...';
```

## perlcritic Compliance

### Running perlcritic

```bash
# Full check (severity 1-5)
CRITIC_FULL=1 ./tools/critic.pl .

# Check specific file
perlcritic --severity 3 ecore/Everything/MyModule.pm
```

### Exceptions

When violations are necessary, use `## no critic`:

```perl
# Disable specific policy
## no critic (ProhibitStringyEval)
my $result = eval $code;
## use critic
```

**Document why:**
```perl
# String eval required for template engine
# TODO: Replace with safer alternative
## no critic (ProhibitStringyEval)
my $result = eval $code;
## use critic
```

## Migration from Legacy Code

### Gradual Improvement

When modifying legacy code:

1. **Fix what you touch** - Update to standards
2. **Don't break working code** - If it's not broken, be careful
3. **Add tests** - Cover the code you're changing
4. **Document changes** - Explain what and why

### Example Migration

```perl
# Legacy code (before):
my $id = $$NODE{node_id};
my $sth = $dbh->do("SELECT * FROM user WHERE id=$id");

# Modernized (after):
my $id = $NODE->{node_id};  # Fixed: Use arrow operator
# Fixed SQL injection: use prepared statement
my $sth = $dbh->prepare('SELECT * FROM user WHERE id=?');
$sth->execute($id);
```

## Questions?

For clarification on any standard, see:
- [Quick Reference](quick-reference.md) - Common patterns
- [Modernization Priorities](modernization-priorities.md) - Strategic direction
- Perl Best Practices (book) - Detailed Perl standards
- perlcritic documentation - Policy explanations

---

**Document Status:** Active
**Last Updated:** 2025-11-07
**Enforcement:** Required for all new code, encouraged for modified code

# XML Ticker Migration to Controller Ecosystem

**Date**: 2025-12-04
**Goal**: Move XML tickers from Everything::Delegation::document to modern Page classes with proper MIME type support

## Background

Currently, XML tickers live in `Everything::Delegation::document.pm` and are dispatched via the legacy ticker nodetype system. This creates several problems:

1. **No MIME type control** - Can't set `Content-Type: application/xml` properly
2. **Mixed with delegation code** - Not part of modern controller architecture
3. **No clean routing** - Relies on title-to-function-name conversion
4. **Hard to test** - Embedded in delegation system

## Current Architecture

### Ticker Dispatch Flow:
```
/node/ticker/Client%20Version%20XML%20Ticker
  ↓
HTML.pm::displayPage() - finds ticker nodetype
  ↓
htmlpage.pm::ticker_display_page() - converts title to function name
  ↓
document.pm::client_version_xml_ticker() - generates XML
  ↓
Returns raw XML string (no Content-Type header control!)
```

### Problems:
- No `<?xml version="1.0"?>` declaration control
- MIME type defaults to `text/html`
- Can't set custom headers
- Not RESTful

## Target Architecture

### Modern Page Class Pattern:
```perl
package Everything::Page::client_version_xml_ticker;
use Moose;
use XML::Generator;
extends 'Everything::Page';

sub handle {
    my ($self, $REQUEST) = @_;

    my $xml = $self->generate_xml($REQUEST);

    return [
        $self->HTTP_OK,
        $xml,
        {type => 'application/xml'}  # ← MIME type support!
    ];
}

sub generate_xml {
    my ($self, $REQUEST) = @_;
    my $DB = $REQUEST->db;

    my $XG = XML::Generator->new();
    # ... generate XML using XML::Generator

    # Add XML declaration manually
    return qq{<?xml version="1.0"?>\n} . $XG->root(...);
}

__PACKAGE__->meta->make_immutable;
1;
```

### Benefits:
- ✅ Full control over MIME type
- ✅ Clean RESTful routing
- ✅ Standard Page class pattern
- ✅ Easy to test
- ✅ Proper HTTP status codes
- ✅ Modern Moose-based OOP

## Required Changes

### 1. Add MIME Type Support to Page Classes ✅ ALREADY SUPPORTED

**Investigation Complete**: MIME type support already exists!

**How it works:**
1. `Everything::Page` base class has a `mimetype` attribute (defaults to `text/html`):
   ```perl
   has 'mimetype' => (is => 'ro', default => 'text/html');
   ```

2. `Everything::Router::output()` method respects the `type` key in response headers:
   ```perl
   $headers->{type} ||= "text/html";
   ```

**Two patterns for setting MIME type:**

**Pattern A: Override mimetype attribute (preferred for Page classes)**
```perl
package Everything::Page::my_xml_ticker;
use Moose;
extends 'Everything::Page';

has 'mimetype' => (default => 'application/xml', is => 'ro');

sub display {
    my ($self, $REQUEST, $node) = @_;
    my $xml = $self->generate_xml($REQUEST);
    return [$self->HTTP_OK, $xml, {type => $self->mimetype}];
}
```

**Pattern B: Inline type in response (flexible for mixed types)**
```perl
sub display {
    my ($self, $REQUEST, $node) = @_;
    my $xml = $self->generate_xml($REQUEST);
    return [$self->HTTP_OK, $xml, {type => 'application/xml'}];
}
```

**Existing example:** `ecore/Everything/Page/other_users_xml_ticker.pm` already uses this pattern (but needs XML declaration fix!)

### 2. Create Page Classes for Each Ticker

**22 tickers need migration:**
- 17 XML tickers
- 3 Atom feeds
- 2 RSS feeds

**Example structure:**
```
ecore/Everything/Page/
  client_version_xml_ticker.pm
  available_rooms_xml_ticker.pm
  cool_nodes_xml_ticker_ii.pm
  ...
```

### 3. Update Routing

**Current**: `/node/ticker/Client%20Version%20XML%20Ticker`
**Target**: Keep same URLs, route to Page classes instead of delegation

**Options:**
1. Keep ticker nodetype, update dispatcher to check for Page classes first
2. Add explicit routes in HTMLRouter for `/node/ticker/*`
3. Create a unified `/api/tickers/*` endpoint structure (breaking change)

**Recommendation**: Option 1 - backward compatible, gradual migration

### 4. XML Declaration Helper

All XML tickers need the `<?xml version="1.0"?>` declaration.

**Create helper in Everything::Page or new module:**
```perl
package Everything::XMLTicker;
use Moose::Role;
use XML::Generator;

has 'xml_generator' => (
    is => 'ro',
    lazy => 1,
    default => sub { XML::Generator->new() }
);

sub xml_header {
    my ($self, $encoding) = @_;
    $encoding ||= '1.0';
    return qq{<?xml version="$encoding"?>\n};
}

# Usage in Page class:
# with 'Everything::XMLTicker';
# return $self->xml_header() . $self->xml_generator->root(...);
```

### 5. MIME Type Constants

Define standard MIME types:
```perl
# In Everything::Page or constants module
use constant {
    MIME_XML => 'application/xml',
    MIME_ATOM => 'application/atom+xml',
    MIME_RSS => 'application/rss+xml',
    MIME_JSON => 'application/json',
    MIME_HTML => 'text/html',
};
```

## Migration Plan

### Phase 1: Add MIME Type Support ✅ COMPLETE
- [x] Investigate current Page class metadata handling
- [x] Verify `type` key support in response metadata (Router.pm:38)
- [x] Found existing example: other_users_xml_ticker.pm
- [x] Document the pattern (two patterns available: attribute override or inline)

### Phase 2: Create XML Ticker Base Class ✅ COMPLETE
- [x] Created `Everything::XMLTicker` role with:
  - `xml_generator` attribute (lazy-built XML::Generator instance)
  - `xml_header()` helper method
  - `display()` method that calls `generate_xml()` and returns proper response
  - Requires implementing classes to provide `generate_xml()` method
- [x] Role-based design allows flexibility (can't override attributes in roles)
- [x] Documented in [ecore/Everything/XMLTicker.pm](../ecore/Everything/XMLTicker.pm)

### Phase 3: Migrate One Ticker as Proof of Concept ✅ COMPLETE
- [x] Created `Everything::Controller::ticker` - Routes ticker nodes to Page classes
  - Checks if Page class exists via `fully_supports()`
  - Falls back to delegation if no Page class found
  - Backward compatible with existing delegation system
- [x] Created `Everything::Page::xml_interfaces_ticker` - First ticker Page controller
  - Uses `Everything::XMLTicker` role
  - Implements `generate_xml()` method
  - Sets MIME type to `application/xml`
  - Returns proper XML with declaration
- [x] Tested and verified:
  - ✅ Content-Type: application/xml; charset=utf-8
  - ✅ XML declaration present
  - ✅ All XML export interfaces listed correctly
  - ✅ Backward compatible - delegation still works for other tickers

### Phase 4: Migrate Remaining Tickers ✅ IN PROGRESS (12 completed, 5 remaining)

**Migrated to Page controllers (2025-12-04):**

**Batch 1:**
- [x] xml_interfaces_ticker ✅ - First proof of concept
- [x] available_rooms_xml_ticker ✅ - Lists all chat rooms
- [x] client_version_xml_ticker ✅ - Lists registered E2 clients
- [x] user_search_xml_ticker_ii ✅ - User writeup search with metadata

**Batch 2:**
- [x] random_nodes_xml_ticker ✅ - Random nodes with witty phrases
- [x] raw_vars_xml_ticker ✅ - User exportable vars
- [x] my_votes_xml_ticker ✅ - User vote history
- [x] personal_session_xml_ticker ✅ - Complete session state

**Batch 3:**
- [x] cool_nodes_xml_ticker_ii ✅ - Cool writeups with filtering/sorting
- [x] editor_cools_xml_ticker ✅ - Editor-selected cools from nodegroup
- [x] new_writeups_xml_ticker ✅ - Recent writeups with infravision filtering
- [x] node_heaven_xml_ticker ✅ - User's deleted writeups

**Ready to migrate (5 remaining XML::Generator tickers):**
- everything_s_best_users_xml_ticker
- maintenance_nodes_xml_ticker
- other_users_xml_ticker_ii (already has Page class but not using role)
- time_since_xml_ticker
- user_information_xml

**Atom/RSS feeds** (need XML::Generator migration first):
- cool_archive_atom_feed
- new_writeups_atom_feed
- podcast_rss_feed

**Complex ticker** (uses XML::Simple):
- universal_message_xml_ticker

**All migrated tickers verified:**
- ✅ Content-Type: application/xml; charset=utf-8
- ✅ XML declarations present
- ✅ Passing smoke tests
- ✅ Backward compatible with delegation system

### Phase 5: Remove Legacy Delegation Code
- [ ] Remove ticker functions from `document.pm` (after all migrated)
- [ ] Clean up `Everything::XML` module usage
- [ ] Update documentation

## Testing Strategy

For each migrated ticker:

1. **Unit test the Page class**
2. **Smoke test output**:
   ```bash
   curl -I 'http://localhost:9080/node/ticker/Client%20Version%20XML%20Ticker'
   # Verify: Content-Type: application/xml

   curl -s 'http://localhost:9080/node/ticker/Client%20Version%20XML%20Ticker'
   # Verify: <?xml version="1.0"?> present
   # Verify: Root element present
   # Verify: Field ordering preserved
   ```
3. **Compare legacy vs new output** (exact match required for backward compat)

## Example: Complete Ticker Migration

### Before (Everything::Delegation::document):
```perl
sub client_version_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;
    my $XG = XML::Generator->new();
    # ... generate XML
    return $XG->clientregistry($clients);  # No XML declaration!
}
```

### After (Everything::Page):
```perl
package Everything::Page::client_version_xml_ticker;
use Moose;
use XML::Generator;
extends 'Everything::Page';

sub handle {
    my ($self, $REQUEST) = @_;

    my $xml = $self->generate_xml($REQUEST);

    return [
        $self->HTTP_OK,
        $xml,
        {type => 'application/xml'}
    ];
}

sub generate_xml {
    my ($self, $REQUEST) = @_;
    my $DB = $REQUEST->db;
    my $XG = XML::Generator->new();

    my $csr = $DB->sqlSelectMany("node_id", "node",
        "type_nodetype=" . $DB->getId($DB->getType('e2client')));

    my $clients = '';
    while (my $r = $csr->fetchrow_hashref()) {
        my $cl = $DB->getNodeById($r);
        my $u = $DB->getNodeById($cl->{author_user});

        $clients .= $XG->client(
            {client_id => $cl->{node_id}, client_class => $cl->{clientstr}},
            $XG->version($cl->{version}) .
            $XG->homepage($cl->{homeurl}) .
            $XG->download($cl->{dlurl}) .
            $XG->maintainer({node_id => $u->{node_id}}, $u->{title})
        );
    }

    # Add XML declaration
    return qq{<?xml version="1.0"?>\n} . $XG->clientregistry($clients);
}

__PACKAGE__->meta->make_immutable;
1;
```

## Benefits of Controller Migration

1. **Clean Architecture**: Tickers as first-class Page classes
2. **Proper MIME Types**: Set `Content-Type` correctly for XML/Atom/RSS
3. **RESTful**: Standard HTTP response handling
4. **Testable**: Unit test Page classes independently
5. **Maintainable**: Modern Moose-based OOP
6. **Flexible**: Easy to add caching, rate limiting, auth checks
7. **Debuggable**: Standard error handling and logging

## Architecture Overview

### Ticker Routing Flow (New)
```
/node/ticker/XML%20Interfaces%20Ticker
  ↓
HTMLRouter::can_route() - Checks if Controller exists for "ticker" nodetype
  ↓
Everything::Controller::ticker::fully_supports() - Checks if Page class exists
  ↓
Everything::Controller::ticker::display() - Loads and instantiates Page class
  ↓
Everything::Page::xml_interfaces_ticker::display() (from XMLTicker role)
  ↓
Everything::Page::xml_interfaces_ticker::generate_xml() - Generates XML content
  ↓
Returns [HTTP_OK, $xml, {type => 'application/xml'}]
```

### Fallback for Legacy Tickers
If no Page class exists, `Everything::Controller::ticker::fully_supports()` returns false, and the request falls back to the legacy delegation system via `htmlpage.pm::ticker_display_page()`.

## Next Steps

1. ✅ **Investigate MIME type support** in current Page class system
2. ✅ **Create XMLTicker base class/role**
3. ✅ **Migrate one ticker as proof of concept**
4. ✅ **Document the pattern**
5. **Migrate remaining 16 tickers progressively**
6. **Remove legacy delegation code** (after all migrated)

## References

- XML ticker standardization: [docs/xml-ticker-standardization.md](xml-ticker-standardization.md)
- Existing Page class example: `ecore/Everything/Page/other_users_xml_ticker.pm`
- Page base class: `ecore/Everything/Page.pm`
- Router: `ecore/Everything/HTMLRouter.pm`

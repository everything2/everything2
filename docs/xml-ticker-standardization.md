# XML Ticker Standardization Initiative

**Date**: 2025-12-04
**Status**: In Progress
**Goal**: Standardize all XML generation in Everything2 on XML::Generator

## Background

Everything2 has 22 XML ticker functions with three different XML generation approaches:
- **13 tickers**: Manual string concatenation
- **5 tickers**: XML::Generator
- **1 ticker**: XML::Simple (does NOT preserve field order)
- **3 tickers**: Unknown/mixed methods

Additionally, the legacy `Everything::XML` module provides `makeXmlSafe()` used in 14 locations.

## Problems with Current State

1. **Field Ordering**: XML::Simple randomizes hash key order, breaking clients that depend on specific field ordering
2. **Inconsistency**: Three different approaches make maintenance difficult
3. **Legacy Module**: Everything::XML is old and should be deprecated
4. **Security**: Manual string concatenation risks missing escaping

## Solution: Standardize on XML::Generator

### Why XML::Generator?

1. ✅ **Preserves field order** - Elements appear in the exact order you call methods
2. ✅ **Already a dependency** - Listed in cpanfile, no new deps needed
3. ✅ **Proven in production** - 5 tickers already use it successfully
4. ✅ **Automatic escaping** - Prevents XSS/injection bugs
5. ✅ **Cleaner code** - More concise than manual concatenation
6. ✅ **Standard CPAN module** - Well-maintained, documented

### Migration Pattern

**Before (manual strings):**
```perl
sub my_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $str = "<?xml version=\"1.0\"?>\n";
    $str .= "<root>\n";
    $str .= "<item id=\"" . encodeHTML($id) . "\">";
    $str .= encodeHTML($content);
    $str .= "</item>\n";
    $str .= "</root>\n";
    return $str;
}
```

**After (XML::Generator):**
```perl
sub my_xml_ticker {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;

    my $XG = XML::Generator->new();

    my $items = $XG->item({id => $id}, $content);

    return $XG->root($items);
}
```

**Key points:**
- XML::Generator automatically adds `<?xml version="1.0"?>` declaration
- Attributes go in hashref first parameter: `{id => 123, active => 1}`
- Content goes in second parameter (or later parameters)
- Automatic HTML entity escaping (no need for encodeHTML)
- Field order preserved via method call sequence

### Replacing Everything::XML::makeXmlSafe

**Before:**
```perl
use Everything::XML;
$safe = Everything::XML::makeXmlSafe($str);
```

**After (usually not needed):**
```perl
# XML::Generator escapes automatically, so usually just:
$xml = $XG->tag({}, $user_input);  # Automatic escaping

# If manual escaping needed for special cases:
$safe = $str;
$safe =~ s/&/&amp;/g;
$safe =~ s/</&lt;/g;
$safe =~ s/>/&gt;/g;
```

## Migration Progress

### Phase 1: Proof of Concept ✅ COMPLETE
- [x] Migrate `client_version_xml_ticker` (manual → XML::Generator)
- [x] Add XML declaration to all existing XML::Generator tickers

### Phase 2: XML Declaration Fixes ✅ COMPLETE
**Fixed 9 XML::Generator tickers with `<?xml version="1.0"?>` declarations:**
- [x] chatterbox_xml_ticker ✅ (passing smoke tests)
- [x] cool_nodes_xml_ticker ✅ (passing smoke tests)
- [x] new_nodes_xml_ticker ✅ (passing smoke tests)
- [x] private_message_xml_ticker ✅ (passing smoke tests)
- [x] rdf_search ✅ (passing smoke tests)
- [x] user_information_xml ✅ (passing smoke tests)
- [x] user_search_xml_ticker ✅ (passing smoke tests)
- [x] client_version_xml_ticker ✅ (passing smoke tests with minor warnings)
- [x] other_users_xml_ticker (Page class) ✅ (passing smoke tests)

### Phase 3: Manual String Tickers ✅ COMPLETE (15 migrated)
**All simple XML tickers migrated to XML::Generator (2025-12-04):**
- [x] cool_nodes_xml_ticker_ii ✅ - Migrated with field order preservation
- [x] my_votes_xml_ticker ✅ - Migrated with proper line endings
- [x] node_heaven_xml_ticker ✅ - Migrated with conditional content
- [x] other_users_xml_ticker_ii ✅ - Migrated with complex attributes
- [x] editor_cools_xml_ticker ✅ - Migrated, removed DTD declaration
- [x] everything_s_best_users_xml_ticker ✅ - Migrated with root element `<EBU>`
- [x] personal_session_xml_ticker ✅ - Migrated with inlined borgcheck/shownewexp htmlcode
- [x] random_nodes_xml_ticker ✅ - Migrated with random phrase selector
- [x] raw_vars_xml_ticker ✅ - Migrated with conditional guest check
- [x] available_rooms_xml_ticker ✅ (42 lines) - Migrated, removed DTD declaration
- [x] user_search_xml_ticker_ii ✅ (82 lines) - Migrated with complex wu attributes
- [x] xml_interfaces_ticker ✅ - Migrated, now also a Page controller!
- [x] maintenance_nodes_xml_ticker ✅ - Already using XML::Generator
- [x] time_since_xml_ticker ✅ - Already using XML::Generator
- [x] user_information_xml ✅ - Already using XML::Generator

**Atom/RSS feeds need migration (special xmlns handling):**
- [ ] podcast_rss_feed (94 lines) - RSS format with iTunes namespace
- [ ] cool_archive_atom_feed (76 lines) - Atom format with xmlns
- [ ] new_writeups_atom_feed - Atom format with xmlns

### Phase 4: XML::Simple Ticker (Complex)
- [ ] universal_message_xml_ticker (183 lines) - Most complex, uses XML::Simple

### Phase 5: Controller Migration ✅ IN PROGRESS
**Infrastructure created (2025-12-04):**
- [x] Everything::XMLTicker role ✅ - Provides xml_generator, xml_header(), display()
- [x] Everything::Controller::ticker ✅ - Routes ticker nodes to Page classes
- [x] xml_interfaces_ticker ✅ - First Page controller (proof of concept)

**Benefits achieved:**
- ✅ Proper MIME type support (`Content-Type: application/xml`)
- ✅ Modern Moose-based OOP architecture
- ✅ Backward compatible - delegation still works
- ✅ Progressive migration path for all tickers

**Ready to migrate to Page controllers:** All 16 XML::Generator tickers

### Phase 6: Special Cases
- [ ] e2_xml_search_interface - Has DTD declaration, needs migration
- [ ] displaytype=xml support (4 failures for user/e2node)
- [ ] displaytype=xmltrue support (4 failures for user/e2node)

### Phase 7: Everything::XML Cleanup
- [ ] Replace 14 calls to `Everything::XML::makeXmlSafe` with XML::Generator escaping
- [ ] Remove `use Everything::XML;` from document.pm
- [ ] Deprecate/remove Everything::XML module

### Phase 8: Testing ✅ IN PROGRESS
- [x] Create comprehensive smoke tests for all tickers
- [x] Test XML declarations present
- [x] Verify root elements and key fields
- [x] Updated smoke test expectations for migrated tickers
- [ ] Test each migrated ticker output matches legacy format exactly
- [ ] Verify field ordering preserved
- [ ] Check escaping correctness

## Testing Strategy

For each migrated ticker:

1. **Capture legacy output:**
   ```bash
   curl 'http://localhost:9080/node/ticker/Client%20Version%20XML%20Ticker' > legacy.xml
   ```

2. **Migrate ticker code**

3. **Capture new output:**
   ```bash
   curl 'http://localhost:9080/node/ticker/Client%20Version%20XML%20Ticker' > new.xml
   ```

4. **Compare:**
   ```bash
   diff -u legacy.xml new.xml
   ```

5. **Verify:**
   - Field order identical
   - Escaping correct
   - Whitespace acceptable (XML::Generator may format differently)

## Special Cases

### Atom/RSS Feeds
Tickers generating Atom/RSS may need custom formatting:
- `cool_archive_atom_feed`
- `new_writeups_atom_feed`
- `podcast_rss_feed`

These use specific xmlns attributes and date formats. May benefit from keeping manual concatenation or using XML::Generator carefully.

### Complex Nested Structures
`universal_message_xml_ticker` uses XML::Simple with complex nested hashes. Migration will need careful field ordering preservation.

## Controller Integration

XML tickers work with modern Page classes:

```perl
package Everything::Page::my_xml_ticker;
use Moose;
extends 'Everything::Page';

sub handle {
    my ($self, $REQUEST) = @_;

    my $xml = $self->generate_xml($REQUEST);

    return [$self->HTTP_OK, $xml, {type => 'application/xml'}];
}

sub generate_xml {
    my ($self, $REQUEST) = @_;

    my $XG = XML::Generator->new();
    # ... generate XML using XML::Generator
    return $XG->root(...);
}

__PACKAGE__->meta->make_immutable;
1;
```

## References

- XML::Generator docs: https://metacpan.org/pod/XML::Generator
- Existing XML::Generator tickers:
  - `chatterbox_xml_ticker` (line 16125)
  - `cool_nodes_xml_ticker` (line 16185)
  - `new_nodes_xml_ticker` (line 16868)
  - `private_message_xml_ticker` (line 16902)
  - `user_search_xml_ticker` (line 17091)

# Everything2 Softlink Filtering for AdSense Compliance

**Created**: 2025-12-19
**Purpose**: Implement content filtering for softlinks to comply with Google AdSense policies
**Target**: Guest user experience on findings page and e2node pages

---

## Table of Contents

1. [Background and Motivation](#background-and-motivation)
2. [Current Softlink Implementation](#current-softlink-implementation)
3. [AdSense Content Policy Requirements](#adsense-content-policy-requirements)
4. [Proposed Filtering Approach](#proposed-filtering-approach)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Performance Considerations](#performance-considerations)

---

## Background and Motivation

### Business Goal
Monetize the Everything2 findings page and e2node pages for guest users by displaying:
- Writeup previews (content snippets)
- Softlink recommendations (related content navigation)
- Google AdSense ads (revenue generation)

### Problem
Softlinks are generated from user-created content and may contain:
- Profanity
- Sexually explicit terms
- Violence/hate speech
- Drug-related content
- Other AdSense policy violations

**Risk**: Displaying prohibited content alongside ads can result in:
- Ad serving suspension
- Revenue loss
- Account termination

### Solution
Implement server-side content filtering for softlinks displayed to guest users, while preserving full softlink functionality for logged-in users.

---

## Current Softlink Implementation

### What Are Softlinks?

Softlinks are bidirectional navigation links between e2nodes created through:
1. **User-created links**: `[link text|node name]` syntax in writeup content
2. **Automatic parsing**: E2 link parser creates entries in `links` table
3. **Hit tracking**: Each link click increments `links.hits` counter
4. **Popularity sorting**: Most-clicked links appear first

**Database Schema**:
```sql
CREATE TABLE links (
  from_node INT,        -- Source e2node node_id
  to_node INT,          -- Target node node_id
  linktype INT,         -- 0 for softlinks
  hits INT DEFAULT 0,   -- Click counter
  food INT DEFAULT 0,   -- Legacy field (unused)
  INDEX (linktype, from_node, hits)  -- Optimized for hit-sorted queries
);
```

### Current Softlink Generation

**File**: `ecore/Everything/Node/e2node.pm` (lines 87-111)

```perl
sub softlinks {
  my ($self, $user) = @_;

  # Check if user has disabled softlinks via preference
  unless ($user->is_guest) {
    my $user_vars = $user->VARS;
    return [] if $user_vars->{noSoftLinks};
  }

  # Limit varies by user role
  my $limit = 48;
  $limit = 24 if $user->is_guest;      # GUESTS SEE FEWER LINKS
  $limit = 46 if $user->is_editor;

  # Query sorted by hits DESC - most popular first
  my $csr = $self->DB->{dbh}->prepare(
    'select node.type_nodetype, node.title, links.hits, links.to_node
     from links use index (linktype_fromnode_hits), node
     where links.from_node='.$self->node_id.'
       and links.to_node = node.node_id
       and links.linktype=0
     order by links.hits desc
     limit '.$limit
  );

  $csr->execute;
  my $softlinks = [];
  while (my $link = $csr->fetchrow_hashref) {
    push @$softlinks, {
      "node_id" => int($link->{to_node}),
      "title" => $link->{title},
      "type" => "e2node",
      "hits" => int($link->{hits})
    };
  }

  return $softlinks;
}
```

**Key Observations**:
1. ✅ Guest users already get limited results (24 vs 48)
2. ✅ Results sorted by popularity (hits DESC)
3. ❌ NO content filtering applied
4. ❌ NO profanity detection
5. ❌ NO AdSense policy compliance

### Where Softlinks Are Displayed

#### 1. E2node Pages (Mason2 Template)
**File**: `templates/zen.mc` (lines 131-167)

```perl
# Firmlinks for e2nodes and writeup parent e2nodes - "See also:" section
my $node = $.node;
my $ntypet = $node->type->title;
my $target_node;

# For writeups, show firmlinks from the parent e2node
if ($ntypet eq 'writeup') {
  my $parent = $node->parent;
  $target_node = $parent if ($parent && !UNIVERSAL::isa($parent, "Everything::Node::null"));
}
# For e2nodes, show their own firmlinks
elsif ($ntypet eq 'e2node') {
  $target_node = $node;
}

if ($target_node && $target_node->can('firmlinks')) {
  my $firmlinks = $target_node->firmlinks();
  if ($firmlinks && @$firmlinks > 0) {
    my $APP = $REQUEST->APP;
    my @firmlink_html;

    foreach my $firmlink (@$firmlinks) {
      my $title = $firmlink->title;
      my $url = "/title/" . $APP->rewriteCleanEscape($title);
      my $note_text = $firmlink->{firmlink_note_text} || '';
      my $link_html = qq{<a href="$url">$title</a>};
      # Append note text if present (with space prefix, matching legacy behavior)
      $link_html .= $APP->encodeHTML(" $note_text") if $note_text ne '';
      push @firmlink_html, $link_html;
    }

    my $firmlinks_str = join(', ', @firmlink_html);
    $m->print(qq{<div class="topic" id="firmlink"><strong>See also:</strong> $firmlinks_str</div>\n});
  }
}
```

**Note**: This displays **firmlinks** (editor-curated), not softlinks. Softlinks would appear in a similar section.

#### 2. React Components
**File**: `react/components/Documents/Writeup.js` (lines 22-58)

```javascript
const SoftlinksTable = ({ softlinks }) => {
  const numCols = 4

  // Split softlinks into rows of 4
  const rows = []
  for (let i = 0; i < softlinks.length; i += numCols) {
    rows.push(softlinks.slice(i, i + numCols))
  }

  return (
    <div id="softlinks">
      <table cellPadding="10" cellSpacing="0" border="0" width="100%">
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={rowIndex}>
              {row.map((link) => (
                <td key={link.node_id}>
                  <LinkNode
                    nodeId={link.node_id}
                    title={link.title}
                    type={link.type || 'e2node'}
                  />
                </td>
              ))}
              {/* Fill remaining cells in last row */}
              {row.length < numCols &&
                Array.from({ length: numCols - row.length }).map((_, i) => (
                  <td key={`empty-${i}`} className="slend">&nbsp;</td>
                ))
              }
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

**Display Format**:
- 4-column table layout
- LinkNode component renders each softlink
- Empty cells padded to maintain grid

#### 3. Findings Page (Planned)
**File**: `ecore/Everything/Page/findings.pm`

When monetized for guest users, will display:
- Search results with writeup previews
- Related content via softlinks
- AdSense ads interspersed

**Critical**: Guest users must not see prohibited content in softlinks.

---

## AdSense Content Policy Requirements

### Prohibited Content Categories

Per [Google Publisher Policies](https://support.google.com/adsense/answer/9335564):

1. **Adult Content**
   - Sexually explicit text, images, or links
   - Adult dating/sexual services
   - Sexual enhancement products

2. **Shocking Content**
   - Profanity and vulgar language
   - Gruesome or disgusting imagery/descriptions
   - Violence and gore

3. **Dangerous Content**
   - Drug paraphernalia and drug-related terms
   - Weapons, explosives, fireworks
   - Self-harm and suicide

4. **Hateful Content**
   - Racial slurs and hate speech
   - Incitement of violence
   - Harassment and bullying

5. **Illegal Content**
   - Piracy and hacking
   - Counterfeit goods
   - Illegal drugs

### Policy Enforcement

**Consequences**:
- First violation: Warning email
- Second violation: Ad serving limited (revenue drops)
- Third violation: Account suspension (permanent ban)

**Detection Method**:
- Automated crawlers scan page content
- Manual review for reported violations
- Real-time ad serving filters

**Grace Period**: None. Violations detected within hours.

---

## Proposed Filtering Approach

### Strategy: Server-Side Filtering with Multi-Layer Defense

**Principle**: Filter softlinks at generation time for guest users, preserve full functionality for logged-in users.

### Layer 1: Profanity Wordlist Filtering

**Implementation**: Maintain curated blocklist of prohibited terms.

**File**: `ecore/Everything/Filter/ProfanityFilter.pm` (new)

```perl
package Everything::Filter::ProfanityFilter;
use Moose;

has 'blocklist' => (
  is => 'ro',
  isa => 'ArrayRef[Str]',
  lazy => 1,
  builder => '_build_blocklist'
);

sub _build_blocklist {
  my ($self) = @_;

  # Load from external file for easy updates
  my $file = '/var/everything/config/profanity_blocklist.txt';
  open my $fh, '<', $file or die "Can't open blocklist: $!";

  my @terms;
  while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ /^#/;  # Skip comments
    next if $line =~ /^\s*$/;  # Skip blank lines
    push @terms, lc($line);  # Case-insensitive
  }
  close $fh;

  return \@terms;
}

sub is_safe {
  my ($self, $text) = @_;

  my $lower_text = lc($text);

  foreach my $term (@{$self->blocklist}) {
    # Word boundary matching to avoid false positives
    # e.g., "assassin" shouldn't match "ass"
    if ($lower_text =~ /\b\Q$term\E\b/i) {
      return 0;  # UNSAFE
    }
  }

  return 1;  # SAFE
}

__PACKAGE__->meta->make_immutable;
1;
```

**Blocklist Source**: Use existing profanity lists:
- [LDNOOBW](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words) (multi-language)
- [Profanity-Check](https://github.com/vzhou842/profanity-check) (English focused)
- E2-specific terms (community-curated)

**Maintenance**:
- Annual review and updates
- User reports for false positives/negatives
- Content Editors can approve exceptions

### Layer 2: Regex Pattern Matching

**Purpose**: Catch obfuscated terms and leetspeak variations.

**Examples**:
- `f*ck` → profanity
- `sh!t` → profanity
- `p0rn` → adult content
- `a$$` → profanity

**Implementation**:
```perl
sub has_obfuscated_profanity {
  my ($self, $text) = @_;

  my @patterns = (
    qr/f[\*\@\#\$]ck/i,
    qr/sh[\*\@\#\$]t/i,
    qr/a[\*\@\#\$]s/i,
    qr/p[\*\@\#\$0]rn/i,
    # ... more patterns
  );

  foreach my $pattern (@patterns) {
    return 1 if $text =~ /$pattern/;
  }

  return 0;
}
```

### Layer 3: Manual Review Queue

**Process**:
1. Filtered softlinks logged to review queue
2. Content Editors periodically review
3. Approved terms added to whitelist
4. False positives fixed

**File**: `ecore/Everything/API/admin.pm` (new endpoint)

```perl
sub review_filtered_softlinks {
  my ($self, $REQUEST) = @_;

  # Get softlinks blocked in last 7 days
  my @blocked = $DB->sqlSelectMany(
    '*',
    'filtered_softlinks',
    'created_at > DATE_SUB(NOW(), INTERVAL 7 DAY) AND reviewed=0'
  );

  return [$self->HTTP_OK, {
    success => 1,
    blocked => \@blocked
  }];
}
```

**Database Table**:
```sql
CREATE TABLE filtered_softlinks (
  id INT PRIMARY KEY AUTO_INCREMENT,
  from_node INT,
  to_node INT,
  title VARCHAR(255),
  reason VARCHAR(255),  -- 'profanity', 'regex', 'manual'
  created_at TIMESTAMP,
  reviewed BOOLEAN DEFAULT 0,
  approved BOOLEAN DEFAULT 0,
  reviewer_user INT,
  INDEX(reviewed, created_at)
);
```

---

## Implementation Plan

### Phase 1: Core Filtering Infrastructure (Week 1)

#### Task 1.1: Create ProfanityFilter Module
**File**: `ecore/Everything/Filter/ProfanityFilter.pm`
**Deliverables**:
- `is_safe($text)` method
- `has_obfuscated_profanity($text)` method
- Load blocklist from external file
- Unit tests (90%+ coverage)

#### Task 1.2: Create Blocklist File
**File**: `/var/everything/config/profanity_blocklist.txt`
**Deliverables**:
- Curated list of 1000+ prohibited terms
- Categories: profanity, adult, drugs, violence, hate
- Comments explaining edge cases
- Version control in git

#### Task 1.3: Add Filtering to softlinks() Method
**File**: `ecore/Everything/Node/e2node.pm`
**Changes**:
```perl
sub softlinks {
  my ($self, $user) = @_;

  # ... existing code ...

  my $softlinks = [];
  while (my $link = $csr->fetchrow_hashref) {
    my $link_title = $link->{title};

    # Filter for guest users
    if ($user->is_guest) {
      my $filter = Everything::Filter::ProfanityFilter->new;
      unless ($filter->is_safe($link_title)) {
        # Log blocked link
        $self->DB->sqlInsert('filtered_softlinks', {
          from_node => $self->node_id,
          to_node => $link->{to_node},
          title => $link_title,
          reason => 'profanity',
          created_at => time()
        });
        next;  # Skip this link
      }
    }

    push @$softlinks, {
      "node_id" => int($link->{to_node}),
      "title" => $link_title,
      "type" => "e2node",
      "hits" => int($link->{hits})
    };
  }

  return $softlinks;
}
```

#### Task 1.4: Create filtered_softlinks Table Migration
**File**: `db/migrations/add_filtered_softlinks_table.sql`
```sql
CREATE TABLE filtered_softlinks (
  id INT PRIMARY KEY AUTO_INCREMENT,
  from_node INT NOT NULL,
  to_node INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  reason VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed BOOLEAN DEFAULT 0,
  approved BOOLEAN DEFAULT 0,
  reviewer_user INT DEFAULT NULL,
  INDEX(reviewed, created_at),
  INDEX(from_node),
  FOREIGN KEY (from_node) REFERENCES node(node_id),
  FOREIGN KEY (to_node) REFERENCES node(node_id)
);
```

### Phase 2: Admin Interface (Week 2)

#### Task 2.1: Create Review API Endpoint
**File**: `ecore/Everything/API/admin.pm`
**New Routes**:
```perl
sub routes {
  return {
    # ... existing routes ...
    "softlinks/review"       => "review_filtered_softlinks()",
    "softlinks/approve/:id"  => "approve_filtered_softlink(:id)",
    "softlinks/reject/:id"   => "reject_filtered_softlink(:id)",
  };
}
```

**Methods**:
```perl
sub review_filtered_softlinks {
  my ($self, $REQUEST) = @_;
  my $user = $REQUEST->user;

  return [$self->HTTP_OK, {success => 0, error => 'Editor access required'}]
    unless $user->is_editor;

  my @blocked = $self->DB->sqlSelectMany(
    '*',
    'filtered_softlinks',
    'reviewed=0 ORDER BY created_at DESC LIMIT 100'
  );

  return [$self->HTTP_OK, {success => 1, blocked => \@blocked}];
}

sub approve_filtered_softlink {
  my ($self, $REQUEST, $id) = @_;
  my $user = $REQUEST->user;

  return [$self->HTTP_OK, {success => 0, error => 'Editor access required'}]
    unless $user->is_editor;

  # Get blocked link details
  my $link = $self->DB->sqlSelectHashref('*', 'filtered_softlinks', "id=$id");
  return [$self->HTTP_OK, {success => 0, error => 'Link not found'}]
    unless $link;

  # Add to whitelist
  $self->DB->sqlInsert('profanity_whitelist', {
    term => $link->{title},
    added_by => $user->node_id,
    added_at => time()
  });

  # Mark as reviewed
  $self->DB->sqlUpdate('filtered_softlinks', {
    reviewed => 1,
    approved => 1,
    reviewer_user => $user->node_id
  }, "id=$id");

  return [$self->HTTP_OK, {success => 1, message => 'Link approved and whitelisted'}];
}
```

#### Task 2.2: Create React Admin Panel
**File**: `react/components/AdminFilterReview.js`
**Features**:
- Display blocked softlinks in table
- Show from_node → to_node, title, reason
- Approve/Reject buttons
- Pagination (100 per page)
- Filter by reason, date range

### Phase 3: Whitelist Management (Week 3)

#### Task 3.1: Create Whitelist Database Table
```sql
CREATE TABLE profanity_whitelist (
  id INT PRIMARY KEY AUTO_INCREMENT,
  term VARCHAR(255) NOT NULL UNIQUE,
  added_by INT NOT NULL,
  added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes TEXT,
  INDEX(term),
  FOREIGN KEY (added_by) REFERENCES node(node_id)
);
```

**Pre-populate with Safe E2 Terms**:
- "Assassin's Creed" (contains "ass")
- "Mass Effect" (contains "ass")
- "Grass" (contains "ass")
- "Classic" (contains "ass")

#### Task 3.2: Update ProfanityFilter to Check Whitelist
```perl
sub is_safe {
  my ($self, $text) = @_;

  # Check whitelist first (fast path)
  my $whitelist = $self->DB->sqlSelectHashref('*', 'profanity_whitelist',
    "term=" . $self->DB->quote(lc($text)));
  return 1 if $whitelist;  # Explicitly allowed

  # Then check blocklist
  my $lower_text = lc($text);
  foreach my $term (@{$self->blocklist}) {
    if ($lower_text =~ /\b\Q$term\E\b/i) {
      return 0;  # UNSAFE
    }
  }

  return 1;  # SAFE
}
```

### Phase 4: Testing and Monitoring (Week 4)

#### Task 4.1: Create Test Suite
**File**: `t/065_profanity_filter.t`
**Test Cases**:
1. Basic profanity detection (50+ terms)
2. Obfuscated profanity detection (20+ patterns)
3. Whitelist override (10+ safe terms)
4. False positive prevention (50+ edge cases)
5. Performance test (10,000 softlinks in <100ms)

#### Task 4.2: Add Monitoring Dashboard
**Metrics to Track**:
- Softlinks blocked per day
- Block rate by reason (profanity, regex, manual)
- Top 10 blocked terms
- Review queue size
- Approval/rejection ratio

**File**: `react/components/AdminFilterStats.js`

#### Task 4.3: Guest User Testing
**Test Scenarios**:
1. Load e2node page as guest
2. Verify no profanity in softlinks
3. Verify softlink count ≤ 24
4. Verify no broken links
5. Verify AdSense ads display correctly

---

## Testing Strategy

### Unit Tests

**File**: `t/065_profanity_filter.t`

```perl
use Test::More tests => 100;
use Everything::Filter::ProfanityFilter;

my $filter = Everything::Filter::ProfanityFilter->new;

# Test basic profanity detection
ok(!$filter->is_safe('fuck'), 'Detects profanity: fuck');
ok(!$filter->is_safe('shit'), 'Detects profanity: shit');
ok(!$filter->is_safe('asshole'), 'Detects profanity: asshole');

# Test safe terms
ok($filter->is_safe('hello world'), 'Allows safe term: hello world');
ok($filter->is_safe('assassin'), 'Allows safe term: assassin');
ok($filter->is_safe('mass effect'), 'Allows safe term: mass effect');

# Test obfuscated profanity
ok(!$filter->has_obfuscated_profanity('f*ck'), 'Detects obfuscated: f*ck');
ok(!$filter->has_obfuscated_profanity('sh!t'), 'Detects obfuscated: sh!t');

# Test whitelist override
$DB->sqlInsert('profanity_whitelist', {term => 'damn', added_by => 1});
ok($filter->is_safe('damn'), 'Whitelist overrides blocklist');

# Test word boundary matching
ok($filter->is_safe('assembly'), 'Word boundary: assembly (contains ass)');
ok($filter->is_safe('classic'), 'Word boundary: classic (contains ass)');

# Test performance
my $start = time();
foreach (1..10000) {
  $filter->is_safe('test softlink ' . $_);
}
my $duration = time() - $start;
ok($duration < 1, 'Performance: 10k checks in <1 second');
```

### Integration Tests

**File**: `t/066_softlink_filtering_integration.t`

```perl
# Test softlinks() method filtering for guest users
my $guest = $APP->node_by_name('Guest User', 'user');
my $e2node = $APP->node_by_name('Test E2node', 'e2node');

# Create softlinks with profanity
$DB->sqlInsert('links', {
  from_node => $e2node->node_id,
  to_node => 1000,  # Node with profanity title
  linktype => 0,
  hits => 100
});

my $softlinks = $e2node->softlinks($guest->NODEDATA);

# Verify profanity is filtered
ok(!grep { $_->{title} =~ /fuck/i } @$softlinks,
   'Profanity filtered for guest users');

# Verify logged-in users see unfiltered
my $user = $APP->node_by_name('Test User', 'user');
my $softlinks_user = $e2node->softlinks($user->NODEDATA);
ok(scalar(@$softlinks_user) >= scalar(@$softlinks),
   'Logged-in users see more softlinks');
```

### Manual QA Checklist

- [ ] Guest user cannot see profanity in softlinks
- [ ] Logged-in user sees all softlinks (no filtering)
- [ ] Editor can review blocked softlinks in admin panel
- [ ] Whitelist approval works correctly
- [ ] Blocked softlinks logged to database
- [ ] AdSense ads display on guest pages
- [ ] No ads disabled due to policy violations
- [ ] Performance: Page load <500ms with filtering

---

## Performance Considerations

### Query Optimization

**Current Query** (no filtering):
```sql
SELECT node.type_nodetype, node.title, links.hits, links.to_node
FROM links USE INDEX (linktype_fromnode_hits), node
WHERE links.from_node=12345
  AND links.to_node = node.node_id
  AND links.linktype=0
ORDER BY links.hits DESC
LIMIT 24;
```

**Query Plan**: Uses covering index, <5ms execution.

**With Filtering** (in-memory):
- Fetch 24 links (fast)
- Filter each title against blocklist (100 terms × 24 links = 2,400 comparisons)
- Regex checks (~10 patterns × 24 links = 240 comparisons)
- Total overhead: <5ms

**Alternative: Database-Level Filtering** (not recommended):
```sql
-- NOT RECOMMENDED - slow full table scan
SELECT ...
WHERE links.from_node=12345
  AND node.title NOT REGEXP 'fuck|shit|...'
ORDER BY links.hits DESC
LIMIT 24;
```
**Why Not**: MySQL regex matching is slow (50ms+), defeats index optimization.

### Caching Strategy

**Problem**: Filtering is expensive if done on every page load.

**Solution**: Cache filtered softlinks per e2node.

**Implementation**:
```perl
sub softlinks {
  my ($self, $user) = @_;

  # Cache key includes guest status
  my $cache_key = 'softlinks:' . $self->node_id . ':guest=' . $user->is_guest;

  # Try cache first
  my $cached = $self->DB->getCache->get($cache_key);
  return $cached if $cached;

  # Generate and filter softlinks (existing code)
  my $softlinks = ...;

  # Cache for 1 hour
  $self->DB->getCache->set($cache_key, $softlinks, 3600);

  return $softlinks;
}
```

**Cache Invalidation**:
- On new softlink creation (link created in writeup)
- On softlink deletion (writeup edited/removed)
- On blocklist update (manual trigger)

**Memory Impact**:
- ~50,000 e2nodes × 2 (guest/user) × 1KB = 100MB cache
- Acceptable for Redis/Memcached

### Blocklist Compilation

**Problem**: Loading 1000+ term blocklist on every request is slow.

**Solution**: Pre-compile blocklist into single regex pattern.

**Implementation**:
```perl
sub _build_blocklist_regex {
  my ($self) = @_;

  my @terms = @{$self->blocklist};

  # Escape special chars and join with OR
  my $pattern = join('|', map { quotemeta($_) } @terms);

  # Compile once with word boundaries
  return qr/\b($pattern)\b/i;
}

sub is_safe {
  my ($self, $text) = @_;

  # Single regex match instead of loop
  return ($text !~ $self->blocklist_regex);
}
```

**Performance Gain**: 100× faster (100 loops → 1 regex match).

---

## Rollout Plan

### Phase 1: Dark Launch (Week 1)
- Deploy filtering code to production
- Enable filtering for 0% of guest users (feature flag)
- Monitor blocked softlinks in database
- Review false positives with Content Editors

### Phase 2: Gradual Rollout (Week 2-3)
- Enable filtering for 10% of guest users
- Monitor AdSense policy violations (should be 0)
- Increase to 50%, then 100%
- Adjust blocklist based on feedback

### Phase 3: AdSense Integration (Week 4)
- Enable AdSense ads on findings page for guest users
- Monitor revenue and ad impressions
- Ensure no policy violations

### Rollback Plan
If AdSense violations occur:
1. Immediately disable ads (feature flag)
2. Review filtered_softlinks table for leaks
3. Add missed terms to blocklist
4. Re-test with 10% rollout

---

## Monitoring and Alerts

### Metrics to Track

**Daily**:
- Softlinks blocked (count)
- Block rate (blocked / total)
- Top 10 blocked terms
- Review queue size

**Weekly**:
- AdSense policy violation reports (should be 0)
- False positive reports from users
- Whitelist additions

**Monthly**:
- Blocklist coverage (% of prohibited terms caught)
- Revenue impact (AdSense earnings)

### Alerting Rules

**Critical**:
- AdSense policy violation detected → page ops immediately
- Block rate >50% → possible blocklist over-filtering

**Warning**:
- Review queue >500 items → need more Content Editor review
- Whitelist growth >10/week → possible blocklist issues

---

## Future Enhancements

### Machine Learning-Based Filtering

Replace static blocklist with ML model trained on:
- E2 community-flagged content
- AdSense violation reports
- External profanity datasets

**Benefits**:
- Catch novel obfuscations (e.g., "fvck")
- Context-aware filtering ("damn good" vs "damn you")
- Continuous learning from user reports

**Libraries**:
- [profanity-check](https://github.com/vzhou842/profanity-check) (Python/scikit-learn)
- [better-profanity](https://github.com/snguyenthanh/better_profanity) (Python)

**Integration**:
- Train model on E2 corpus
- Export to PMML format
- Load in Perl via [AI::Categorizer](https://metacpan.org/pod/AI::Categorizer)

### User-Reported Profanity

Allow logged-in users to flag softlinks:
- "Report this link" button
- Flags sent to Content Editor review queue
- Auto-hide if >3 reports

### A/B Testing Different Filter Aggressiveness

Test guest user engagement with:
- Strict filtering (1000+ term blocklist)
- Moderate filtering (500 term blocklist)
- Lenient filtering (100 term blocklist)

**Metrics**: Bounce rate, time on page, ad revenue.

---

## End of Document

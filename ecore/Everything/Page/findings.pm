package Everything::Page::findings;

use Moose;
use Readonly;
extends 'Everything::Page';

=head1 NAME

Everything::Page::findings - Findings page

=head1 DESCRIPTION

Displays search results when multiple nodes match a search query. Shows a list
of findings with nodeshells marked specially.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about search findings.

=cut

Readonly my $EXCERPT_LENGTH => 400;
Readonly my $EXCERPT_COUNT => 10;

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;
    my $NODE = $REQUEST->node;
    my $query = $REQUEST->cgi;

    my $title = $query->param('node') || '';
    my $lastnode_id = $query->param('lastnode_id') || 0;
    my $is_admin = $APP->isAdmin($USER);
    my $is_guest = $USER->is_guest;  # Use blessed object method directly

    # If no title, return random node suggestion
    unless ($title) {
        return {
            type => 'findings',
            no_search_term => 1,
            message => 'Psst! Over here!'
        };
    }

    # Check if search term contains dirty words - if so, skip all filtering
    my $search_has_dirty_word = $self->_contains_dirty_word($title);

    my @nodes = ();

    # If node doesn't have group, do a search
    if (!exists($NODE->{group}) && defined($title)) {
        $NODE->{group} = $APP->searchNodeName($title, ["e2node"], undef, 1);
    }

    # Get the group of matching nodes
    if (defined $NODE->{group}) {
        @nodes = @{$NODE->{group}};
    }

    # Identify e2nodes to check for nodeshells
    my @e2node_ids = ();
    foreach my $node (@nodes) {
        if ($node->{type} && $node->{type}{title} && $node->{type}{title} eq "e2node") {
            push @e2node_ids, $node->{node_id};
        }
    }

    # Find which e2nodes have writeups (not nodeshells) and count them
    my %filled_node_ids = ();
    my %writeup_counts = ();
    if (@e2node_ids) {
        my $sql = "SELECT nodegroup_id, COUNT(*) FROM nodegroup WHERE nodegroup_id IN (" .
                  join(", ", @e2node_ids) . ") GROUP BY nodegroup_id";
        my $results = $DB->{dbh}->selectall_arrayref($sql);
        foreach my $row (@$results) {
            my ($node_id, $count) = @$row;
            $filled_node_ids{$node_id} = 1;
            $writeup_counts{$node_id} = $count;
        }
    }

    # Process findings
    my @findings = ();
    my $excerpt_count = 0;

    foreach my $ND (@{$NODE->{group} || []}) {
        next unless $DB->canReadNode($USER, $ND);
        my $cur_type = $ND->{type}{title} // '';
        next unless $cur_type;  # Skip nodes without a valid type

        # Skip writeups and debatecomments
        next if $cur_type eq 'writeup';
        next if $cur_type eq 'debatecomment';

        # Skip drafts unless user can see them
        next if $cur_type eq 'draft' && !$APP->canSeeDraft($USER, $ND, 'find');

        # Skip debates if not admin and not in restricted group
        if ($cur_type eq 'debate' && !$is_admin) {
            next unless $APP->inUsergroup($USER, $DB->getNodeById($ND->{restricted}));
        }

        # Check if this e2node is a nodeshell
        my $is_nodeshell = 0;
        if ($cur_type eq 'e2node') {
            $is_nodeshell = !exists $filled_node_ids{$ND->{node_id}};
        }

        # Skip nodeshells for guest users
        next if $is_guest && $is_nodeshell;

        # Track if this node has a dirty title (for potential second pass)
        my $has_dirty_title = ($cur_type eq 'e2node' && $self->_contains_dirty_word($ND->{title}));

        # For guests only: Filter dirty words UNLESS search term has dirty words
        if ($is_guest && !$search_has_dirty_word && $has_dirty_title) {
            # Skip e2nodes with dirty words in title (first pass)
            next;
        }

        my $finding = {
            node_id => $ND->{node_id},
            title => $ND->{title},
            type => $cur_type,
            is_nodeshell => $is_nodeshell
        };

        # Add writeup count for e2nodes
        if ($cur_type eq 'e2node' && !$is_nodeshell) {
            $finding->{writeup_count} = $writeup_counts{$ND->{node_id}} || 0;
        }

        # For guests, add excerpts to first N non-nodeshell e2nodes
        if ($is_guest && $cur_type eq 'e2node' && !$is_nodeshell && $excerpt_count < $EXCERPT_COUNT) {
            my $excerpt = $self->_get_writeup_excerpt($ND->{node_id});
            if ($excerpt) {
                # If excerpt contains dirty word AND search doesn't, skip the excerpt
                if (!$search_has_dirty_word && $self->_contains_dirty_word($excerpt)) {
                    # Don't add excerpt, but still include in findings list
                    # excerpt_count doesn't increment, so we can show another excerpt instead
                } else {
                    # Clean excerpt - show it
                    $finding->{excerpt} = $excerpt;
                    $excerpt_count++;
                }
            }
        }

        push @findings, $finding;
    }

    # If filtering left us with no results, do a second pass including dirty titles
    # Content discoverability is more important than ad safety for empty results
    if ($is_guest && !$search_has_dirty_word && scalar(@findings) == 0 && scalar(@nodes) > 0) {
        $excerpt_count = 0;
        foreach my $ND (@nodes) {
            my $cur_type = $ND->{type}{title} // '';
            next unless $cur_type;  # Skip nodes without a valid type

            # Apply same basic filters as first pass
            next if $cur_type eq 'writeup';
            next if $cur_type eq 'debatecomment';
            next if $cur_type eq 'draft' && !$APP->canSeeDraft($USER, $ND, 'find');
            if ($cur_type eq 'debate' && !$is_admin) {
                next unless $APP->inUsergroup($USER, $DB->getNodeById($ND->{restricted}));
            }

            my $is_nodeshell = 0;
            if ($cur_type eq 'e2node') {
                $is_nodeshell = !exists $filled_node_ids{$ND->{node_id}};
            }
            next if $is_nodeshell;  # Still skip nodeshells

            my $finding = {
                node_id => $ND->{node_id},
                title => $ND->{title},
                type => $cur_type,
                is_nodeshell => $is_nodeshell
            };

            if ($cur_type eq 'e2node' && !$is_nodeshell) {
                $finding->{writeup_count} = $writeup_counts{$ND->{node_id}} || 0;
            }

            # Add excerpts for all results in fallback mode
            if ($cur_type eq 'e2node' && !$is_nodeshell && $excerpt_count < $EXCERPT_COUNT) {
                my $excerpt = $self->_get_writeup_excerpt($ND->{node_id});
                if ($excerpt) {
                    $finding->{excerpt} = $excerpt;
                    $excerpt_count++;
                }
            }

            push @findings, $finding;
        }
    }

    return {
        type => 'findings',
        search_term => $title,
        findings => \@findings,
        lastnode_id => $lastnode_id,
        is_guest => $is_guest,
        has_excerpts => $excerpt_count > 0
    };
}

sub _get_writeup_excerpt {
    my ($self, $e2node_id) = @_;

    my $DB = $self->DB;

    # Get highest-rated writeup for this e2node
    # Join with node table to get reputation, order by reputation DESC (highest first)
    my $sql = "SELECT ng.node_id FROM nodegroup ng
               JOIN node n ON ng.node_id = n.node_id
               WHERE ng.nodegroup_id = ?
               ORDER BY n.reputation DESC, ng.orderby ASC
               LIMIT 1";
    my ($writeup_id) = $DB->{dbh}->selectrow_array($sql, undef, $e2node_id);

    return unless $writeup_id;

    # Get writeup doctext
    my $writeup = $DB->getNodeById($writeup_id);
    return unless $writeup && $writeup->{doctext};

    my $text = $writeup->{doctext};

    # Replace closing paragraph tags with space to preserve paragraph separation
    $text =~ s/<\/p>/ /gi;

    # Strip remaining HTML tags
    $text =~ s/<[^>]+>//g;

    # Strip E2 link syntax
    # Handle pipelinks: [target|display text] -> display text
    $text =~ s/\[[^\|\]]+\|([^\]]+)\]/$1/g;
    # Handle regular links: [link text] -> link text
    $text =~ s/\[([^\]]+)\]/$1/g;

    # HTML entities are decoded on the React side via decodeHtmlEntities()

    # Collapse whitespace
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    # Truncate to excerpt length
    if (length($text) > $EXCERPT_LENGTH) {
        $text = substr($text, 0, $EXCERPT_LENGTH);
        # Try to break at word boundary
        $text =~ s/\s+\S*$//;
        $text .= '...';
    }

    return $text;
}

sub _contains_dirty_word {
    my ($self, $text) = @_;

    return 0 unless defined $text && $text ne '';

    # Get dirty words from configuration
    my $badwords = $self->CONF->google_ads_badwords;

    # Normalize text for matching (lowercase)
    my $normalized_text = lc($text);

    # Check each dirty word
    foreach my $word (@$badwords) {
        # Use word boundary matching to avoid false positives
        # e.g., "assistant" shouldn't match "ass"
        if ($normalized_text =~ /\b\Q$word\E/i) {
            return 1;
        }
    }

    return 0;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

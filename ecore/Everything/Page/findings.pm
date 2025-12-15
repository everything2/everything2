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

Readonly my $EXCERPT_LENGTH => 200;
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
    my $is_guest = $APP->isGuest($USER);

    # If no title, return random node suggestion
    unless ($title) {
        return {
            type => 'findings',
            no_search_term => 1,
            message => 'Psst! Over here!'
        };
    }

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

    # Find which e2nodes have writeups (not nodeshells)
    my %filled_node_ids = ();
    if (@e2node_ids) {
        my $sql = "SELECT DISTINCT nodegroup_id FROM nodegroup WHERE nodegroup_id IN (" .
                  join(", ", @e2node_ids) . ")";
        my @filled = @{$DB->{dbh}->selectcol_arrayref($sql)};
        @filled_node_ids{@filled} = ();
    }

    # Process findings
    my @findings = ();
    my $excerpt_count = 0;

    foreach my $ND (@{$NODE->{group} || []}) {
        next unless $DB->canReadNode($USER, $ND);
        my $cur_type = $ND->{type}{title};

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

        my $finding = {
            node_id => $ND->{node_id},
            title => $ND->{title},
            type => $cur_type,
            is_nodeshell => $is_nodeshell
        };

        # For guests, add excerpts to first N non-nodeshell e2nodes
        # DISABLED: Re-enable after stability fixes deployed
        # if ($is_guest && $cur_type eq 'e2node' && !$is_nodeshell && $excerpt_count < $EXCERPT_COUNT) {
        #     my $excerpt = $self->_get_writeup_excerpt($ND->{node_id});
        #     if ($excerpt) {
        #         $finding->{excerpt} = $excerpt;
        #         $excerpt_count++;
        #     }
        # }

        push @findings, $finding;
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

    # Get first writeup for this e2node
    my $sql = "SELECT node_id FROM nodegroup WHERE nodegroup_id = ? ORDER BY orderby LIMIT 1";
    my ($writeup_id) = $DB->{dbh}->selectrow_array($sql, undef, $e2node_id);

    return unless $writeup_id;

    # Get writeup doctext
    my $writeup = $DB->getNodeById($writeup_id);
    return unless $writeup && $writeup->{doctext};

    my $text = $writeup->{doctext};

    # Strip HTML tags
    $text =~ s/<[^>]+>//g;

    # Decode common HTML entities
    $text =~ s/&nbsp;/ /g;
    $text =~ s/&amp;/&/g;
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&quot;/"/g;

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

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

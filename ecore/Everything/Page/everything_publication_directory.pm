package Everything::Page::everything_publication_directory;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_publication_directory - Publications discussion directory

=head1 DESCRIPTION

Shows debate discussions for E2 Publications, sorted by most recent comment.
Restricted to users in the 'thepub' usergroup.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns list of publication debates with metadata and form for creating new debates.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;
    my $APP = $self->APP;

    # Check permission - must be in 'thepub' usergroup or be an admin
    unless ($APP->inUsergroup($USER, 'thepub') || $APP->isAdmin($USER->NODEDATA)) {
        return {
            type => 'everything_publication_directory',
            error => 'Access denied. This page is restricted to thepub usergroup members and admins.'
        };
    }

    # Get debate type ID
    my $debate_type = $DB->getType('debate');
    my $debate_type_id = $debate_type->{node_id};

    # Get all debates with restricted=114 (thepub), ordered by most recent comment
    my $csr = $DB->sqlSelectMany(
        "root_debatecomment",
        "debatecomment",
        "restricted=114",
        "ORDER BY debatecomment_id DESC"
    );

    # Collect unique root debate nodes
    my %seen = ();
    my @debate_ids = ();
    while (my $row = $csr->fetchrow_hashref) {
        my $root_id = $row->{root_debatecomment};
        unless ($seen{$root_id}) {
            push @debate_ids, $root_id;
            $seen{$root_id} = 1;
        }
    }

    # Build debate list with metadata
    my @debates = ();
    foreach my $debate_id (@debate_ids) {
        my $debate = $DB->getNodeById($debate_id);
        next unless $debate;

        # Get restricted group
        my $restricted_id = $debate->{restricted} || 923653;  # Default to thepub
        $restricted_id = 114 if $restricted_id == 1;  # Backwards compatibility
        my $restricted_group = $DB->getNodeById($restricted_id, 'light');

        # Check if user can view this debate
        next unless $DB->isApproved($USER, $restricted_group);

        # Get author
        my $author = $DB->getNodeById($debate->{author_user}, 'light');

        # Format created date (YYYY-MM-DD to M/D/YYYY)
        my $created = $debate->{createtime};
        $created =~ s/^(\d+)-(\d+)-(\d+).*$/$2\/$3\/$1/;
        $created =~ s/(^|\/)0/$1/g;  # Remove leading zeros

        # Get latest comment
        my $latest_comment_id = $DB->sqlSelect(
            "MAX(debatecomment_id)",
            "debatecomment",
            "root_debatecomment=$debate_id"
        );

        my $latest_time = '';
        if ($latest_comment_id) {
            my $latest_comment = $DB->getNodeById($latest_comment_id, 'light');
            if ($latest_comment) {
                $latest_time = $latest_comment->{createtime};
                $latest_time =~ s/^(\d+)-(\d+)-(\d+).*$/$2\/$3\/$1/;
                $latest_time =~ s/(^|\/)0/$1/g;
            }
        }
        $latest_time ||= '(none)';

        push @debates, {
            node_id => $debate->{node_id},
            title => $debate->{title},
            author_id => $author ? $author->{node_id} : 0,
            author_title => $author ? $author->{title} : 'Unknown',
            created => $created,
            latest_time => $latest_time,
            restricted_id => $restricted_group ? $restricted_group->{node_id} : 0,
            restricted_title => $restricted_group ? $restricted_group->{title} : 'thepub'
        };
    }

    return {
        type => 'everything_publication_directory',
        debates => \@debates,
        can_create => 1
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

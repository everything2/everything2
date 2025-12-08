package Everything::API::betweenthecracks;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::betweenthecracks - API for finding neglected writeups

=head1 DESCRIPTION

Provides API endpoint for fetching writeups with few votes that the
current user hasn't voted on yet.

=head1 METHODS

=head2 routes

Define API routes.

=cut

sub routes {
    return {
        "search" => "search"
    };
}

=head2 search($REQUEST)

Returns writeups with low vote counts that the user hasn't voted on.

GET /api/betweenthecracks/search?max_votes=5&min_rep=-3

Parameters:
- max_votes: Maximum total votes (1-10, default 5)
- min_rep: Minimum reputation (-3 to 3, optional)

Returns JSON with list of writeups.

=cut

sub search {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;

    # Guest check
    if ($APP->isGuest($USER->NODEDATA)) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'You must be logged in to use this feature'
        }];
    }

    # Parse parameters
    my $max_votes = int($REQUEST->param('max_votes') || 5);
    $max_votes = 5 if $max_votes <= 0;
    $max_votes = 10 if $max_votes > 10;

    my $min_rep_param = $REQUEST->param('min_rep');
    my $min_rep;
    my $rep_restriction = '';

    if (defined $min_rep_param && $min_rep_param ne '') {
        $min_rep = int($min_rep_param);
        # Validate min_rep range
        if ($min_rep > 5 || abs($min_rep) > ($max_votes - 2)) {
            $min_rep = undef;
        }

        if (defined $min_rep) {
            $rep_restriction = "AND reputation >= $min_rep";
        }
    }

    my $user_id = $USER->NODEDATA->{user_id};
    my $count = 1000;
    my $result_limit = 50;

    # Query for writeups the user hasn't voted on with low vote counts
    # wrtype_writeuptype 177599 is "e2node" type to exclude
    my $query = qq|
        SELECT title, author_user, createtime, writeup_id, totalvotes
        FROM writeup
        JOIN node ON writeup.writeup_id = node.node_id
        LEFT OUTER JOIN vote ON vote.vote_id = node.node_id AND vote.voter_user = ?
        WHERE
            node.totalvotes <= ?
            $rep_restriction
            AND node.author_user <> ?
            AND vote.voter_user IS NULL
            AND wrtype_writeuptype <> 177599
        ORDER BY writeup.writeup_id
        LIMIT ?
    |;

    my $sth = $DB->{dbh}->prepare($query);
    $sth->execute($user_id, $max_votes, $user_id, $count);

    my @writeups;
    my $row_count = 0;

    while (my $wu = $sth->fetchrow_hashref) {
        # Skip unvotable writeups
        next if $APP->isUnvotable($wu->{writeup_id});

        # Get author info
        my $author = $DB->getNodeById($wu->{author_user});

        push @writeups, {
            writeup_id => $wu->{writeup_id},
            title => $wu->{title},
            author_id => $wu->{author_user},
            author => $author ? $author->{title} : 'unknown',
            totalvotes => $wu->{totalvotes},
            createtime => $wu->{createtime}
        };

        $row_count++;
        last if $row_count >= $result_limit;
    }

    return [$self->HTTP_OK, {
        success => 1,
        data => {
            writeups => \@writeups,
            max_votes => $max_votes,
            min_rep => $min_rep
        }
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::Page::between_the_cracks>

=cut

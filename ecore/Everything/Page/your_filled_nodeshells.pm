package Everything::Page::your_filled_nodeshells;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

=head1 NAME

Everything::Page::your_filled_nodeshells - Shows user's nodeshells that have been filled

=head1 DESCRIPTION

Displays nodeshells created by the current user that have been filled by other users.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns list of filled nodeshells for the current user.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Query: Get e2nodes created by user that:
    # 1. Have a nodegroup entry (filled)
    # 2. User doesn't have a writeup in them
    my $user_id = $USER->node_id;
    my $csr = $DB->sqlSelectMany(
        'title, fillede2nodes.e2node_id',
        "(Select title, e2node_id,
            (select nodegroup_id from nodegroup where nodegroup_id = e2node_id limit 1) As groupentry
        From e2node Join node On node.node_id = e2node_id
        Where createdby_user = $user_id
        Having groupentry > 0)
        AS fillede2nodes
    LEFT JOIN
        (Select parent_e2node
        From node
        Join writeup On node_id = writeup_id
        Where author_user = $user_id)
        AS writeups
    ON fillede2nodes.e2node_id = writeups.parent_e2node",
        'parent_e2node IS NULL'
    );

    my @nodeshells = ();
    while (my $row = $csr->fetchrow_hashref) {
        push @nodeshells, {
            node_id => $row->{e2node_id},
            title => $row->{title}
        };
    }

    # Sort alphabetically by title
    @nodeshells = sort { lc($a->{title}) cmp lc($b->{title}) } @nodeshells;

    return {
        type => 'your_filled_nodeshells',
        nodeshells => \@nodeshells,
        count => scalar(@nodeshells)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut

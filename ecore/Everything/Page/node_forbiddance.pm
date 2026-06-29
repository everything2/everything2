package Everything::Page::node_forbiddance;

use Moose;
extends 'Everything::Page';

use Everything qw(getId getNode getNodeById getType);
use Everything::HTML qw(parseLinks);

=head1 Everything::Page::node_forbiddance

React page for Node Forbiddance - admin tool to forbid/unforbid users from creating nodes.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB = $self->DB;

    # Forbid/unforbid moved to POST /api/nodeforbiddance/{forbid,unforbid}
    # (Everything::API::nodeforbiddance) so rendering this page no longer writes
    # to nodelock off request params (#4408). buildReactData is pure-render: just
    # the current forbidden-users list below.

    # Get list of currently forbidden users
    my $user_type_id = getId( getType('user') );
    my $csr = $DB->sqlSelectMany(
        "*",
        "nodelock left join node on nodelock_node = node_id",
        "type_nodetype=$user_type_id"
    );

    my @forbidden_users = ();
    while ( my $row = $csr->fetchrow_hashref ) {
        my $forbidder = getNodeById( $row->{nodelock_user} );
        my $reason = $row->{nodelock_reason} || '';

        # Parse links in reason
        $reason = parseLinks( $reason ) if $reason;

        push @forbidden_users, {
            user_id         => $row->{nodelock_node},
            user_title      => $row->{title} || 'unknown',
            forbidder_id    => $forbidder ? $forbidder->{node_id} : 0,
            forbidder_title => $forbidder ? $forbidder->{title} : 'unknown',
            reason          => $reason
        };
    }
    $csr->finish;

    return {
        type            => 'node_forbiddance',
        forbidden_users => \@forbidden_users
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

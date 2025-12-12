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

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $NODE  = $REQUEST->node;

    my $message = '';

    # Handle unforbid action
    my $unforbid = $query->param("unforbid");
    if ( $unforbid ) {
        my $ufusr = getNodeById( $unforbid );
        if ( $ufusr ) {
            $DB->sqlDelete( "nodelock", "nodelock_node=" . $ufusr->{user_id} );
            $message = "It is done...they are free";
        }
    }

    # Handle forbid action
    my $forbid = $query->param("forbid");
    if ( $forbid ) {
        my $fusr = getNode( $forbid, 'user' );
        if ( $fusr ) {
            $DB->sqlInsert( "nodelock", {
                nodelock_node   => $fusr->{user_id},
                nodelock_user   => $USER->node_id,
                nodelock_reason => $query->param("reason") || ''
            });
            $message = "It is done...they have been forbidden";
        }
    }

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
        message         => $message,
        forbidden_users => \@forbidden_users,
        node_id         => $NODE->NODEDATA->{node_id}
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

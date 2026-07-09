package Everything::Page::websterbless;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::websterbless

React page for Websterbless - rewards users who suggest corrections to Webster 1913.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;

    # Only editors and admins can access this tool
    unless ( $APP->isEditor( $USER->NODEDATA ) || $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type  => 'websterbless',
            error => 'Access denied. This tool is restricted to editors and administrators.'
        };
    }

    # Get Webster 1913 user node
    my $webster = $DB->getNode( 'Webster 1913', 'user' );
    unless ($webster) {
        return {
            type  => 'websterbless',
            error => 'Webster 1913 user not found in database.'
        };
    }

    my $webster_id = $webster->{node_id};

    # Count Webster 1913's messages
    my $msg_count = $DB->sqlSelect( 'COUNT(*)', 'message', "for_user=$webster_id" ) || 0;

    # The bless WRITE (per user: Webster thank-you PM + karma + GP + securityLog) moved
    # to POST /api/websterbless/bless (Everything::API::websterbless, #4451), so this
    # page no longer mutates a user's data off query params. buildReactData is now
    # pure-render: the React component posts the blessings and renders the per-user
    # results from the response.

    # prefill_username from the URL (user-tools modal integration). Transport-agnostic
    # accessor ($REQUEST->param delegates to the Plack query object) so the pagestate API
    # path parses it identically. (routing-epoch param sweep, tranche T3a -- #4494.)
    my $prefill_username = $REQUEST->param('prefill_username') || '';

    return {
        type             => 'websterbless',
        msg_count        => $msg_count,
        webster_id       => $webster_id,
        prefill_username => $prefill_username
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

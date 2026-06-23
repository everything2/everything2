package Everything::Page::everything_s_most_wanted;

use Moose;
extends 'Everything::Page';

use Everything::API::bounties;

=head1 Everything::Page::everything_s_most_wanted

React page for Everything's Most Wanted - bounty system for filling nodeshells.

Thin read-only shell now: the bounty read model comes from
C<Everything::API::bounties::build_state>, and every mutation (post / remove /
reward / award / yank) goes through the level/sheriff-gated POST /api/bounties
endpoints. The old server-side C<_process_form> (guarded by the
C<verifyRequest>/C<verifyRequestHash> form-CSRF htmlcodes) is gone. #4198

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $USER = $REQUEST->user;

    return {
        type => 'everything_s_most_wanted',
        %{ Everything::API::bounties::build_state( $self->DB, $self->APP, $USER->NODEDATA ) },
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::bounties>

=cut

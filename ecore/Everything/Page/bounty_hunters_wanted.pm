package Everything::Page::bounty_hunters_wanted;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::bounty_hunters_wanted

React page for Bounty Hunters Wanted - displays recent bounties from
Everything's Most Wanted.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $APP = $self->APP;

    # Get bounty data from settings nodes
    # Note: node_by_name returns blessed objects, getVars expects hashrefs (NODEDATA)
    my $bounty_order_node = $APP->node_by_name( 'bounty order', 'setting' );
    my $outlaws_node = $APP->node_by_name( 'outlaws', 'setting' );
    my $bounties_node = $APP->node_by_name( 'bounties', 'setting' );
    my $bounty_number_node = $APP->node_by_name( 'bounty number', 'setting' );

    my $REQ  = $bounty_order_node ? $APP->getVars( $bounty_order_node->NODEDATA ) : {};
    my $OUT  = $outlaws_node ? $APP->getVars( $outlaws_node->NODEDATA ) : {};
    my $REW  = $bounties_node ? $APP->getVars( $bounties_node->NODEDATA ) : {};
    my $HIGH = $bounty_number_node ? $APP->getVars( $bounty_number_node->NODEDATA ) : {};

    my $bounty_total = $HIGH->{1} || 0;
    my $max_shown    = 5;
    my @bounties;

    # Get the 5 most recent bounties
    my $number_shown = 0;
    for ( my $i = $bounty_total; $number_shown < $max_shown && $i > 0; $i-- ) {
        if ( exists $REQ->{$i} ) {
            my $requester  = $REQ->{$i};
            my $outlaw_str = $OUT->{$requester} || '';
            my $reward     = $REW->{$requester} || 0;

            push @bounties, {
                requester => $requester,
                outlaw    => $outlaw_str,
                reward    => $reward
            };
            $number_shown++;
        }
    }

    # Get node_id for Everything's Most Wanted link
    my $emw_node = $APP->node_by_name( "Everything's Most Wanted", 'superdoc' );

    return {
        type        => 'bounty_hunters_wanted',
        bounties    => \@bounties,
        emw_node_id => $emw_node ? $emw_node->NODEDATA->{node_id} : undef
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::Page::nate_s_secret_unborg_doc;

use Moose;
extends 'Everything::Page';

use Everything qw(getId getVars setVars);

=head1 Everything::Page::nate_s_secret_unborg_doc

React page for Nate's Secret Unborg Doc - instantly unborgs admin.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $VARS  = $APP->getVars( $USER->NODEDATA );

    # Non-admins cannot use
    unless ( $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type    => 'nate_s_secret_unborg_doc',
            success => 0,
            message => "Maybe you'd better just stay in there"
        };
    }

    # Unborg the user
    $VARS->{borged} = '';
    setVars( $USER->NODEDATA, $VARS );

    my $UID = getId( $USER->NODEDATA );
    $DB->sqlUpdate( 'room', { borgd => 0 }, "member_user=$UID" );

    return {
        type    => 'nate_s_secret_unborg_doc',
        success => 1,
        message => "you're unborged"
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::Page::the_tokenator;

use Moose;
extends 'Everything::Page';

use Everything qw(setVars);
use Everything::Delegation::htmlcode qw(htmlcode);

=head1 Everything::Page::the_tokenator

React page for The Tokenator - admin tool to give tokens to users.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Security: Admins only (implied by oppressor_superdoc)
    unless ( $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type          => 'the_tokenator',
            access_denied => 1
        };
    }

    my @results;

    # Process any tokenation requests
    my @params = $query->param;
    foreach my $param (@params) {
        if ( $param =~ /^tokenateUser(\d+)$/ ) {
            my $username = $query->param($param);
            next unless $username;

            my $target_user = $DB->getNode( $username, 'user' );
            if ( !$target_user ) {
                push @results, {
                    success  => 0,
                    username => $username,
                    message  => "Couldn't find user $username"
                };
                next;
            }

            # Send notification via Cool Man Eddie
            my $cme = $DB->getNode( 'Cool Man Eddie', 'user' );
            if ($cme) {
                $DB->sqlInsert(
                    'message',
                    {
                        msgtext     => 'Whoa! Somebody has given you a [token]! Use it to [E2 Gift Shop|reset the chatterbox topic].',
                        author_user => $cme->{node_id},
                        for_user    => $target_user->{node_id}
                    }
                );
            }

            # Add token to user's vars
            my $v = $APP->getVars($target_user);
            $v->{tokens} = ( $v->{tokens} || 0 ) + 1;
            setVars( $target_user, $v );

            push @results, {
                success  => 1,
                username => $target_user->{title},
                message  => "User $target_user->{title} was given one token"
            };
        }
    }

    return {
        type    => 'the_tokenator',
        results => \@results
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

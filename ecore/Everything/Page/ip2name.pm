package Everything::Page::ip2name;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::ip2name

React page for IP2Name - looks up users by IP address.
Admin/Editor tool.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Security: Editors and admins only (implied by restricted_superdoc)
    unless ( $APP->isEditor( $USER->NODEDATA ) || $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type          => 'ip2name',
            access_denied => 1
        };
    }

    my $ipaddy = $query->param('ipaddy') || '';
    my @results;

    if ($ipaddy) {
        # Escape dots for SQL LIKE pattern
        my $like = $ipaddy;
        $like =~ s/\./\%\%2e/g;
        $like = "\%ipaddy=$like\%";

        my $csr = $DB->sqlSelectMany(
            'setting_id',
            'setting',
            'vars like ' . $DB->{dbh}->quote($like)
        );

        while ( my ($id) = $csr->fetchrow ) {
            my $node = $DB->getNodeById($id);
            if ($node) {
                push @results, {
                    node_id => $node->{node_id},
                    title   => $node->{title}
                };
            }
        }
    }

    return {
        type    => 'ip2name',
        ipaddy  => $ipaddy,
        results => \@results
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut

package Everything::API::recent_registry_entries;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::recent_registry_entries - the 100 most recent registry entries site-wide

=head1 DESCRIPTION

Lists the last 100 registrations across all registries (registry, submitting user, data/comments).
Moved out of C<Everything::Page::recent_registry_entries>'s buildReactData (#4548): the Page is a
pure gate. Login-required (NoGuest).

  GET /api/recent_registry_entries

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    my $csr = $DB->sqlSelectMany('*', 'registration', '', 'ORDER BY tstamp DESC LIMIT 100');

    my @entries;
    while (my $ref = $csr->fetchrow_hashref()) {
        my $registry  = $DB->getNodeById($ref->{for_registry});
        my $user_node = $DB->getNodeById($ref->{from_user});
        next unless $registry && $user_node;
        push @entries, {
            registry   => { node_id => int($registry->{node_id}),  title => $registry->{title} },
            user       => { node_id => int($user_node->{node_id}), title => $user_node->{title} },
            data       => $APP->parseAsPlainText($ref->{data} || ''),
            comments   => $APP->parseAsPlainText($ref->{comments} || ''),
            in_profile => $ref->{in_user_profile} ? \1 : \0,
            timestamp  => $ref->{tstamp},
        };
    }

    return [$self->HTTP_OK, { success => 1, entries => \@entries }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut

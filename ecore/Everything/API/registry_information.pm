package Everything::API::registry_information;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::registry_information - the current user's own registry entries

=head1 DESCRIPTION

Lists the registries the logged-in user has submitted entries to (their data/comments, whether it
shows in their profile). Moved out of C<Everything::Page::registry_information>'s buildReactData
(#4548): the Page is a pure gate. Login-required (NoGuest); user-scoped to C<< $REQUEST->user >>.

  GET /api/registry_information

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    # from_user is the caller's own node_id (an int off the blessed user), not request input.
    my $csr = $DB->sqlSelectMany('*', 'registration', 'from_user=' . int($user->node_id));

    my @entries;
    while (my $ref = $csr->fetchrow_hashref()) {
        my $registry = $DB->getNodeById($ref->{for_registry});
        next unless $registry;
        push @entries, {
            registry   => { node_id => int($registry->{node_id}), title => $registry->{title} },
            data       => $APP->htmlScreen($ref->{data} || ''),
            comments   => $APP->htmlScreen($ref->{comments} || ''),
            in_profile => $ref->{in_user_profile} ? \1 : \0,
        };
    }

    return [$self->HTTP_OK, {
        success     => 1,
        entries     => \@entries,
        has_entries => (@entries ? \1 : \0),
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut

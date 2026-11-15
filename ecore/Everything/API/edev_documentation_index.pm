package Everything::API::edev_documentation_index;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::edev_documentation_index - index of edevdoc nodes

=head1 DESCRIPTION

Lists every C<edevdoc>, plus whether the caller is an edev developer (React uses that for the
create-new affordance; creation itself is a separate endpoint). Moved out of
C<Everything::Page::edev_documentation_index>'s buildReactData (#4557): the Page is a pure gate.
Public listing (superdoc) -- the index itself was never gated.

  GET /api/edev_documentation_index

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $user = $REQUEST->user;

    my @docs = map { { node_id => int($_->{node_id}), title => $_->{title} } }
        $DB->getNodeWhere({}, 'edevdoc', 'title');

    # is_developer drives an affordance, not access; guests are never developers. Deliberately the
    # gods-count form ($APP->isDeveloper without "nogods"), matching the Page this replaced -- admins
    # can create edevdocs, so they get the create box. ($user->is_developer passes "nogods".)
    my $is_developer = (!$user->is_guest && $self->APP->isDeveloper($user->NODEDATA)) ? \1 : \0;

    return [$self->HTTP_OK, {
        success      => 1,
        docs         => \@docs,
        is_developer => $is_developer,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut

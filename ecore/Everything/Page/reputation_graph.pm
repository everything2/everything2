package Everything::Page::reputation_graph;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::reputation_graph - Monthly reputation graph for writeups (vertical layout)

=head1 DESCRIPTION

Pure gate: ships only { type, layout }. React (ReputationGraph) reads the writeup C<id> off the URL
and resolves everything -- writeup + author metadata, the per-user permission, and the monthly vote
data -- via GET /api/reputation/votes. No param reading or resolution here (#4504). C<layout> is
static config (vertical vs horizontal), not a param.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;
    return { type => 'reputation_graph', layout => 'vertical' };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::reputation>

=cut

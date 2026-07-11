package Everything::Page::reputation_graph_horizontal;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::reputation_graph_horizontal - Monthly reputation graph for writeups (horizontal layout)

=head1 DESCRIPTION

Pure gate: ships only { type, layout }. Identical to reputation_graph except the layout flag; React
(ReputationGraph, type => 'reputation_graph') reads the writeup C<id> off the URL and resolves the
writeup/author/permission/vote data via GET /api/reputation/votes. No param reading here (#4504).

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;
    return { type => 'reputation_graph', layout => 'horizontal' };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::reputation_graph>, L<Everything::API::reputation>

=cut

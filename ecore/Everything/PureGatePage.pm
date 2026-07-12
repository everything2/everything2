package Everything::PureGatePage;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::PureGatePage - generic page instance for a pure-gate (skinny) controller

=head1 DESCRIPTION

A single generic Page used for every entry in L<Everything::PureGates>: it carries a static
contentData payload and returns it from buildReactData, so a skinny page needs no dedicated
C<Everything::Page::*> module. L<Everything::Controller>'s C<_build_page_table> builds one of these
per registry entry (#4513).

Lives OUTSIDE C<Everything/Page/> on purpose: L<Everything::PluginFactory> instantiates every
C<Everything::Page::*> module it finds with a bare C<new()>, and this class has a required attribute.

=cut

has 'content' => (is => 'ro', isa => 'HashRef', required => 1);

sub buildReactData {
    my ($self, $REQUEST) = @_;
    # Shallow copy so a caller can't mutate the shared registry payload.
    return { %{ $self->content } };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::PureGates>, L<Everything::Controller>, L<Everything::Page>

=cut

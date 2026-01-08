package Everything::Controller::Role::BasicEdit;

use Moose::Role;

=head1 NAME

Everything::Controller::Role::BasicEdit - Role for controllers using basicedit for edit mode

=head1 DESCRIPTION

This role provides a default C<edit> method that routes to C<basicedit>.
Many nodetypes use the standard basicedit form (gods-only raw database field editor)
for editing, so this role eliminates the boilerplate.

=head1 USAGE

    package Everything::Controller::mytype;
    use Moose;
    extends 'Everything::Controller';
    with 'Everything::Controller::Role::BasicEdit';

    # Now 'edit' displaytype automatically uses basicedit
    # No need to define sub edit { ... }

=head1 METHODS

=head2 edit($REQUEST, $node)

Routes to the basicedit method from Everything::Controller.

=cut

sub edit {
    my ($self, $REQUEST, $node) = @_;
    return $self->basicedit($REQUEST, $node);
}

1;

=head1 SEE ALSO

L<Everything::Controller>

=cut

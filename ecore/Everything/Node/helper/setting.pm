package Everything::Node::helper::setting;

use Moose::Role;

has 'VARS' => ('is' => 'ro', 'isa' => 'HashRef', 'lazy' => 1, 'builder' => '_build_VARS');

sub _build_VARS
{
  my ($self) = @_;
  return $self->APP->getVars($self->NODEDATA); 
}

sub set_vars
{
  my ($self, $vars) = @_;
  return Everything::setVars($self->NODEDATA, $vars);
}

1;

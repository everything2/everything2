package Everything::Node;

use Moose;

with 'Everything::Globals';

has 'NODEDATA' => (isa => "HashRef", required => 1, is => "rw");
has 'author' => (is => "ro", lazy => 1, builder => "_build_author");

sub id
{
  my $self = shift;
  return $self->NODEDATA->{node_id};
}

sub node_id
{
  my $self = shift;
  return $self->NODEDATA->{node_id};
}

sub title
{
  my $self = shift;
  return $self->NODEDATA->{title};
}

sub type
{
  my $self = shift;
  return $self->APP->node_by_id($self->NODEDATA->{type_nodetype});
}

sub author_user
{
  my $self = shift;
  return $self->NODEDATA->{author_user};
}

sub _build_author
{
  my $self = shift;
  return $self->APP->node_by_id($self->author_user);
}

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $class = shift; 
  my $NODEDATA = shift;

  return $class->$orig("NODEDATA" => $NODEDATA);
};

sub can_read_node
{
  my ($self, $user) = @_;

  return $self->DB->canReadNode($user, $self->NODEDATA);
}

sub json_reference
{
  my ($self) = @_;
  return $self->APP->node_json_reference($self->NODEDATA); 
}

sub json_display
{
  my $self = shift;
  return $self->json_reference(@_);
}

__PACKAGE__->meta->make_immutable;
1;

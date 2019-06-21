package Everything::Link;

use Moose;

with 'Everything::Globals';

has 'LINKDATA' => (isa => 'HashRef', is => 'ro', required => 1);

has 'to' => (isa => 'Everything::Node', is => 'ro', lazy => 1, builder => '_build_to');
has 'from' => (isa => 'Everything::Node', is => 'ro', lazy => 1, builder => '_build_from');
has 'linktype' => (isa => 'Everything::Node', is => 'ro', lazy => 1, builder => '_build_linktype'); 

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $class = shift;
  my $LINKDATA = shift;

  return $class->$orig("NODEDATA" => $LINKDATA);
};

sub _build_to
{
  my ($self) = @_;
  return $self->APP->node_by_id($self->LINKDATA->{to_node});
}

sub _build_from
{
  my ($self) = @_;
  return $self->APP->node_by_id($self->LINKDATA->{from_node});
}

sub _build_linktype
{
  my ($self) = @_;
  return $self->APP->node_by_id($self->LINKDATA->{linktype});
}

sub food
{
  my ($self) = @_;
  return $self->LINKDATA->{food};
}

sub hits
{
  my ($self) = @_;
  return $self->LINKDATA->{hits};
}

__PACKAGE__->meta->make_immutable;
1;

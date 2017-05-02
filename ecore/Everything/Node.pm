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

  return $self->DB->canReadNode($user->NODEDATA, $self->NODEDATA);
}

sub can_update_node
{
  my ($self, $user) = @_;
  return $self->DB->canUpdateNode($user->NODEDATA, $self->NODEDATA);
}

sub can_delete_node
{
  my ($self, $user) = @_;
  return $self->DB->canDeleteNode($user->NODEDATA, $self->NODEDATA);
}

sub json_reference
{
  my ($self) = @_;
  return $self->APP->node_json_reference($self->NODEDATA); 
}

sub json_display
{
  my $self = shift;
  my $values = $self->json_reference(@_);
  $values->{author} = $self->author->json_reference;
  $values->{createtime} = $self->APP->iso_date_format($self->createtime);

  return $values;
}

sub insert
{
  my ($self, $user, $data) = @_;
  $self->devLog("Insert called by user '".$user->title."' with data ".$self->JSON->encode($data));

  my $title = $data->{title};
  unless(defined $title)
  {
    $self->devLog("Everything::Node::insert: Didn't get a title in the \$data hash, returning");
    return;
  }

  delete $data->{title};

  my $new_node_id = $self->DB->insertNode($title, $self->typeclass, $user->NODEDATA,$data, "skip maintenances");
  unless($new_node_id)
  {
    $self->devLog("Did not get good node_id back from insertNode. Returning");
    return;
  }

  $self->NODEDATA($self->DB->getNodeById($new_node_id));
  return $self;
}

sub can_create_type
{
  my ($self, $user) = @_;

  return $self->DB->canCreateNode($user->NODEDATA, $self->typeclass);  
}

sub typeclass
{
  my ($self) = @_;
  my $string = ref($self);
  $string =~ s/.*:://g;
  return $string;
}


sub createtime
{
  my ($self) = @_;
  return $self->NODEDATA->{createtime};
}

sub update
{
  my ($self, $user) = @_;
  return $self->DB->updateNode($self->NODEDATA, $user->NODEDATA, undef, "skip maintenance")
}

sub delete
{
  my ($self, $user) = @_;

  return $self->DB->nukeNode($self->NODEDATA, $user->NODEDATA, undef, "skip maintenances");
}

__PACKAGE__->meta->make_immutable;
1;

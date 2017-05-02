package Everything::Node::e2node;

use Moose;
extends 'Everything::Node';

with 'Everything::Node::helper::group';

override 'json_display' => sub
{
  my ($self, $user) = @_;
  my $values = super();

  my $group = [];
  $values->{author} = $self->author->json_reference;

  foreach my $writeup (@{$self->group || []})
  {
    push @$group, $writeup->single_writeup_display($user);
  }

  if(scalar(@$group) > 0)
  {
    $values->{group} = $group;
  }

  my $softlinks = $self->softlinks($user);

  if(scalar(@$softlinks) > 0)
  {
    $values->{softlinks} = $softlinks;
  }
  return $values;
};

sub softlinks
{
  my ($self, $user) = @_;
  
  my $limit = 48;
  $limit = 24 if $user->is_guest;
  $limit = 46 if $user->is_editor;

  my $csr = $self->DB->{dbh}->prepare('select node.type_nodetype, node.title, links.hits, links.to_node from links use index (linktype_fromnode_hits), node where links.from_node='.$self->node_id.' and links.to_node = node.node_id and links.linktype=0 order by links.hits desc limit '.$limit);

  $csr->execute;
  my $softlinks = [];
  while (my $link = $csr->fetchrow_hashref)
  {
    push @$softlinks, {"node_id" => int($link->{to_node}), "title" => $link->{title}, "type" => "e2node", "hits" => int($link->{hits})};
  }

  return $softlinks;
}

around 'insert' => sub {
 my ($orig, $self, $user, $data) = @_;

 $data->{author_user} = $self->APP->node_by_name("Content Editors","usergroup")->node_id;

 return $self->$orig($user, $data);
};

__PACKAGE__->meta->make_immutable;
1;

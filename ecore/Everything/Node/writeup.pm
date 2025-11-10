package Everything::Node::writeup;

use Moose;
extends 'Everything::Node::document';

override 'json_display' => sub
{
  my ($self, $user) = @_;
  my $writeup = $self->single_writeup_display($user);
  my $softlinks = $self->parent->softlinks($user);
  if(scalar(@$softlinks))
  {
    $writeup->{softlinks} = $softlinks;
  }

  return $writeup;
};

sub single_writeup_display
{
  my ($self, $user) = @_;

  my $values = $self->SUPER::json_display;

  my $cools = $self->cools;
  if(scalar(@$cools) > 0)
  {
    $values->{cools} = $cools;
  }

  $values->{writeuptype} = $self->writeuptype;

  return $values if $user->is_guest;

  my $vote = $self->user_has_voted($user);

  if($self->author_user == $user->node_id)
  {
    $values->{notnew} = $self->notnew;
  }

  if($vote || $self->author_user == $user->node_id)
  {
    foreach my $key ("reputation","upvotes","downvotes")
    {
      $values->{$key} = int($self->$key);
    }
  }

  if($vote)
  {
    $values->{vote} = $vote->{weight};
  }

  if($self->parent)
  {
    $values->{parent} = $self->parent->json_reference;
  }

  return $values;
}

sub cools
{
  my ($self) = @_;

  my $csr = $self->DB->sqlSelectMany("*","coolwriteups","coolwriteups_id=".$self->node_id." ORDER BY tstamp");
  my $cools = [];
  while(my $row = $csr->fetchrow_hashref)
  {
    my $cooledby = $self->APP->node_by_id($row->{cooledby_user});
    next unless $cooledby;
    push @$cools, $cooledby->json_reference;
  }

  return $cools;
}

sub user_has_voted
{
  my ($self,$user) = @_;

  my $record = $self->DB->sqlSelectHashref("*","vote","voter_user=".$user->node_id." and vote_id=".$self->node_id);
  if($record)
  {
    return $record;
  }
}

sub reputation
{
  my ($self) = @_;
  return $self->NODEDATA->{reputation};
}

sub downvotes
{
  my ($self) = @_;
  return $self->vote_count(-1);
}

sub upvotes
{
  my ($self) = @_;
  return $self->vote_count(1);
}

sub vote_count
{
  my ($self, $direction) = @_;
  return $self->DB->sqlSelect("count(*)","vote","vote_id=".$self->node_id." and weight=$direction");
}

sub parent
{
  my ($self) = @_;

  return $self->APP->node_by_id($self->NODEDATA->{parent_e2node}) || Everything::Node::null->new;
}

sub writeuptype
{
  my ($self) = @_;

  if(defined($self->NODEDATA->{wrtype_writeuptype}))
  {
    if(my $writeuptype = $self->APP->node_by_id($self->NODEDATA->{wrtype_writeuptype}))
    {
      return $writeuptype->title;
    }
  }
  return;
}

sub publishtime
{
  my ($self) = @_;
  return $self->NODEDATA->{publishtime};
}

sub canonical_url
{
  my ($self) = @_;
  return "/user/".$self->author->uri_safe_title."/writeups/".$self->parent->uri_safe_title;
}

sub notnew
{
  my ($self) = @_;
  return int($self->NODEDATA->{notnew} || 0);
}

sub is_junk
{
  my ($self) = @_;

  return ($self->reputation < $self->CONF->writeuplowrepthreshold) || 0;
}

sub is_log
{
  my ($self) = @_;

  return ($self->title =~ /^((January|February|March|April|May|June|July|August|September|October|November|December) [[:digit:]]{1,2}, [[:digit:]]{4})|(dream|editor|root) Log: /i) || 0;
}

sub field_whitelist
{
  return ["doctext","parent_e2node","wrtype_writeuptype","notnew"];
}

sub new_writeups_reference
{
  my ($self) = @_;

  my $outdata = {};

  foreach my $key (qw|author parent|)
  {
    unless(UNIVERSAL::isa($self->$key, "Everything::Node::null"))
    {
      $outdata->{$key} = $self->$key->json_reference;
    }
  }

  foreach my $key (qw|title notnew node_id is_junk is_log writeuptype|)
  {
    $outdata->{$key} = $self->$key;
  }

  return $outdata;
}

around 'insert' => sub {
 my ($orig, $self, $user, $data) = @_;

 my $newnode = $self->$orig($user, $data);

 # TODO: better superuser insert
 my $root = $self->APP->node_by_name("root","user");
 my $parent = $newnode->parent;
 $parent->group_add([$newnode->node_id], $root);
 $parent->update($root);

 return $newnode;
};

__PACKAGE__->meta->make_immutable;
1;

package Everything::Node::writeup;

use Moose;
extends 'Everything::Node::document';

override 'json_display' => sub
{
  my ($self, $user) = @_;
  return $self->single_writeup_display($user);
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

  $values->{author} = $self->author->json_reference;
  return $values if $user->is_guest;

  my $vote = $self->user_has_voted($user);

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

__PACKAGE__->meta->make_immutable;
1;

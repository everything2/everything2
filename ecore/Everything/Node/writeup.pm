package Everything::Node::writeup;

use Moose;
extends 'Everything::Node::document';

override 'json_display' => sub
{
  my ($self) = @_;
  my $values = super();

  my $cools = $self->cools;
  if(scalar(@$cools) > 0)
  {
    $values->{cools} = $cools;
  }

  $values->{author} = $self->author->json_reference;

  return $values;
};

sub voting_display
{
  my ($self, $user) = @_;

  my $display = $self->json_display;
  return $display if $user->is_guest;

  if(my $vote = $self->user_has_voted($user))
  {
    $display->{reputation} = $self->reputation;
    $display->{vote} = int($vote->{weight}); 
  }

  return $display;
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

__PACKAGE__->meta->make_immutable;
1;

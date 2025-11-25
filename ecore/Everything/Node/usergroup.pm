package Everything::Node::usergroup;

use Moose;
extends 'Everything::Node::document';
with 'Everything::Node::helper::group';

override 'json_display' => sub
{
  my ($self) = @_;
  my $values = super();

  my $group = [];

  foreach my $user (@{$self->group})
  {
    push @$group,$user->json_reference;
  }

  if(scalar(@$group) > 0)
  {
    $values->{group} = $group;
  }

  return $values;
};


sub deliver_message
{
  my ($self, $messagedata) = @_;

  $messagedata->{recurse_counter} ||= 0;
  $messagedata->{recurse_counter}++;
  if($messagedata->{recurse_counter} > 100)
  {
    return {"errors" => 1, "errortext" => ["Recursion limit reached"]};
  }

  # Check if sender is member of usergroup
  my $sender_hash = ref($messagedata->{from}) ? $messagedata->{from}->NODEDATA : $messagedata->{from};
  unless ($self->APP->inUsergroup($sender_hash, $self->NODEDATA)) {
    return {"errors" => 1, "errortext" => ["You are not a member of ".$self->title]};
  }

  # Set for_usergroup field so replies work correctly
  $messagedata->{for_usergroup} = $self->node_id;

  my $responses = {};

  # Get list of users ignoring this usergroup
  my $csr = $self->DB->sqlSelectMany('messageignore_id', 'messageignore',
    'ignore_node='.$self->node_id);
  my %ignores = ();
  while (my ($ig) = $csr->fetchrow) {
    $ignores{$ig} = 1;
  }
  $csr->finish;

  foreach my $groupmember (@{$self->group || []})
  {
    # Skip users who are ignoring this usergroup
    next if $ignores{$groupmember->node_id};

    if($groupmember->can("deliver_message"))
    {
      my $response = $groupmember->deliver_message($messagedata);

      foreach my $key("successes", "errors", "ignores")
      {
        $responses->{$key} ||= 0;
        $responses->{$key} += $response->{$key} || 0;
      }

      if($response->{errortext})
      {
        $responses->{errortext} ||= [];
        push @{$responses->{errortext}},$response->{errortext};
      }
    }
  }

  # Check if usergroup itself should get archive copy
  if ($self->APP->getParameter($self->node_id, 'allow_message_archive')) {
    my $author_id = ref($messagedata->{from}) ? $messagedata->{from}->node_id : $messagedata->{from}{node_id};
    $self->DB->sqlInsert('message', {
      msgtext => $messagedata->{message},
      author_user => $author_id,
      for_user => $self->node_id,
      for_usergroup => $self->node_id,
      archive => 0
    });
  }

  return $responses;
}


__PACKAGE__->meta->make_immutable;
1;

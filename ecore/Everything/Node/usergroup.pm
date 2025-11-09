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

  my $responses = {};

  foreach my $groupmember (@{$self->group || []})
  {
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

  return $responses;
}


__PACKAGE__->meta->make_immutable;
1;

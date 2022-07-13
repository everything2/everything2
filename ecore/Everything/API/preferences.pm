
package Everything::API::preferences;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

has 'allowed_preferences' => (isa => 'HashRef', is => 'ro', default => sub { {
  'vit_hidemaint' => [0,1],
  'vit_hidenodeinfo' => [0,1],
  'vit_hideutil' => [0,1],
  'vit_hidelist' => [0,1],
  'vit_hidemisc' => [0,1]
}});

sub routes
{
  return {
  "set" => "set_preferences",
  "get" => "get_preferences",
  }
}

sub set_preferences
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;

  my $valid = 1;
  if(ref $data ne "HASH" or scalar(keys %$data) == 0)
  {
    return [$self->HTTP_BAD_REQUEST];
  }

  foreach my $key (keys %$data)
  {
    unless(defined($self->allowed_preferences->{$key}) and scalar(grep({"$data->{$key}" eq "$_"} @{$self->allowed_preferences->{$key}})) == 1)
    {
      $valid = 0;
    }
  }

  return [$self->HTTP_UNAUTHORIZED] if $valid == 0;

  foreach my $key (keys %$data)
  {
    $REQUEST->user->VARS->{$key} = $data->{$key};
  }
  $REQUEST->user->set_vars($REQUEST->user->VARS);

  return [$self->HTTP_OK, $self->current_preferences($REQUEST)];
}

sub get_preferences
{
  my ($self, $REQUEST) = @_;

  return [$self->HTTP_OK, $self->current_preferences($REQUEST)];
}

sub current_preferences
{
  my ($self, $REQUEST) = @_;

  my $vars = $REQUEST->user->VARS;

  my $result = {};
  foreach my $key (keys %{$self->allowed_preferences})
  {
    if(defined($vars->{$key}))
    {
      if($vars->{$key} eq " ")
      {
        $result->{$key} = 0;
      }else {
        $result->{$key} = $vars->{$key};
      }
    }else{
      $result->{$key} = 0;
    }
  }
  return $result;
}

around ['set_preferences'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

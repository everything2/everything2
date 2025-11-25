package Everything::API::preferences;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

use Everything::Preference::List;
use Everything::Preference::String;

## no critic (ProhibitBuiltinHomonyms)

has 'allowed_preferences' => (isa => 'HashRef', is => 'ro', default => sub { {
  'vit_hidemaintenance' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidenodeinfo' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidenodeutil' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidelist' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidemisc' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'edn_hideutil' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'edn_hideedev' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'nw_nojunk' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'num_newwus' => Everything::Preference::List->new(default_value => 15, allowed_values => [1,5,10,15,20,25,30,40]),
  'collapsedNodelets' => Everything::Preference::String->new(default_value => '', allowed_values => qr/.?/),
  'nodetrail' => Everything::Preference::String->new(default_value => '', allowed_values => qr/.?/)
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
    if(defined($self->allowed_preferences->{$key}))
    {
      $valid = $self->allowed_preferences->{$key}->validate($data->{$key});
    }else{
      $valid = 0;
    }

    last if $valid == 0;
  }

  return [$self->HTTP_UNAUTHORIZED] if $valid == 0;

  foreach my $key (keys %$data)
  {
    if($self->allowed_preferences->{$key}->should_delete($data->{$key}))
    {
      delete $REQUEST->user->VARS->{$key};
    }else{
      $REQUEST->user->VARS->{$key} = $data->{$key};
    }
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
      if($self->allowed_preferences->{$key}->validate($vars->{$key}))
      {
        $result->{$key} = $vars->{$key};
        next;
      }
    }

    $result->{$key} = $self->allowed_preferences->{$key}->default_value;
  }
  return $result;
}

around ['set_preferences'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;

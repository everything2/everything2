package Everything::Page::silver_trinkets;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub display
{
  my ($self, $REQUEST) = @_;

  my $for_user = undef;
  my $error = undef;

  my $other_user = scalar($REQUEST->param("gtuser"));

  if(defined($other_user))
  {
    if($REQUEST->user->is_admin)
    {
      $for_user = $self->APP->node_by_name($other_user,'user');
      if(not defined $for_user) {
        $error = "User not found";
      }
    }
  } else {
    $error = "No other user given";
  }

  return { for_user => $for_user, error => $error }
}

__PACKAGE__->meta->make_immutable;

1;

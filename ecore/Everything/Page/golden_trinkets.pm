package Everything::Page::golden_trinkets;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub display
{
  my ($self, $REQUEST) = @_;

  my $for_user = undef;
  my $error = undef;

  if($REQUEST->user->is_admin)
  {
    my $form_result = $self->validate_username($REQUEST);
    $for_user = $form_result->{result};
    $error = $form_result->{error};
    $error = $form_result->{message} if not defined $error;
  }

  return { for_user => $for_user, error => $error }
}


__PACKAGE__->meta->make_immutable;
1;

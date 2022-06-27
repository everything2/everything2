package Everything::Page::your_ignore_list;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub display
{
  my ($self, $REQUEST) = @_;

  my $for_user = undef;
  my $error = undef;

  if($REQUEST->user->is_admin || $REQUEST->user->is_chanop)
  {
    my $form_result = $self->validate_username($REQUEST);
    $for_user = $form_result->{result};
    $error = $form_result->{error};
    $error = $form_result->{message} if not defined $error;
  }

  if(not defined $for_user)
  {
    $for_user = $REQUEST->user
  }

  return { for_user => $for_user, error => $error };
}

__PACKAGE__->meta->make_immutable;

1;

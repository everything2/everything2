package Everything::Page::your_nodeshells;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub display
{
  my ($self, $REQUEST) = @_;

  my $for_user = undef;
  my $error = undef;

  my $form_result = $self->validate_username($REQUEST);
  $for_user = $form_result->{result};
  $error = $form_result->{error};

  if(not defined($for_user))
  {
    $for_user = $REQUEST->user;
  }


  return { for_user => $for_user, error => $error, nodeshells => $self->APP->get_user_nodeshells($for_user)}
}

__PACKAGE__->meta->make_immutable;

1;

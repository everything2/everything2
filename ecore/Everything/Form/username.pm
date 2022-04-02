package Everything::Form::username;

use Moose::Role;

sub validate_username
{
  my ($self, $REQUEST,$form_field) = @_;

  $form_field = "username" unless defined($form_field);

  my $result = scalar($REQUEST->param($form_field));
  my $message = undef;
  my $error = undef;

  if(defined($result))
  {
    $result = $self->APP->node_by_name($result,'user');
    if(not defined $result) {
      $error = "User not found";
      $result = undef;
    }
  } else {
    $message = "No other given";
  }

  return {error => $error, message => $message, result => $result};
}

1;

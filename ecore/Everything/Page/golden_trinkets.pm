package Everything::Page::golden_trinkets;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $for_user = undef;
  my $error = undef;

  # Admin user lookup
  if($user->is_admin)
  {
    my $form_result = $self->validate_username($REQUEST);
    $for_user = $form_result->{result};
    $error = $form_result->{error};
    $error = $form_result->{message} if not defined $error;
  }

  return {
    contentData => {
      type => 'golden_trinkets',
      karma => $user->karma,
      isAdmin => $user->is_admin ? 1 : 0,
      forUser => $for_user ? {
        username => $for_user->title,
        karma => $for_user->karma,
        node_id => $for_user->node_id
      } : undef,
      error => $error
    }
  };
}


__PACKAGE__->meta->make_immutable;
1;

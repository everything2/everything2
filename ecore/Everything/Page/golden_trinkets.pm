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

  # Return the fields flat: buildNodeInfoStructure already wraps buildReactData's return in
  # contentData (and adds type). Wrapping them in an extra { contentData => ... } here double-nested
  # everything under contentData.contentData, so GoldenTrinkets.js (which reads data.karma/forUser)
  # saw nothing and rendered an empty "karma 0" -- the page looked deprecated (#4516 sibling).
  return {
    type => 'golden_trinkets',
    karma => $user->karma,
    forUser => $for_user ? {
      username => $for_user->title,
      karma => $for_user->karma,
      node_id => $for_user->node_id
    } : undef,
    error => $error
  };
}


__PACKAGE__->meta->make_immutable;
1;

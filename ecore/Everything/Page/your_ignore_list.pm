package Everything::Page::your_ignore_list;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub buildReactData
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

  # Get the ignore lists (pass 1 for JSON-safe references)
  my $ignoring = $for_user->ignoring_messages_from(1);
  my $ignored_by = $for_user->messages_ignored_by(1);

  return {
    for_user => {
      node_id => $for_user->id,
      title => $for_user->title
    },
    error => $error,
    ignoring_messages_from => $ignoring,
    messages_ignored_by => $ignored_by
  };
}

__PACKAGE__->meta->make_immutable;

1;

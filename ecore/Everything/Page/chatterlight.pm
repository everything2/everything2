package Everything::Page::chatterlight;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;

  # Get pagenodelets for header (Notifications + Messages)
  my $notifications_id = $self->DB->getNode('Notifications', 'nodelet')->{node_id};
  my $messages_id = $self->DB->getNode('Messages', 'nodelet')->{node_id};
  my @pagenodelets = ();

  # Add Notifications if user has it in their nodelet list
  my $user_nodelets = $user->VARS->{nodelets} || '';
  if ($user_nodelets =~ /\b$notifications_id\b/) {
    push @pagenodelets, $notifications_id;
  }

  # Always add Messages for chatterlight
  push @pagenodelets, $messages_id;

  return {
    pagenodelets => \@pagenodelets
  };
}

__PACKAGE__->meta->make_immutable;

1;

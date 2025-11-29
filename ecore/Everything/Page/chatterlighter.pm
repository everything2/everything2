package Everything::Page::chatterlighter;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;

  # Get pagenodelets for header (Notifications + New Writeups + Messages)
  my $notifications_id = $self->DB->getNode('Notifications', 'nodelet')->{node_id};
  my $new_writeups_id = $self->DB->getNode('New Writeups', 'nodelet')->{node_id};
  my $messages_id = $self->DB->getNode('Messages', 'nodelet')->{node_id};
  my @pagenodelets = ($new_writeups_id);

  # Add Notifications if user has it in their nodelet list
  my $user_nodelets = $user->VARS->{nodelets} || '';
  if ($user_nodelets =~ /\b$notifications_id\b/) {
    unshift @pagenodelets, $notifications_id;
  }

  # Always add Messages for chatterlighter
  push @pagenodelets, $messages_id;

  return {
    pagenodelets => \@pagenodelets
  };
}

__PACKAGE__->meta->make_immutable;

1;

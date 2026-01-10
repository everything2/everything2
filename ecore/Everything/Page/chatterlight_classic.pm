package Everything::Page::chatterlight_classic;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Classic version - Messages only, no other nodelets
  my $messages_id = $self->DB->getNode('Messages', 'nodelet')->{node_id};

  return {
    standalone => \1,  # Full-screen layout without header/footer/sidebar
    pagenodelets => [$messages_id]
  };
}

__PACKAGE__->meta->make_immutable;

1;

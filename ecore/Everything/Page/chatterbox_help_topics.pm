package Everything::Page::chatterbox_help_topics;

use Moose;
extends 'Everything::Page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $helpuser = $self->APP->node_by_name('Virgil','user');
  my $helptopics = $self->APP->node_by_name('help topics','setting')->VARS;
  return {helpuser => $helpuser, helptopics => $helptopics};
}

__PACKAGE__->meta->make_immutable;

1;

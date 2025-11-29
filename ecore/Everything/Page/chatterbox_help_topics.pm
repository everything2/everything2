package Everything::Page::chatterbox_help_topics;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $helpuser = $self->APP->node_by_name('Virgil','user');
  my $helptopics = $self->APP->node_by_name('help topics','setting')->VARS;

  return {
    helpuser => {
      node_id => $helpuser->id,
      title => $helpuser->title
    },
    helptopics => $helptopics
  };
}

__PACKAGE__->meta->make_immutable;

1;

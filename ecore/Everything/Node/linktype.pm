package Everything::Node::linktype;
use Moose;
extends 'Everything::Node';

sub get_link
{
  my ($self, $from, $to) = @_;
 
  return unless defined($from) and defined($to);

  my $linkdata = $self->DB->sqlSelectHashref("*","links","to_node=".$to->node_id." and from_node=".$from->node_id." and linktype=".$self->node_id." limit 1");
  return unless defined($linkdata);
  return Everything::Link->new($linkdata);
}

sub any_link
{
  my ($self, $from) = @_;
  return unless defined($from);

  my $linkdata = $self->DB->sqlSelectHashref("*","links","from_node=".$from->node_id." and linktype=".$self->node_id." limit 1");
  return unless defined($linkdata);
  return Everything::Link->new($linkdata);
}

__PACKAGE__->meta->make_immutable;
1;

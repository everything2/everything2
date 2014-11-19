has 'text';
has 'link_to_node';
has 'escape_tags';

sub main {
  my $self = shift;
  $m->print($self->text);
} 

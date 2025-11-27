package Everything::Page::everything_s_obscure_writeups;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $nodes = $self->APP->obscure_writeups;

  # Convert blessed node objects to simple data structures
  my @writeups;
  foreach my $node (@$nodes) {
    my $parent = $node->parent;
    my $author = $node->author;

    # Skip nodes with missing data
    next unless $parent && ref($parent) ne 'Everything::Node::null';
    next unless $author && ref($author) ne 'Everything::Node::null';

    push @writeups, {
      node_id => $node->node_id,
      title => $node->title,
      parent_title => $parent->title,
      author => $author->title,
      author_id => $author->node_id,
      createtime => $node->createtime
    };
  }

  return {
    type => 'everything_s_obscure_writeups',
    writeups => \@writeups
  };
}

__PACKAGE__->meta->make_immutable;

1;

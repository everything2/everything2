package Everything::Controller::page;

use Moose;
extends 'Everything::Controller';

use Everything::Page::_unimplemented;

# Lazy-loaded fallback page for unimplemented pages
has '_unimplemented_page' => (
  is => 'ro',
  lazy => 1,
  builder => '_build_unimplemented_page'
);

sub _build_unimplemented_page {
  return Everything::Page::_unimplemented->new;
}

sub page_delegate
{
  my ($self, $REQUEST, $node) = @_;

  return $self->page_class($node)->display($REQUEST, $node);
}

sub page_class
{
  my ($self, $node, $htmlpage) = @_;
  my $page_class = $self->PAGE_TABLE->{$self->title_to_page($node->title)};

  # If no Page class exists, use the fallback
  unless ($page_class) {
    my $fallback = $self->_unimplemented_page;
    $fallback->htmlpage($htmlpage) if $htmlpage;
    return $fallback;
  }

  return $page_class;
}
__PACKAGE__->meta->make_immutable();
1;

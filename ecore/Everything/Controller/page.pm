package Everything::Controller::page;
  
use Moose;
extends 'Everything::Controller';

has 'login_link' => (isa => "Str", is => 'ro', default => '/?node=Login');

sub fully_supports
{
  my ($self, $page) = @_;
  return 1 if $self->page_exists($page);
  return;
}

# TODO: Always make sure this returns the same data struct
# fullpage - Currently raw text
# superdoc and other "real" controllers - Hashref

sub page_delegate
{
  my ($self, $REQUEST, $node) = @_;
  return $self->page_class($node)->display($REQUEST, $node);
}

sub page_class
{
  my ($self, $node) = @_;
  return $self->PAGE_TABLE->{$self->title_to_page($node->title)};
}
__PACKAGE__->meta->make_immutable();
1;

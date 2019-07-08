package Everything::Controller::superdoc;

use Moose;
extends 'Everything::Controller::page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $permission_result = $self->page_class($node)->check_permission($REQUEST, $node);

  if($permission_result->allowed)
  {
    $self->devLog("Page permission allowed: ".(ref $permission_result));
    my $controller_output = $self->page_class($node)->display($REQUEST, $node);
    my $html = $self->layout('/pages/'.$self->title_to_page($node->title), %$controller_output, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK,$html];
  } else {
    $self->devLog("Page permission not allowed");
    return [$self->HTTP_FOUND, '', {'Location' => $permission_result->redirect}];
  }
}

__PACKAGE__->meta->make_immutable();
1;

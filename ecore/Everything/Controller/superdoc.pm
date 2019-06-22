package Everything::Controller::superdoc;

use Moose;
extends 'Everything::Controller::page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  if(!$self->page_class($node)->guest_allowed and $REQUEST->user->is_guest)
  {
    return [$self->HTTP_FOUND,'', {location => $self->login_link}]
  }else{
    my $controller_output = $self->page_class($node)->display($REQUEST, $node);
    my $html = $self->layout('/pages/'.$self->title_to_page($node->title), %$controller_output, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK,$html];
  }
}

__PACKAGE__->meta->make_immutable();
1;
